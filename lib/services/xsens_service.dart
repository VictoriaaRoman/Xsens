import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class XsensService {
  static const MethodChannel _channel = MethodChannel('xsens');

  // Stream de sensores encontrados
  static final _sensorStreamController = StreamController<Map<String, String>>.broadcast();
  static Stream<Map<String, String>> get sensorStream => _sensorStreamController.stream;

  // Stream de estado de conexión (conectado / desconectado)
  static final _connectionStatusController = StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get connectionStatusStream => _connectionStatusController.stream;

  /// Solicita permisos necesarios para escanear y conectar
  static Future<void> requestBluetoothScanPermission() async {
    if (Platform.isAndroid) {
      if (await Permission.bluetoothScan.request().isDenied ||
          await Permission.bluetoothConnect.request().isDenied ||
          await Permission.location.request().isDenied) {
        throw Exception("Permisos de Bluetooth necesarios no concedidos.");
      }
    }
  }

  /// Inicia el escaneo de sensores
  static Future<void> startScan() async {
    await _channel.invokeMethod('scanSensors');
  }

  /// Conecta con un sensor por ID
  static Future<void> connectToSensor(String sensorId) async {
    await _channel.invokeMethod('connectToSensor', {'id': sensorId});
  }

  /// Desconecta un sensor por ID
  static Future<void> disconnectFromSensor(String sensorId) async {
    await _channel.invokeMethod('disconnectFromSensor', {'id': sensorId});
  }

  /// Inicializa el canal de comunicación con el lado nativo
  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onSensorFound':
          final sensor = Map<String, String>.from(call.arguments);
          _sensorStreamController.add(sensor);
          break;
        case 'onSensorConnected':
          _connectionStatusController.add({
            'address': call.arguments,
            'connected': true,
          });
          break;
        case 'onSensorDisconnected':
          _connectionStatusController.add({
            'address': call.arguments,
            'connected': false,
          });
          break;
      }
    });
  }
}
