import 'package:flutter/material.dart';
import '../models/history.dart';
import '../widgets/app_drawer.dart'; // <-- Importa el Drawer

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = History.all;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Actividades'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Borrar historial',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('¿Borrar historial?'),
                  content: const Text('¿Estás seguro de que quieres borrar todo el historial? Esta acción no se puede deshacer.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Borrar'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await History.clear();
                (context as Element).reassemble();
              }
            },
          ),
        ],
      ),
      drawer: const AppDrawer(), // <-- Añade el Drawer aquí
      body: history.isEmpty
          ? const Center(child: Text('No hay actividades registradas'))
          : ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(item['actividad']),
                    subtitle: Text(
                      'Fecha: ${item['fecha']} ${item['hora']}\n'
                      'Resultado: ${item['resultado']}\n'
                      'Tiempo: ${item['tiempo']}',
                    ),
                    leading: const Icon(Icons.history),
                  ),
                );
              },
            ),
    );
  }
}