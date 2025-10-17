// services/pickup_service.dart (Updated)
import 'package:cloud_firestore/cloud_firestore.dart';

class PickupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> scheduleSpecialPickup({
    required String userId,
    required String userName,
    required String userEmail,
    required String wasteType,
    required String description,
    required DateTime scheduledDate,
    required Map<String, dynamic> location,
    required String address,
    required double estimatedAmount, // NEW: Waste amount field
  }) async {
    try {
      await _firestore.collection('special_pickups').add({
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'wasteType': wasteType,
        'description': description,
        'scheduledDate': Timestamp.fromDate(scheduledDate),
        'location': location,
        'address': address,
        'estimatedAmount': estimatedAmount, // NEW
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'approvedAt': null,
        'approvedBy': null,
        'actualAmount': null, // Will be filled by collector
        'collectionDate': null, // Will be filled by collector
        'billStatus': 'pending', // pending, paid, overdue
        'billGeneratedAt': null,
      });
    } catch (e) {
      throw Exception('Failed to schedule special pickup: $e');
    }
  }

  // Update method for collector to complete pickup
  Future<void> completePickup({
    required String pickupId,
    required String collectorId,
    required String collectorName,
    required double actualAmount,
    required String binId,
    required double weight,
    required String notes,
  }) async {
    try {
      await _firestore.collection('special_pickups').doc(pickupId).update({
        'status': 'completed',
        'collectorId': collectorId,
        'collectorName': collectorName,
        'actualAmount': actualAmount,
        'binId': binId,
        'collectedWeight': weight,
        'collectorNotes': notes,
        'collectionDate': FieldValue.serverTimestamp(),
        'billStatus': 'pending',
        'billGeneratedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to complete pickup: $e');
    }
  }

  // Get completed pickups with bills
  Stream<List<Map<String, dynamic>>> getCompletedPickupsWithBills(String userId) {
    return _firestore
        .collection('special_pickups')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'completed')
        .orderBy('collectionDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            ...data,
          };
        }).toList());
  }

  // Update bill status
  Future<void> updateBillStatus(String pickupId, String billStatus) async {
    try {
      await _firestore.collection('special_pickups').doc(pickupId).update({
        'billStatus': billStatus,
        'billPaidAt': billStatus == 'paid' ? FieldValue.serverTimestamp() : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update bill status: $e');
    }
  }

  // Add payment slip
  Future<void> addPaymentSlip(String pickupId, String slipUrl) async {
    try {
      await _firestore.collection('special_pickups').doc(pickupId).update({
        'paymentSlipUrl': slipUrl,
        'billStatus': 'paid',
        'billPaidAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to add payment slip: $e');
    }
  }

  // Rest of existing methods remain the same...
  // Returns a list-mapped stream of pending special pickups
  Stream<List<Map<String, dynamic>>> getPendingSpecialPickups() {
    return _firestore
        .collection('special_pickups')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList());
  }

  // Alias for compatibility with views expecting this name
  Stream<List<Map<String, dynamic>>> getPendingSpecialPickupsList() {
    return getPendingSpecialPickups();
  }


  Future<void> updateSpecialPickupStatus(
    String pickupId, 
    String status, 
    String approvedBy
  ) async {
    try {
      await _firestore.collection('special_pickups').doc(pickupId).update({
        'status': status,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': approvedBy,
      });
    } catch (e) {
      throw Exception('Failed to update pickup status: $e');
    }
  }

  Future<Map<String, int>> getUserPickupStatistics(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('special_pickups')
          .where('userId', isEqualTo: userId)
          .get();

      final pickups = querySnapshot.docs;
      
      return {
        'total': pickups.length,
        'scheduled': pickups.where((doc) => doc['status'] == 'scheduled').length,
        'collected': pickups.where((doc) => doc['status'] == 'completed').length,
        'missed': pickups.where((doc) => doc['status'] == 'missed').length,
      };
    } catch (e) {
      throw Exception('Failed to get pickup statistics: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getUserPickups(String userId) {
    return _firestore
        .collection('special_pickups')
        .where('userId', isEqualTo: userId)
        .orderBy('scheduledDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'wasteType': data['wasteType'] ?? '',
            'status': data['status'] ?? 'pending',
            'scheduledDate': (data['scheduledDate'] as Timestamp).toDate(),
            'address': data['address'] ?? '',
            'description': data['description'] ?? '',
            'estimatedAmount': data['estimatedAmount'] ?? 0.0,
            'actualAmount': data['actualAmount'] ?? 0.0,
            'billStatus': data['billStatus'] ?? 'pending',
          };
        }).toList());
  }
}