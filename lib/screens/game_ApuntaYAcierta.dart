import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/xsens_service.dart';

// Cambia esto a la dirección MAC de TU sensor derecho
const String rightHandAddress = 'D4:22:CD:00:50:60';

class ApuntaYAciertaScreen extends StatefulWidget {
  const ApuntaYAciertaScreen({super.key});

  @override
  State<ApuntaYAciertaScreen> createState() => _ApuntaYAciertaScreenState();
}

class _ApuntaYAciertaScreenState extends State<ApuntaYAciertaScreen> {
  // --------- CALIBRACIÓN ---------
  bool calibrating = true;
  bool calibratingInProgress = false;

  // --------- JUEGO -------------
  final List<Offset> targets = [
    Offset(0.7, 0.7),
    Offset(-0.7, -0.7),
    Offset(0.5, -0.2),
    Offset(-0.6, 0.6),
    Offset(0.0, 0.0),
  ]; // Objetivos (normalizado -1..1)
  int currentTarget = 0;
  bool holding = false;
  Timer? holdTimer;
  double holdElapsed = 0.0;
  bool gameFinished = false;
  List<bool> achieved = List.filled(5, false);
  List<double> times = List.filled(5, 0.0);
  DateTime? roundStart;
  StreamSubscription? _dataSub;
  Offset pointer = Offset(0, 0);
  Map<String, dynamic>? lastSensorData;

  // Nueva: Timer y estado para la cuenta atrás por ronda
  double roundElapsed = 0.0;
  double maxRoundTime = 10.0; // segundos para cada objetivo
  Timer? roundTimer;

  @override
  void initState() {
    super.initState();
    XsensService.startMeasuring();
    _startRound();
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
    holdTimer?.cancel();
    roundTimer?.cancel();
    super.dispose();
  }

  // ------ Lógica de calibración -------
  Future<void> _calibrate() async {
    setState(() {
      calibratingInProgress = true;
    });
    try {
      await XsensService.calibrateSensor(rightHandAddress);
      await Future.delayed(const Duration(milliseconds: 400));
    } catch (e) {}
    setState(() {
      calibrating = false;
      calibratingInProgress = false;
      currentTarget = 0;
      achieved = List.filled(targets.length, false);
      times = List.filled(targets.length, 0.0);
      gameFinished = false;
      pointer = Offset(0, 0);
      roundElapsed = 0.0;
    });
    _startRound();
  }

  // ------ Nueva: Iniciar ronda con cuenta atrás ------
  void _startRound() {
    holding = false;
    holdElapsed = 0.0;
    roundElapsed = 0.0;
    roundTimer?.cancel();
    roundTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        roundElapsed += 0.1;
        if (roundElapsed >= maxRoundTime) {
          // Si no se acierta a tiempo, marcar como NO conseguido y pasar al siguiente
          _markTarget(achieved: false, timedOut: true);
        }
      });
    });
  }

  // ------ Lógica del juego ----------
  void _checkTarget() {
    if (gameFinished || calibrating) return;
    final target = targets[currentTarget];
    final distance = (pointer - target).distance;
    if (distance < 0.18) {
      if (!holding) {
        holding = true;
        roundStart = DateTime.now();
        holdTimer = Timer(const Duration(seconds: 2), () {
          _markTarget(achieved: true);
        });
      } else {
        holdElapsed = DateTime.now().difference(roundStart!).inMilliseconds / 1000.0;
      }
    } else {
      holding = false;
      holdTimer?.cancel();
      holdElapsed = 0.0;
    }
  }

  void _markTarget({required bool achieved, bool timedOut = false}) {
    holdTimer?.cancel();
    roundTimer?.cancel();
    // El tiempo gastado: si acertó, es el tiempo que tardó; si falló, el máximo
    times[currentTarget] = achieved ? roundElapsed : maxRoundTime;
    this.achieved[currentTarget] = achieved;
    if (currentTarget < targets.length - 1) {
      setState(() {
        currentTarget++;
      });
      _startRound();
    } else {
      setState(() {
        gameFinished = true;
      });
    }
  }

  // ------------ UI PRINCIPAL ------------
  @override
  Widget build(BuildContext context) {
    if (calibrating) {
      return Scaffold(
        appBar: AppBar(title: const Text("Apunta y Acierta")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Coloca el sensor derecho como en la imagen y pulsa Calibrar",
                style: TextStyle(fontSize: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Image.asset(
                'assets/images/PosicionDeCalibracion.jpg',
                width: 500,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.image_not_supported, size: 90, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: calibratingInProgress ? null : _calibrate,
                child: calibratingInProgress
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3))
                    : const Text('Calibrar y Empezar'),
              ),
            ],
          ),
        ),
      );
    }
    if (gameFinished) {
      return _buildResultsScreen(context);
    }
    final target = targets[currentTarget];
    return Scaffold(
      appBar: AppBar(title: const Text('Apunta y Acierta')),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Text('Objetivo ${currentTarget + 1} de ${targets.length}',
              style: const TextStyle(fontSize: 22)),
          Text(
            'Tiempo restante: ${(maxRoundTime - roundElapsed).clamp(0, maxRoundTime).toStringAsFixed(1)} s',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: _GameAreaWidget(
                pointer: pointer,
                target: target,
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
                    if (lastSensorData!['quatX'] != null)
                      Text(
                        'quat: (${lastSensorData!['quatX']}, ${lastSensorData!['quatY']}, ${lastSensorData!['quatZ']}, ${lastSensorData!['quatW']})',
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (holding) ...[
            const Text('¡Mantén el puntero en el objetivo!',
                style: TextStyle(color: Colors.green, fontSize: 20)),
            Text('${(2.0 - holdElapsed).toStringAsFixed(1)} s',
                style: const TextStyle(fontSize: 18)),
          ],
          const SizedBox(height: 24),
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
          const Text('¡Juego terminado!', style: TextStyle(fontSize: 20)),
          ...List.generate(targets.length, (i) => ListTile(
                title: Text('Objetivo ${i + 1}: ${achieved[i] ? "✔️" : "❌"}'),
                subtitle: Text('Tiempo: ${times[i].toStringAsFixed(1)} s'),
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
                calibrating = true;
                calibratingInProgress = false;
                currentTarget = 0;
                achieved = List.filled(targets.length, false);
                times = List.filled(targets.length, 0.0);
                pointer = Offset(0, 0);
                gameFinished = false;
                lastSensorData = null;
                roundElapsed = 0.0;
              });
            },
            child: const Text('Volver a jugar'),
          ),
        ],
      ),
    );
  }
}

// ------------------- WIDGET ÁREA DE JUEGO ---------------------
class _GameAreaWidget extends StatelessWidget {
  final Offset pointer; // Posición actual del puntero (normalizada, ej. -1..1)
  final Offset target;  // Posición del objetivo (normalizada)

  const _GameAreaWidget({required this.pointer, required this.target});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1, // Área cuadrada
      child: LayoutBuilder(
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
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey.shade400,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              Positioned(
                left: map(target).dx - 22,
                top: map(target).dy - 22,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withOpacity(0.2),
                    border: Border.all(color: Colors.blue, width: 3),
                  ),
                  child: const Center(
                      child: Icon(Icons.adjust, color: Colors.blue, size: 24)),
                ),
              ),
              Positioned(
                left: map(pointer).dx - 12,
                top: map(pointer).dy - 12,
                child: Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.red.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 2)
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.radio_button_checked,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
