// views/collector/task_details_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_waste_management/controllers/auth_controller.dart';
import 'package:smart_waste_management/utils/app_themes.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'task_completion_screen.dart';
import 'package:smart_waste_management/services/map_service.dart';

class TaskDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> task;

  const TaskDetailsScreen({super.key, required this.task});

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  final AuthController _authController = Get.find();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  LatLng? _destinationLatLng;
  LatLng? _currentLocation;
  bool _isLoadingLocation = false;
  MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Get current location
      final position = await MapService.getCurrentLocation();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      // Convert task address to coordinates
      final address = widget.task['address'];
      if (address != null) {
        final destination = await MapService.addressToLatLng(address);
        setState(() {
          _destinationLatLng = destination;
        });

        // Fit map bounds to show both locations
        if (_currentLocation != null && _destinationLatLng != null) {
          _mapController.fitBounds(
            LatLngBounds(_currentLocation!, _destinationLatLng!),
            options: const FitBoundsOptions(padding: EdgeInsets.all(50)),
          );
        }
      }
    } catch (e) {
      print('Error initializing map: $e');
      Get.snackbar(
        'Error',
        'Failed to load map: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheduledDate = widget.task['scheduledDate'] != null
        ? (widget.task['scheduledDate'] as Timestamp).toDate()
        : DateTime.now();

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'Task Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_rounded),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task Status Card
            _buildStatusCard(),
            
            const SizedBox(height: 20),
            
            // Task Information
            _buildTaskInfoCard(scheduledDate),
            
            const SizedBox(height: 20),
            
            // Location Section with Flutter Map
            _buildLocationCard(),
            
            const SizedBox(height: 20),
            
            // Action Buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final status = widget.task['status'];
    final statusColor = _getTaskColor(status);
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getTaskIcon(status),
                color: statusColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getTaskStatusText(status),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                  Text(
                    'Current Task Status',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskInfoCard(DateTime scheduledDate) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Task Information',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Customer', widget.task['userName'] ?? 'Unknown'),
            _buildInfoRow('Email', widget.task['userEmail'] ?? 'Not provided'),
            _buildInfoRow('Waste Type', _getWasteTypeText(widget.task['wasteType'])),
            _buildInfoRow('Scheduled Date', DateFormat('MMM dd, yyyy HH:mm').format(scheduledDate)),
            const SizedBox(height: 8),
            Text(
              'Description:',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.task['description'] ?? 'No description provided',
              style: GoogleFonts.poppins(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pickup Location',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  onPressed: _initializeMap,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh Location',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on_rounded, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.task['address'] ?? 'No address provided',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Flutter Map Container
            Container(
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: _isLoadingLocation
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppThemes.primaryGreen),
                          const SizedBox(height: 16),
                          Text(
                            'Loading Map...',
                            style: GoogleFonts.poppins(),
                          ),
                        ],
                      ),
                    )
                  : _buildFlutterMap(),
            ),
            
            const SizedBox(height: 12),
            _buildLocationInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildFlutterMap() {
    final initialCenter = _currentLocation ?? LatLng(6.9271, 79.8612); // Default to Colombo
    
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: 13.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        // OpenStreetMap Tile Layer
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.smart_waste_management',
        ),
        
        // Current Location Marker
        if (_currentLocation != null)
        MarkerLayer(
          markers: [
            Marker(
              point: _currentLocation!,
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blue, width: 2),
                ),
                child: Icon(Icons.person_pin_circle_rounded, color: Colors.blue, size: 24),
              ),
            ),
          ],
        ),
        
        // Destination Marker
        if (_destinationLatLng != null)
        MarkerLayer(
          markers: [
            Marker(
              point: _destinationLatLng!,
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: Icon(Icons.location_on_rounded, color: Colors.red, size: 24),
              ),
            ),
          ],
        ),
        
        // Route Line (if both locations available)
        if (_currentLocation != null && _destinationLatLng != null)
        PolylineLayer(
          polylines: [
            Polyline(
              points: [_currentLocation!, _destinationLatLng!],
              color: AppThemes.primaryGreen.withOpacity(0.7),
              strokeWidth: 4,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationInfo() {
    if (_currentLocation == null || _destinationLatLng == null) {
      return Container();
    }

    final distance = MapService.calculateDistance(_currentLocation!, _destinationLatLng!);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemes.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.directions_rounded, color: AppThemes.primaryGreen, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Route Information',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppThemes.primaryGreen,
                  ),
                ),
                Text(
                  'Distance: ${distance.toStringAsFixed(1)} km',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final status = widget.task['status'];
    
    return Column(
      children: [
        if (status == 'assigned') ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startTask,
              icon: const Icon(Icons.directions_run_rounded),
              label: Text(
                'Start Task & Open Navigation',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppThemes.primaryGreen,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        if (status == 'in_progress') ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openExternalNavigation,
              icon: const Icon(Icons.navigation_rounded),
              label: Text(
                'Open External Navigation',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _completeTask,
              icon: const Icon(Icons.check_circle_rounded),
              label: Text(
                'Complete Pickup',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: AppThemes.collectedColor),
                foregroundColor: AppThemes.collectedColor,
              ),
            ),
          ),
        ],
        
        if (status == 'completed') 
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // Show completion details
                _showCompletionDetails();
              },
              icon: const Icon(Icons.visibility_rounded),
              label: Text(
                'View Completion Details',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppThemes.collectedColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startTask() async {
    try {
      // Update task status
      await _firestore.collection('assigned_tasks').doc(widget.task['id']).update({
        'status': 'in_progress',
        'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Open external navigation
      await _openExternalNavigation();
      
      Get.snackbar(
        'Task Started',
        'Navigation opened and task marked as in progress',
        backgroundColor: AppThemes.collectedColor,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to start task: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _openExternalNavigation() async {
    final address = widget.task['address'];
    if (address == null) {
      Get.snackbar(
        'Error',
        'No address provided for this task',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final url = 'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(address)}&travelmode=driving';
    
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      Get.snackbar(
        'Error',
        'Could not launch navigation app',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _completeTask() {
    Get.to(() => TaskCompletionScreen(task: widget.task));
  }

  void _showCompletionDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Task Completion Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCompletionDetail('Completed At', 
                widget.task['completedAt'] != null 
                    ? DateFormat('MMM dd, yyyy HH:mm').format(
                        (widget.task['completedAt'] as Timestamp).toDate())
                    : 'Not available'),
            _buildCompletionDetail('Bin ID', widget.task['binId'] ?? 'Not scanned'),
            _buildCompletionDetail('Weight', 
                widget.task['collectedWeight'] != null 
                    ? '${widget.task['collectedWeight']} kg'
                    : 'Not recorded'),
            _buildCompletionDetail('Collector Notes', 
                widget.task['collectorNotes'] ?? 'No notes provided'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  Color _getTaskColor(String status) {
    switch (status) {
      case 'assigned':
        return Colors.blue;
      case 'in_progress':
        return Colors.orange;
      case 'completed':
        return AppThemes.collectedColor;
      default:
        return Colors.grey;
    }
  }

  IconData _getTaskIcon(String status) {
    switch (status) {
      case 'assigned':
        return Icons.assignment_rounded;
      case 'in_progress':
        return Icons.directions_run_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _getTaskStatusText(String status) {
    switch (status) {
      case 'assigned':
        return 'Assigned';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  String _getWasteTypeText(String type) {
    switch (type.toLowerCase()) {
      case 'general':
        return 'General Waste';
      case 'recyclable':
        return 'Recyclable Waste';
      case 'organic':
        return 'Organic Waste';
      case 'hazardous':
        return 'Hazardous Waste';
      default:
        return type;
    }
  }
}