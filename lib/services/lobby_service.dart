import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class LobbyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // generate a random 6-digit room code
  String _generateRoomCode() {
    var rng = Random();
    return (100000 + rng.nextInt(900000)).toString();
  }

  // create a new session in Firestore
  Future<String> createSession({required String hostName}) async {
    try {
      String roomId = _generateRoomCode();
      
      // use the roomID as the document ID
      // creates the session main document
      await _db.collection('sessions').doc(roomId).set({
        'roomId': roomId,
        'hostName': hostName,
        'status': 'active', // active, locked, finished
        'createdAt': FieldValue.serverTimestamp(),
        'taxRate': 0.10, // Default 10%
        'serviceCharge': 0.05, // Default 5%
        'items': [], // Placeholder for food items
        'participantIds': [], // Placeholder for users
      });

      // Add the host as the first participant
      await _db.collection('sessions').doc(roomId).collection('participants').add({
        'displayName': hostName,
        'isGuest': false,
        'isHost': true, // This person is the host
        'status': 'active',
        'joinedAt': FieldValue.serverTimestamp(),
        'totalOwed': 0,
      });

      return roomId; // Return the code so UI can show it
    } catch (e) {
      print("Error creating session: $e");
      rethrow;
    }
  }

  Future<void> addManualParticipant({required String roomId, required String name}) async {
    try {
      // We create a sub-collection called 'participants' inside the session
      await _db.collection('sessions').doc(roomId).collection('participants').add({
        'displayName': name,
        'isGuest': true, // Flag to know this isn't a real user account
        'isHost': false,
        'status': 'unpaid', 
        'joinedAt': FieldValue.serverTimestamp(),
        // We will store their items here later
        'totalOwed': 0,
      });
    } catch (e) {
      print("Error adding participant: $e");
      rethrow;
    }
  }
  
  // NEW: Stream to listen to participants (so the UI updates automatically)
  Stream<QuerySnapshot> getParticipants(String roomId) {
    return _db.collection('sessions')
        .doc(roomId)
        .collection('participants')
        .orderBy('joinedAt')
        .snapshots();
  }
 Future<bool> joinSession({required String roomId, required String userName}) async {
    try {
      // 1. Check if the room actually exists
      DocumentSnapshot roomDoc = await _db.collection('sessions').doc(roomId).get();
      
      if (!roomDoc.exists) {
        return false; // Room not found
      }

      // 2. Add them to the participants list
      await _db.collection('sessions').doc(roomId).collection('participants').add({
        'displayName': userName,
        'isGuest': false, // False because they are a real user on their own phone
        'isHost': false,
        'status': 'active',
        'joinedAt': FieldValue.serverTimestamp(),
        'totalOwed': 0,
      });

      return true; // Success
    } catch (e) {
      print("Error joining session: $e");
      rethrow;
    }
  }

  // Save bill split data to Firestore
  Future<void> saveBillSplit({
    required String roomId,
    required List<Map<String, dynamic>> items,
    required Map<String, double> totals,
  }) async {
    try {
      await _db.collection('sessions').doc(roomId).update({
        'billItems': items,
        'billTotals': totals,
        'billFinalized': true,
        'finalizedAt': FieldValue.serverTimestamp(),
      });

      // Update each participant's totalOwed
      for (var entry in totals.entries) {
        await _db
            .collection('sessions')
            .doc(roomId)
            .collection('participants')
            .doc(entry.key)
            .update({'totalOwed': entry.value});
      }
    } catch (e) {
      print("Error saving bill split: $e");
      rethrow;
    }
  }

  // Check if bill has been finalized
  Future<bool> hasBillData(String roomId) async {
    try {
      DocumentSnapshot doc = await _db.collection('sessions').doc(roomId).get();
      if (!doc.exists) return false;
      var data = doc.data() as Map<String, dynamic>?;
      return data?['billFinalized'] == true;
    } catch (e) {
      return false;
    }
  }

  // Get bill data
  Stream<DocumentSnapshot> getBillData(String roomId) {
    return _db.collection('sessions').doc(roomId).snapshots();
  }
}