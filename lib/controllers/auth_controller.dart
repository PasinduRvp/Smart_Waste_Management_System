import 'dart:async';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_waste_management/services/firebase_user_service.dart';
import 'package:smart_waste_management/services/payment_service.dart';
import 'package:smart_waste_management/views/signin_screen.dart';
import 'package:smart_waste_management/views/admin/admin_home_screen.dart';
import 'package:smart_waste_management/views/resident/resident_home_screen.dart';
import 'package:smart_waste_management/views/collector/collector_home_screen.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseUserService _userService = FirebaseUserService();
  late PaymentService _paymentService;
  
  final _isLoggedIn = false.obs;
  final _userRole = ''.obs;
  final _membershipStatus = 'inactive'.obs;
  final _userData = <String, dynamic>{}.obs;
  final _latestPayment = <String, dynamic>{}.obs;
  bool _isFirstTime = true;
  bool _isLoggingOut = false;
  bool _isSigningUp = false;

  // Stream subscriptions for real-time updates
  StreamSubscription<DocumentSnapshot>? _userDataSubscription;
  StreamSubscription<QuerySnapshot>? _paymentSubscription;

  bool get isLoggedIn => _isLoggedIn.value;
  String get userRole => _userRole.value;
  String get membershipStatus => _membershipStatus.value;
  Map<String, dynamic> get userData => _userData;
  Map<String, dynamic> get latestPayment => _latestPayment;
  bool get isFirstTime => _isFirstTime;
  bool get hasActiveMembership => _membershipStatus.value == 'active';
  User? get user => _auth.currentUser;

  @override
  void onInit() {
    super.onInit();
    _initializeServices();
    ever(_isLoggedIn, _handleAuthChanged);
    
    // Listen to auth state changes
    _auth.authStateChanges().listen((User? user) async {
      if (!_isLoggingOut && !_isSigningUp) {
        _isLoggedIn.value = user != null;
        if (user != null) {
          await _loadUserData(user.uid);
          _startRealtimeUpdates(user.uid);
          _navigateBasedOnRole();
        } else {
          _stopRealtimeUpdates();
        }
      }
    });
  }

  @override
  void onClose() {
    _stopRealtimeUpdates();
    super.onClose();
  }

  void _initializeServices() {
    try {
      _paymentService = PaymentService();
      developer.log('PaymentService initialized successfully', name: 'AuthController');
    } catch (e) {
      developer.log('Error initializing PaymentService: $e', name: 'AuthController');
      _paymentService = PaymentService();
    }
  }

  void _startRealtimeUpdates(String userId) {
    try {
      // Listen for user data changes
      _userDataSubscription = _firestore
          .collection('users')
          .doc(userId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data()!;
          _userData.value = data;
          _userRole.value = data['role'] ?? 'resident';
          _membershipStatus.value = data['membershipStatus'] ?? 'inactive';
          developer.log('User data updated: ${data['role']}, ${data['membershipStatus']}', name: 'AuthController');
        }
      });

      // Listen for payment updates (for residents)
      _paymentSubscription = _firestore
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .orderBy('submittedAt', descending: true)
          .limit(1)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final payment = snapshot.docs.first.data();
          _latestPayment.value = payment;
          developer.log('Latest payment updated: ${payment['status']}', name: 'AuthController');
          
          // Update membership status based on payment status
          if (payment['status'] == 'approved') {
            _membershipStatus.value = 'active';
          } else if (payment['status'] == 'rejected') {
            _membershipStatus.value = 'inactive';
          }
        }
      });

      developer.log('Realtime updates started for user: $userId', name: 'AuthController');
    } catch (e) {
      developer.log('Error starting realtime updates: $e', name: 'AuthController');
    }
  }

  void _stopRealtimeUpdates() {
    try {
      _userDataSubscription?.cancel();
      _paymentSubscription?.cancel();
      _userDataSubscription = null;
      _paymentSubscription = null;
      developer.log('Realtime updates stopped', name: 'AuthController');
    } catch (e) {
      developer.log('Error stopping realtime updates: $e', name: 'AuthController');
    }
  }

  void _handleAuthChanged(bool loggedIn) {
    if (!loggedIn && !_isLoggingOut && !_isSigningUp) {
      developer.log('Auth changed: User logged out', name: 'AuthController');
      Get.offAll(() => const SigninScreen());
    }
  }

  void _navigateBasedOnRole() {
    if (_isLoggedIn.value && !_isSigningUp && !_isLoggingOut) {
      developer.log('Navigating based on role: ${_userRole.value}', name: 'AuthController');
      switch (_userRole.value) {
        case 'admin':
          Get.offAll(() => const AdminHomeScreen());
          break;
        case 'collector':
          Get.offAll(() => const CollectorHomeScreen());
          break;
        case 'resident':
        default:
          Get.offAll(() => const ResidentHomeScreen());
          break;
      }
    }
  }

  void resetLogoutFlag() {
    _isLoggingOut = false;
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      developer.log('Attempting sign in for: $email', name: 'AuthController');
      
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (userCredential.user != null) {
        developer.log('Sign in successful for: ${userCredential.user!.uid}', name: 'AuthController');
        
        _isLoggedIn.value = true;
        await _loadUserData(userCredential.user!.uid);
        _startRealtimeUpdates(userCredential.user!.uid);
        
        // Navigate based on role
        await Future<void>.delayed(Duration.zero, () {
          switch (_userRole.value) {
            case 'admin':
              Get.offAll(() => const AdminHomeScreen());
              break;
            case 'collector':
              Get.offAll(() => const CollectorHomeScreen());
              break;
            case 'resident':
            default:
              Get.offAll(() => const ResidentHomeScreen());
              break;
          }
        });
      }
    } catch (e) {
      developer.log('Sign in failed: $e', name: 'AuthController');
      _isLoggedIn.value = false;
      rethrow;
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? phone,
    String? address,
  }) async {
    try {
      _isSigningUp = true;
      developer.log('Starting sign up process for: $email', name: 'AuthController');
      
      // Create Firebase Auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        developer.log('Firebase Auth user created: ${userCredential.user!.uid}', name: 'AuthController');
        
        // Update display name
        await userCredential.user!.updateDisplayName(name);
        
        // Create Firestore document with membership status
        await _userService.createUserDocument(
          userId: userCredential.user!.uid,
          email: email,
          name: name,
          role: role,
          phone: phone,
          address: address,
          membershipStatus: role == 'resident' ? 'inactive' : 'active',
        );
        
        developer.log('Firestore user document created', name: 'AuthController');
        
        _userRole.value = role;
        _membershipStatus.value = role == 'resident' ? 'inactive' : 'active';
        _isLoggedIn.value = true;
        
        // Load complete user data
        await _loadUserData(userCredential.user!.uid);
        _startRealtimeUpdates(userCredential.user!.uid);
        
        // Navigate based on role
        await Future<void>.delayed(Duration.zero, () {
          switch (role) {
            case 'admin':
              Get.offAll(() => const AdminHomeScreen());
              break;
            case 'collector':
              Get.offAll(() => const CollectorHomeScreen());
              break;
            case 'resident':
            default:
              Get.offAll(() => const ResidentHomeScreen());
              break;
          }
        });
        
        developer.log('Sign up completed successfully', name: 'AuthController');
      }
    } catch (e) {
      developer.log('Sign up failed: $e', name: 'AuthController');
      
      // Clean up auth user if creation failed
      if (_auth.currentUser != null) {
        try {
          await _auth.currentUser!.delete();
          developer.log('Cleaned up auth user after failed sign up', name: 'AuthController');
        } catch (deleteError) {
          developer.log('Error deleting auth user: $deleteError', name: 'AuthController');
        }
      }
      
      rethrow;
    } finally {
      _isSigningUp = false;
    }
  }

  Future<void> logout() async {
    try {
      _isLoggingOut = true;
      developer.log('Starting logout process', name: 'AuthController');
      
      await _auth.signOut();
      _isLoggedIn.value = false;
      _userRole.value = '';
      _membershipStatus.value = 'inactive';
      _userData.clear();
      _latestPayment.clear();
      _stopRealtimeUpdates();
      
      await Future<void>.delayed(Duration.zero, () {
        Get.offAll(() => const SigninScreen());
      });
      
      developer.log('Logout completed successfully', name: 'AuthController');
    } catch (e) {
      developer.log('Error during logout: $e', name: 'AuthController');
      rethrow;
    } finally {
      _isLoggingOut = true;
      Future.delayed(const Duration(milliseconds: 500), () {
        _isLoggingOut = false;
      });
    }
  }

  Future<void> _loadUserData(String userId) async {
    try {
      developer.log('Loading user data for: $userId', name: 'AuthController');
      
      final userData = await _userService.getUserData(userId);
      if (userData != null) {
        _userRole.value = userData['role'] ?? 'resident';
        _membershipStatus.value = userData['membershipStatus'] ?? 'inactive';
        _userData.value = userData;
        developer.log('User data loaded successfully: ${userData['role']}, ${userData['membershipStatus']}', name: 'AuthController');
      } else {
        _userRole.value = 'resident';
        _membershipStatus.value = 'inactive';
        _userData.value = {};
        developer.log('No user data found, using defaults', name: 'AuthController');
      }
    } catch (e) {
      developer.log('Error loading user data: $e', name: 'AuthController');
      _userRole.value = 'resident';
      _membershipStatus.value = 'inactive';
      _userData.value = {};
    }
  }

  Future<void> refreshUserData() async {
    if (user != null) {
      developer.log('Refreshing user data', name: 'AuthController');
      await _loadUserData(user!.uid);
    }
  }

  Future<void> refreshMembershipStatus() async {
    if (user != null && userRole == 'resident') {
      try {
        developer.log('Refreshing membership status', name: 'AuthController');
        // Use direct Firestore query instead of non-existent method
        final userDoc = await _firestore.collection('users').doc(user!.uid).get();
        if (userDoc.exists) {
          _membershipStatus.value = userDoc.data()?['membershipStatus'] ?? 'inactive';
        }
        developer.log('Membership status refreshed: ${_membershipStatus.value}', name: 'AuthController');
      } catch (e) {
        developer.log('Error refreshing membership status: $e', name: 'AuthController');
        if (_userData.containsKey('membershipStatus')) {
          _membershipStatus.value = _userData['membershipStatus'] ?? 'inactive';
        }
      }
    }
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    if (user != null) {
      try {
        developer.log('Updating user profile', name: 'AuthController');
        
        await _userService.updateUserProfile(user!.uid, updates);
        await refreshUserData();
        
        // Update Firebase Auth display name if name changed
        if (updates.containsKey('name')) {
          await user!.updateDisplayName(updates['name']);
          developer.log('Updated display name: ${updates['name']}', name: 'AuthController');
        }
        
        Get.snackbar(
          'Success',
          'Profile updated successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        
        developer.log('Profile updated successfully', name: 'AuthController');
      } catch (e) {
        developer.log('Profile update failed: $e', name: 'AuthController');
        Get.snackbar(
          'Error',
          'Failed to update profile: ${e.toString()}',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        rethrow;
      }
    }
  }

  Future<void> signOut() async {
    try {
      developer.log('Signing out user', name: 'AuthController');
      await FirebaseAuth.instance.signOut();
      Get.offAll(() => const SigninScreen());
      developer.log('Sign out completed', name: 'AuthController');
    } catch (e) {
      developer.log('Sign out failed: $e', name: 'AuthController');
      Get.snackbar(
        'Error',
        'Failed to sign out: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      rethrow;
    }
  }

  void login(String email, String role) {
    developer.log('Manual login: $email, $role', name: 'AuthController');
    _isLoggedIn.value = true;
    _userRole.value = role;
  }

  void setFirstTimeDone() {
    _isFirstTime = false;
    developer.log('First time setup completed', name: 'AuthController');
  }

  // Getter for payment service with error handling
  PaymentService get paymentService {
    return _paymentService;
  }

  // Collector collections/history stream used by collector views
  Stream<List<Map<String, dynamic>>> getCollectorCollections() {
    if (user == null) return const Stream.empty();
    try {
      return _firestore
          .collection('special_pickups')
          .where('collectorId', isEqualTo: user!.uid)
          .orderBy('collectionDate', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return {
                  'id': doc.id,
                  ...data,
                };
              }).toList());
    } catch (_) {
      return const Stream.empty();
    }
  }

  // Get real-time payment status stream
  Stream<Map<String, dynamic>?> getPaymentStatusStream() {
    if (user != null) {
      return _firestore
          .collection('payments')
          .where('userId', isEqualTo: user!.uid)
          .orderBy('submittedAt', descending: true)
          .limit(1)
          .snapshots()
          .map((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          return snapshot.docs.first.data();
        }
        return null;
      });
    }
    return Stream.value(null);
  }

  // Get real-time membership status stream
  Stream<String> getMembershipStatusStream() {
    if (user != null) {
      return _firestore
          .collection('users')
          .doc(user!.uid)
          .snapshots()
          .map((snapshot) {
        if (snapshot.exists) {
          return snapshot.data()?['membershipStatus'] ?? 'inactive';
        }
        return 'inactive';
      });
    }
    return Stream.value('inactive');
  }

  // Get user payment history
  Stream<QuerySnapshot> getUserPaymentHistory() {
    if (user != null) {
      return _firestore
          .collection('payments')
          .where('userId', isEqualTo: user!.uid)
          .orderBy('submittedAt', descending: true)
          .snapshots();
    }
    return const Stream.empty();
  }

  // Check if user has pending payment
  Future<bool> hasPendingPayment() async {
    if (user != null) {
      try {
        final query = await _firestore
            .collection('payments')
            .where('userId', isEqualTo: user!.uid)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .get();
        return query.docs.isNotEmpty;
      } catch (e) {
        developer.log('Error checking pending payment: $e', name: 'AuthController');
        return false;
      }
    }
    return false;
  }

  // Force refresh all user data
  Future<void> forceRefresh() async {
    if (user != null) {
      developer.log('Force refreshing all user data', name: 'AuthController');
      await _loadUserData(user!.uid);
      _stopRealtimeUpdates();
      _startRealtimeUpdates(user!.uid);
    }
  }

  // Get user statistics for dashboard
  Future<Map<String, dynamic>> getUserStatistics() async {
    if (user != null) {
      try {
        // Implement user statistics logic here
        return {
          'totalPickups': 0,
          'completedPickups': 0,
          'pendingPickups': 0,
          'membershipStatus': _membershipStatus.value,
        };
      } catch (e) {
        developer.log('Error getting user statistics: $e', name: 'AuthController');
        return {};
      }
    }
    return {};
  }

  // Add to AuthController class

