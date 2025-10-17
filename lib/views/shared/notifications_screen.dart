// views/shared/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_waste_management/controllers/auth_controller.dart';
import 'package:smart_waste_management/services/notification_service.dart';
import 'package:smart_waste_management/utils/app_themes.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final AuthController _authController = Get.find();
  final NotificationService _notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_rounded),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _markAllAsRead();
            },
            child: Text(
              'Mark all read',
              style: GoogleFonts.poppins(
                color: AppThemes.primaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _notificationService.getUserNotifications(_authController.user!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading notifications',
                style: GoogleFonts.poppins(),
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final notificationId = notification['id'];
              final isRead = notification['isRead'] ?? false;

              return _buildNotificationItem(notification, notificationId, isRead);
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
            Icons.notifications_off_rounded,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Notifications',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re all caught up!',
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
    Map<String, dynamic> notification,
    String notificationId,
    bool isRead,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final createdAt = notification['createdAt'] != null
        ? (notification['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isRead 
          ? (isDark ? Colors.grey[800] : Colors.white) 
          : (isDark ? Colors.blue[900]!.withValues(alpha: 0.3) : Colors.blue[50]),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getNotificationColor(notification['type']).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getNotificationIcon(notification['type']),
            color: _getNotificationColor(notification['type']),
            size: 20,
          ),
        ),
        title: Text(
          notification['title'] ?? 'Notification',
          style: GoogleFonts.poppins(
            fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification['message'] ?? '',
              style: GoogleFonts.poppins(
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM dd, yyyy HH:mm').format(createdAt),
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        trailing: !isRead
            ? Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppThemes.primaryGreen,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () {
          _markAsRead(notificationId);
          _handleNotificationTap(notification);
        },
      ),
    );
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'payment':
        return Colors.green;
      case 'pickup':
        return Colors.purple;
      default:
        return AppThemes.primaryGreen;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'payment':
        return Icons.payment_rounded;
      case 'pickup':
        return Icons.assignment_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  void _markAsRead(String notificationId) {
    _notificationService.markAsRead(notificationId);
  }

  void _markAllAsRead() {
    _notificationService.markAllAsRead(_authController.user!.uid);
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    final type = notification['type'];
    final referenceId = notification['referenceId'];

    switch (type) {
      case 'payment':
        Get.snackbar(
          'Payment Update',
          'Payment status updated',
          backgroundColor: AppThemes.collectedColor,
          colorText: Colors.white,
        );
        break;
      case 'pickup':
        Get.snackbar(
          'Pickup Update',
          'Pickup status updated',
          backgroundColor: Colors.purple,
          colorText: Colors.white,
        );
        break;
      default:
        break;
    }
  }
}