package com.example.xsense_demo

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothProfile
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.ActivityCompat
import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.xsens.dot.android.sdk.interfaces.XsensDotScannerCallback
import com.xsens.dot.android.sdk.interfaces.XsensDotDeviceCallback
import com.xsens.dot.android.sdk.models.XsensDotDevice
import com.xsens.dot.android.sdk.utils.XsensDotScanner
import com.xsens.dot.android.sdk.XsensDotSdk
import com.xsens.dot.android.sdk.events.XsensDotData
import com.xsens.dot.android.sdk.models.FilterProfileInfo
import com.xsens.dot.android.sdk.models.XsensDotPayload

class MainActivity : FlutterActivity(), XsensDotScannerCallback, XsensDotDeviceCallback {

    private val CHANNEL = "xsens"
    private lateinit var methodChannel: MethodChannel
    private lateinit var scanner: XsensDotScanner

    private val foundDevices = mutableListOf<Map<String, String>>()
    private val devicesMap = mutableMapOf<String, BluetoothDevice>()
    private val connectedDevices = mutableMapOf<String, XsensDotDevice>()

    private var mIsMeasuring = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  ─── Pedir permisos Bluetooth en tiempo de ejecución (Android 12+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val permissions = arrayOf(
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_SCAN
            )
            val missingPermissions = permissions.filter {
                ActivityCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
            }
            if (missingPermissions.isNotEmpty()) {
                ActivityCompat.requestPermissions(this, missingPermissions.toTypedArray(), 1)
            }
        }

