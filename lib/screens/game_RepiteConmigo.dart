import 'dart:async';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/xsens_service.dart';

class RepiteConmigoScreen extends StatefulWidget {
  const RepiteConmigoScreen({super.key});

  @override
  State<RepiteConmigoScreen> createState() => _RepiteConmigoScreenState();
}

class _RepiteConmigoScreenState extends State<RepiteConmigoScreen> {
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

  int currentTarget = 0;
  final List<double> leftTargets = [30, -45, 60, -30, 0]; // Ejemplo de objetivos
  final List<double> rightTargets = [30, -45, 60, -30, 0];
  final List<bool> leftAchieved = List.filled(5, false);
  final List<bool> rightAchieved = List.filled(5, false);
  final List<double> leftTimes = List.filled(5, 0.0);
  final List<double> rightTimes = List.filled(5, 0.0);

  Timer? roundTimer;
  Timer? holdTimer;
  double roundElapsed = 0.0;
  bool holding = false;
  bool roundActive = false;

  final String leftHandAddress = 'D4:22:CD:00:50:4A';
  final String rightHandAddress = 'D4:22:CD:00:50:60';

  @override
  void initState() {
    super.initState();
    startRound();
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

  void finishRound(bool achieved) {
    roundTimer?.cancel();
    holdTimer?.cancel();
    roundActive = false;

    leftAchieved[currentTarget] = achieved;
    rightAchieved[currentTarget] = achieved;
    leftTimes[currentTarget] = roundElapsed;
    rightTimes[currentTarget] = roundElapsed;

    if (currentTarget < leftTargets.length - 1) {
      setState(() {
        currentTarget++;
      });
      startRound();
    } else {
      setState(() {
        currentTarget++;
      }); // Esto fuerza el build y mostrará _buildResultsScreen
    }
  }

  double getCurrentAngle(String address) {
    final data = sensorData[address]?['inclinationAngle'] ?? [];
    return data.isNotEmpty ? data.last.y : 0.0;
  }
  void startRound() {
    roundActive = true;
    holding = false;
    roundElapsed = 0.0;

    roundTimer?.cancel();
    holdTimer?.cancel();

    roundTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        roundElapsed += 0.1;
        final leftAngle = getCurrentAngle(leftHandAddress);
        final rightAngle = getCurrentAngle(rightHandAddress);

        final leftOk = (leftAngle - leftTargets[currentTarget]).abs() < 5;
        final rightOk = (rightAngle - rightTargets[currentTarget]).abs() < 5;

        if (leftOk && rightOk && !holding) {
          holding = true;
          holdTimer = Timer(const Duration(seconds: 3), () {
            finishRound(true);
          });
        } else if (!leftOk || !rightOk) {
          holding = false;
          holdTimer?.cancel();
        }

        if (roundElapsed >= 10.0) {
          finishRound(false);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (currentTarget >= leftTargets.length) {
      return _buildResultsScreen(context);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Repite Conmigo')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            'Objetivo ${currentTarget + 1}/5',
            style: const TextStyle(fontSize: 24),
            textAlign: TextAlign.center,
          ),
          Text(
            'Tiempo restante: ${(10 - roundElapsed).toStringAsFixed(1)} s',
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Brazo Izquierdo: ${leftTargets[currentTarget]}°',
                          style: const TextStyle(fontSize: 18)),
                      InclinationGaugeWidget(
                        address: leftHandAddress,
                        sensorData: sensorData,
                        minAngle: getMinY('inclinationAngle'),
                        maxAngle: getMaxY('inclinationAngle'),
                        targetAngle: leftTargets[currentTarget],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Brazo Derecho: ${rightTargets[currentTarget]}°',
                          style: const TextStyle(fontSize: 18)),
                      InclinationGaugeWidget(
                        address: rightHandAddress,
                        sensorData: sensorData,
                        minAngle: getMinY('inclinationAngle'),
                        maxAngle: getMaxY('inclinationAngle'),
                        targetAngle: rightTargets[currentTarget],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: Center(
              child: holding
                ? Text(
                    '¡Mantén la posición!',
                    style: const TextStyle(color: Colors.green, fontSize: 22),
                    textAlign: TextAlign.center,
                  )
                : null,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildResultsScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resultados')),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Text('Resultados:', style: const TextStyle(fontSize: 20)),
          ...List.generate(leftTargets.length, (i) => ListTile(
            title: Text('Objetivo ${i + 1}: ${leftAchieved[i] ? "✔️" : "❌"}'),
            subtitle: Text('Tiempo: ${leftTimes[i].toStringAsFixed(1)} s'),
          )),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/game_menu_screen');
            },
            child: const Text('Ir al menú de juegos'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                currentTarget = 0;
                leftAchieved.fillRange(0, leftAchieved.length, false);
                rightAchieved.fillRange(0, rightAchieved.length, false);
                leftTimes.fillRange(0, leftTimes.length, 0.0);
                rightTimes.fillRange(0, rightTimes.length, 0.0);
              });
              startRound();
            },
            child: const Text('Volver a jugar'),
          ),
        ],
      ),
    );
  }
}

class InclinationGaugeWidget extends StatelessWidget {
  final String address;
  final Map<String, Map<String, List<FlSpot>>> sensorData;
  final double minAngle;
  final double maxAngle;
  final double targetAngle; // <-- NUEVO

  const InclinationGaugeWidget({
    super.key,
    required this.address,
    required this.sensorData,
    required this.minAngle,
    required this.maxAngle,
    required this.targetAngle, // <-- NUEVO
  });

  @override
  Widget build(BuildContext context) {
    final data = sensorData[address]?['inclinationAngle'] ?? [];
    final angle = data.isNotEmpty ? data.last.y : 0.0;

    return Column(
      children: [
        Text('Ángulo actual', style: const TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(
          height: 200, // antes 120
          width: 140,  // antes 80
          child: CustomPaint(
            painter: _InclinationGaugePainter(
              angle: angle,
              minAngle: minAngle,
              maxAngle: maxAngle,
              targetAngle: targetAngle,
            ),
          ),
        ),
        Text('${angle.toStringAsFixed(1)}°', style: const TextStyle(fontSize: 16)),
      ],
    );
  }
}

class _InclinationGaugePainter extends CustomPainter {
  final double angle;
  final double minAngle;
  final double maxAngle;
  final double targetAngle;

  _InclinationGaugePainter({
    required this.angle,
    required this.minAngle,
    required this.maxAngle,
    required this.targetAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.height / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final arcPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;

    // Semicírculo vertical: -90° abajo, +90° arriba
    canvas.drawArc(rect, -math.pi / 2, math.pi, false, arcPaint);

    double mapAngleToRadian(double value) {
      final normalized = ((value - minAngle) / (maxAngle - minAngle)).clamp(0.0, 1.0);
      return (-math.pi / 2) + normalized * math.pi;
    }

    // Línea azul (objetivo)
    final thetaTarget = mapAngleToRadian(targetAngle);
    final targetX = center.dx + radius * math.cos(thetaTarget);
    final targetY = center.dy - radius * math.sin(thetaTarget);
    canvas.drawLine(center, Offset(targetX, targetY), Paint()
      ..color = Colors.blue
      ..strokeWidth = 2);

    // Línea roja (valor actual)
    final theta = mapAngleToRadian(angle);
    final markerX = center.dx + radius * math.cos(theta);
    final markerY = center.dy - radius * math.sin(theta);
    canvas.drawLine(center, Offset(markerX, markerY), Paint()
      ..color = Colors.red
      ..strokeWidth = 4);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

