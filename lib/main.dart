import 'package:flutter/material.dart';
import 'package:xsense_demo/services/xsens_service.dart';
import 'screens/home_screen.dart';
import 'screens/game_menu_screen.dart'; // <-- Asegúrate de importar la pantalla

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
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/game_menu_screen': (context) => const GameMenuScreen(), // <-- Añade esta línea
        // ...otras rutas...
      },
    );
  }
}
