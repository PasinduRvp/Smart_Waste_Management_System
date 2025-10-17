import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_waste_management/services/cloudinary_service.dart';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudinaryService _cloudinaryService = CloudinaryService();

  // Get pending payments with error handling for index issues
  Stream<QuerySnapshot> getPendingPayments() {
    try {
      return _firestore
          .collection('payments')
          .where('status', isEqualTo: 'pending')
          .orderBy('submittedAt', descending: true)
          .snapshots();
    } catch (e) {
      // Fallback without ordering if index not ready
      print('Index error, using fallback query: $e');
      return _firestore
          .collection('payments')
          .where('status', isEqualTo: 'pending')
          .snapshots();
    }
  }

  // Get all payments for a user with error handling
  Stream<QuerySnapshot> getUserPayments(String userId) {
    try {
      return _firestore
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .orderBy('submittedAt', descending: true)
          .snapshots();
    } catch (e) {
      print('Index error, using fallback query: $e');
      return _firestore
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .snapshots();
    }
  }

  // Get user's latest payment with error handling
  Stream<Map<String, dynamic>?> getUserLatestPayment(String userId) {
    try {
      return _firestore
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .orderBy('submittedAt', descending: true)
          .limit(1)
          .snapshots()
          .map((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          return snapshot.docs.first.data();
        }
        return null;
      });
    } catch (e) {
      print('Index error, using fallback query: $e');
      return _firestore
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .map((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          // Manually find latest by submittedAt
          var latestDoc = snapshot.docs.reduce((curr, next) {
            final currTime = curr['submittedAt'] ?? Timestamp.now();
            final nextTime = next['submittedAt'] ?? Timestamp.now();
            return currTime.compareTo(nextTime) > 0 ? curr : next;
          });
          return latestDoc.data();
        }
        return null;
      });
    }
  }

  // Rest of your PaymentService methods remain the same...
  Stream<DocumentSnapshot> getPaymentStatus(String userId) {
    return _firestore
        .collection('payments')
        .doc(userId)
        .snapshots();
  }

  Stream<Map<String, dynamic>> getUserMembershipDetails(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        return {
          'status': data['membershipStatus'] ?? 'inactive',
          'updatedAt': data['membershipUpdatedAt'],
        };
      }
      return {'status': 'inactive'};
    });
  }

  Future<Map<String, dynamic>> getUserMembershipStatus(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        return {
          'status': userData['membershipStatus'] ?? 'inactive',
          'updatedAt': userData['membershipUpdatedAt'],
        };
      }
      return {'status': 'inactive'};
    } catch (e) {
      throw Exception('Failed to get membership status: $e');
    }
  }

  Future<String> uploadPaymentSlip(XFile image) async {
    try {
      final imageUrl = await _cloudinaryService.uploadImage(image, 'payment_slips');
      if (imageUrl == null) {
        throw Exception('Failed to upload payment slip');
      }
      return imageUrl;
    } catch (e) {
      throw Exception('Failed to upload payment slip: $e');
    }
  }

  Future<void> submitPayment({
    required String userId,
    required String userName,
    required String userEmail,
    required String fullName,
    required String nic,
    required String address,
    required String phone,
    required double amount,
    required String paymentMethod,
    required String slipImageUrl,
  }) async {
    try {
      await _firestore.collection('payments').doc(userId).set({
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'fullName': fullName,
        'nic': nic,
        'address': address,
        'phone': phone,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'slipImageUrl': slipImageUrl,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('users').doc(userId).update({
        'membershipStatus': 'pending',
        'paymentSubmitted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to submit payment: $e');
    }
  }

  Future<void> updatePaymentStatus(
    String paymentId,
    String status,
    String adminId,
  ) async {
    try {
      final paymentDoc = await _firestore.collection('payments').doc(paymentId).get();
      final paymentData = paymentDoc.data();
      final userId = paymentData?['userId'];

      if (userId == null) {
        throw Exception('User ID not found in payment data');
      }

      await _firestore.collection('payments').doc(paymentId).update({
        'status': status,
        'reviewedBy': adminId,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      String membershipStatus = status == 'approved' ? 'active' : 'inactive';
      
      await _firestore.collection('users').doc(userId).update({
        'membershipStatus': membershipStatus,
        'membershipUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _createPaymentStatusNotification(userId, status);

    } catch (e) {
      throw Exception('Failed to update payment status: $e');
    }
  }

  Future<void> _createPaymentStatusNotification(String userId, String status) async {
    String title = '';
    String message = '';

    if (status == 'approved') {
      title = 'Membership Approved! 🎉';
      message = 'Your membership payment has been approved. You can now schedule waste pickups.';
    } else if (status == 'rejected') {
      title = 'Membership Payment Rejected';
      message = 'Your membership payment was rejected. Please contact support for more information.';
    }

    await _firestore.collection('notifications').add({
      'userId': userId,
      'title': title,
      'message': message,
      'type': 'payment_status',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, int>> getPaymentStatistics() async {
    try {
      final pendingQuery = await _firestore
          .collection('payments')
          .where('status', isEqualTo: 'pending')
          .get();
      
      final approvedQuery = await _firestore
          .collection('payments')
          .where('status', isEqualTo: 'approved')
          .get();
      
      final rejectedQuery = await _firestore
          .collection('payments')
          .where('status', isEqualTo: 'rejected')
          .get();

      return {
        'pending': pendingQuery.docs.length,
        'approved': approvedQuery.docs.length,
        'rejected': rejectedQuery.docs.length,
        'total': pendingQuery.docs.length + approvedQuery.docs.length + rejectedQuery.docs.length,
      };
    } catch (e) {
      throw Exception('Failed to get payment statistics: $e');
    }
  }
}