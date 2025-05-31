import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/xsens_service.dart';

class DataCaptureScreen extends StatefulWidget {
  const DataCaptureScreen({super.key});

  @override
  State<DataCaptureScreen> createState() => _DataCaptureScreenState();
}

class _DataCaptureScreenState extends State<DataCaptureScreen> {
  final List<String> connectedSensors = [];
  final Map<String, Map<String, List<FlSpot>>> sensorData = {};
  final Map<String, String> sensorNames = {}; // address -> tag
  final List<String> dataTypes = ['accX', 'accY', 'accZ', 'gyrX', 'gyrY', 'gyrZ', 'magX', 'magY', 'magZ', 'yaw', 'pitch', 'roll'];

  StreamSubscription? _dataSubscription;
  StreamSubscription? _connectionSubscription;

  @override
  void initState() {
    super.initState();

    XsensService.startMeasuring();

    // Escucha datos
    _dataSubscription = XsensService.sensorDataStream.listen((event) {
      final address = event['address'] ?? '';
      final timestamp = DateTime.now().millisecondsSinceEpoch.toDouble();

      setState(() {
        // Añade sensor si no está
        if (!connectedSensors.contains(address)) {
          connectedSensors.add(address);
        }

        sensorData.putIfAbsent(address, () => {});

        for (final key in dataTypes) {
          final value = double.tryParse(event[key]?.toString() ?? '');
          if (value != null) {
            final list = sensorData[address]!.putIfAbsent(key, () => []);
            list.add(FlSpot(timestamp, value));
            if (list.length > 100) {
              sensorData[address]![key] = list.sublist(list.length - 100);
            }
          }
        }
      });
    });

    // Escucha conexiones
    _connectionSubscription = XsensService.connectionStatusStream.listen((event) {
      final address = event['address'] ?? '';
      final connected = event['connected'] ?? false;
      setState(() {
        if (connected && !connectedSensors.contains(address)) {
          connectedSensors.add(address);
        } else if (!connected) {
          connectedSensors.remove(address);
        }
      });
    });

    // Escucha nombres
    XsensService.sensorStream.listen((sensor) {
      final address = sensor['address'] ?? '';
      final name = sensor['name'] ?? '';
      setState(() {
        sensorNames[address] = name;
      });
    });
  }

  @override
  void dispose() {
    XsensService.stopMeasuring();
    _dataSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (connectedSensors.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Datos de sensores')),
        body: const Center(child: Text('No hay sensores conectados')),
      );
    }

    return DefaultTabController(
      length: dataTypes.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Datos de sensores'),
          bottom: TabBar(
            isScrollable: true,
            tabs: dataTypes.map((e) => Tab(text: e)).toList(),
          ),
        ),
        body: TabBarView(
          children: dataTypes.map((type) {
            return ListView.builder(
              itemCount: connectedSensors.length,
              itemBuilder: (context, index) {
                final address = connectedSensors[index];
                final data = sensorData[address]?[type] ?? [];
                final sensorName = XsensService.sensorTags[address] ?? address;

                // Ajuste de límites dinámicos
                final minY = data.isNotEmpty ? data.map((e) => e.y).reduce((a, b) => a < b ? a : b) : -10;
                final maxY = data.isNotEmpty ? data.map((e) => e.y).reduce((a, b) => a > b ? a : b) : 10;
                final yMargin = (maxY - minY) * 0.2;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sensor: $sensorName', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 200,
                            child: LineChart(
                              LineChartData(
                                minY: minY - yMargin,
                                maxY: maxY + yMargin,
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 30,
                                      interval: 10000,
                                      getTitlesWidget: (value, meta) {
                                        final ts = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text("${ts.second}s", style: const TextStyle(fontSize: 10)),
                                        );
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      getTitlesWidget: (value, meta) => Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: Text("${value.toStringAsFixed(1)}"),
                                      ),
                                    ),
                                  ),
                                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                gridData: FlGridData(show: true),
                                borderData: FlBorderData(show: true),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: data,
                                    isCurved: true,
                                    color: Colors.blue,
                                    dotData: FlDotData(show: false),
                                    belowBarData: BarAreaData(show: false),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
