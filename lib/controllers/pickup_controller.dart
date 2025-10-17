import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:rxdart/rxdart.dart';

class PickupController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get user pickup statistics with better error handling
  Future<Map<String, int>> getUserPickupStatistics(String userId) async {
    try {
      developer.log('Fetching pickup statistics for user: $userId', name: 'PickupController');
      
      if (userId.isEmpty) {
        developer.log('User ID is empty', name: 'PickupController');
        return _getDefaultStats();
      }

      // Try to get regular pickups
      final regularSnapshot = await _firestore
          .collection('pickups')
          .where('userId', isEqualTo: userId)
          .get()
          .timeout(const Duration(seconds: 10));

      // Try to get special pickups
      final specialSnapshot = await _firestore
          .collection('special_pickups')
          .where('userId', isEqualTo: userId)
          .get()
          .timeout(const Duration(seconds: 10));

      // Combine both collections
      final allPickups = [...regularSnapshot.docs, ...specialSnapshot.docs];
      
      developer.log('Found ${allPickups.length} total pickups for user $userId', name: 'PickupController');

      int total = allPickups.length;
      int scheduled = 0;
      int collected = 0;
      int missed = 0;

      for (var doc in allPickups) {
        final status = doc['status']?.toString().toLowerCase() ?? 'pending';
        developer.log('Pickup ${doc.id} status: $status', name: 'PickupController');
        
        if (status == 'scheduled' || status == 'approved') {
          scheduled++;
        } else if (status == 'collected' || status == 'completed') {
          collected++;
        } else if (status == 'missed' || status == 'cancelled' || status == 'rejected') {
          missed++;
        }
      }

      final stats = {
        'total': total,
        'scheduled': scheduled,
        'collected': collected,
        'missed': missed,
      };

      developer.log('Final statistics: $stats', name: 'PickupController');
      return stats;

    } catch (e) {
      developer.log('Error getting pickup statistics: $e', name: 'PickupController');
      return _getDefaultStats();
    }
  }

  Map<String, int> _getDefaultStats() {
    return {
      'total': 0,
      'scheduled': 0,
      'collected': 0,
      'missed': 0,
    };
  }

  /// Get user pickups stream with better error handling
  Stream<List<PickupItem>> getUserPickups(String userId) {
    if (userId.isEmpty) {
      developer.log('User ID is empty in getUserPickups', name: 'PickupController');
      return Stream.value([]);
    }

    try {
      return _firestore
          .collection('pickups')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .handleError((error) {
            developer.log('Error in getUserPickups stream: $error', name: 'PickupController');
            return [];
          })
          .map((snapshot) {
            final pickups = snapshot.docs.map((doc) {
              return _createPickupItemFromDoc(doc, 'regular');
            }).toList();
            
            // Sort by scheduledDate descending
            pickups.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
            developer.log('Loaded ${pickups.length} regular pickups', name: 'PickupController');
            return pickups;
          });
    } catch (e) {
      developer.log('Error creating getUserPickups stream: $e', name: 'PickupController');
      return Stream.value([]);
    }
  }

  /// Get user special pickups stream with better error handling
  Stream<List<PickupItem>> getUserSpecialPickups(String userId) {
    if (userId.isEmpty) {
      return Stream.value([]);
    }

    try {
      return _firestore
          .collection('special_pickups')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .handleError((error) {
            developer.log('Error in getUserSpecialPickups stream: $error', name: 'PickupController');
            return [];
          })
          .map((snapshot) {
            final pickups = snapshot.docs.map((doc) {
              return _createPickupItemFromDoc(doc, 'special');
            }).toList();
            
            // Sort by scheduledDate descending
            pickups.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
            developer.log('Loaded ${pickups.length} special pickups', name: 'PickupController');
            return pickups;
          });
    } catch (e) {
      developer.log('Error creating getUserSpecialPickups stream: $e', name: 'PickupController');
      return Stream.value([]);
    }
  }

  /// Get today's pickups for a collector
  Stream<List<PickupItem>> getTodayPickupsForCollector(String collectorId) {
    if (collectorId.isEmpty) {
      developer.log('Collector ID is empty', name: 'PickupController');
      return Stream.value([]);
    }

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // Get regular pickups for today
      final regularStream = _firestore
          .collection('pickups')
          .where('collectorId', isEqualTo: collectorId)
          .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('scheduledDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => _createPickupItemFromDoc(doc, 'regular'))
              .toList());

      // Get special pickups for today
      final specialStream = _firestore
          .collection('special_pickups')
          .where('collectorId', isEqualTo: collectorId)
          .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('scheduledDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => _createPickupItemFromDoc(doc, 'special'))
              .toList());

      return CombineLatestStream.combine2<List<PickupItem>, List<PickupItem>, List<PickupItem>>(
        regularStream,
        specialStream,
        (regular, special) {
          final allPickups = [...regular, ...special];
          allPickups.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
          developer.log('Found ${allPickups.length} pickups for today for collector $collectorId', 
              name: 'PickupController');
          return allPickups;
        },
      ).handleError((error) {
        developer.log('Error in getTodayPickupsForCollector: $error', name: 'PickupController');
        return <PickupItem>[];
      });
    } catch (e) {
      developer.log('Error creating getTodayPickupsForCollector stream: $e', name: 'PickupController');
      return Stream.value([]);
    }
  }

  /// Get all pickups assigned to a collector
  Stream<List<PickupItem>> getCollectorPickups(String collectorId) {
    if (collectorId.isEmpty) {
      return Stream.value([]);
    }

    try {
      final regularStream = _firestore
          .collection('pickups')
          .where('collectorId', isEqualTo: collectorId)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => _createPickupItemFromDoc(doc, 'regular'))
              .toList());

      final specialStream = _firestore
          .collection('special_pickups')
          .where('collectorId', isEqualTo: collectorId)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => _createPickupItemFromDoc(doc, 'special'))
              .toList());

      return CombineLatestStream.combine2<List<PickupItem>, List<PickupItem>, List<PickupItem>>(
        regularStream,
        specialStream,
        (regular, special) {
          final allPickups = [...regular, ...special];
          allPickups.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
          developer.log('Found ${allPickups.length} total pickups for collector $collectorId', 
              name: 'PickupController');
          return allPickups;
        },
      ).handleError((error) {
        developer.log('Error in getCollectorPickups: $error', name: 'PickupController');
        return <PickupItem>[];
      });
    } catch (e) {
      developer.log('Error creating getCollectorPickups stream: $e', name: 'PickupController');
      return Stream.value([]);
    }
  }

  /// Get pending/scheduled pickups for collector
  Stream<List<PickupItem>> getPendingPickupsForCollector(String collectorId) {
    if (collectorId.isEmpty) {
      return Stream.value([]);
    }

    try {
      final regularStream = _firestore
          .collection('pickups')
          .where('collectorId', isEqualTo: collectorId)
          .where('status', whereIn: ['pending', 'scheduled', 'approved'])
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => _createPickupItemFromDoc(doc, 'regular'))
              .toList());

      final specialStream = _firestore
          .collection('special_pickups')
          .where('collectorId', isEqualTo: collectorId)
          .where('status', whereIn: ['pending', 'scheduled', 'approved'])
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => _createPickupItemFromDoc(doc, 'special'))
              .toList());

      return CombineLatestStream.combine2<List<PickupItem>, List<PickupItem>, List<PickupItem>>(
        regularStream,
        specialStream,
        (regular, special) {
          final allPickups = [...regular, ...special];
          allPickups.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
          return allPickups;
        },
      ).handleError((error) {
        developer.log('Error in getPendingPickupsForCollector: $error', name: 'PickupController');
        return <PickupItem>[];
      });
    } catch (e) {
      developer.log('Error creating getPendingPickupsForCollector stream: $e', name: 'PickupController');
      return Stream.value([]);
    }
  }

  /// Get collector statistics
  Future<Map<String, int>> getCollectorStatistics(String collectorId) async {
    try {
      if (collectorId.isEmpty) {
        return _getDefaultStats();
      }

      final regularSnapshot = await _firestore
          .collection('pickups')
          .where('collectorId', isEqualTo: collectorId)
          .get()
          .timeout(const Duration(seconds: 10));

      final specialSnapshot = await _firestore
          .collection('special_pickups')
          .where('collectorId', isEqualTo: collectorId)
          .get()
          .timeout(const Duration(seconds: 10));

      final allPickups = [...regularSnapshot.docs, ...specialSnapshot.docs];

      int total = allPickups.length;
      int scheduled = 0;
      int collected = 0;
      int missed = 0;

      for (var doc in allPickups) {
        final status = doc['status']?.toString().toLowerCase() ?? 'pending';
        
        if (status == 'scheduled' || status == 'approved' || status == 'pending') {
          scheduled++;
        } else if (status == 'collected' || status == 'completed') {
          collected++;
        } else if (status == 'missed' || status == 'cancelled' || status == 'rejected') {
          missed++;
        }
      }

      return {
        'total': total,
        'scheduled': scheduled,
        'collected': collected,
        'missed': missed,
      };
    } catch (e) {
      developer.log('Error getting collector statistics: $e', name: 'PickupController');
      return _getDefaultStats();
    }
  }

  /// Helper method to create PickupItem from document
  PickupItem _createPickupItemFromDoc(DocumentSnapshot doc, String pickupType) {
    try {
      Timestamp? scheduledDate = doc['scheduledDate'];
      Timestamp? createdAt = doc['createdAt'];
      Timestamp? collectionDate = doc['collectionDate'];
      
      return PickupItem(
        id: doc.id,
        wasteType: doc['wasteType']?.toString() ?? 'general',
        status: doc['status']?.toString() ?? 'pending',
        scheduledDate: scheduledDate?.toDate() ?? DateTime.now(),
        address: doc['address']?.toString() ?? 'No address provided',
        binId: doc['binId']?.toString() ?? '',
        pickupType: pickupType,
        description: doc['description']?.toString() ?? '',
        createdAt: createdAt?.toDate() ?? DateTime.now(),
        userId: doc['userId']?.toString() ?? '',
        collectorId: doc['collectorId']?.toString() ?? '',
        notes: doc['notes']?.toString() ?? '',
        actualAmount: (doc.data() as Map<String, dynamic>?)?['actualAmount'] is num
            ? ((doc.data() as Map<String, dynamic>)['actualAmount'] as num).toDouble()
            : null,
        collectedWeight: (doc.data() as Map<String, dynamic>?)?['collectedWeight'] is num
            ? ((doc.data() as Map<String, dynamic>)['collectedWeight'] as num).toDouble()
            : null,
        billStatus: (doc.data() as Map<String, dynamic>?)?['billStatus']?.toString(),
        collectionDate: collectionDate?.toDate(),
      );
    } catch (e) {
      developer.log('Error creating PickupItem from doc ${doc.id}: $e', name: 'PickupController');
      // Return a default pickup item
      return PickupItem(
        id: doc.id,
        wasteType: 'general',
        status: 'pending',
        scheduledDate: DateTime.now(),
        address: 'Unknown address',
        binId: '',
        pickupType: pickupType,
        description: 'Error loading pickup details',
        createdAt: DateTime.now(),
        userId: '',
        collectorId: '',
        notes: 'Error loading pickup',
      );
    }
  }

  /// Get combined pickups (regular + special)
  Stream<List<PickupItem>> getCombinedUserPickups(String userId) {
    if (userId.isEmpty) return Stream.value([]);

    return CombineLatestStream.combine2<List<PickupItem>, List<PickupItem>, List<PickupItem>>(
      getUserPickups(userId),
      getUserSpecialPickups(userId),
      (regularPickups, specialPickups) {
        final allPickups = [...regularPickups, ...specialPickups];
        allPickups.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
        developer.log('Combined ${allPickups.length} total pickups', name: 'PickupController');
        return allPickups;
      },
    ).handleError((error) {
      developer.log('Error in combined pickups stream: $error', name: 'PickupController');
      return <PickupItem>[];
    });
  }

  /// Create a new pickup request
  Future<bool> createPickupRequest({
    required String userId,
    required String wasteType,
    required DateTime scheduledDate,
    required String address,
    required String description,
    String? binId,
    String pickupType = 'regular',
  }) async {
    try {
      final pickupData = {
        'userId': userId,
        'wasteType': wasteType,
        'status': 'pending',
        'scheduledDate': Timestamp.fromDate(scheduledDate),
        'address': address,
        'description': description,
        'binId': binId ?? '',
        'pickupType': pickupType,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (pickupType == 'regular') {
        await _firestore.collection('pickups').add(pickupData);
      } else {
        await _firestore.collection('special_pickups').add(pickupData);
      }

      developer.log('Pickup request created successfully', name: 'PickupController');
      return true;
    } catch (e) {
      developer.log('Error creating pickup request: $e', name: 'PickupController');
      return false;
    }
  }

  /// Update pickup status
  Future<bool> updatePickupStatus({
    required String pickupId,
    required String status,
    required String pickupType,
    String? collectorId,
    String? notes,
  }) async {
    try {
      final updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (collectorId != null) {
        updateData['collectorId'] = collectorId;
      }
      if (notes != null) {
        updateData['notes'] = notes;
      }

      final collection = pickupType == 'regular' ? 'pickups' : 'special_pickups';
      await _firestore.collection(collection).doc(pickupId).update(updateData);

      developer.log('Pickup status updated to $status', name: 'PickupController');
      return true;
    } catch (e) {
      developer.log('Error updating pickup status: $e', name: 'PickupController');
      return false;
    }
  }

  /// Assign pickup to collector
  Future<bool> assignPickupToCollector({
    required String pickupId,
    required String collectorId,
    required String pickupType,
  }) async {
    try {
      final collection = pickupType == 'regular' ? 'pickups' : 'special_pickups';
      await _firestore.collection(collection).doc(pickupId).update({
        'collectorId': collectorId,
        'status': 'scheduled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      developer.log('Pickup assigned to collector $collectorId', name: 'PickupController');
      return true;
    } catch (e) {
      developer.log('Error assigning pickup to collector: $e', name: 'PickupController');
      return false;
    }
  }
}

class PickupItem {
  final String id;
  final String wasteType;
  final String status;
  final DateTime scheduledDate;
  final String address;
  final String binId;
  final String pickupType;
  final String description;
  final DateTime createdAt;
  final String userId;
  final String collectorId;
  final String notes;
  // NEW: Billing/collection fields
  final double? actualAmount; // Bill amount when completed
  final double? collectedWeight; // Collected weight (kg)
  final String? billStatus; // pending/paid/overdue
  final DateTime? collectionDate; // when collected

  PickupItem({
    required this.id,
    required this.wasteType,
    required this.status,
    required this.scheduledDate,
    required this.address,
    required this.binId,
    required this.pickupType,
    required this.description,
    required this.createdAt,
    required this.userId,
    required this.collectorId,
    required this.notes,
    this.actualAmount,
    this.collectedWeight,
    this.billStatus,
    this.collectionDate,
  });

  String get displayStatus {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'scheduled':
        return 'Scheduled';
      case 'approved':
        return 'Approved';
      case 'collected':
        return 'Collected';
      case 'completed':
        return 'Completed';
      case 'missed':
        return 'Missed';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'scheduled':
      case 'approved':
        return Colors.blue;
      case 'collected':
      case 'completed':
        return Colors.green;
      case 'missed':
      case 'rejected':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String get displayWasteType {
    switch (wasteType.toLowerCase()) {
      case 'general':
        return 'General Waste';
      case 'recyclable':
        return 'Recyclable Waste';
      case 'organic':
        return 'Organic Waste';
      case 'hazardous':
        return 'Hazardous Waste';
      case 'bulky items':
        return 'Bulky Items';
      case 'e-waste':
        return 'E-Waste';
      case 'construction waste':
        return 'Construction Waste';
      case 'garden waste':
        return 'Garden Waste';
      default:
        return wasteType;
    }
  }

  IconData get statusIcon {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending_actions;
      case 'scheduled':
      case 'approved':
        return Icons.schedule;
      case 'collected':
      case 'completed':
        return Icons.check_circle;
      case 'missed':
      case 'rejected':
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  bool get isUpcoming {
    return scheduledDate.isAfter(DateTime.now()) && 
           (status == 'pending' || status == 'scheduled' || status == 'approved');
  }

  bool get isCompleted {
    return status == 'collected' || status == 'completed';
  }

  bool get isCancelled {
    return status == 'missed' || status == 'rejected' || status == 'cancelled';
  }

  // Helper method to format date for display
  String get formattedDate {
    return '${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year}';
  }

  // Helper method to format time for display
  String get formattedTime {
    return '${scheduledDate.hour.toString().padLeft(2, '0')}:${scheduledDate.minute.toString().padLeft(2, '0')}';
  }
}