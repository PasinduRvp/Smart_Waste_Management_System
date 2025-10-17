// views/collector/task_completion_screen.dart (Updated)
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_waste_management/controllers/auth_controller.dart';
import 'package:smart_waste_management/services/notification_service.dart';
import 'package:smart_waste_management/services/pickup_service.dart';
import 'package:smart_waste_management/utils/app_themes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class TaskCompletionScreen extends StatefulWidget {
  final Map<String, dynamic> task;

  const TaskCompletionScreen({super.key, required this.task});

  @override
  State<TaskCompletionScreen> createState() => _TaskCompletionScreenState();
}

class _TaskCompletionScreenState extends State<TaskCompletionScreen> {
  final AuthController _authController = Get.find();
  final NotificationService _notificationService = NotificationService();
  final PickupService _pickupService = PickupService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _binIdController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _actualAmountController = TextEditingController();

  bool _isSubmitting = false;
  bool _showScanner = false;
  MobileScannerController _scannerController = MobileScannerController();

  @override
  void initState() {
    super.initState();
    // Pre-fill with estimated amount if available
    final estimatedAmount = widget.task['estimatedAmount'] ?? 0.0;
    _actualAmountController.text = estimatedAmount.toString();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'Complete Pickup',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_rounded),
        ),
      ),
      body: _showScanner ? _buildQRScanner() : _buildCompletionForm(),
    );
  }

  Widget _buildQRScanner() {
    return Column(
      children: [
        AppBar(
          title: Text(
            'Scan Bin QR Code',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () {
              setState(() {
                _showScanner = false;
              });
            },
            icon: const Icon(Icons.arrow_back_ios_rounded),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              MobileScanner(
                controller: _scannerController,
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null) {
                      setState(() {
                        _binIdController.text = barcode.rawValue!;
                        _showScanner = false;
                      });
                      Get.snackbar(
                        'Success',
                        'QR Code scanned successfully',
                        backgroundColor: AppThemes.collectedColor,
                        colorText: Colors.white,
                      );
                      break;
                    }
                  }
                },
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black54,
                  child: Text(
                    'Position the QR code within the frame',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppThemes.primaryGreen,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionForm() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final estimatedAmount = widget.task['estimatedAmount'] ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task Summary Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pickup Summary',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow('Customer', widget.task['userName'] ?? 'Unknown'),
                  _buildSummaryRow('Address', widget.task['address'] ?? 'No address'),
                  _buildSummaryRow('Waste Type', _getWasteTypeText(widget.task['wasteType'])),
                  _buildSummaryRow('Estimated Amount', '${estimatedAmount.toStringAsFixed(2)} kg'),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Collection Details Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Collection Details',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Bin ID with QR Scanner
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bin ID *',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _binIdController,
                              decoration: InputDecoration(
                                hintText: 'Enter or scan bin ID',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _startQRScan,
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            style: IconButton.styleFrom(
                              backgroundColor: AppThemes.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(16),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Weight Input
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Actual Weight (kg) *',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Enter actual weight in kilograms',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Actual Amount (NEW)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Actual Amount (LKR) *',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _actualAmountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Enter actual amount in LKR',
                          prefixText: 'LKR ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Additional Notes
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Additional Notes',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Any additional notes or observations...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitCompletion,
              icon: _isSubmitting 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_rounded),
              label: Text(
                _isSubmitting ? 'Submitting...' : 'Submit Completion',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppThemes.collectedColor,
                disabledBackgroundColor: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
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

  void _startQRScan() {
    setState(() {
      _showScanner = true;
    });
  }

  Future<void> _submitCompletion() async {
    if (_binIdController.text.isEmpty) {
      Get.snackbar(
        'Error',
        'Please enter or scan bin ID',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (_weightController.text.isEmpty) {
      Get.snackbar(
        'Error',
        'Please enter waste weight',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (_actualAmountController.text.isEmpty) {
      Get.snackbar(
        'Error',
        'Please enter actual amount',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final weight = double.tryParse(_weightController.text);
    if (weight == null || weight <= 0) {
      Get.snackbar(
        'Error',
        'Please enter a valid weight',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final actualAmount = double.tryParse(_actualAmountController.text);
    if (actualAmount == null || actualAmount <= 0) {
      Get.snackbar(
        'Error',
        'Please enter a valid amount',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Use the new pickup service method
      await _pickupService.completePickup(
        pickupId: widget.task['pickupId'],
        collectorId: _authController.user!.uid,
        collectorName: _authController.user?.displayName ?? 'Collector',
        actualAmount: actualAmount,
        binId: _binIdController.text,
        weight: weight,
        notes: _notesController.text,
      );

      // Update assigned task
      await _firestore.collection('assigned_tasks').doc(widget.task['id']).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'binId': _binIdController.text,
        'collectedWeight': weight,
        'actualAmount': actualAmount,
        'collectorNotes': _notesController.text,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notifications
      await _sendCompletionNotifications(weight, actualAmount);

      setState(() {
        _isSubmitting = false;
      });

      Get.until((route) => route.isFirst);
      Get.snackbar(
        'Success',
        'Pickup completed successfully! Bill generated for resident.',
        backgroundColor: AppThemes.collectedColor,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );

    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      
      Get.snackbar(
        'Error',
        'Failed to submit completion: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _sendCompletionNotifications(double weight, double amount) async {
    try {
      // Notify resident about completion and bill
      await _notificationService.sendCollectionCompletionNotification(
        userId: widget.task['userId'],
        collectorName: _authController.user?.displayName ?? 'Collector',
        binId: _binIdController.text,
        weight: weight,
        address: widget.task['address'],
        amount: amount, // NEW: Include amount in notification
      );

      // Notify admin
      final adminSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      for (final adminDoc in adminSnapshot.docs) {
        await _firestore.collection('notifications').add({
          'userId': adminDoc.id,
          'title': 'Pickup Completed',
          'message': '${_authController.user?.displayName} completed pickup for ${widget.task['userName']}. Weight: ${weight.toStringAsFixed(2)} kg, Amount: LKR ${amount.toStringAsFixed(2)}',
          'type': 'collection_completed',
          'referenceId': widget.task['id'],
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Send progress update to collector
      await _firestore.collection('notifications').add({
        'userId': _authController.user!.uid,
        'title': 'Task Completed',
        'message': 'You successfully completed the pickup for ${widget.task['userName']}',
        'type': 'task_completed',
        'referenceId': widget.task['id'],
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

    } catch (e) {
      print('Error sending completion notifications: $e');
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