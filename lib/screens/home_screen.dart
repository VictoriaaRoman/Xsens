import 'package:flutter/material.dart';
import 'sensor_list_screen.dart';
import 'data_capture_screen.dart'; // 👈 Asegúrate de importar esto


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
            const SizedBox(height: 16), // Espaciado entre botones
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
          ],
        ),
      ),
    );
  }
}
