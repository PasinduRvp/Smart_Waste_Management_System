// controllers/route_controller.dart
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_waste_management/controllers/auth_controller.dart';
import 'package:smart_waste_management/services/notification_service.dart';
import 'dart:developer' as developer;

class RouteController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthController _authController = Get.find();
  final NotificationService _notificationService = NotificationService();

  final currentStopIndex = 0.obs;
  final totalStops = 0.obs;
  final completedStops = 0.obs;
  final pendingStops = 0.obs;
  final missedStops = 0.obs;
  final isRouteActive = false.obs;
  final isRouteCompleted = false.obs;
  final routeProgress = 0.0.obs;
  
  final Rx<dynamic> currentStop = Rx<dynamic>(null);
  final RxList<dynamic> routeStops = RxList<dynamic>([]);
  final RxList<Map<String, dynamic>> collectedData = RxList<Map<String, dynamic>>([]);

  String? routeId;
  DateTime? routeStartTime;

  @override
  void onInit() {
    super.onInit();
    _loadTodayRoute();
  }

  Future<void> _loadTodayRoute() async {
    try {
      final collectorId = _authController.user?.uid ?? '';
      if (collectorId.isEmpty) return;

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // Get regular pickups
      final regularQuery = await _firestore
          .collection('pickups')
          .where('collectorId', isEqualTo: collectorId)
          .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('scheduledDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      // Get special pickups
      final specialQuery = await _firestore
          .collection('special_pickups')
          .where('collectorId', isEqualTo: collectorId)
          .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('scheduledDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      final allDocs = [...regularQuery.docs, ...specialQuery.docs];

      routeStops.value = allDocs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _createStopFromDoc(doc.id, data);
      }).toList();

      // Sort by scheduled time (safely)
      routeStops.sort((a, b) {
        final aDate = a.scheduledDate;
        final bDate = b.scheduledDate;
        return aDate.compareTo(bDate);
      });

      totalStops.value = routeStops.length;
      _updateStats();

      if (routeStops.isNotEmpty && currentStopIndex.value < routeStops.length) {
        currentStop.value = routeStops[currentStopIndex.value];
      }

      developer.log('Loaded ${routeStops.length} stops for today', name: 'RouteController');
    } catch (e) {
      developer.log('Error loading route: $e', name: 'RouteController');
    }
  }

  dynamic _createStopFromDoc(String id, Map<String, dynamic> data) {
    return RouteStop(
      id: id,
      address: data['address'] ?? 'Unknown',
      binId: data['binId'],
      wasteType: data['wasteType'] ?? 'general',
      status: data['status'] ?? 'pending',
      scheduledDate: (data['scheduledDate'] as Timestamp).toDate(),
      userId: data['userId'] ?? '',
      description: data['description'] ?? '',
      notes: data['notes'] ?? '',
    );
  }

  void _updateStats() {
    completedStops.value = routeStops.where((s) => s.status == 'collected').length;
    missedStops.value = routeStops.where((s) => s.status == 'missed').length;
    pendingStops.value = routeStops.where((s) => 
      s.status == 'pending' || s.status == 'scheduled').length;
    
    if (totalStops.value > 0) {
      routeProgress.value = completedStops.value / totalStops.value;
    }
  }

  Future<void> startRoute() async {
    try {
      isRouteActive.value = true;
      routeStartTime = DateTime.now();
      
      // Create route session
      final routeDoc = await _firestore.collection('route_sessions').add({
        'collectorId': _authController.user?.uid,
        'startTime': FieldValue.serverTimestamp(),
        'status': 'active',
        'totalStops': totalStops.value,
        'completedStops': 0,
      });
      
      routeId = routeDoc.id;
      
      developer.log('Route started: $routeId', name: 'RouteController');
    } catch (e) {
      developer.log('Error starting route: $e', name: 'RouteController');
    }
  }

  Future<void> markStopAsCollected(dynamic stop, Map<String, dynamic> sensorData) async {
    try {
      final stopData = {
        'stopId': stop.id,
        'collectedAt': FieldValue.serverTimestamp(),
        'weight': sensorData['weight'] ?? 0.0,
        'level': sensorData['level'] ?? 0.0,
        'binId': stop.binId,
        'address': stop.address,
        'wasteType': stop.wasteType,
      };

      // Update pickup status
      await _updatePickupStatus(stop.id, 'collected', stopData);
      
      // Add to collected data
      collectedData.add(stopData);
      
      // Update stop in route
      final index = routeStops.indexWhere((s) => s.id == stop.id);
      if (index != -1) {
        routeStops[index].status = 'collected';
        routeStops.refresh();
      }
      
      // Send notification to resident
      await _notificationService.sendCollectionNotification(
        userId: stop.userId,
        binId: stop.binId ?? 'N/A',
        weight: sensorData['weight'] ?? 0.0,
        timestamp: DateTime.now(),
      );
      
      _updateStats();
      
      // Move to next stop
      if (currentStopIndex.value < routeStops.length - 1) {
        currentStopIndex.value++;
        currentStop.value = routeStops[currentStopIndex.value];
      } else {
        isRouteCompleted.value = true;
        await _completeRoute();
      }
      
      developer.log('Stop marked as collected: ${stop.id}', name: 'RouteController');
    } catch (e) {
      developer.log('Error marking stop as collected: $e', name: 'RouteController');
      rethrow;
    }
  }

  Future<void> markStopAsMissed(dynamic stop) async {
    try {
      await _updatePickupStatus(stop.id, 'missed', {});
      
      final index = routeStops.indexWhere((s) => s.id == stop.id);
      if (index != -1) {
        routeStops[index].status = 'missed';
        routeStops.refresh();
      }
      
      // Send notification to resident
      await _notificationService.sendMissedPickupNotification(
        userId: stop.userId,
        binId: stop.binId ?? 'N/A',
        timestamp: DateTime.now(),
      );
      
      _updateStats();
      
      // Move to next stop
      if (currentStopIndex.value < routeStops.length - 1) {
        currentStopIndex.value++;
        currentStop.value = routeStops[currentStopIndex.value];
      } else {
        isRouteCompleted.value = true;
        await _completeRoute();
      }
      
      developer.log('Stop marked as missed: ${stop.id}', name: 'RouteController');
    } catch (e) {
      developer.log('Error marking stop as missed: $e', name: 'RouteController');
    }
  }

  Future<void> reportIssue(dynamic stop, String issue) async {
    try {
      await _firestore.collection('pickup_issues').add({
        'stopId': stop.id,
        'binId': stop.binId,
        'address': stop.address,
        'collectorId': _authController.user?.uid,
        'issue': issue,
        'reportedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      
      developer.log('Issue reported for stop: ${stop.id}', name: 'RouteController');
    } catch (e) {
      developer.log('Error reporting issue: $e', name: 'RouteController');
    }
  }

  Future<void> _updatePickupStatus(
    String pickupId, 
    String status, 
    Map<String, dynamic> additionalData
  ) async {
    try {
      final updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        ...additionalData,
      };

      // Try regular pickups first
      final regularDoc = await _firestore.collection('pickups').doc(pickupId).get();
      if (regularDoc.exists) {
        await _firestore.collection('pickups').doc(pickupId).update(updateData);
        return;
      }

      // Try special pickups
      final specialDoc = await _firestore.collection('special_pickups').doc(pickupId).get();
      if (specialDoc.exists) {
        await _firestore.collection('special_pickups').doc(pickupId).update(updateData);
        return;
      }
    } catch (e) {
      developer.log('Error updating pickup status: $e', name: 'RouteController');
      rethrow;
    }
  }

  void skipToNextStop() {
    if (currentStopIndex.value < routeStops.length - 1) {
      currentStopIndex.value++;
      currentStop.value = routeStops[currentStopIndex.value];
    } else {
      isRouteCompleted.value = true;
    }
  }

  void pauseRoute() {
    isRouteActive.value = false;
    developer.log('Route paused', name: 'RouteController');
  }

  void resumeRoute() {
    isRouteActive.value = true;
    developer.log('Route resumed', name: 'RouteController');
  }

  Future<void> _completeRoute() async {
    try {
      if (routeId != null) {
        await _firestore.collection('route_sessions').doc(routeId).update({
          'endTime': FieldValue.serverTimestamp(),
          'status': 'completed',
          'completedStops': completedStops.value,
          'missedStops': missedStops.value,
          'totalWeight': collectedData.fold<double>(
            0, (sum, item) => sum + (item['weight'] as double? ?? 0.0)
          ),
        });
      }
      
      isRouteActive.value = false;
      developer.log('Route completed', name: 'RouteController');
    } catch (e) {
      developer.log('Error completing route: $e', name: 'RouteController');
    }
  }

  Map<String, dynamic> getRouteSummary() {
    final totalWeight = collectedData.fold<double>(
      0, (sum, item) => sum + (item['weight'] as double? ?? 0.0)
    );
    
    final duration = routeStartTime != null 
      ? DateTime.now().difference(routeStartTime!)
      : Duration.zero;

    return {
      'totalStops': totalStops.value,
      'completedStops': completedStops.value,
      'missedStops': missedStops.value,
      'totalWeight': totalWeight,
      'duration': duration,
      'startTime': routeStartTime,
      'endTime': DateTime.now(),
    };
  }

  void resetRoute() {
    currentStopIndex.value = 0;
    completedStops.value = 0;
    missedStops.value = 0;
    pendingStops.value = 0;
    isRouteActive.value = false;
    isRouteCompleted.value = false;
    routeProgress.value = 0.0;
    collectedData.clear();
    routeId = null;
    routeStartTime = null;
  }
}

class RouteStop {
  final String id;
  final String address;
  final String? binId;
  final String wasteType;
  String status;
  final DateTime scheduledDate;
  final String userId;
  final String description;
  final String notes;

  RouteStop({
    required this.id,
    required this.address,
    this.binId,
    required this.wasteType,
    required this.status,
    required this.scheduledDate,
    required this.userId,
    required this.description,
    required this.notes,
  });
}