        //  ─── Inicializar el SDK y configurar el escáner
        XsensDotSdk.setDebugEnabled(true)
        XsensDotSdk.setReconnectEnabled(true)
        scanner = XsensDotScanner(applicationContext, this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        methodChannel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    // ─── “scanSensors”: arrancar BLE scan y devolver la lista tras 3 s
                    "scanSensors" -> {
                        foundDevices.clear()
                        devicesMap.clear()
                        scanner.startScan()
                        Handler(Looper.getMainLooper()).postDelayed({
                            Log.d("XSENS", "Dispositivos encontrados (nativo): $foundDevices")
                            result.success(foundDevices)
                            scanner.stopScan()
                        }, 3000L)
                    }

                    // ─── “connectToSensor”: instanciar XsensDotDevice y conectar
                    "connectToSensor" -> {
                        val id = call.argument<String>("id")
                        val device = devicesMap[id]
                        if (device != null) {
                            val xsens = XsensDotDevice(applicationContext, device, this)
                            connectedDevices[id!!] = xsens
                            xsens.connect()
                            result.success(true)
                        } else {
                            result.error("NOT_FOUND", "Sensor no encontrado", null)
                        }
                    }

                    // ─── “disconnectFromSensor”: desconectar y quitar del mapa
                    "disconnectFromSensor" -> {
                        val id = call.argument<String>("id")
                        connectedDevices[id]?.disconnect()
                        connectedDevices.remove(id)
                        result.success(true)
                    }

                    // ─── “movella_measurementStatus”: devuelve si está midiendo o no
                    "movella_measurementStatus" -> {
                        result.success(mIsMeasuring)
                    }

                    // ─── “startMeasuring”: poner modo + startMeasuring en cada dispositivo conectado
                    "startMeasuring" -> {
                        if (connectedDevices.isNotEmpty()) {
                            for ((_, sensorDevice) in connectedDevices) {
                                // Muy importante: fijar un modo de medida válido antes de startMeasuring()
                                sensorDevice.setMeasurementMode(XsensDotPayload.PAYLOAD_TYPE_CUSTOM_MODE_4)
                                sensorDevice.startMeasuring()
                            }
                            mIsMeasuring = true
                            result.success(true)
                        } else {
                            result.error("ERROR", "No hay dispositivos conectados", null)
                        }
                    }

                    // ─── “stopMeasuring”: stopMeasuring en todos
                    "movella_measurementStop" -> {
                        for ((_, sensorDevice) in connectedDevices) {
                            sensorDevice.stopMeasuring()
                        }
                        mIsMeasuring = false
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("ERROR", "Error nativo: ${e.message}", null)
            }
        }
    }

    // ─── Cuando el escáner encuentra un sensor
    override fun onXsensDotScanned(device: BluetoothDevice, rssi: Int) {
        val address = device.address
        val name = device.name ?: "Sin nombre"
        if (!devicesMap.containsKey(address)) {
            devicesMap[address] = device
            val deviceMap = mapOf("address" to address, "name" to name)
            foundDevices.add(deviceMap)

            // Enviar inmediatamente a Flutter
            runOnUiThread {
                methodChannel.invokeMethod("onSensorFound", deviceMap)
            }
            Log.d("XSENS", "Dispositivo detectado: $address ($name)")
        }
    }

    // ─── Cambio de estado de conexión Bluetooth GATT
    override fun onXsensDotConnectionChanged(address: String, status: Int) {
        val statusStr = when (status) {
            XsensDotDevice.CONN_STATE_CONNECTED -> {
                Log.d("XSENS", "Conectado: $address")
                runOnUiThread { methodChannel.invokeMethod("onSensorConnected", address) }
                "connected"
            }
            XsensDotDevice.CONN_STATE_DISCONNECTED -> {
                Log.d("XSENS", "Desconectado: $address")
                runOnUiThread { methodChannel.invokeMethod("onSensorDisconnected", address) }
                "disconnected"
            }
            XsensDotDevice.CONN_STATE_CONNECTING -> {
                Log.d("XSENS", "Conectando: $address")
                "connecting"
            }
            else -> {
                Log.d("XSENS", "Estado desconocido: $address ($status)")
                "unknown"
            }
        }

        // También mandamos un evento genérico “onConnectionChanged” con dirección y booleano
        runOnUiThread {
            methodChannel.invokeMethod("onConnectionChanged", mapOf(
                "address" to address,
                "connected" to (status == XsensDotDevice.CONN_STATE_CONNECTED)
            ))
        }
    }

    // ─── Cuando se completa inicialización de servicios GATT
    override fun onXsensDotServicesDiscovered(address: String, status: Int) {
        if (status == android.bluetooth.BluetoothGatt.GATT_SUCCESS) {
            Log.d("XSENS", "Servicios descubiertos: $address")
        }
    }

    override fun onXsensDotInitDone(address: String) {
        Log.d("XSENS", "Inicialización completada: $address")
    }

    override fun onXsensDotFirmwareVersionRead(address: String, version: String) { }

    override fun onXsensDotGetFilterProfileInfo(address: String, filterProfiles: ArrayList<FilterProfileInfo>) { }

    override fun onXsensDotTagChanged(address: String, tag: String) {
        Log.d("XSENS", "Tag actualizado: $address -> $tag")
        runOnUiThread {
            methodChannel.invokeMethod("onSensorTagChanged", mapOf(
                "address" to address,
                "tag" to tag
            ))
        }
    }

    override fun onXsensDotBatteryChanged(address: String, batteryLevel: Int, chargingStatus: Int) { }

    override fun onXsensDotButtonClicked(address: String, timestamp: Long) { }

    override fun onXsensDotPowerSavingTriggered(address: String) { }

    override fun onReadRemoteRssi(address: String, rssi: Int) { }

    override fun onXsensDotOutputRateUpdate(address: String, outputRate: Int) { }

    override fun onXsensDotFilterProfileUpdate(address: String, parameter: Int) { }

    override fun onSyncStatusUpdate(address: String, syncStatus: Boolean) { }

   override fun onXsensDotDataChanged(address: String, data: XsensDotData) {
        // Aceleración libre (sin gravedad) (m/s²)
        val freeAcc = data.getCalFreeAcc()

        // Velocidad angular (deg/s)
        val gyr = data.getGyr().map { it.toFloat() }.toFloatArray()

        // Campo magnético (a.u.)
        val mag = data.getMag() // Ya es FloatArray

        // Orientación (quaternion → Euler)
        val quat = data.getQuat() // FloatArray con 4 elementos: qx, qy, qz, qw

        // Conversión a ángulos de Euler
        val euler = quaternionToEuler(quat)

        // Angulo de inclinación respecto el plano horizontal
        val inclinationAngle = computeInclinationAngleFromQuat(quat)


        // Calcula magnitud total del giro
        val gyrMag = Math.sqrt(
            (gyr[0] * gyr[0] + gyr[1] * gyr[1] + gyr[2] * gyr[2]).toDouble()
        )

        // Map para enviar a Flutter
        val sensorData = mapOf<String, Any>(
            "address" to address,
            // Aceleración libre
            "freeAccX" to freeAcc[0].toDouble(),
            "freeAccY" to freeAcc[1].toDouble(),
            "freeAccZ" to freeAcc[2].toDouble(),
            // Giroscopio
            "gyrX" to gyr[0],
            "gyrY" to gyr[1],
            "gyrZ" to gyr[2],
            "gyrMag" to gyrMag,
            // Magnetómetro
            //"magX" to mag[0].toDouble(),
            //"magY" to mag[1].toDouble(),
            //"magZ" to mag[2].toDouble(),
            // Orientación (Euler angles)
            //"yaw"   to euler[0],
            //"pitch" to euler[1],
            //"roll"  to euler[2]
            // Enviar los cuaterniones directamente
            //"quatX" to quat[0].toDouble(),
            //"quatY" to quat[1].toDouble(),
            //"quatZ" to quat[2].toDouble(),
            //"quatW" to quat[3].toDouble(),
            "inclinationAngle" to inclinationAngle

        )

        // Envía los datos a Flutter
        runOnUiThread {
            methodChannel.invokeMethod("onSensorData", sensorData)
        }
    }

}
fun quaternionToEuler(q: FloatArray): DoubleArray {
    val qw = q[3].toDouble()
    val qx = q[0].toDouble()
    val qy = q[1].toDouble()
    val qz = q[2].toDouble()

    val yaw = Math.atan2(2.0 * (qw * qz + qx * qy), 1.0 - 2.0 * (qy * qy + qz * qz)) * 180 / Math.PI
    val pitch = Math.asin(2.0 * (2.0 * (qw * qy - qz * qx)).coerceIn(-1.0, 1.0)) * 180 / Math.PI
    val roll = Math.atan2(2.0 * (qw * qx + qy * qz), 1.0 - 2.0 * (qx * qx + qy * qy)) * 180 / Math.PI

    return doubleArrayOf(yaw, pitch, roll)
}
fun quaternionToRotationMatrix(q: FloatArray): Array<DoubleArray> {
    val qw = q[3].toDouble()
    val qx = q[0].toDouble()
    val qy = q[1].toDouble()
    val qz = q[2].toDouble()

    return arrayOf(
        doubleArrayOf(
            qw*qw + qx*qx - qy*qy - qz*qz,
            2.0 * (qx*qy - qw*qz),
            2.0 * (qx*qz + qw*qy)
        ),
        doubleArrayOf(
            2.0 * (qx*qy + qw*qz),
            qw*qw - qx*qx + qy*qy - qz*qz,
            2.0 * (qy*qz - qw*qx)
        ),
        doubleArrayOf(
            2.0 * (qx*qz - qw*qy),
            2.0 * (qy*qz + qw*qx),
            qw*qw - qx*qx - qy*qy + qz*qz
        )
    )
}
fun computeInclinationAngleFromQuat(q: FloatArray): Double {
    val qw = q[3].toDouble()
    val qx = q[0].toDouble()
    val qy = q[1].toDouble()
    val qz = q[2].toDouble()

    // R[2][0] = 2*(qx*qz - qw*qy)
    val R_31 = 2.0 * (qx * qz - qw * qy)

    // Asegurar dominio válido [-1, 1]
    val angle = -(Math.acos(R_31.coerceIn(-1.0, 1.0)) * 180.0 / Math.PI - 90.0)

    return angle
}



