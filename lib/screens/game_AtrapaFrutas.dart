import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/xsens_service.dart';

const String rightHandAddress = 'D4:22:CD:00:50:60';

class AtrapaFrutasScreen extends StatefulWidget {
  const AtrapaFrutasScreen({super.key});

  @override
  State<AtrapaFrutasScreen> createState() => _AtrapaFrutasScreenState();
}

class _AtrapaFrutasScreenState extends State<AtrapaFrutasScreen> {
  // ------ ESTADO ------
  bool calibrating = true;             // Modo de calibración/cuenta atrás inicial
  int calibrateCountdown = 3;          // Cuenta atrás de calibración
  bool calibratingInProgress = false;

  // Para transición entre rondas
  bool showRoundSplash = false;
  int splashRound = 1;

  final List<List<Offset>> roundsTargets = [
    [
      Offset(0.7, 0.7),
      Offset(-0.7, -0.7),
      Offset(0.5, -0.2),
      Offset(-0.6, 0.6),
      Offset(0.0, 0.0),
    ],
    [
      Offset(-0.5, 0.8),
      Offset(0.6, -0.5),
      Offset(-0.3, -0.2),
      Offset(0.7, 0.2),
      Offset(-0.7, 0.0),
    ],
    [
      Offset(0.0, 0.8),
      Offset(0.8, 0.0),
      Offset(-0.8, -0.1),
      Offset(0.2, -0.7),
      Offset(-0.5, 0.4),
    ],
  ];
  final List<double> roundTimes = [25.0, 20.0, 15.0]; // Segundos por ronda

  final List<String> fruitAssets = [
    'assets/images/apple.png',
    'assets/images/bananas.png',
    'assets/images/watermelon.png',
    'assets/images/orange-juice.png',
    'assets/images/grapes.png',
  ];

  int currentRound = 0;
  int currentTarget = 0;
  bool gameFinished = false;
  bool roundFinished = false;
  StreamSubscription? _dataSub;
  Offset pointer = Offset(0, 0);
  Map<String, dynamic>? lastSensorData;

  late Stopwatch stopwatch;
  double roundElapsed = 0.0;
  double totalElapsed = 0.0;
  Timer? progressTimer;

  List<List<bool>> achieved = [];
  List<double> roundsTimesElapsed = [];

  List<Offset> get targets => roundsTargets[currentRound];
  double get maxTotalTime => roundTimes[currentRound];

  @override
  void initState() {
    super.initState();
    XsensService.startMeasuring();
    stopwatch = Stopwatch();
    achieved = List.generate(roundsTargets.length, (_) => List.filled(5, false));
    roundsTimesElapsed = List.filled(roundsTargets.length, 0.0);

    // Cuenta atrás de calibración automática
    if (calibrating) _startCalibrateCountdown();

    _dataSub = XsensService.sensorDataStream.listen((event) {
      if (event['address'] == rightHandAddress) {
        final dx = (event['directionX'] ?? 0.0).toDouble();
        final dy = (event['directionY'] ?? 0.0).toDouble();
        setState(() {
          pointer = Offset(dx, dy);
          lastSensorData = event;
        });
        _checkTarget();
      }
    });
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    progressTimer?.cancel();
    super.dispose();
  }

