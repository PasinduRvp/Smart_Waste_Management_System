import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_waste_management/controllers/auth_controller.dart';
import 'package:smart_waste_management/controllers/pickup_controller.dart';
import 'package:smart_waste_management/utils/app_themes.dart';
import 'package:smart_waste_management/views/shared/notifications_screen.dart';
import 'package:smart_waste_management/views/resident/payment_process_screen.dart';
import 'package:smart_waste_management/views/resident/schedule_special_pickup_screen.dart';
import 'package:smart_waste_management/services/notification_service.dart';
import 'package:smart_waste_management/views/resident/pickup_history_screen.dart';
import 'package:smart_waste_management/views/resident/billing_center_screen.dart';
import 'package:smart_waste_management/views/resident/bill_payment_screen.dart'; // NEW
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

class ResidentHomePage extends StatefulWidget {
  const ResidentHomePage({super.key});

  @override
  State<ResidentHomePage> createState() => _ResidentHomePageState();
}

class _ResidentHomePageState extends State<ResidentHomePage> {
  final AuthController authController = Get.find();
  final PickupController pickupController = Get.put(PickupController());
  final NotificationService _notificationService = NotificationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = authController.user?.uid ?? '';

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(context),
            const SizedBox(height: 24), // Increased from 16 to 24
            
            // Combined Status Section
            _buildCombinedStatusSection(context),
            const SizedBox(height: 16),
            
            // Pending Bills Section (NEW)
            _buildPendingBillsSection(context, userId),
            const SizedBox(height: 16),
            
