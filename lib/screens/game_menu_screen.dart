// game_menu_screen.dart
import 'package:flutter/material.dart';
import 'game_RepiteConmigo.dart';
import 'game_Velocidad.dart';
import 'game_ApuntaYAcierta.dart';

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
            icon: const Icon(Icons.repeat),
            label: const Text('Repite Conmigo'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RepiteConmigoScreen()),
              );
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.speed),
            label: const Text('Velocidad'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => VelocidadScreen()),
              );
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.adjust),
            label: const Text('Apunta y Acierta'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ApuntaYAciertaScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
