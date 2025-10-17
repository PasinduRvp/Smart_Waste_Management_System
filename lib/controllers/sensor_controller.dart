// controllers/sensor_controller.dart
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'dart:developer' as developer;

class SensorController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final currentSensorData = <String, dynamic>{}.obs;
  final isReading = false.obs;
  final lastReadTime = Rx<DateTime?>(null);

  /// Scan bin and verify
  Future<bool> scanBin(String binId) async {
    try {
      developer.log('Scanning bin: $binId', name: 'SensorController');
      
      // Simulate scanning delay
      await Future.delayed(const Duration(seconds: 2));
      
      // Verify bin exists in database
      final binDoc = await _firestore
          .collection('bins')
          .where('binId', isEqualTo: binId)
          .limit(1)
          .get();

      if (binDoc.docs.isEmpty) {
        // Create bin if not exists (for demo purposes)
        await _firestore.collection('bins').add({
          'binId': binId,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      developer.log('Bin verified: $binId', name: 'SensorController');
      return true;
    } catch (e) {
      developer.log('Error scanning bin: $e', name: 'SensorController');
      return false;
    }
  }

  /// Read sensor data from bin
  Future<Map<String, dynamic>> readSensorData(String binId) async {
    try {
      isReading.value = true;
      developer.log('Reading sensor data for bin: $binId', name: 'SensorController');
      
      // Simulate sensor reading delay
      await Future.delayed(const Duration(milliseconds: 1500));
      
      // Generate simulated sensor data
      final sensorData = _generateSensorData(binId);
      
      // Update current sensor data
      currentSensorData.value = sensorData;
      lastReadTime.value = DateTime.now();
      
      // Save sensor reading to database
      await _saveSensorReading(binId, sensorData);
      
      isReading.value = false;
      developer.log('Sensor data read successfully', name: 'SensorController');
      
      return sensorData;
    } catch (e) {
      isReading.value = false;
      developer.log('Error reading sensor data: $e', name: 'SensorController');
      rethrow;
    }
  }

  /// Generate simulated sensor data
  Map<String, dynamic> _generateSensorData(String binId) {
    final random = Random();
    
    // Generate realistic waste data
    final weight = 5.0 + random.nextDouble() * 45.0; // 5-50 kg
    final level = 20.0 + random.nextDouble() * 70.0; // 20-90%
    final temperature = 15.0 + random.nextDouble() * 15.0; // 15-30°C
    final humidity = 30.0 + random.nextDouble() * 40.0; // 30-70%
    
    return {
      'binId': binId,
      'weight': double.parse(weight.toStringAsFixed(2)),
      'level': double.parse(level.toStringAsFixed(1)),
      'temperature': double.parse(temperature.toStringAsFixed(1)),
      'humidity': double.parse(humidity.toStringAsFixed(1)),
      'batteryLevel': 75 + random.nextInt(25), // 75-100%
      'lastUpdated': DateTime.now(),
      'sensorStatus': 'active',
    };
  }

  /// Save sensor reading to database
  Future<void> _saveSensorReading(String binId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('sensor_readings').add({
        'binId': binId,
        'weight': data['weight'],
        'level': data['level'],
        'temperature': data['temperature'],
        'humidity': data['humidity'],
        'batteryLevel': data['batteryLevel'],
        'timestamp': FieldValue.serverTimestamp(),
        'status': data['sensorStatus'],
      });
      
      // Update bin document with latest reading
      final binQuery = await _firestore
          .collection('bins')
          .where('binId', isEqualTo: binId)
          .limit(1)
          .get();
      
      if (binQuery.docs.isNotEmpty) {
        await _firestore.collection('bins').doc(binQuery.docs.first.id).update({
          'lastWeight': data['weight'],
          'lastLevel': data['level'],
          'lastReadingAt': FieldValue.serverTimestamp(),
        });
      }
      
      developer.log('Sensor reading saved for bin: $binId', name: 'SensorController');
    } catch (e) {
      developer.log('Error saving sensor reading: $e', name: 'SensorController');
    }
  }

  /// Update sensor data manually
  void updateSensorData(double weight, double level) {
    currentSensorData.value = {
      ...currentSensorData.value,
      'weight': weight,
      'level': level,
      'lastUpdated': DateTime.now(),
    };
    lastReadTime.value = DateTime.now();
    
    developer.log('Sensor data updated manually: weight=$weight, level=$level', 
        name: 'SensorController');
  }

  /// Get historical sensor data for a bin
  Future<List<Map<String, dynamic>>> getHistoricalData(String binId) async {
    try {
      final query = await _firestore
          .collection('sensor_readings')
          .where('binId', isEqualTo: binId)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();
      
      return query.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      developer.log('Error getting historical data: $e', name: 'SensorController');
      return [];
    }
  }

  /// Check if bin needs collection based on sensor data
  bool needsCollection(Map<String, dynamic> sensorData) {
    final level = sensorData['level'] as double? ?? 0.0;
    final weight = sensorData['weight'] as double? ?? 0.0;
    
    // Collection needed if level > 80% or weight > 45kg
    return level > 80.0 || weight > 45.0;
  }

  /// Get bin status based on sensor data
  String getBinStatus(Map<String, dynamic> sensorData) {
    final level = sensorData['level'] as double? ?? 0.0;
    
    if (level >= 90) return 'critical';
    if (level >= 70) return 'full';
    if (level >= 50) return 'half';
    return 'empty';
  }

  /// Validate sensor data
  bool validateSensorData(Map<String, dynamic> data) {
    try {
      final weight = data['weight'] as double?;
      final level = data['level'] as double?;
      
      if (weight == null || level == null) return false;
      if (weight < 0 || weight > 100) return false;
      if (level < 0 || level > 100) return false;
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Reset sensor data
  void resetSensorData() {
    currentSensorData.value = {};
    lastReadTime.value = null;
    isReading.value = false;
  }

  /// Get sensor health status
  String getSensorHealth(Map<String, dynamic> sensorData) {
    final batteryLevel = sensorData['batteryLevel'] as int? ?? 0;
    final lastUpdated = sensorData['lastUpdated'] as DateTime?;
    
    if (batteryLevel < 20) return 'Low Battery';
    if (lastUpdated != null) {
      final timeSinceUpdate = DateTime.now().difference(lastUpdated);
      if (timeSinceUpdate.inHours > 24) return 'Offline';
    }
    
    return 'Healthy';
  }
}