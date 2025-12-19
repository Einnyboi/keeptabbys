import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/scanner_service.dart';
import '../services/lobby_service.dart';

class BillSplitScreen extends StatefulWidget {
  final String roomId;
  final List<BillItem> initialItems;

  const BillSplitScreen({super.key, required this.roomId, required this.initialItems});

  @override
  State<BillSplitScreen> createState() => _BillSplitScreenState();
}

class _BillSplitScreenState extends State<BillSplitScreen> {
  // Local state for items so we can assign them before saving
  late List<BillItem> _items;
  int? _selectedItemIndex; // Which item is currently highlighted?

  @override
  void initState() {
    super.initState();
    _items = widget.initialItems;
  }

  // LOGIC: Assign the currently selected item to a person
  void _assignToPerson(String personId, String personName) {
    if (_selectedItemIndex == null) return;

    setState(() {
      _items[_selectedItemIndex!].assignedToId = personId;
      // Auto-advance to next unassigned item for speed
      _selectNextUnassigned();
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Assigned to $personName"), 
        duration: const Duration(milliseconds: 500)
      ),
    );
  }

  void _selectNextUnassigned() {
    // Find the next index that has no owner
    int nextIndex = _items.indexWhere((item) => item.assignedToId == null);
    if (nextIndex != -1) {
      setState(() => _selectedItemIndex = nextIndex);
    } else {
      setState(() => _selectedItemIndex = null); // All done!
    }
  }

  // TODO: Add "Save/Finalize" Logic here later

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Assign Items")),
      body: Column(
        children: [
          // 1. ITEMS LIST (Top Half)
          Expanded(
            flex: 3,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final isSelected = index == _selectedItemIndex;
                final isAssigned = item.assignedToId != null;

                return GestureDetector(
                  onTap: () => setState(() => _selectedItemIndex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Colors.teal.shade50 
                          : (isAssigned ? Colors.grey.shade100 : Colors.white),
                      border: Border.all(
                        color: isSelected ? Colors.teal : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isSelected ? [] : [
                         BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isAssigned ? Colors.grey : Colors.black,
                            ),
                          ),
                        ),
                        Text(
                          "\$${item.price.toStringAsFixed(2)}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (isAssigned) 
                          const Padding(
                            padding: EdgeInsets.only(left: 8.0),
                            child: Icon(Icons.check_circle, color: Colors.green, size: 16),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. INSTRUCTIONS
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            width: double.infinity,
            color: Colors.grey.shade200,
            child: Text(
              _selectedItemIndex == null 
                  ? "Tap an item above to select it" 
                  : "Now tap a person below to assign",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),

          // 3. PEOPLE SELECTOR (Bottom Half)
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              child: StreamBuilder<QuerySnapshot>(
                stream: LobbyService().getParticipants(widget.roomId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  
                  var people = snapshot.data!.docs;

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, // 3 people per row
                      childAspectRatio: 1.0,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: people.length,
                    itemBuilder: (context, index) {
                      var person = people[index];
                      var personId = person.id; // Document ID from Firestore
                      var personName = person['displayName'];

                      return InkWell(
                        onTap: () => _assignToPerson(personId, personName),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.teal.withOpacity(0.3)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                child: Text(personName[0].toUpperCase()),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                personName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}