            // Statistics Section
            FutureBuilder<Map<String, int>>(
              future: pickupController.getUserPickupStatistics(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildStatisticsLoading(context);
                }

                if (snapshot.hasError) {
                  developer.log('Error loading statistics: ${snapshot.error}', name: 'ResidentHomePage');
                  return _buildStatisticsError(context);
                }

                final stats = snapshot.data ?? {
                  'total': 0,
                  'scheduled': 0,
                  'collected': 0,
                  'missed': 0,
                };

                return _buildStatistics(stats, context);
              },
            ),

            const SizedBox(height: 24),
            _buildQuickActionsSection(context),
            const SizedBox(height: 24),
            _buildRecentPickupsSection(context, userId),
            const SizedBox(height: 100),
          ],
        ),
      ),
      floatingActionButton: GetBuilder<AuthController>(
        builder: (authController) {
          // Only show FAB if user has active membership
          if (authController.hasActiveMembership) {
            return FloatingActionButton.extended(
              onPressed: () {
                Get.to(() => const ScheduleSpecialPickupScreen());
              },
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'Special Pickup',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              backgroundColor: AppThemes.primaryGreen,
              foregroundColor: Colors.white,
            );
          } else {
            return const SizedBox(); // Hide FAB if no active membership
          }
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // NEW: Pending Bills Section
  Widget _buildPendingBillsSection(BuildContext context, String userId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getPendingBills(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildBillsLoading();
        }

        if (snapshot.hasError) {
          developer.log('Error loading bills: ${snapshot.error}', name: 'ResidentHomePage');
          return const SizedBox(); // Hide on error
        }

        final bills = snapshot.data ?? [];
        final pendingBills = bills.where((bill) => 
          bill['billStatus'] == 'pending' && 
          bill['actualAmount'] != null
        ).toList();

        if (pendingBills.isEmpty) {
          return const SizedBox();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pending Bills',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (pendingBills.length > 2)
                  TextButton(
                    onPressed: () {
                      Get.to(() => const BillingCenterScreen());
                    },
                    child: Text(
                      'View All',
                      style: GoogleFonts.poppins(
                        color: AppThemes.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...pendingBills.take(2).map((bill) => _buildBillCard(bill)).toList(),
          ],
        );
      },
    );
  }

  // NEW: Get pending bills stream
  Stream<List<Map<String, dynamic>>> _getPendingBills(String userId) {
    return _firestore
        .collection('special_pickups')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'completed')
        .orderBy('collectionDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            ...data,
          };
        }).toList());
  }

  // NEW: Build bill card
  Widget _buildBillCard(Map<String, dynamic> bill) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amount = bill['actualAmount'] ?? 0.0;
    final collectionDate = bill['collectionDate'] != null
        ? (bill['collectionDate'] as Timestamp).toDate()
        : DateTime.now();
    final wasteType = bill['wasteType'] ?? 'Special Waste';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                  'Pickup Bill',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Pending Payment',
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getWasteTypeIcon(wasteType),
                    size: 20,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getWasteTypeDisplayName(wasteType),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        DateFormat('MMM dd, yyyy').format(collectionDate),
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
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Amount',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'LKR ${amount.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppThemes.primaryGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Get.to(() => BillPaymentScreen(pickup: bill));
                    },
                    icon: const Icon(Icons.payment_rounded, size: 16),
                    label: const Text('Pay Now'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      backgroundColor: AppThemes.primaryGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _downloadBillPdf(bill),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Download'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Bills loading state
  Widget _buildBillsLoading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pending Bills',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 16,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // NEW: Download bill PDF
  void _downloadBillPdf(Map<String, dynamic> bill) {
    Get.snackbar(
      'Info',
      'PDF download feature will be implemented soon',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
    );
  }

  // Combined status section that handles both payment and membership status
  Widget _buildCombinedStatusSection(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: authController.getPaymentStatusStream(),
      builder: (context, paymentSnapshot) {
        return StreamBuilder<String>(
          stream: authController.getMembershipStatusStream(),
          builder: (context, membershipSnapshot) {
            // Fallback banner if streams error out (e.g., missing Firestore index)
            if (paymentSnapshot.hasError || membershipSnapshot.hasError) {
              return _buildInactiveMembershipBanner();
            }
            
            final payment = paymentSnapshot.data;
            final paymentStatus = payment?['status'];
            final membershipStatus = membershipSnapshot.data ?? authController.membershipStatus;
            
            developer.log('=== STATUS DEBUG ===', name: 'ResidentHomePage');
            developer.log('Payment Status: $paymentStatus', name: 'ResidentHomePage');
            developer.log('Membership Status: $membershipStatus', name: 'ResidentHomePage');
            developer.log('Has Active Membership: ${authController.hasActiveMembership}', name: 'ResidentHomePage');
            developer.log('===================', name: 'ResidentHomePage');

            // Show loading state
            if (paymentSnapshot.connectionState == ConnectionState.waiting || 
                membershipSnapshot.connectionState == ConnectionState.waiting) {
              return _buildPaymentStatusLoading();
            }

            // PRIORITY 1: If payment is pending or rejected, show payment status
            if (paymentStatus == 'pending' || paymentStatus == 'rejected') {
              final submittedAt = payment?['submittedAt'] != null
                  ? (payment!['submittedAt'] as Timestamp).toDate()
                  : null;
              return _buildPaymentStatusCard(payment!, paymentStatus!, submittedAt);
            }

            // PRIORITY 2: If membership is active, show active banner
            if (membershipStatus == 'active' || authController.hasActiveMembership) {
              return _buildActiveMembershipBanner();
            }

            // PRIORITY 3: If payment was approved but membership not updated yet
            if (paymentStatus == 'approved' && membershipStatus != 'active') {
              return _buildPaymentApprovedProcessingCard();
            }

            // PRIORITY 4: If no payment data and membership is inactive
            if (payment == null && membershipStatus == 'inactive') {
              return _buildInactiveMembershipBanner();
            }

            // PRIORITY 5: Default fallback
            return _buildInactiveMembershipBanner();
          },
        );
      },
    );
  }

  Widget _buildPaymentApprovedProcessingCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
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
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.verified_rounded, color: Colors.green, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Approved - Activating Membership',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        'Your membership is being activated...',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: null,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentStatusLoading() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Checking Status...',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Please wait while we load your information',
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

  Widget _buildPaymentStatusCard(
      Map<String, dynamic> payment, String status, DateTime? submittedAt) {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    String description;

    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending_actions_rounded;
        statusText = 'Payment Under Review';
        description = 'Your payment is being reviewed by our team. You will be notified once approved.';
        break;
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.verified_rounded;
        statusText = 'Payment Approved';
        description = 'Your membership has been activated! You can now schedule pickups.';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel_rounded;
        statusText = 'Payment Rejected';
        description = 'Your payment was rejected. Please contact support for more information.';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.payment_rounded;
        statusText = 'Payment Submitted';
        description = 'Your payment has been submitted successfully.';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
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
                    color: statusColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusText,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: statusColor,
                        ),
                      ),
                      if (submittedAt != null)
                        Text(
                          'Submitted: ${DateFormat('MMM dd, yyyy HH:mm').format(submittedAt)}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                if (status == 'pending')
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
            if (status == 'pending') ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: null,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Waiting for admin approval...',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (status == 'rejected') ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Get.to(() => const PaymentProcessScreen());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Resubmit Payment'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInactiveMembershipBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Membership Required',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[700],
                  ),
                ),
                Text(
                  'Complete membership payment to schedule pickups',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.orange[600],
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Get.to(() => const PaymentProcessScreen());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              'Pay Now',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveMembershipBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_rounded, color: Colors.green[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Membership Active',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                  ),
                ),
                Text(
                  'Annual membership • You can schedule pickups',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.green[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green[700],
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'Active',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    final userName = authController.user?.displayName ?? 'Resident';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppThemes.primaryGreen,
            AppThemes.lightGreen,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppThemes.primaryGreen.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Name with Modern Styling
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white,
                      Colors.white.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.eco_rounded,
                  color: AppThemes.primaryGreen,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'EcoCollect',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10), // Increased from 16 to 20
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 4), // Added extra bottom spacing
                    Text(
                      userName,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () {
                        Get.to(() => const NotificationsScreen());
                      },
                      icon: const Icon(
                        Icons.notifications_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  StreamBuilder<int>(
                    stream: _notificationService.getUnreadNotificationCount(authController.user!.uid),
                    builder: (context, snapshot) {
                      final unreadCount = snapshot.data ?? 0;
                      
                      if (unreadCount > 0) {
                        return Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            child: Text(
                              unreadCount > 9 ? '9+' : unreadCount.toString(),
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10), // Increased from 16 to 20
          Row(
            children: [
              const Icon(Icons.eco_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Making our environment cleaner, one pickup at a time',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.95),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsLoading(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            'Total',
            '0',
            Icons.delete_outline,
            AppThemes.primaryGreen,
            isLoading: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            'Scheduled',
            '0',
            Icons.schedule,
            AppThemes.scheduledColor,
            isLoading: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            'Collected',
            '0',
            Icons.check_circle_outline,
            AppThemes.collectedColor,
            isLoading: true,
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsError(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.red[400], size: 40),
          const SizedBox(height: 8),
          Text(
            'Unable to load statistics',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Please check your connection',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics(Map<String, int> stats, BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            'Total',
            stats['total'].toString(),
            Icons.delete_outline,
            AppThemes.primaryGreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            'Scheduled',
            stats['scheduled'].toString(),
            Icons.schedule,
            AppThemes.scheduledColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            'Collected',
            stats['collected'].toString(),
            Icons.check_circle_outline,
            AppThemes.collectedColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color, {
    bool isLoading = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: isLoading 
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  )
                : Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          if (isLoading)
            SizedBox(
              height: 24,
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
            )
          else
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: [
            _buildActionCard(
              context,
              'Make Payment',
              Icons.payment_rounded,
              AppThemes.primaryGreen,
              'Pay membership fee',
              () {
                Get.to(() => const PaymentProcessScreen());
              },
            ),
            
            _buildActionCard(
              context,
              'Special Pickup',
              Icons.star_rounded,
              Colors.purple,
              'Schedule special pickup',
              () {
                if (authController.hasActiveMembership) {
                  Get.to(() => const ScheduleSpecialPickupScreen());
                } else {
                  Get.snackbar(
                    'Membership Required',
                    'Please complete membership payment to schedule pickups',
                    backgroundColor: Colors.orange,
                    colorText: Colors.white,
                    duration: const Duration(seconds: 3),
                  );
                }
              },
            ),
            _buildActionCard(
              context,
              'My Pickups',
              Icons.history_rounded,
              AppThemes.scheduledColor,
              'View pickup history',
              () {
                Get.to(() => const PickupHistoryScreen());
              },
            ),
            _buildActionCard(
              context,
              'Support',
              Icons.support_agent_rounded,
              AppThemes.pendingColor,
              'Get help & support',
              () {
                Get.snackbar(
                  'Support', 
                  'Contact support for assistance',
                  backgroundColor: AppThemes.primaryGreen,
                  colorText: Colors.white,
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    String subtitle,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentPickupsSection(BuildContext context, String userId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Pickups',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () {
                Get.to(() => const PickupHistoryScreen());
              },
              child: Text(
                'View All',
                style: GoogleFonts.poppins(
                  color: AppThemes.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<PickupItem>>(
          stream: pickupController.getCombinedUserPickups(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildPickupsLoadingState();
            }

            if (snapshot.hasError) {
              developer.log('Error loading pickups: ${snapshot.error}', name: 'ResidentHomePage');
              return _buildPickupsErrorState('Failed to load pickups');
            }

            final pickups = snapshot.data ?? [];
            final recentPickups = pickups.take(3).toList();

            if (recentPickups.isEmpty) {
              return _buildEmptyPickupsState();
            }

            return Column(
              children: recentPickups.map((pickup) {
                return _buildPickupItem(pickup);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPickupsLoadingState() {
    return Column(
      children: [
        _buildPickupItemLoading(),
        const SizedBox(height: 12),
        _buildPickupItemLoading(),
        const SizedBox(height: 12),
        _buildPickupItemLoading(),
      ],
    );
  }

  Widget _buildPickupItemLoading() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        title: Container(
          height: 16,
          width: 120,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Container(
              height: 12,
              width: 80,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 10,
              width: 60,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
        trailing: Container(
          width: 60,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildPickupsErrorState(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(
            'Error Loading Pickups',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPickupsState() {
    return GetBuilder<AuthController>(
      builder: (authController) {
        return Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(
                Icons.delete_sweep_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                authController.hasActiveMembership ? 'No Pickups Yet' : 'Membership Required',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                authController.hasActiveMembership 
                    ? 'Schedule your first pickup to get started'
                    : 'Complete membership payment to schedule pickups',
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              if (!authController.hasActiveMembership) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Get.to(() => const PaymentProcessScreen());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemes.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Pay Membership Fee',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPickupItem(PickupItem pickup) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: pickup.statusColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getWasteTypeIcon(pickup.wasteType),
            color: pickup.statusColor,
            size: 24,
          ),
        ),
        title: Text(
          pickup.displayWasteType,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              pickup.address,
              style: GoogleFonts.poppins(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${pickup.formattedDate} • ${pickup.formattedTime}',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
            if (pickup.pickupType == 'special')
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Special',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.purple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        trailing: Chip(
          label: Text(
            pickup.displayStatus,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          backgroundColor: pickup.statusColor,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  IconData _getWasteTypeIcon(String type) {
    switch (type) {
      case 'general':
        return Icons.delete_outline;
      case 'recyclable':
        return Icons.recycling_rounded;
      case 'organic':
        return Icons.eco_rounded;
      case 'hazardous':
        return Icons.warning_amber_rounded;
      default:
        return Icons.delete_outline;
    }
  }

  // NEW: Helper method for waste type display names
  String _getWasteTypeDisplayName(String type) {
    switch (type) {
      case 'general':
        return 'General Waste';
      case 'recyclable':
        return 'Recyclable Waste';
      case 'organic':
        return 'Organic Waste';
      case 'hazardous':
        return 'Hazardous Waste';
      case 'Paper':
        return 'Paper Waste';
      case 'Polythene & Plastic':
        return 'Plastic Waste';
      case 'Food Waste':
        return 'Food Waste';
      case 'E-Waste':
        return 'E-Waste';
      case 'Other Special Waste':
        return 'Special Waste';
      default:
        return type;
    }
  }
}