// Get assigned tasks for collector
Stream<List<Map<String, dynamic>>> getAssignedTasks() {
  if (user != null && userRole == 'collector') {
    return _firestore
        .collection('assigned_tasks')
        .where('collectorId', isEqualTo: user!.uid)
        .where('status', whereIn: ['assigned', 'in_progress'])
        .orderBy('assignedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return {
                'id': doc.id,
                ...data,
              };
            }).toList());
  }
  return const Stream.empty();
}

// Get task statistics for collector
Future<Map<String, dynamic>> getTaskStatistics() async {
  if (user != null && userRole == 'collector') {
    try {
      final assignedQuery = await _firestore
          .collection('assigned_tasks')
          .where('collectorId', isEqualTo: user!.uid)
          .where('status', isEqualTo: 'assigned')
          .get();

      final inProgressQuery = await _firestore
          .collection('assigned_tasks')
          .where('collectorId', isEqualTo: user!.uid)
          .where('status', isEqualTo: 'in_progress')
          .get();

      final completedQuery = await _firestore
          .collection('assigned_tasks')
          .where('collectorId', isEqualTo: user!.uid)
          .where('status', isEqualTo: 'completed')
          .get();

      return {
        'assigned': assignedQuery.docs.length,
        'inProgress': inProgressQuery.docs.length,
        'completed': completedQuery.docs.length,
        'total': assignedQuery.docs.length + inProgressQuery.docs.length + completedQuery.docs.length,
      };
    } catch (e) {
      developer.log('Error getting task statistics: $e', name: 'AuthController');
      return {'assigned': 0, 'inProgress': 0, 'completed': 0, 'total': 0};
    }
  }
  return {'assigned': 0, 'inProgress': 0, 'completed': 0, 'total': 0};
}
}