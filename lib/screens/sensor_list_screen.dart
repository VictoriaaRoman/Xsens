import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/xsens_service.dart';

class SensorListScreen extends StatefulWidget {
  const SensorListScreen({super.key});

  @override
  State<SensorListScreen> createState() => _SensorListScreenState();
}

class _SensorListScreenState extends State<SensorListScreen> {
  List<Map<String, String>> sensors = [];
  Map<String, bool> connectionStatus = {};
  bool loading = false;

  @override
  void initState() {
    super.initState();
    XsensService.initialize();
    _listenToSensorStream();

    XsensService.connectionStatusStream.listen((event) {
      final address = event['address'] as String;
      final connected = event['connected'] as bool;

      setState(() {
        connectionStatus[address] = connected;
      });
    });
    _startScanning();
  }


  void _listenToSensorStream() {
    XsensService.sensorStream.listen((sensor) {
      if (!sensors.any((s) => s['address'] == sensor['address'])) {
        setState(() {
          sensors.add(sensor);
        });
      }
    });
  }

  void _startScanning() async {
    await XsensService.requestBluetoothScanPermission();
    await XsensService.startScan();
  }


  Future<void> _connectToSensor(String sensorId) async {
    try {
      await XsensService.connectToSensor(sensorId);
      setState(() {
        connectionStatus[sensorId] = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Conectado a $sensorId')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al conectar: $e')),
      );
    }
  }

/*
  static void listenConnectionEvents(
      Function(String) onConnected, Function(String) onDisconnected) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSensorConnected') {
        onConnected(call.arguments as String);
      } else if (call.method == 'onSensorDisconnected') {
        onDisconnected(call.arguments as String);
      }
    });
  }
*/
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sensores disponibles')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
            itemCount: sensors.length,
            itemBuilder: (context, index) {
              final sensor = sensors[index];
              final address = sensor['address'] ?? '';
              final isConnected = connectionStatus[address] ?? false;

              return ListTile(
                title: Text(sensor['name'] ?? 'Sin nombre'),
                subtitle: Text(address),
                trailing: Switch(
                  value: isConnected,
                  onChanged: (value) async {
                    if (value) {
                      await _connectToSensor(address);
                    } else {
                      await XsensService.disconnectFromSensor(address);
                      setState(() {
                        connectionStatus[address] = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Desconectado de $address')),
                      );
                    }
                  },
                ),
              );
            },
          ),
    );
  }
}