  void _startCalibrateCountdown() {
    setState(() {
      calibratingInProgress = true;
      calibrateCountdown = 10;
    });

    Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        calibrateCountdown--;
      });
      if (calibrateCountdown <= 0) {
        timer.cancel();
        _calibrate();
      }
    });
  }

  Future<void> _calibrate() async {
    try {
      await XsensService.calibrateSensor(rightHandAddress);
      await Future.delayed(const Duration(milliseconds: 400));
    } catch (e) {}
    setState(() {
      calibrating = false;
      calibratingInProgress = false;
      currentRound = 0;
      currentTarget = 0;
      gameFinished = false;
      roundFinished = false;
      pointer = Offset(0, 0);
      totalElapsed = 0.0;
      achieved = List.generate(roundsTargets.length, (_) => List.filled(5, false));
      roundsTimesElapsed = List.filled(roundsTargets.length, 0.0);
    });
    _randomizeTargets();
    _showRoundSplashAndStart();
  }

  void _randomizeTargets() {
    for (int i = 0; i < roundsTargets.length; i++) {
      roundsTargets[i] = List.of(roundsTargets[i]);
      roundsTargets[i].shuffle(Random(DateTime.now().millisecondsSinceEpoch + i));
    }
  }

  void _showRoundSplashAndStart() async {
    setState(() {
      showRoundSplash = true;
      splashRound = currentRound + 1;
    });
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      showRoundSplash = false;
    });
    _startRound();
  }

  void _startRound() {
    currentTarget = 0;
    roundElapsed = 0.0;
    roundFinished = false;
    stopwatch.reset();
    stopwatch.start();
    progressTimer?.cancel();
    progressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!roundFinished && stopwatch.isRunning) {
        setState(() {
          roundElapsed = stopwatch.elapsedMilliseconds / 1000.0;
          if (roundElapsed >= maxTotalTime) {
            _finishRound();
          }
        });
      }
    });
  }

  void _checkTarget() {
    if (gameFinished || calibrating || roundFinished || showRoundSplash) return;
    final target = targets[currentTarget];
    final distance = (pointer - target).distance;
    if (distance < 0.18 && !achieved[currentRound][currentTarget]) {
      setState(() {
        achieved[currentRound][currentTarget] = true;
      });
      _nextTarget();
    }
  }

  void _nextTarget() {
    if (currentTarget < targets.length - 1) {
      setState(() {
        currentTarget++;
      });
    } else {
      _finishRound();
    }
  }

  void _finishRound() {
    stopwatch.stop();
    progressTimer?.cancel();
    roundFinished = true;
    roundsTimesElapsed[currentRound] =
        roundElapsed > maxTotalTime ? maxTotalTime : roundElapsed;
    if (currentRound < roundsTargets.length - 1) {
      Future.delayed(const Duration(seconds: 1), () {
        setState(() {
          currentRound++;
        });
        _randomizeTargets();
        _showRoundSplashAndStart();
      });
    } else {
      setState(() {
        gameFinished = true;
        totalElapsed = roundsTimesElapsed.reduce((a, b) => a + b);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ---- CALIBRACIÓN AUTOMÁTICA CON CUENTA ATRÁS ----
    if (calibrating) {
      return Scaffold(
        appBar: AppBar(title: const Text("Recolector de Frutas")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Coloca el sensor derecho como en la imagen",
                style: TextStyle(fontSize: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Image.asset(
                'assets/images/PosicionDeCalibracion2.jpg',
                width: 500,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.image_not_supported, size: 90, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              if (calibratingInProgress)
                Column(
                  children: [
                    Text(
                      calibrateCountdown > 0
                          ? "Calibrando en..."
                          : "¡Calibrando!",
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(height: 16),
                    calibrateCountdown > 0
                        ? Text(
                            calibrateCountdown.toString(),
                            style: const TextStyle(
                              fontSize: 70,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 130, 34, 255),
                            ),
                          )
                        : const CircularProgressIndicator(),
                  ],
                ),
            ],
          ),
        ),
      );
    }

    // ---- PANTALLA SPLASH DE RONDA ----
    if (showRoundSplash) {
      return Scaffold(
        body: Center(
          child: Text(
            'Ronda $splashRound',
            style: TextStyle(
              fontSize: 60,
              fontWeight: FontWeight.bold,
              color: const Color.fromARGB(255, 130, 34, 255).withOpacity(0.96),
              shadows: [
                Shadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6)),
              ],
            ),
          ),
        ),
      );
    }

    if (gameFinished) {
      return _buildResultsScreen(context);
    }

    final target = targets[currentTarget];
    final fruitAsset = fruitAssets[currentTarget];

    final progresoBarra = 1.0 - (roundElapsed / maxTotalTime).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Ronda ${currentRound + 1} de ${roundsTargets.length}'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          // Barra horizontal de tiempo decreciente
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progresoBarra,
                minHeight: 18,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                    progresoBarra > 0.3 ? Colors.green : Colors.red),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tiempo restante: ${(maxTotalTime - roundElapsed).clamp(0, maxTotalTime).toStringAsFixed(1)} s',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Fruta ${currentTarget + 1} de ${targets.length}',
            style: const TextStyle(fontSize: 22),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade100, Colors.yellow.shade50],
                ),
                border: Border.all(color: Colors.green.shade200, width: 3),
                borderRadius: BorderRadius.circular(32),
              ),
              child: _GameAreaWidget(
                pointer: pointer,
                target: target,
                fruitAsset: fruitAsset,
              ),
            ),
          ),
          if (lastSensorData != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Valores recibidos del sensor:',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      'directionX: ${(lastSensorData!['directionX'] ?? 0.0).toStringAsFixed(4)}'
                      ' | directionY: ${(lastSensorData!['directionY'] ?? 0.0).toStringAsFixed(4)}'
                      ' | directionZ: ${(lastSensorData!['directionZ'] ?? 0.0).toStringAsFixed(4)}',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildResultsScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('¡Resultados de las rondas!')),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
            const SizedBox(height: 12),
            const Text('¡Juego terminado!', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 18),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: roundsTargets.length,
              itemBuilder: (context, i) {
                final recogidas = achieved[i].where((x) => x).length;
                final total = achieved[i].length;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 6),
                  child: ListTile(
                    leading: Icon(
                      recogidas == total ? Icons.check_circle : Icons.warning_amber,
                      color: recogidas == total ? Colors.green : Colors.red,
                    ),
                    title: Text('Ronda ${i + 1}'),
                    subtitle: Text(
                        'Frutas recogidas: $recogidas de $total\nTiempo: ${roundsTimesElapsed[i].toStringAsFixed(2)} s'),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Text(
              achieved.expand((x) => x).every((b) => b)
                  ? '¡Has recogido TODAS las frutas en todas las rondas!'
                  : '¡Intenta conseguirlas todas la próxima vez!',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text('Tiempo total: ${totalElapsed.toStringAsFixed(2)} s', style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  calibrating = true;
                  calibratingInProgress = false;
                  currentRound = 0;
                  currentTarget = 0;
                  gameFinished = false;
                  roundFinished = false;
                  pointer = Offset(0, 0);
                  lastSensorData = null;
                  totalElapsed = 0.0;
                  achieved = List.generate(roundsTargets.length, (_) => List.filled(5, false));
                  roundsTimesElapsed = List.filled(roundsTargets.length, 0.0);
                });
                _startCalibrateCountdown();
              },
              child: const Text('¡Volver a jugar!'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/game_menu_screen');
              },
              child: const Text('Ir al menú de juegos'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _GameAreaWidget extends StatelessWidget {
  final Offset pointer;
  final Offset target;
  final String fruitAsset;

  const _GameAreaWidget({
    required this.pointer,
    required this.target,
    required this.fruitAsset,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        Offset map(Offset norm) => Offset(
              w / 2 + norm.dx * w / 2,
              h / 2 - norm.dy * h / 2,
            );

        return Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.fromARGB(255, 168, 156, 197), // Lila
                        Color.fromARGB(255, 245, 209, 235), // Rosa suave
                        Color.fromARGB(255, 226, 164, 255), // Púrpura intenso
                        Color.fromARGB(255, 158, 229, 245), // Azul-lila pastel
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: CustomPaint(
                    painter: _FruitBackgroundPainter(),
                  ),
                ),
              ),
            ),
            // Fruta (objetivo)
            Positioned(
              left: map(target).dx - 32,
              top: map(target).dy - 32,
              child: Image.asset(fruitAsset, width: 64),
            ),
            // Mano (puntero)
            Positioned(
              left: map(pointer).dx - 26,
              top: map(pointer).dy - 26,
              child: const Icon(Icons.front_hand, color: Color(0xFFFFA000), size: 52),
            ),
          ],
        );
      },
    );
  }
}

class _FruitBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final confetti = [
      Colors.redAccent, Colors.green, Colors.orange, Colors.purple, Colors.yellow.shade700,
      Colors.lightGreen, Colors.pink, Colors.deepOrange, Colors.teal
    ];

    final rnd = Random(2024); // Fijo para que cada partida no cambie

    for (int i = 0; i < 40; i++) {
      final color = confetti[i % confetti.length];
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height;
      final radius = 6 + rnd.nextDouble() * 6;
      final paint = Paint()..color = color.withOpacity(0.18 + rnd.nextDouble() * 0.25);
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
