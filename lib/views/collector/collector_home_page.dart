import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_waste_management/controllers/auth_controller.dart';
import 'package:smart_waste_management/controllers/pickup_controller.dart';
import 'package:smart_waste_management/utils/app_themes.dart';
import 'package:smart_waste_management/views/collector/assigned_tasks_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

class CollectorHomePage extends StatefulWidget {
  const CollectorHomePage({super.key});

  @override
  State<CollectorHomePage> createState() => _CollectorHomePageState();
}

class _CollectorHomePageState extends State<CollectorHomePage> {
  final AuthController authController = Get.find();
  final PickupController pickupController = Get.find();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    developer.log('Collector Home initialized for user: ${authController.user?.uid}', 
        name: 'CollectorHomePage');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final collectorId = authController.user?.uid ?? '';

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modern Header
              _buildModernHeader(context),
              const SizedBox(height: 32),
              
              // Quick Actions
              _buildQuickActionsSection(context),
              const SizedBox(height: 32),
              
              // Statistics Cards
              _buildStatisticsSection(context, collectorId),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      
    );
  }

  Widget _buildModernHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentTime = DateTime.now();
    final hour = currentTime.hour;
    String greeting = 'Good Morning';

    if (hour >= 12 && hour < 17) {
      greeting = 'Good Afternoon';
    } else if (hour >= 17) {
      greeting = 'Good Evening';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Colors.grey[800]!,
                  Colors.grey[850]!,
                  Colors.grey[900]!,
                ]
              : [
                  Colors.white,
                  Color(0xFFF8F9FA),
                  Color(0xFFE9ECEF),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Profile and Text Section
          Expanded(
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
                            AppThemes.primaryGreen,
                            AppThemes.primaryGreen.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.eco_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'EcoCollect',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppThemes.primaryGreen,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  greeting,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  authController.user?.displayName?.split(' ').first ?? 'Collector',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Waste Collection Specialist',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                
              ],
            ),
          ),
          
          // Profile Icon and Notification
          const SizedBox(width: 16),
          Column(
            children: [
              // Profile Avatar
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppThemes.primaryGreen,
                      AppThemes.primaryGreen.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppThemes.primaryGreen.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ],
      ),
    );
  }

  

  Widget _buildMiniStatItem(String value, String label, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.white 
                : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                context,
                'Start Route',
                Icons.play_arrow_rounded,
                AppThemes.primaryGreen,
                () {
                  _startRoute();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                context,
                'View Tasks',
                Icons.assignment_rounded,
                Colors.blue,
                () {
                  Get.to(() => const AssignedTasksScreen());
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                context,
                'Reports',
                Icons.assessment_rounded,
                Colors.orange,
                () {
                  _viewReports();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsSection(BuildContext context, String collectorId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistics Overview',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.white 
                : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('assigned_tasks')
              .where('collectorId', isEqualTo: collectorId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return _buildStatCardsLoading();
            }

            final tasks = snapshot.data!.docs;
            // Aggregate current tasks
            final completed = tasks.where((doc) {
              final status = (doc.data() as Map<String, dynamic>)['status'];
              return status == 'completed';
            }).length;

            final pending = tasks.where((doc) {
              final status = (doc.data() as Map<String, dynamic>)['status'];
              return status == 'assigned' || status == 'in_progress';
            }).length;

            // Calculate total collected weight
            double totalWeight = 0.0;
            for (var doc in tasks) {
              final data = doc.data() as Map<String, dynamic>;
              if (data['status'] == 'completed' && data['collectedWeight'] != null) {
                totalWeight += (data['collectedWeight'] as num).toDouble();
              }
            }

            final cards = <Widget>[
              _buildStatCard(
                'Completed Tasks',
                '$completed',
                Icons.check_circle_rounded,
                AppThemes.collectedColor,
              ),
              _buildStatCard(
                'Pending Tasks',
                '$pending',
                Icons.pending_actions_rounded,
                Colors.orange,
              ),
              _buildStatCard(
                'Total Weight',
                '${totalWeight.toStringAsFixed(1)} kg',
                Icons.scale_rounded,
                Colors.blue,
              ),
              _buildStatCard(
                'Total Tasks',
                '${tasks.length}',
                Icons.assignment_rounded,
                Colors.purple,
              ),
            ];

            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: cards,
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCardsLoading() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _buildStatCard('Completed', '0', Icons.check_circle_rounded, AppThemes.collectedColor),
        _buildStatCard('Pending', '0', Icons.pending_actions_rounded, Colors.orange),
        _buildStatCard('Total Weight', '0kg', Icons.scale_rounded, Colors.blue),
        _buildStatCard('Total Tasks', '0', Icons.assignment_rounded, Colors.purple),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // Helper Methods
  void _startRoute() {
    Get.snackbar(
      'Route Started',
      'Beginning your collection route',
      backgroundColor: AppThemes.primaryGreen,
      colorText: Colors.white,
    );
  }

  void _viewReports() {
    Get.snackbar(
      'Reports',
      'Opening reports dashboard',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
    );
  }

  // Status and Type Helpers (kept for potential future use)
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
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

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
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

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
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

  IconData _getWasteTypeIcon(String type) {
    switch (type.toLowerCase()) {
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

  String _getWasteTypeText(String type) {
    switch (type.toLowerCase()) {
      case 'general':
        return 'General';
      case 'recyclable':
        return 'Recyclable';
      case 'organic':
        return 'Organic';
      case 'hazardous':
        return 'Hazardous';
      default:
        return type;
    }
  }

  Color _getWasteTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'general':
        return Colors.grey;
      case 'recyclable':
        return Colors.blue;
      case 'organic':
        return AppThemes.collectedColor;
      case 'hazardous':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}