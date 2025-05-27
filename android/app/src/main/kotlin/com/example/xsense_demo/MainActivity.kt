package com.example.xsense_demo

import android.bluetooth.BluetoothDevice
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import android.Manifest
import android.os.Build
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat

import com.xsens.dot.android.sdk.interfaces.XsensDotScannerCallback
import com.xsens.dot.android.sdk.interfaces.XsensDotDeviceCallback
import com.xsens.dot.android.sdk.models.XsensDotDevice
import com.xsens.dot.android.sdk.utils.XsensDotScanner
import com.xsens.dot.android.sdk.XsensDotSdk
import com.xsens.dot.android.sdk.events.XsensDotData
import com.xsens.dot.android.sdk.models.FilterProfileInfo

class MainActivity : FlutterActivity(), XsensDotScannerCallback, XsensDotDeviceCallback {

    private val CHANNEL = "xsens"
    private lateinit var methodChannel: MethodChannel
    private lateinit var scanner: XsensDotScanner
    private val foundDevices = mutableListOf<Map<String, String>>() // Siempre inicializado
    private val devicesMap = mutableMapOf<String, BluetoothDevice>()
    private var xsensDevice: XsensDotDevice? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // PEDIR PERMISOS EN TIEMPO DE EJECUCIÓN
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

        // Inicializa el SDK
        XsensDotSdk.setDebugEnabled(true)
        XsensDotSdk.setReconnectEnabled(true)

        // Instancia del escáner con esta actividad como callback
        scanner = XsensDotScanner(applicationContext, this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        methodChannel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "scanSensors" -> {
                        foundDevices.clear()
                        devicesMap.clear()
                        scanner.startScan()

                        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                            Log.d("XSENS", "Dispositivos encontrados (nativo): $foundDevices")
                            result.success(foundDevices)
                            scanner.stopScan()
                        }, 3000)
                    }

                    "connectToSensor" -> {
                        val id = call.argument<String>("id")
                        val device = devicesMap[id]
                        if (device != null) {
                            xsensDevice = XsensDotDevice(applicationContext, device, this)
                            xsensDevice?.connect()
                            result.success(true)
                        } else {
                            result.error("NOT_FOUND", "Sensor no encontrado", null)
                        }
                    }
                    
                    "disconnectFromSensor" -> {
                        val id = call.argument<String>("id")
                        if (id != null && xsensDevice != null && xsensDevice!!.address == id) {
                            xsensDevice?.disconnect()
                            result.success(true)
                        } else {
                            result.error("NOT_FOUND", "Sensor no conectado", null)
                        }
                    }

                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("ERROR", "Error en el lado nativo: ${e.message}", null)
            }
        }
    }


    //Esto envía un Map<String, String> a Flutter cuando se encuentra un nuevo dispositivo.
    override fun onXsensDotScanned(device: BluetoothDevice, rssi: Int) {
        val address = device.address
        val name = device.name ?: "Sin nombre"
        if (!devicesMap.containsKey(address)) {
            devicesMap[address] = device
            val deviceMap = mapOf("address" to address, "name" to name)
            foundDevices.add(deviceMap)

            // Envía el dispositivo a Flutter en tiempo real
            MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger ?: return, CHANNEL)
                .invokeMethod("onSensorFound", deviceMap)

            Log.d("XSENS", "Dispositivo detectado: $address ($name)")
        }
    }


    // --- Callbacks del Dispositivo ---
    override fun onXsensDotConnectionChanged(address: String, status: Int) {
        val methodChannel = MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger ?: return, "xsens")

        val statusStr = when (status) {
            XsensDotDevice.CONN_STATE_CONNECTED -> {
                Log.d("XSENS", "Conectado: $address")
                methodChannel.invokeMethod("onSensorConnected", address)
                "connected"
            }
            XsensDotDevice.CONN_STATE_DISCONNECTED -> {
                Log.d("XSENS", "Desconectado: $address")
                methodChannel.invokeMethod("onSensorDisconnected", address)
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

        // Si deseas mandar también el estado como string genérico
        methodChannel.invokeMethod("onConnectionChanged", mapOf(
            "address" to address,
            "status" to statusStr
        ))
    }


    override fun onXsensDotServicesDiscovered(address: String, status: Int) {
        if (status == android.bluetooth.BluetoothGatt.GATT_SUCCESS) {
            Log.d("XSENS", "Servicios descubiertos: $address")
        }
    }

    override fun onXsensDotInitDone(address: String) {
        Log.d("XSENS", "Inicialización completada: $address")
    }

    override fun onXsensDotFirmwareVersionRead(address: String, version: String) {
        Log.d("XSENS", "Firmware de $address: $version")
    }

    // Métodos requeridos por la interfaz que no estás usando, pero deben estar presentes:
    // Callbacks requeridos
    override fun onXsensDotGetFilterProfileInfo(
        address: String,
        filterProfiles: ArrayList<FilterProfileInfo>
    ) {}

    override fun onXsensDotDataChanged(
        address: String,
        data: XsensDotData
    ) {}

    override fun onXsensDotTagChanged(address: String, tag: String) {
        // Puedes dejarlo vacío si no lo necesitas
    }

    override fun onXsensDotBatteryChanged(address: String, batteryLevel: Int, chargingStatus: Int) {
        // Puedes dejarlo vacío si no necesitas manejar el evento de batería
    }

    override fun onXsensDotButtonClicked(address: String, timestamp: Long) {
        // Puedes dejarlo vacío si no necesitas manejar el evento del botón
    }

    override fun onXsensDotPowerSavingTriggered(address: String) {
        // Puedes dejarlo vacío si no necesitas manejar este evento
        Log.d("XSENS", "Modo de ahorro de energía activado para el dispositivo: $address")
    }
    
    override fun onReadRemoteRssi(address: String, rssi: Int) {
        // Puedes dejarlo vacío si no necesitas manejar este evento
        Log.d("XSENS", "RSSI leído para el dispositivo $address: $rssi")
    }

    override fun onXsensDotOutputRateUpdate(address: String, outputRate: Int) {
        // Puedes dejarlo vacío si no necesitas manejar este evento
        Log.d("XSENS", "Tasa de salida actualizada para el dispositivo $address: $outputRate Hz")
    }

    override fun onXsensDotFilterProfileUpdate(address: String, parameter: Int) {
        // Puedes dejarlo vacío si no lo necesitas, o registrar el evento:
        Log.d("XSENS", "Filter profile updated for device $address: parameter = $parameter")
    }

    override fun onSyncStatusUpdate(address: String, syncStatus: Boolean) {
        // Puedes dejarlo vacío o registrar el evento
        Log.d("XSENS", "Sync status for $address updated: $syncStatus")
    }
}
