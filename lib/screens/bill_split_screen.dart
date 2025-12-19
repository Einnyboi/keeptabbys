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

  // Rescan the receipt
  void _rescanReceipt() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rescan Receipt?"),
        content: const Text("This will clear all current assignments. Continue?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Rescan", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Opening camera...")),
      );

      List<BillItem> newItems = await ScannerService().scanAndParse();
      
      if (newItems.isNotEmpty && mounted) {
        setState(() {
          _items = newItems;
          _selectedItemIndex = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Scanned ${newItems.length} items")),
        );
      }
    }
  }

  // Calculate totals per person
  Map<String, double> _calculateTotals() {
    Map<String, double> totals = {};
    for (var item in _items) {
      if (item.assignedToId != null) {
        totals[item.assignedToId!] = (totals[item.assignedToId!] ?? 0) + item.price;
      }
    }
    return totals;
  }

  // Check if all items are assigned
  bool _allItemsAssigned() {
    return _items.every((item) => item.assignedToId != null);
  }

  // Navigate to summary
  void _showSummary() {
    if (!_allItemsAssigned()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please assign all items first!")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BillSummaryScreen(
          roomId: widget.roomId,
          items: _items,
          totals: _calculateTotals(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int assignedCount = _items.where((item) => item.assignedToId != null).length;
    
    return Scaffold(
      appBar: AppBar(
        title: Text("Assign Items ($assignedCount/${_items.length})"),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            tooltip: "Rescan Receipt",
            onPressed: _rescanReceipt,
          ),
        ],
      ),
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
      bottomNavigationBar: _allItemsAssigned()
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _showSummary,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.receipt_long),
                label: const Text(
                  "VIEW SUMMARY",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            )
          : null,
    );
  }
}

// Summary Screen showing per-person totals in cute receipt format
class BillSummaryScreen extends StatelessWidget {
  final String roomId;
  final List<BillItem> items;
  final Map<String, double> totals;

  const BillSummaryScreen({
    super.key,
    required this.roomId,
    required this.items,
    required this.totals,
  });

  @override
  Widget build(BuildContext context) {
    double grandTotal = items.fold(0, (sum, item) => sum + item.price);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bill Summary"),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: LobbyService().getParticipants(roomId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          var people = snapshot.data!.docs;
          
          // Create a map of person ID to name
          Map<String, String> personNames = {};
          for (var person in people) {
            var data = person.data() as Map<String, dynamic>;
            personNames[person.id] = data['displayName'] ?? 'Unknown';
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade400, Colors.teal.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.receipt_long, color: Colors.white, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        "Bill Split Complete!",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Room $roomId",
                        style: const TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Per-Person Breakdown
                ...totals.entries.map((entry) {
                  String personName = personNames[entry.key] ?? 'Unknown';
                  double amount = entry.value;
                  List<BillItem> personItems = items
                      .where((item) => item.assignedToId == entry.key)
                      .toList();

                  return GestureDetector(
                    onTap: () {
                      // Navigate to person detail screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PersonBillDetailScreen(
                            personName: personName,
                            items: personItems,
                            total: amount,
                            roomId: roomId,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                        tilePadding: const EdgeInsets.all(16),
                        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal,
                          child: Text(
                            personName[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          personName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        subtitle: Text(
                          "${personItems.length} item${personItems.length > 1 ? 's' : ''}",
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "\$${amount.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: personItems.map((item) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          "• ${item.name}",
                                          style: TextStyle(color: Colors.grey.shade700),
                                        ),
                                      ),
                                      Text(
                                        "\$${item.price.toStringAsFixed(2)}",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ),
                  );
                }),

                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),

                // Grand Total
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Total Bill",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "\$${grandTotal.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.teal),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.edit, color: Colors.teal),
                        label: const Text(
                          "Edit",
                          style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          // Convert items to Map for Firestore
                          List<Map<String, dynamic>> itemsData = items.map((item) => {
                            'name': item.name,
                            'price': item.price,
                            'assignedToId': item.assignedToId,
                          }).toList();

                          try {
                            await LobbyService().saveBillSplit(
                              roomId: roomId,
                              items: itemsData,
                              totals: totals,
                            );

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("✅ Bill saved! Everyone can now view it."),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              
                              // Navigate back to lobby
                              Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name == 'lobby');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error saving: $e")),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check_circle),
                        label: const Text(
                          "Finalize & Share",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Individual Person's Bill Detail Screen
class PersonBillDetailScreen extends StatelessWidget {
  final String personName;
  final List<BillItem> items;
  final double total;
  final String roomId;

  const PersonBillDetailScreen({
    super.key,
    required this.personName,
    required this.items,
    required this.total,
    required this.roomId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text("$personName's Bill"),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade400, Colors.teal.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: Text(
                      personName[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    personName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${items.length} item${items.length > 1 ? 's' : ''}",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Total: ",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        "\$${total.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Items List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Items",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...items.asMap().entries.map((entry) {
                    int index = entry.key;
                    BillItem item = entry.value;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "${index + 1}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            "\$${item.price.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}