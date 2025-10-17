// views/admin/manage_pickups_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_waste_management/controllers/auth_controller.dart';
import 'package:smart_waste_management/services/pickup_service.dart';
import 'package:smart_waste_management/services/notification_service.dart';
import 'package:smart_waste_management/utils/app_themes.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManagePickupsScreen extends StatefulWidget {
  const ManagePickupsScreen({super.key});

  @override
  State<ManagePickupsScreen> createState() => _ManagePickupsScreenState();
}

class _ManagePickupsScreenState extends State<ManagePickupsScreen> {
  final AuthController _authController = Get.find();
  final PickupService _pickupService = PickupService();
  final NotificationService _notificationService = NotificationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'Manage Special Pickups',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_rounded),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _pickupService.getPendingSpecialPickupsList(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading pickups',
                style: GoogleFonts.poppins(),
              ),
            );
          }

          final pickups = snapshot.data ?? [];

          if (pickups.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pickups.length,
            itemBuilder: (context, index) {
              final pickup = pickups[index];
              final pickupId = pickup['id'];

              return _buildPickupCard(pickup, pickupId);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_turned_in_rounded,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Pending Pickups',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All pickup requests have been processed',
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickupCard(Map<String, dynamic> pickup, String pickupId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheduledDate = pickup['scheduledDate'] != null
        ? (pickup['scheduledDate'] as Timestamp).toDate()
        : DateTime.now();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Colors.purple,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pickup['userName'] ?? 'Unknown',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        pickup['userEmail'] ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Pending',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildPickupDetail('Waste Type', pickup['wasteType'] ?? 'Unknown'),
                _buildPickupDetail('Scheduled', DateFormat('MMM dd').format(scheduledDate)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Description:',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              pickup['description'] ?? 'No description provided',
              style: GoogleFonts.poppins(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              'Address: ${pickup['address'] ?? 'Not provided'}',
              style: GoogleFonts.poppins(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              'Scheduled: ${DateFormat('MMM dd, yyyy HH:mm').format(scheduledDate)}',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _rejectPickup(pickupId, pickup);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _approveAndAssignPickup(pickupId, pickup);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Approve & Assign'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickupDetail(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _approveAndAssignPickup(String pickupId, Map<String, dynamic> pickup) async {
    try {
      // First, get list of available collectors
      final collectorsSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'collector')
          .get();

      if (collectorsSnapshot.docs.isEmpty) {
        Get.snackbar(
          'No Collectors',
          'No collectors available. Please add collectors first.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }

      final collectors = collectorsSnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'name': doc['name'] ?? 'Unknown',
          'email': doc['email'] ?? '',
        };
      }).toList();

      // Show dialog to select collector
      _showCollectorSelectionDialog(pickupId, pickup, collectors);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load collectors: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _showCollectorSelectionDialog(
    String pickupId,
    Map<String, dynamic> pickup,
    List<Map<String, dynamic>> collectors,
  ) {
    String? selectedCollectorId;
    String? selectedCollectorName;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            'Approve & Assign Pickup',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select a collector to assign this pickup:',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: Text(
                      'Select Collector',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    value: selectedCollectorId,
                    items: collectors.map((collector) {
                      return DropdownMenuItem<String>(
                        value: collector['id'],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              collector['name'],
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              collector['email'],
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedCollectorId = value;
                        selectedCollectorName = collectors
                            .firstWhere((c) => c['id'] == value)['name'];
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This will approve the pickup and assign it to the selected collector.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(),
              ),
            ),
            ElevatedButton(
              onPressed: selectedCollectorId == null
                  ? null
                  : () async {
                      Get.back();
                      await _processApprovalAndAssignment(
                        pickupId,
                        pickup,
                        selectedCollectorId!,
                        selectedCollectorName!,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: Text(
                'Approve & Assign',
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Update the _processApprovalAndAssignment method in ManagePickupsScreen

Future<void> _processApprovalAndAssignment(
  String pickupId,
  Map<String, dynamic> pickup,
  String collectorId,
  String collectorName,
) async {
  try {
    // Show loading
    Get.dialog(
      const Center(
        child: CircularProgressIndicator(),
      ),
      barrierDismissible: false,
    );

    // Create assigned task
    await _firestore.collection('assigned_tasks').add({
      'pickupId': pickupId,
      'pickupType': 'special',
      'collectorId': collectorId,
      'collectorName': collectorName,
      'userId': pickup['userId'],
      'userName': pickup['userName'],
      'userEmail': pickup['userEmail'],
      'wasteType': pickup['wasteType'],
      'description': pickup['description'],
      'address': pickup['address'],
      'scheduledDate': pickup['scheduledDate'],
      'assignedBy': _authController.user!.uid,
      'assignedAt': FieldValue.serverTimestamp(),
      'status': 'assigned',
      'location': pickup['location'] ?? {},
      'priority': 'medium',
    });

    // Update pickup status to scheduled and assign collector
    await _firestore.collection('special_pickups').doc(pickupId).update({
      'status': 'scheduled',
      'collectorId': collectorId,
      'collectorName': collectorName,
      'approvedBy': _authController.user!.uid,
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Send notification to resident
    await _notificationService.sendPickupStatusNotification(
      userId: pickup['userId'],
      userName: pickup['userName'],
      status: 'approved',
      pickupId: pickupId,
    );

    // Send notification to assigned collector
    await _firestore.collection('notifications').add({
      'userId': collectorId,
      'title': 'New Task Assigned',
      'message': 'You have been assigned a new pickup task for ${pickup['userName']}',
      'type': 'task_assigned',
      'taskId': pickupId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Close loading dialog
    Get.back();

    Get.snackbar(
      'Success',
      'Pickup approved and assigned to $collectorName',
      backgroundColor: AppThemes.collectedColor,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  } catch (e) {
    // Close loading dialog if open
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }

    Get.snackbar(
      'Error',
      'Failed to approve and assign pickup: ${e.toString()}',
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }
}

  void _rejectPickup(String pickupId, Map<String, dynamic> pickup) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Reject Pickup',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to reject this pickup request?',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Reason (Optional)',
                hintText: 'Enter reason for rejection',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _pickupService.updateSpecialPickupStatus(
                  pickupId,
                  'rejected',
                  _authController.user!.uid,
                );

                // Update with rejection reason if provided
                if (reasonController.text.trim().isNotEmpty) {
                  await _firestore.collection('special_pickups').doc(pickupId).update({
                    'rejectionReason': reasonController.text.trim(),
                  });
                }

                // Send notification to resident
                await _notificationService.sendPickupStatusNotification(
                  userId: pickup['userId'],
                  userName: pickup['userName'],
                  status: 'rejected',
                  pickupId: pickupId,
                );

                Get.back();
                Get.snackbar(
                  'Success',
                  'Pickup rejected',
                  backgroundColor: Colors.orange,
                  colorText: Colors.white,
                );
              } catch (e) {
                Get.back();
                Get.snackbar(
                  'Error',
                  'Failed to reject pickup: ${e.toString()}',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(
              'Reject',
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
    );
  }
}