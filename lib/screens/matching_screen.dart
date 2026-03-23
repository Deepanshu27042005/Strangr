import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';

class MatchingScreen extends StatelessWidget {
  final String status;

  const MatchingScreen({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final db = context.read<DatabaseService>();
    final auth = context.read<AuthService>();

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 48),
            const Text(
              'Finding your sync...',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Looking for someone also "$status"',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            const SizedBox(height: 64),
            TextButton.icon(
              onPressed: () async {
                final userId = auth.currentUserId;
                if (userId != null) {
                  // Simply reset status to go back
                  await db.updateUserStatus(userId, ''); // Empty or handle removal
                  // Better yet, add a specific clear method in service
                }
              },
              icon: const Icon(Icons.close),
              label: const Text('Cancel Search'),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }
}
