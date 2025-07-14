import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class XsensService {
  static const MethodChannel _channel = MethodChannel('xsens');
  static final Map<String, String> sensorTags = {};

  // ➊ Stream de sensores encontrados
  static final _sensorStreamController =
      StreamController<Map<String, String>>.broadcast();
  static Stream<Map<String, String>> get sensorStream =>
      _sensorStreamController.stream;

  // ➋ Stream de estado de conexión
  static final _connectionStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get connectionStatusStream =>
      _connectionStatusController.stream;

  // ➌ Stream de datos “onSensorData”
  static final _sensorDataController =
      StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get sensorDataStream =>
      _sensorDataController.stream;

  /// Solicita permisos Bluetooth / ubicación
  static Future<void> requestBluetoothScanPermission() async {
    if (Platform.isAndroid) {
      if (await Permission.bluetoothScan.request().isDenied ||
          await Permission.bluetoothConnect.request().isDenied ||
          await Permission.location.request().isDenied) {
        throw Exception("Permisos de Bluetooth necesarios no concedidos.");
      }
    }
  }

  /// Inicia el escaneo
  static Future<void> startScan() async {
    await _channel.invokeMethod('scanSensors');
  }

  /// Conecta con un sensor (dart → nativo)
  static Future<void> connectToSensor(String sensorId) async {
    await _channel.invokeMethod('connectToSensor', {'id': sensorId});
  }

  /// Desconecta un sensor
  static Future<void> disconnectFromSensor(String sensorId) async {
    await _channel.invokeMethod('disconnectFromSensor', {'id': sensorId});
  }

  /// Instruye al nativo para arrancar la medida en todos los sensores conectados
  static Future<void> startMeasuring() async {
    await _channel.invokeMethod('startMeasuring');
  }

  /// Instruye al nativo para parar la medida
  static Future<void> stopMeasuring() async {
    await _channel.invokeMethod('stopMeasuring');
  }

  /// Inicializa el canal y gestiona los callbacks nativos
  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      print('Método recibido en Dart: ${call.method}');
      switch (call.method) {
        case 'onSensorFound':
          final sensor = Map<String, String>.from(call.arguments);
          _sensorStreamController.add(sensor);
          break;
        case 'onSensorConnected':
          _connectionStatusController
              .add({'address': call.arguments, 'connected': true});
          break;
        case 'onSensorDisconnected':
          _connectionStatusController
              .add({'address': call.arguments, 'connected': false});
          break;
        case 'onSensorData':
          final data = Map<String, dynamic>.from(call.arguments);
          _sensorDataController.add(data);
          break;
        case 'onSensorTagChanged':
          final tagData = Map<String, String>.from(call.arguments);
          // Actualiza el nombre del sensor en vivo
          _sensorStreamController.add({
            'address': tagData['address'] ?? '',
            'name': tagData['tag'] ?? '',
          });
          final address = tagData['address'] as String;
          final tag = tagData['tag'] as String;
          sensorTags[address] = tag;
          break;
        case 'onConnectionChanged':
          final conn = Map<String, dynamic>.from(call.arguments);
          _connectionStatusController.add(conn);
          break;

      }
    });
  }
}
