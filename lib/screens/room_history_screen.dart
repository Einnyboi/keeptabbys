import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'lobby_screen.dart';

class RoomHistoryScreen extends StatefulWidget {
  const RoomHistoryScreen({super.key});

  @override
  State<RoomHistoryScreen> createState() => _RoomHistoryScreenState();
}

class _RoomHistoryScreenState extends State<RoomHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Hosted", icon: Icon(Icons.stars)),
            Tab(text: "Joined", icon: Icon(Icons.group)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHostedRooms(currentUser.uid),
          _buildJoinedRooms(currentUser.uid),
        ],
      ),
    );
  }

  // Build list of rooms user created as host
  Widget _buildHostedRooms(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sessions')
          .where('hostUid', isEqualTo: userId)
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
                Icon(Icons.stars, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  "No hosted rooms yet",
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

        return _buildRoomList(rooms, isHost: true);
      },
    );
  }

  // Build list of rooms user joined as participant
  Widget _buildJoinedRooms(String userId) {
    return StreamBuilder<QuerySnapshot>(
      // Use collection group query to find all participants where userId matches
      stream: FirebaseFirestore.instance
          .collectionGroup('participants')
          .where('userId', isEqualTo: userId)
          .where('isHost', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final participants = snapshot.data?.docs ?? [];

        if (participants.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  "No joined rooms yet",
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  "Join a room to see it here!",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // Extract room IDs from the participants' parent paths
        final roomIds = participants.map((doc) {
          // Path is like: sessions/{roomId}/participants/{participantId}
          final path = doc.reference.path;
          final parts = path.split('/');
          return parts[1]; // Room ID is the second part
        }).toSet().toList(); // Use Set to remove duplicates

        // Now fetch the actual session documents
        return FutureBuilder<List<DocumentSnapshot>>(
          future: _fetchSessions(roomIds),
          builder: (context, sessionSnapshot) {
            if (sessionSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (sessionSnapshot.hasError) {
              return Center(child: Text("Error: ${sessionSnapshot.error}"));
            }

            final rooms = sessionSnapshot.data ?? [];

            if (rooms.isEmpty) {
              return const Center(child: Text("No rooms found"));
            }

            return _buildRoomList(rooms, isHost: false);
          },
        );
      },
    );
  }

  // Fetch session documents by room IDs
  Future<List<DocumentSnapshot>> _fetchSessions(List<String> roomIds) async {
    if (roomIds.isEmpty) return [];
    
    List<DocumentSnapshot> sessions = [];
    for (String roomId in roomIds) {
      final doc = await FirebaseFirestore.instance
          .collection('sessions')
          .doc(roomId)
          .get();
      if (doc.exists) {
        sessions.add(doc);
      }
    }
    return sessions;
  }

  // Build the actual room list UI (shared between both tabs)
  Widget _buildRoomList(List<DocumentSnapshot> rooms, {required bool isHost}) {
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
        final hostName = data['hostName'] ?? 'Unknown';
        
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
                if (!isHost) Text('Host: $hostName', style: const TextStyle(fontSize: 12)),
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
                    isHost: isHost,
                  ),
                ),
              );
            },
            onLongPress: isHost ? () {
              // Only hosts can edit room name
              _showEditRoomNameDialog(context, room.id, roomName);
            } : null,
          ),
        );
      },
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
