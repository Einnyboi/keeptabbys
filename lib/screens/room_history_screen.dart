import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'lobby_screen.dart';

class RoomHistoryScreen extends StatelessWidget {
  const RoomHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService().currentUser;
    
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Please sign in to view history")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Rooms"),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Query sessions where current user is the host
        stream: FirebaseFirestore.instance
            .collection('sessions')
            .where('hostUid', isEqualTo: currentUser.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final rooms = snapshot.data?.docs ?? [];

          if (rooms.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "No rooms yet",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Host a meal to get started!",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              final data = room.data() as Map<String, dynamic>;
              
              final roomId = data['roomId'] ?? room.id;
              final roomName = data['roomName'] ?? 'Room $roomId';
              final status = data['status'] ?? 'active';
              final createdAt = data['createdAt'] as Timestamp?;
              final billFinalized = data['billFinalized'] ?? false;
              
              // Format date
              String dateStr = 'Unknown date';
              if (createdAt != null) {
                final date = createdAt.toDate();
                dateStr = '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
              }

              // Status color and icon
              Color statusColor;
              IconData statusIcon;
              String statusText;
              
              if (billFinalized) {
                statusColor = Colors.green;
                statusIcon = Icons.check_circle;
                statusText = 'Completed';
              } else if (status == 'active') {
                statusColor = Colors.orange;
                statusIcon = Icons.pending;
                statusText = 'Active';
              } else {
                statusColor = Colors.grey;
                statusIcon = Icons.cancel;
                statusText = status;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(statusIcon, color: statusColor, size: 32),
                  title: Text(
                    roomName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Room Code: $roomId'),
                      Text(dateStr, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    // Navigate to the room
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
                  onLongPress: () {
                    // Edit room name
                    _showEditRoomNameDialog(context, room.id, roomName);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showEditRoomNameDialog(BuildContext context, String docId, String currentName) {
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Room Name"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "Room Name",
            hintText: "e.g. Dinner at Bob's",
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                try {
                  await FirebaseFirestore.instance
                      .collection('sessions')
                      .doc(docId)
                      .update({'roomName': newName});
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Room name updated!")),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: $e")),
                    );
                  }
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
