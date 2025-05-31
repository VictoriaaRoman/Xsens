import 'package:flutter/material.dart';
import 'package:xsense_demo/services/xsens_service.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // <-- MUY IMPORTANTE

  // 1) Inicializar XsensService para que ya esté escuchando invocaciones nativas.
  XsensService.initialize();

  // 2) Ya puedes arrancar la aplicación.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xsens Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}
