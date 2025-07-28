import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/xsens_service.dart';

class VelocidadScreen extends StatefulWidget {
  const VelocidadScreen({super.key});

  @override
  State<VelocidadScreen> createState() => _VelocidadScreenState();
}

class _VelocidadScreenState extends State<VelocidadScreen> {
  final List<String> connectedSensors = [];
  final Map<String, Map<String, List<FlSpot>>> sensorData = {};
  final Map<String, String> sensorNames = {};

  final List<String> dataTypes = ['freeAccZ', 'gyrMag', 'inclinationAngle'];

  StreamSubscription? _dataSubscription;
  StreamSubscription? _connectionSubscription;

  final String leftHandAddress = 'D4:22:CD:00:50:4A';
  final String rightHandAddress = 'D4:22:CD:00:50:60';

  int currentTarget = 0;
  final int totalTargets = 5;
  final List<double> leftVelocityTargets = [50, 120, 200, 80, 220];
  final List<double> rightVelocityTargets = [50, 120, 200, 80, 220];
  final List<bool> leftAchieved = List.filled(5, false);
  final List<bool> rightAchieved = List.filled(5, false);
  final List<double> leftTimes = List.filled(5, 0.0);
  final List<double> rightTimes = List.filled(5, 0.0);

  Timer? roundTimer;
  Timer? holdTimer;
  double roundElapsed = 0.0;
  bool holding = false;
  bool roundActive = false;

  Map<String, double> lastSMA = {};
  Map<String, int> lastSMAIndex = {};

  static const double roundDuration = 20.0;

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
            final cutoff = timestamp - 10000;
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

