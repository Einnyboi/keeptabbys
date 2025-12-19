import 'package:flutter/material.dart';
import '../services/lobby_service.dart';
import 'join_screen.dart';
import 'lobby_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Tabby", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("History coming soon!")),
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(), 
            
            const Icon(Icons.receipt_long_rounded, size: 80, color: Colors.teal),
            const SizedBox(height: 16),
            const Text(
              "Split bills without\nlosing friends.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            
            const Spacer(),

            // BUTTON 1: HOST (Create Lobby)
            _buildBigButton(
              context: context,
              icon: Icons.add_a_photo_outlined,
              title: "Host a Meal",
              subtitle: "Scan receipt & create lobby",
              color: Colors.teal,
              // 2. Make this Async so we can wait for Firebase
              onTap: () async {
                // A. Show Loading
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Creating Room...")),
                );

                try {
                  // B. Call the Backend
                  String roomId = await LobbyService().createSession(hostName: "Host");

                  // C. Success!
                  print("✅ Room Created: $roomId");
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    // Navigate to Lobby Screen as Host
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LobbyScreen(
                          roomId: roomId,
                          isHost: true,
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  // D. Error Handling
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),

            const SizedBox(height: 20),

            // BUTTON 2: JOIN (Scan QR)
            _buildBigButton(
              context: context,
              icon: Icons.qr_code_scanner_rounded,
              title: "Join a Meal",
              subtitle: "Scan friend's QR code",
              color: Colors.orange.shade700,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const JoinScreen()),
                );
              },
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildBigButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5), width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}