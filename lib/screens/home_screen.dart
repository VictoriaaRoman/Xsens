import 'package:flutter/material.dart';
import 'sensor_list_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Xsens Demo')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SensorListScreen()),
            );
          },
          child: const Text('Conectar sensores'),
        ),
      ),
    );
  }
}