  double calculateMovingAverageRecursive(String address, int windowSize) {
    final data = sensorData[address]?['gyrMag'] ?? [];
    if (data.length < windowSize) return 0.0;

    if (!lastSMA.containsKey(address) || lastSMAIndex[address] != data.length - 2) {
      double sma = 0.0;
      for (int i = 0; i < windowSize; i++) {
        sma += data[data.length - 1 - i].y;
      }
      sma /= windowSize;
      lastSMA[address] = sma;
      lastSMAIndex[address] = data.length - 1;
      return sma;
    }

    final prevSMA = lastSMA[address]!;
    final x_new = data.last.y;
    final x_old = data[data.length - windowSize - 1].y;
    final sma = prevSMA + (x_new - x_old) / windowSize;
    lastSMA[address] = sma;
    lastSMAIndex[address] = data.length - 1;
    return sma;
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
        final leftVelocity = calculateMovingAverageRecursive(leftHandAddress, 60);
        final rightVelocity = calculateMovingAverageRecursive(rightHandAddress, 60);

        final leftOk = (leftVelocity - leftVelocityTargets[currentTarget]).abs() < 25;
        final rightOk = (rightVelocity - rightVelocityTargets[currentTarget]).abs() < 25;

        if (leftOk && rightOk && !holding) {
          holding = true;
          holdTimer = Timer(const Duration(seconds: 2), () {
            finishRound(true);
          });
        } else if (!leftOk || !rightOk) {
          holding = false;
          holdTimer?.cancel();
        }

        if (roundElapsed >= roundDuration) {
          finishRound(false);
        }
      });
    });
  }

  void finishRound(bool achieved) {
    roundTimer?.cancel();
    holdTimer?.cancel();
    roundActive = false;

    leftAchieved[currentTarget] = achieved;
    rightAchieved[currentTarget] = achieved;
    leftTimes[currentTarget] = roundElapsed;
    rightTimes[currentTarget] = roundElapsed;

    if (currentTarget < totalTargets - 1) {
      setState(() {
        currentTarget++;
      });
      startRound();
    } else {
      setState(() {
        currentTarget++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentTarget >= totalTargets) {
      return _buildResultsScreen(context);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Velocidad')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            'Objetivo ${currentTarget + 1}/$totalTargets',
            style: const TextStyle(fontSize: 24),
            textAlign: TextAlign.center,
          ),
          Text(
            'Tiempo restante: ${(roundDuration - roundElapsed).toStringAsFixed(1)} s',
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
                      Text('Brazo Izquierdo: ${leftVelocityTargets[currentTarget].toStringAsFixed(1)} rad/s',
                          style: const TextStyle(fontSize: 18)),
                      VelocityBarWidget(
                        velocity: calculateMovingAverageRecursive(leftHandAddress, 160),
                        minVelocity: 0,
                        maxVelocity: 500,
                        targetVelocity: leftVelocityTargets[currentTarget],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Brazo Derecho: ${rightVelocityTargets[currentTarget].toStringAsFixed(1)} rad/s',
                          style: const TextStyle(fontSize: 18)),
                      VelocityBarWidget(
                        velocity: calculateMovingAverageRecursive(rightHandAddress, 160),
                        minVelocity: 0,
                        maxVelocity: 500,
                        targetVelocity: rightVelocityTargets[currentTarget],
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
                      '¡Mantén la velocidad!',
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
          ...List.generate(totalTargets, (i) => ListTile(
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

class VelocityBarWidget extends StatelessWidget {
  final double velocity;
  final double minVelocity;
  final double maxVelocity;
  final double targetVelocity;

  const VelocityBarWidget({
    super.key,
    required this.velocity,
    required this.minVelocity,
    required this.maxVelocity,
    required this.targetVelocity,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 80,
          width: 400,
          child: CustomPaint(
            painter: _VelocityBarPainter(
              velocity: velocity,
              minVelocity: minVelocity,
              maxVelocity: maxVelocity,
              targetVelocity: targetVelocity,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${velocity.toStringAsFixed(2)} rad/s',
          style: const TextStyle(fontSize: 18),
        ),
        Text(
          'Objetivo: ${targetVelocity.toStringAsFixed(1)} rad/s',
          style: const TextStyle(fontSize: 18, color: Colors.red),
        ),
      ],
    );
  }
}

class _VelocityBarPainter extends CustomPainter {
  final double velocity;
  final double minVelocity;
  final double maxVelocity;
  final double targetVelocity;

  _VelocityBarPainter({
    required this.velocity,
    required this.minVelocity,
    required this.maxVelocity,
    required this.targetVelocity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barHeight = size.height * 0.8;
    final barTop = (size.height - barHeight) / 2;
    final barLeft = 10.0;
    final barRight = size.width - 10.0;
    final barWidth = barRight - barLeft;

    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(barLeft, barTop, barWidth, barHeight), bgPaint);

    final normalizedVelocity = ((velocity - minVelocity) / (maxVelocity - minVelocity)).clamp(0.0, 1.0);
    final velocityX = barLeft + normalizedVelocity * barWidth;
    final bluePaint = Paint()..color = Colors.blue;
    canvas.drawRect(Rect.fromLTWH(barLeft, barTop, velocityX - barLeft, barHeight), bluePaint);

    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromLTWH(barLeft, barTop, barWidth, barHeight), borderPaint);

    const double margin = 25.0;
    final normalizedTargetMin = ((targetVelocity - margin - minVelocity) / (maxVelocity - minVelocity)).clamp(0.0, 1.0);
    final normalizedTargetMax = ((targetVelocity + margin - minVelocity) / (maxVelocity - minVelocity)).clamp(0.0, 1.0);
    final targetMinX = barLeft + normalizedTargetMin * barWidth;
    final targetMaxX = barLeft + normalizedTargetMax * barWidth;

    final redZonePaint = Paint()..color = Colors.red.withOpacity(0.5);
    canvas.drawRect(Rect.fromLTWH(targetMinX, barTop, targetMaxX - targetMinX, barHeight), redZonePaint);

    final centerX = barLeft + ((targetVelocity - minVelocity) / (maxVelocity - minVelocity)).clamp(0.0, 1.0) * barWidth;
    final centerLinePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2;
    canvas.drawLine(Offset(centerX, barTop), Offset(centerX, barTop + barHeight), centerLinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
