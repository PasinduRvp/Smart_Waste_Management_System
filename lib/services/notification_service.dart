// lib/services/notification_service.dart (Updated with collection notifications)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initializeNotifications() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    }

    String? token = await _firebaseMessaging.getToken();
    print('FCM Token: $token');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');
    });
  }

  Future<void> sendPaymentStatusNotification({
    required String userId,
    required String userName,
    required String status,
    required String paymentId,
  }) async {
    try {
      String title = '';
      String message = '';

      if (status == 'approved') {
        title = 'Membership Approved! 🎉';
        message = 'Your annual membership payment has been approved. You can now schedule waste pickups.';
      } else if (status == 'rejected') {
        title = 'Membership Payment Rejected';
        message = 'Your payment was rejected. Please contact support for more information.';
      } else {
        title = 'Payment Status Update';
        message = 'Your payment status has been updated to $status';
      }

      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': message,
        'type': 'payment_status',
        'referenceId': paymentId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('Payment notification sent to user: $userId');
    } catch (e) {
      print('Error sending payment notification: $e');
      throw Exception('Failed to send payment notification: $e');
    }
  }

  Future<void> sendNewPaymentNotification({
    required String userName,
    required double amount,
  }) async {
    try {
      final adminSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      for (final adminDoc in adminSnapshot.docs) {
        final adminId = adminDoc.id;
        
        await _firestore.collection('notifications').add({
          'userId': adminId,
          'title': 'New Membership Payment',
          'message': '$userName submitted a membership payment of LKR ${amount.toStringAsFixed(2)}',
          'type': 'new_payment',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      print('New payment notification sent to admins');
    } catch (e) {
      print('Error sending new payment notification: $e');
      throw Exception('Failed to send new payment notification: $e');
    }
  }

  Future<void> sendPickupStatusNotification({
    required String userId,
    required String userName,
    required String status,
    required String pickupId,
  }) async {
    try {
      String message = '';
      String title = '';
      String emoji = '';

      if (status == 'scheduled') {
        emoji = '✅';
        title = 'Pickup Scheduled';
        message = 'Your special pickup request has been approved and assigned to a collector. You will be notified when the collection is completed.';
      } else if (status == 'approved') {
        emoji = '✅';
        title = 'Pickup Request Approved';
        message = 'Your special pickup request has been approved and will be assigned to a collector soon.';
      } else if (status == 'rejected') {
        emoji = '❌';
        title = 'Pickup Request Rejected';
        message = 'Your special pickup request has been rejected. Please contact support for more information.';
      } else if (status == 'collected') {
        emoji = '✅';
        title = 'Pickup Completed';
        message = 'Your special pickup has been completed successfully. Thank you for using our service!';
      } else {
        emoji = 'ℹ️';
        title = 'Pickup Status Update';
        message = 'Your special pickup request status has been updated to $status';
      }

      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': '$emoji $title',
        'message': message,
        'type': 'pickup_status',
        'referenceId': pickupId,
        'isRead': false,
        'metadata': {
          'pickupId': pickupId,
          'status': status,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('Pickup notification sent to user: $userId with status: $status');
    } catch (e) {
      print('Error sending pickup notification: $e');
    }
  }

  // New method for collection notifications
  Future<void> sendCollectionNotification({
    required String userId,
    required String binId,
    required double weight,
    required DateTime timestamp,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': 'Waste Collected Successfully ✅',
        'message': 'Your waste has been collected from Bin $binId. Total weight: ${weight.toStringAsFixed(2)} kg. Thank you for using our service!',
        'type': 'collection',
        'referenceId': binId,
        'isRead': false,
        'metadata': {
          'binId': binId,
          'weight': weight,
          'timestamp': Timestamp.fromDate(timestamp),
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('Collection notification sent to user: $userId');
    } catch (e) {
      print('Error sending collection notification: $e');
    }
  }


  // New method for missed pickup notifications
  Future<void> sendMissedPickupNotification({
    required String userId,
    required String binId,
    required DateTime timestamp,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': 'Pickup Missed',
        'message': 'We missed your scheduled pickup at Bin ID: $binId. Please contact support to reschedule.',
        'type': 'missed_pickup',
        'referenceId': binId,
        'isRead': false,
        'metadata': {
          'binId': binId,
          'timestamp': Timestamp.fromDate(timestamp),
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('Missed pickup notification sent to user: $userId');
    } catch (e) {
      print('Error sending missed pickup notification: $e');
      throw Exception('Failed to send missed pickup notification: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              ...data,
            };
          }).toList();
          
          notifications.sort((a, b) {
            final aTime = a['createdAt'] as Timestamp?;
            final bTime = b['createdAt'] as Timestamp?;
            
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });
          
          return notifications;
        });
  }

  Stream<QuerySnapshot> getUserNotificationsWithOrder(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
      print('Notification marked as read: $notificationId');
    } catch (e) {
      print('Error marking notification as read: $e');
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      final query = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
      print('All notifications marked as read for user: $userId');
    } catch (e) {
      print('Error marking all notifications as read: $e');
      throw Exception('Failed to mark all notifications as read: $e');
    }
  }

  Stream<int> getUnreadNotificationCount(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // NEW: Send task assignment notification to collector
  Future<void> sendTaskAssignmentNotification({
  required String collectorId,
  required String userName,
  required String address,
  required DateTime scheduledDate,
}) async {
  try {
    await _firestore.collection('notifications').add({
      'userId': collectorId,
      'title': 'New Task Assigned',
      'message': 'You have been assigned a pickup for $userName at $address',
      'type': 'task_assigned',
      'metadata': {
        'userName': userName,
        'address': address,
        'scheduledDate': Timestamp.fromDate(scheduledDate),
      },
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    print('Task assignment notification sent to collector: $collectorId');
  } catch (e) {
    print('Error sending task assignment notification: $e');
    throw Exception('Failed to send task assignment notification: $e');
  }
}

  // NEW: Send collection progress notification to admin
  Future<void> sendCollectionProgressNotification({
    required String adminId,
    required String collectorName,
    required String address,
    required double weight,
    required String pickupId,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': adminId,
        'title': 'Collection Completed ✅',
        'message': '$collectorName completed pickup at $address. Weight collected: ${weight.toStringAsFixed(2)} kg',
        'type': 'collection_progress',
        'referenceId': pickupId,
        'isRead': false,
        'metadata': {
          'pickupId': pickupId,
          'collectorName': collectorName,
          'address': address,
          'weight': weight,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('Collection progress notification sent to admin: $adminId');
    } catch (e) {
      print('Error sending collection progress notification: $e');
    }
  }


  // Send collection completion notification

  Future<void> sendRouteStartedNotification({
    required String collectorId,
    required int totalStops,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': collectorId,
        'title': 'Route Started 🚛',
        'message': 'Your route with $totalStops stops has been started. Drive safely!',
        'type': 'route_started',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending route started notification: $e');
    }
  }

  // NEW: Send route completed notification
  Future<void> sendRouteCompletedNotification({
    required String collectorId,
    required int completedStops,
    required int totalStops,
    required double totalWeight,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': collectorId,
        'title': 'Route Completed 🎉',
        'message': 'Great job! You completed $completedStops/$totalStops stops. Total waste collected: ${totalWeight.toStringAsFixed(2)} kg',
        'type': 'route_completed',
        'isRead': false,
        'metadata': {
          'completedStops': completedStops,
          'totalStops': totalStops,
          'totalWeight': totalWeight,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending route completed notification: $e');
    }
  }

  // Add this method to NotificationService
Future<void> sendCollectionCompletionNotification({
  required String userId,
  required String collectorName,
  required String binId,
  required double weight,
  required String address,
  required double amount, // NEW parameter
}) async {
  try {
    await _firestore.collection('notifications').add({
      'userId': userId,
      'title': 'Waste Collection Completed ✅',
      'message': 'Your waste has been collected by $collectorName. '
          'Bin: $binId, Weight: ${weight.toStringAsFixed(2)} kg. '
          'Bill Amount: LKR ${amount.toStringAsFixed(2)}. '
          'Please check your bills section to make payment.',
      'type': 'collection_completed',
      'metadata': {
        'binId': binId,
        'weight': weight,
        'collectorName': collectorName,
        'address': address,
        'amount': amount, // NEW
        'timestamp': Timestamp.fromDate(DateTime.now()),
      },
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    print('Collection completion notification sent to user: $userId');
  } catch (e) {
    print('Error sending collection completion notification: $e');
    throw Exception('Failed to send collection completion notification: $e');
  }
}
}