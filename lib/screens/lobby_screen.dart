import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/lobby_service.dart';
import '../services/scanner_service.dart';
import 'bill_split_screen.dart';

class LobbyScreen extends StatefulWidget {
  final String roomId;
  final bool isHost;

  const LobbyScreen({
    super.key,
    required this.roomId,
    this.isHost = false,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final TextEditingController _nameController = TextEditingController();

  // Function to launch Camera
  void _scanReceipt() async {
    // 1. Show Loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Processing Receipt...")),
    );

    // 2. Call the NEW Parser
    List<BillItem> items = await ScannerService().scanAndParse();

    if (items.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      // 3. Navigate to Split Screen with the data
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BillSplitScreen(
            roomId: widget.roomId, 
            initialItems: items
          ),
        ),
      );
    } else {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Could not read receipt price data.")),
         );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Room: ${widget.roomId}"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. Header with Room Code
          Container(
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
                Row(
                  children: [
                    const Icon(Icons.group, color: Colors.white, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isHost ? "Your Meal Room" : "Joined Room",
                            style: const TextStyle(fontSize: 16, color: Colors.white70),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                "Room ${widget.roomId}",
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (widget.isHost)
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: widget.roomId));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Room code copied!"),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.copy, size: 14, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text(
                                          "Copy",
                                          style: TextStyle(fontSize: 12, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.isHost) ..[
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.white70),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Share this code with friends so they can join!",
                          style: TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ] else ..[
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Icon(Icons.hourglass_empty, size: 16, color: Colors.white70),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Waiting for host to scan the receipt...",
                          style: TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // 2. The List of People
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: LobbyService().getParticipants(widget.roomId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var people = snapshot.data!.docs;
                if (people.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          widget.isHost 
                            ? "No one here yet!\nShare the room code with friends"
                            : "Waiting for others to join...",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        "People in this meal (${people.length})",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: people.length,
                        itemBuilder: (context, index) {
                          var person = people[index];
                          bool isHost = person['isHost'] ?? false;
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            elevation: 0,
                            color: Colors.grey.shade50,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isHost ? Colors.teal : Colors.orange.shade200,
                                child: Text(
                                  person['displayName'][0].toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    person['displayName'],
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  if (isHost) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.teal,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        "HOST",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                person['status'] ?? 'Ready',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                              trailing: Icon(Icons.check_circle, color: Colors.green.shade400, size: 20),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // 3. Add Person Input (Only for Host - for offline friends)
          if (widget.isHost)
            Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.person_add_outlined, size: 18, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(
                        "Add someone without the app",
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: "Name (e.g. Budi)",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FloatingActionButton.small(
                        onPressed: () {
                          if (_nameController.text.isNotEmpty) {
                            LobbyService().addManualParticipant(
                              roomId: widget.roomId,
                              name: _nameController.text.trim(),
                            );
                            _nameController.clear();
                          }
                        },
                        backgroundColor: Colors.teal,
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
      
      // 4. BIG SCAN BUTTON (Only shows for Host)
      bottomNavigationBar: widget.isHost ? Padding(
        padding: const EdgeInsets.all(24.0),
        child: ElevatedButton.icon(
          onPressed: _scanReceipt, // <--- Calls the camera
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 5,
          ),
          icon: const Icon(Icons.camera_alt_rounded, size: 28),
          label: const Text("SCAN RECEIPT", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ) : null,
    );
  }
}