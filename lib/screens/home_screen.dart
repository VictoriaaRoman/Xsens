// home_screen.dart (actualizado)
import 'package:flutter/material.dart';
import 'sensor_list_screen.dart';
import 'data_capture_screen.dart';
import 'game_menu_screen.dart'; // 👈 Importar nueva pantalla

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Xsens Demo')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SensorListScreen()),
                );
              },
              child: const Text('Conectar sensores'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DataCaptureScreen()),
                );
              },
              icon: const Icon(Icons.bar_chart),
              label: const Text('Capturar datos'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GameMenuScreen()),
                );
              },
              icon: const Icon(Icons.videogame_asset),
              label: const Text('Jugar'),
            ),
          ],
        ),
      ),
    );
  }
}
