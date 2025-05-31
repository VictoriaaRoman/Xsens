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
      setState(() {
        final index = sensors.indexWhere((s) => s['address'] == sensor['address']);
        if (index != -1) {
          // Actualizar nombre si ya existía
          sensors[index]['name'] = sensor['name'] ?? sensors[index]['name']!;
        } else {
          sensors.add(sensor);
        }
      });
    });
  }


  void _startScanning() async {
    await XsensService.requestBluetoothScanPermission();
    await XsensService.startScan();
  }

  int get connectedCount => connectionStatus.values.where((e) => e).length;

  Future<void> _connectToSensor(String sensorId) async {
    try {
      await XsensService.connectToSensor(sensorId);
      setState(() {
        connectionStatus[sensorId] = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sensores conectados: $connectedCount')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al conectar: $e')),
      );
    }
  }

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

                return Card(
                  color: isConnected ? Colors.green[100] : null,
                  child: ListTile(
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
                            SnackBar(content: Text('Sensores conectados: $connectedCount')),
                          );
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
