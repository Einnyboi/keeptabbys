import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/lobby_service.dart';
import '../services/auth_service.dart';
import 'join_screen.dart';
import 'lobby_screen.dart';
import 'auth_screen.dart';
import 'room_history_screen.dart';
import '../utils/currency_helper.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService().currentUser;
    // Use display name, or first part of email, or fallback to "Friend"
    final userName = currentUser?.displayName ?? 
                     currentUser?.email?.split('@').first ?? 
                     "Friend";
    final firstWord = userName.split(' ').first;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // 1. HERO AREA (Top 25%)
            _buildHeroArea(context, firstWord),
            
            // 2. HISTORY AREA (Middle 55% - Scrollable)
            Expanded(
              child: _buildHistoryArea(currentUser?.uid),
            ),
            
            // 3. QUICK ACTION AREA (Bottom 20% - Fixed)
            _buildQuickActionArea(context),
          ],
        ),
      ),
    );
  }

  // HERO AREA: Greeting + Profile + Stats
  Widget _buildHeroArea(BuildContext context, String firstName) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade400, Colors.teal.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // Top Row: Greeting + Profile
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Hi, $firstName! 👋",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              GestureDetector(
                onTap: () => _showProfileMenu(context),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  child: Text(
                    firstName[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Stats Card
          _buildStatsCard(),
        ],
      ),
    );
  }

  // Stats Card with gradient background
  Widget _buildStatsCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sessions')
          .where('hostUid', isEqualTo: AuthService().currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        int mealsHosted = 0;
        if (snapshot.hasData) {
          mealsHosted = snapshot.data!.docs.length;
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(Icons.restaurant, "Meals Hosted", mealsHosted.toString()),
              Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
              _buildStatItem(Icons.group, "This Month", mealsHosted.toString()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  // HISTORY AREA: Recent Meals List
  Widget _buildHistoryArea(String? userId) {
    if (userId == null) {
      return const Center(child: Text("Please sign in"));
    }

    return Container(
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text(
              "Recent Meals",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sessions')
                  .where('hostUid', isEqualTo: userId)
                  .limit(10)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final rooms = snapshot.data?.docs ?? [];

                if (rooms.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.restaurant_menu, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          "No meals yet",
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Host your first meal to get started!",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    final data = room.data() as Map<String, dynamic>;
                    
                    final roomId = data['roomId'] ?? room.id;
                    final roomName = data['roomName'] ?? 'Room $roomId';
                    final createdAt = data['createdAt'] as Timestamp?;
                    final billFinalized = data['billFinalized'] ?? false;
                    
                    String dateStr = 'Recently';
                    if (createdAt != null) {
                      final date = createdAt.toDate();
                      final now = DateTime.now();
                      final diff = now.difference(date);
                      
                      if (diff.inDays == 0) {
                        dateStr = 'Today';
                      } else if (diff.inDays == 1) {
                        dateStr = 'Yesterday';
                      } else if (diff.inDays < 7) {
                        dateStr = '${diff.inDays} days ago';
                      } else {
                        dateStr = '${date.day}/${date.month}/${date.year}';
                      }
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: billFinalized ? Colors.green.shade50 : Colors.orange.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            billFinalized ? Icons.check_circle : Icons.pending,
                            color: billFinalized ? Colors.green : Colors.orange,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          roomName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          dateStr,
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LobbyScreen(
                                roomId: roomId,
                                isHost: true,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // QUICK ACTION AREA: Host & Join Buttons
  Widget _buildQuickActionArea(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Primary Button: Host a Meal
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Creating Room...")),
                );

                try {
                  String userName = AuthService().getUserDisplayName() ?? "Host";
                  String roomId = await LobbyService().createSession(hostName: userName);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Text(
                    "Host a Meal",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Secondary Button: Join a Meal
          SizedBox(
            width: double.infinity,
            height: 60,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const JoinScreen()),
                );
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.teal.shade600, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.login, color: Colors.teal.shade600, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    "Join a Meal",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Profile Menu Modal
  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final user = AuthService().currentUser;
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.teal.shade100,
                child: Text(
                  (user?.displayName ?? "?")[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                user?.displayName ?? user?.email?.split('@').first ?? "Unknown",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (user?.email != null)
                Text(
                  user!.email!,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text("Room History"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RoomHistoryScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text("Sign Out", style: TextStyle(color: Colors.red)),
                onTap: () async {
                  // Close the bottom sheet first and capture the navigator
                  final navigator = Navigator.of(context);
                  navigator.pop(); // Close bottom sheet
                  
                  // Show confirmation dialog using the root context
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text("Sign Out?"),
                      content: const Text("Are you sure you want to sign out?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          child: const Text("Sign Out", style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    await AuthService().signOut();
                    // Use pushAndRemoveUntil to clear the navigation stack
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const AuthScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}