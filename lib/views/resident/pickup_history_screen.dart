// lib/views/resident/pickup_history_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:smart_waste_management/controllers/auth_controller.dart';
import 'package:smart_waste_management/controllers/pickup_controller.dart';
import 'package:smart_waste_management/utils/app_themes.dart';
import 'package:smart_waste_management/views/resident/schedule_special_pickup_screen.dart';
import 'package:smart_waste_management/views/resident/bill_payment_screen.dart'; // NEW
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_waste_management/services/bill_pdf_service.dart';

class PickupHistoryScreen extends StatefulWidget {
  const PickupHistoryScreen({super.key});

  @override
  State<PickupHistoryScreen> createState() => _PickupHistoryScreenState();
}

class _PickupHistoryScreenState extends State<PickupHistoryScreen> {
  final AuthController _authController = Get.find();
  final PickupController _pickupController = Get.find();
  
  final List<String> _statusFilters = ['All', 'Upcoming', 'Completed', 'Cancelled'];
  String _selectedStatusFilter = 'All';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  List<PickupItem> _filterPickups(List<PickupItem> pickups) {
    if (_selectedStatusFilter == 'All') return pickups;
    
    return pickups.where((pickup) {
      switch (_selectedStatusFilter) {
        case 'Upcoming':
          return pickup.isUpcoming;
        case 'Completed':
          return pickup.isCompleted;
        case 'Cancelled':
          return pickup.isCancelled;
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    
    // The streams will automatically update, but we can trigger a rebuild
    await Future.delayed(const Duration(milliseconds: 500));
    
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = _authController.user?.uid ?? '';

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'Special Pickup History',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_rounded),
        ),
        actions: [
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? Colors.grey[800] : Colors.white,
            child: Row(
              children: [
                Text(
                  'Filter:',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedStatusFilter,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: _statusFilters.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedStatusFilter = newValue!;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<PickupItem>>(
              stream: _pickupController.getUserSpecialPickups(userId),
              builder: (context, snapshot) {
                return _buildPickupList(snapshot);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickupList(AsyncSnapshot<List<PickupItem>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading pickups',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please try again later',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final pickups = snapshot.data ?? [];
    final filteredPickups = _filterPickups(pickups);

    if (filteredPickups.isEmpty) {
      return _buildEmptyState(pickups.isEmpty);
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredPickups.length,
        itemBuilder: (context, index) {
          final pickup = filteredPickups[index];
          return _buildPickupCard(pickup);
        },
      ),
    );
  }

  Widget _buildEmptyState(bool noData) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.star_outline_rounded,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  noData ? 'No Special Pickups' : 'No Matching Pickups',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  noData
                      ? 'You haven\'t scheduled any special pickups yet'
                      : 'No ${_selectedStatusFilter.toLowerCase()} special pickups found',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (noData)
                  ElevatedButton.icon(
                    onPressed: () {
                      Get.to(() => const ScheduleSpecialPickupScreen());
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Schedule Special Pickup'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPickupCard(PickupItem pickup) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasBill = pickup.status == 'completed' && (pickup.actualAmount ?? 0) > 0;
    final billStatus = pickup.billStatus;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Type and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Special Pickup',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.purple,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: pickup.statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            pickup.statusIcon,
                            size: 12,
                            color: pickup.statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            pickup.displayStatus,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: pickup.statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasBill) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getBillStatusColor(billStatus).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getBillStatusText(billStatus),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _getBillStatusColor(billStatus),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Waste Type and Date
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getWasteTypeIcon(pickup.wasteType),
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
                        pickup.displayWasteType,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        DateFormat('MMM dd, yyyy • HH:mm').format(pickup.scheduledDate),
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
            // Address
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pickup.address,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            // Description (if available)
            if (pickup.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pickup.description,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            // Bill Amount (NEW)
            if (hasBill) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bill Amount:',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'LKR ${(pickup.actualAmount ?? 0).toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppThemes.primaryGreen,
                    ),
                  ),
                ],
              ),
            ],
            // Action Buttons for Pending Bills (NEW)
            if (hasBill && billStatus == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Convert PickupItem to Map for BillPaymentScreen
                        final billData = {
                          'id': pickup.id,
                          'wasteType': pickup.wasteType,
                          'actualAmount': pickup.actualAmount,
                          'collectedWeight': pickup.collectedWeight,
                          'collectionDate': Timestamp.fromDate(pickup.scheduledDate),
                          'address': pickup.address,
                          'description': pickup.description,
                        };
                        Get.to(() => BillPaymentScreen(pickup: billData));
                      },
                      icon: const Icon(Icons.payment_rounded, size: 16),
                      label: const Text('Pay Bill'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        backgroundColor: AppThemes.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _downloadBillPdf(pickup),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Download'),
                    ),
                  ),
                ],
              ),
            ],
            // Created Date
            const SizedBox(height: 12),
            Text(
              'Scheduled: ${DateFormat('MMM dd, yyyy').format(pickup.createdAt)}',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Bill status helper methods
  Color _getBillStatusColor(String? status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getBillStatusText(String? status) {
    switch (status) {
      case 'paid':
        return 'Paid';
      case 'pending':
        return 'Pending Payment';
      case 'overdue':
        return 'Overdue';
      default:
        return 'No Bill';
    }
  }

  // NEW: Download bill PDF
  void _downloadBillPdf(PickupItem pickup) async {
    final bill = {
      'id': pickup.id,
      'wasteType': pickup.wasteType,
      'actualAmount': pickup.actualAmount ?? 0,
      'collectedWeight': pickup.collectedWeight ?? 0,
      'collectionDate': Timestamp.fromDate(pickup.scheduledDate),
      'address': pickup.address,
      'description': pickup.description,
    };
    final pdfService = BillPdfService();
    await pdfService.generateAndShareBillPdf(bill: bill);
  }

  IconData _getWasteTypeIcon(String wasteType) {
    switch (wasteType) {
      case 'general':
        return Icons.delete_outline;
      case 'recyclable':
        return Icons.recycling_rounded;
      case 'organic':
        return Icons.eco_rounded;
      case 'hazardous':
      case 'Hazardous Waste':
        return Icons.warning_amber_rounded;
      case 'Bulky Items':
        return Icons.weekend_outlined;
      case 'E-Waste':
        return Icons.computer_rounded;
      case 'Construction Waste':
        return Icons.construction_rounded;
      case 'Garden Waste':
        return Icons.nature_rounded;
      case 'Paper':
        return Icons.description;
      case 'Polythene & Plastic':
        return Icons.local_drink;
      case 'Food Waste':
        return Icons.restaurant;
      case 'Other Special Waste':
        return Icons.warning;
      default:
        return Icons.delete_outline;
    }
  }
}