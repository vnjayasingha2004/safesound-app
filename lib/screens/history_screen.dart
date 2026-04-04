import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = [
      {'place': 'Factory Floor', 'level': '88 dB', 'time': '2h 45m'},
      {'place': 'Main Road', 'level': '76 dB', 'time': '45m'},
      {'place': 'Lecture Hall', 'level': '55 dB', 'time': '1h 30m'},
      {'place': 'Gym', 'level': '82 dB', 'time': '1h 10m'},
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'History',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: ListView.builder(
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.history)),
                      title: Text(session['place']!),
                      subtitle: Text('Level: ${session['level']}'),
                      trailing: Text(session['time']!),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
