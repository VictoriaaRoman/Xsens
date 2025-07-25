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
  final Map<String, String> sensorNames = {}; 

  final Map<String, String> dataLabels = {
    'freeAccZ': 'Aceleración en la dirección vertical',
    'gyrMag': 'Velocidad angular del movimiento',
    'inclinationAngle': 'Ángulo respecto del plano horizontal',
  };

  final List<String> dataTypes = ['freeAccZ', 'gyrMag', 'inclinationAngle'];

  StreamSubscription? _dataSubscription;
  StreamSubscription? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    XsensService.startMeasuring();

    _dataSubscription = XsensService.sensorDataStream.listen((event) {
      final address = event['address'] ?? '';
      final timestamp = DateTime.now().millisecondsSinceEpoch.toDouble();

      setState(() {
        if (!connectedSensors.contains(address)) {
          connectedSensors.add(address);
        }

        sensorData.putIfAbsent(address, () => {});
        for (final key in dataTypes) {
          final value = double.tryParse(event[key]?.toString() ?? '');
          if (value != null) {
            final list = sensorData[address]!.putIfAbsent(key, () => []);
            list.add(FlSpot(timestamp, value));
            final cutoff = timestamp - 10000; // últimos 10 segundos
            sensorData[address]![key] = list.where((e) => e.x >= cutoff).toList();
          }
        }
      });
    });

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

  double getMinY(String type) {
    switch (type) {
      case 'inclinationAngle':
        return -90;
      case 'freeAccZ':
        return -10;
      case 'gyrMag':
        return 0; // La magnitud del giro no debería ser negativa
      default:
        return -10;
    }
  }

  double getMaxY(String type) {
    switch (type) {
      case 'inclinationAngle':
        return 90;
      case 'freeAccZ':
        return 10;
      case 'gyrMag':
        return 500;
      default:
        return 10;
    }
  }

  Color getColorByValue(String type, double value) {
    if (type == 'inclinationAngle') {
      if (value.abs() >= 45) return Colors.green;
      if (value.abs() >= 15) return Colors.orange;
      return Colors.red;
    } else if (type == 'freeAccZ') {
      if (value.abs() <= 4) return Colors.red;
      if (value.abs() <= 7) return Colors.orange;
      return Colors.green;
    } else if (type == 'gyrMag') {
      if (value > 100) return Colors.orange;
      if (value > 200) return Colors.green;
      return Colors.red;
    }
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    if (connectedSensors.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Datos de sensores')),
        body: const Center(child: Text('No hay sensores conectados')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Datos de sensores')),
      body: DefaultTabController(
        length: connectedSensors.length,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              tabs: connectedSensors.map((address) {
                final name = sensorNames[address];
                return Tab(text: name != null && name.isNotEmpty ? name : address);
              }).toList(),
            ),
            Expanded(
              child: TabBarView(
                children: connectedSensors.map((address) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: dataTypes.map((type) {
                        final data = sensorData[address]?[type] ?? [];
                        if (data.isEmpty) {
                          return const Expanded(child: Center(child: Text("Sin datos aún...")));
                        }

                        final now = DateTime.now().millisecondsSinceEpoch.toDouble();
                        final spots = data
                            .map((e) => FlSpot((e.x - now) / 1000, e.y))
                            .where((e) => e.x >= -10 && e.x <= 0)
                            .toList();

                        List<LineChartBarData> segments = [];
                        if (spots.isNotEmpty) {
                          List<FlSpot> segment = [spots.first];
                          Color currentColor = getColorByValue(type, spots.first.y);

                          for (int i = 1; i < spots.length; i++) {
                            final spot = spots[i];
                            final color = getColorByValue(type, spot.y);
                            if (color != currentColor || i == spots.length - 1) {
                              if (i == spots.length - 1) {
                                segment.add(spot);
                              }
                              segments.add(LineChartBarData(
                                spots: List.from(segment),
                                isCurved: true,
                                color: currentColor,
                                barWidth: 3,
                                isStrokeCapRound: true,
                                curveSmoothness: 0.2,
                                dotData: FlDotData(show: false),
                                belowBarData: BarAreaData(show: false),
                              ));
                              segment = [spot];
                              currentColor = color;
                            } else {
                              segment.add(spot);
                            }
                          }
                        }

                        return Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                children: [
                                  Text(
                                    dataLabels[type] ?? type,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: LineChart(
                                      LineChartData(
                                        minX: -10,
                                        maxX: 0,
                                        minY: getMinY(type),
                                        maxY: getMaxY(type),
                                        clipData: FlClipData.all(),
                                        titlesData: FlTitlesData(
                                          bottomTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              reservedSize: 28,
                                              interval: 2,
                                              getTitlesWidget: (value, meta) => Text(
                                                "${value.toInt()}s",
                                                style: const TextStyle(fontSize: 10),
                                              ),
                                            ),
                                          ),
                                          leftTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              reservedSize: 40,
                                              getTitlesWidget: (value, meta) =>
                                                  Text(value.toStringAsFixed(0), style: const TextStyle(fontSize: 10)),
                                            ),
                                          ),
                                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        ),
                                        gridData: FlGridData(show: true),
                                        borderData: FlBorderData(show: true),
                                        lineBarsData: segments,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
