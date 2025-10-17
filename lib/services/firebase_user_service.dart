// lib/services/firebase_user_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

class FirebaseUserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create user document in Firestore with membership status
  Future<void> createUserDocument({
    required String userId,
    required String email,
    required String name,
    required String role,
    String? phone,
    String? address,
    String membershipStatus = 'inactive',
  }) async {
    try {
      developer.log('Creating user document for: $email with role: $role', 
          name: 'FirebaseUserService');
      
      await _firestore.collection('users').doc(userId).set({
        'email': email,
        'name': name,
        'role': role,
        'phone': phone,
        'address': address,
        'membershipStatus': membershipStatus,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      developer.log('User document created successfully for: $email', 
          name: 'FirebaseUserService');
    } catch (e) {
      developer.log('Error creating user document: $e', 
          name: 'FirebaseUserService');
      throw Exception('Failed to create user document: $e');
    }
  }

  /// Get user data by ID
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      developer.log('Getting user data for userId: $userId', 
          name: 'FirebaseUserService');
      
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        developer.log('User document found for userId: $userId', 
            name: 'FirebaseUserService');
        return userDoc.data() as Map<String, dynamic>;
      }
      
      developer.log('User document not found for userId: $userId', 
          name: 'FirebaseUserService');
      return null;
    } catch (e) {
      developer.log('Error getting user data: $e', 
          name: 'FirebaseUserService');
      throw Exception('Failed to get user data: $e');
    }
  }

  /// Update user profile
  Future<void> updateUserProfile(
    String userId, 
    Map<String, dynamic> updates
  ) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      
      await _firestore
          .collection('users')
          .doc(userId)
          .update(updates);
      
      developer.log('User profile updated for userId: $userId', 
          name: 'FirebaseUserService');
    } catch (e) {
      developer.log('Error updating user profile: $e', 
          name: 'FirebaseUserService');
      throw Exception('Failed to update user profile: $e');
    }
  }

  /// Update user membership status
  Future<void> updateUserMembership(
    String userId, 
    String membershipStatus,
    String? paymentId,
    DateTime? expiryDate,
  ) async {
    try {
      final updates = <String, dynamic>{
        'membershipStatus': membershipStatus,
        'membershipApprovedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (paymentId != null) {
        updates['lastPaymentId'] = paymentId;
      }

      if (expiryDate != null) {
        updates['membershipExpiry'] = Timestamp.fromDate(expiryDate);
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .update(updates);
      
      developer.log('User membership updated for userId: $userId to $membershipStatus', 
          name: 'FirebaseUserService');
    } catch (e) {
      developer.log('Error updating user membership: $e', 
          name: 'FirebaseUserService');
      throw Exception('Failed to update user membership: $e');
    }
  }

  /// Check if user is admin
  Future<bool> isUserAdmin(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['role'] == 'admin';
      }
      return false;
    } catch (e) {
      developer.log('Error checking user role: $e', 
          name: 'FirebaseUserService');
      throw Exception('Failed to check user role: $e');
    }
  }

  /// Check if user is collector
  Future<bool> isUserCollector(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['role'] == 'collector';
      }
      return false;
    } catch (e) {
      developer.log('Error checking user role: $e', 
          name: 'FirebaseUserService');
      return false;
    }
  }

  /// Check if user has active membership
  Future<bool> hasActiveMembership(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final membershipStatus = userData['membershipStatus'] ?? 'inactive';
        final expiry = userData['membershipExpiry'];
        
        if (membershipStatus == 'active' && expiry != null) {
          final expiryDate = (expiry as Timestamp).toDate();
          return expiryDate.isAfter(DateTime.now());
        }
      }
      return false;
    } catch (e) {
      developer.log('Error checking membership: $e', 
          name: 'FirebaseUserService');
      return false;
    }
  }

  /// Get all users (admin only)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();
      
      return querySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();
    } catch (e) {
      developer.log('Error getting all users: $e', 
          name: 'FirebaseUserService');
      throw Exception('Failed to get all users: $e');
    }
  }

  /// Delete user document
  Future<void> deleteUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).delete();
      developer.log('User deleted: $userId', name: 'FirebaseUserService');
    } catch (e) {
      developer.log('Error deleting user: $e', 
          name: 'FirebaseUserService');
      throw Exception('Failed to delete user: $e');
    }
  }

  /// Stream user data
  Stream<Map<String, dynamic>?> streamUserData(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return snapshot.data();
      }
      return null;
    });
  }

  /// Get user membership status
  Future<Map<String, dynamic>> getUserMembershipStatus(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return {
          'status': userData['membershipStatus'] ?? 'inactive',
          'expiry': userData['membershipExpiry'],
          'approvedAt': userData['membershipApprovedAt'],
        };
      }
      return {'status': 'inactive', 'expiry': null, 'approvedAt': null};
    } catch (e) {
      developer.log('Error getting membership status: $e', 
          name: 'FirebaseUserService');
      return {'status': 'inactive', 'expiry': null, 'approvedAt': null};
    }
  }
}