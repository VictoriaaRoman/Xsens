// filepath: /Users/victoriaromangarrido/Desktop/TFG/xsense_demo/lib/models/history.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class History {
  static final List<Map<String, dynamic>> records = [];

  static Future<void> add({
    required String actividad,
    required String resultado,
    required String tiempo,
  }) async {
    final now = DateTime.now();
    records.add({
      'fecha': now.toIso8601String().substring(0, 10),
      'hora': "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}",
      'actividad': actividad,
      'resultado': resultado,
      'tiempo': tiempo,
    });
    await save();
  }

  static List<Map<String, dynamic>> get all {
    final sorted = List<Map<String, dynamic>>.from(records);
    sorted.sort((a, b) {
      final dateA = DateTime.parse("${a['fecha']}T${a['hora']}:00");
      final dateB = DateTime.parse("${b['fecha']}T${b['hora']}:00");
      return dateB.compareTo(dateA); // Más nuevos primero
    });
    return List.unmodifiable(sorted);
  }

  static Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = jsonEncode(records);
    await prefs.setString('history', jsonList);
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getString('history');
    if (jsonList != null) {
      final List<dynamic> decoded = jsonDecode(jsonList);
      records.clear();
      records.addAll(decoded.map((e) => Map<String, dynamic>.from(e)));
    }
  }

  static Future<void> clear() async {
    records.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('history');
  }
}