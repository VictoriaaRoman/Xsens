// game_menu_screen.dart
import 'package:flutter/material.dart';
import 'game_RepiteConmigo.dart';
import 'package:xsense_demo/screens/game_menu_screen.dart';

class GameMenuScreen extends StatelessWidget {
  const GameMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menú de Juegos')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.rocket_launch),
            label: const Text('Evita los obstáculos'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RepiteConmigoScreen()),
              );
            },
          ),
          /*const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.music_note),
            label: const Text('Sigue el ritmo'),
            onPressed: () {
              // Placeholder para futuros juegos
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.memory),
            label: const Text('Repite el patrón'),
            onPressed: () {
              // Placeholder para futuros juegos
            },
          ),*/
        ],
      ),
    );
  }
}
