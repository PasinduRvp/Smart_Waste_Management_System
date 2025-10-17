import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_waste_management/controllers/auth_controller.dart';
import 'package:smart_waste_management/services/pickup_service.dart';
import 'package:smart_waste_management/utils/app_themes.dart';
import 'package:smart_waste_management/views/resident/bill_payment_screen.dart';
import 'package:smart_waste_management/services/bill_pdf_service.dart';

class BillingCenterScreen extends StatefulWidget {
  const BillingCenterScreen({super.key});

  @override
  State<BillingCenterScreen> createState() => _BillingCenterScreenState();
}

class _BillingCenterScreenState extends State<BillingCenterScreen> {
  final AuthController _authController = Get.find();
  final PickupService _pickupService = PickupService();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = _authController.user?.uid ?? '';

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'Bills & Payments',
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
        stream: _pickupService.getCompletedPickupsWithBills(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load bills', style: GoogleFonts.poppins()),
            );
          }
          final items = (snapshot.data ?? [])
              .where((e) => (e['actualAmount'] ?? 0) > 0)
              .toList();
          if (items.isEmpty) {
            return _buildEmpty(isDark);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return _buildBillCard(items[index], isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No bills available',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Completed pickups with bills will appear here',
            style: GoogleFonts.poppins(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildBillCard(Map<String, dynamic> bill, bool isDark) {
    final amount = (bill['actualAmount'] ?? 0.0) as num;
    final wasteType = (bill['wasteType'] ?? 'Special Waste').toString();
    final status = (bill['billStatus'] ?? 'pending').toString();
    final collectedAt = bill['collectionDate'] is Timestamp
        ? (bill['collectionDate'] as Timestamp).toDate()
        : null;

    Color statusColor;
    String statusText;
    switch (status) {
      case 'paid':
        statusColor = Colors.green;
        statusText = 'Paid';
        break;
      case 'overdue':
        statusColor = Colors.red;
        statusText = 'Overdue';
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'Pending Payment';
    }

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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.star_rounded, color: Colors.purple, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wasteType,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        if (collectedAt != null)
                          Text(
                            'Collected: ${DateFormat('MMM dd, yyyy').format(collectedAt)}',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                          ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
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
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                Text(
                  'LKR ${amount.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
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
                    onPressed: status == 'paid'
                        ? null
                        : () {
                            final billData = {
                              'id': bill['id'],
                              'wasteType': bill['wasteType'],
                              'actualAmount': bill['actualAmount'],
                              'collectedWeight': bill['collectedWeight'],
                              'collectionDate': bill['collectionDate'] is Timestamp
                                  ? bill['collectionDate']
                                  : (bill['collectionDate'] == null
                                      ? null
                                      : Timestamp.fromDate(collectedAt!)),
                              'address': bill['address'],
                              'description': bill['description'],
                            };
                            Get.to(() => BillPaymentScreen(pickup: billData));
                          },
                    icon: const Icon(Icons.payment_rounded, size: 16),
                    label: const Text('Pay Bill'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      backgroundColor: AppThemes.primaryGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                
              ],
            ),
          ],
        ),
      ),
    );
  }
}


