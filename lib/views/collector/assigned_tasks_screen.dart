// views/collector/assigned_tasks_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_waste_management/controllers/auth_controller.dart';
import 'package:smart_waste_management/utils/app_themes.dart';
import 'package:intl/intl.dart';
import 'package:smart_waste_management/views/collector/task_details_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

class AssignedTasksScreen extends StatefulWidget {
  const AssignedTasksScreen({super.key});

  @override
  State<AssignedTasksScreen> createState() => _AssignedTasksScreenState();
}

class _AssignedTasksScreenState extends State<AssignedTasksScreen> {
  final AuthController _authController = Get.find();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    developer.log('AssignedTasksScreen initialized for collector: ${_authController.user?.uid}', 
        name: 'AssignedTasksScreen');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'Assigned Tasks',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_rounded),
        ),
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getFilteredTasks(),
              builder: (context, snapshot) {
                developer.log('Stream state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, hasError: ${snapshot.hasError}', 
                    name: 'AssignedTasksScreen');
                
                if (snapshot.hasError) {
                  developer.log('Stream error: ${snapshot.error}', name: 'AssignedTasksScreen');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading tasks',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final tasks = snapshot.data ?? [];
                developer.log('Loaded ${tasks.length} tasks', name: 'AssignedTasksScreen');

                if (tasks.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return _buildTaskItem(task);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'value': 'all', 'label': 'All'},
      {'value': 'assigned', 'label': 'Assigned'},
      {'value': 'in_progress', 'label': 'In Progress'},
      {'value': 'completed', 'label': 'Completed'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _filterStatus == filter['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter['label']!),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _filterStatus = filter['value']!;
                  developer.log('Filter changed to: $_filterStatus', name: 'AssignedTasksScreen');
                });
              },
              backgroundColor: Colors.grey[300],
              selectedColor: AppThemes.primaryGreen,
              labelStyle: GoogleFonts.poppins(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Stream<List<Map<String, dynamic>>> _getFilteredTasks() {
    final collectorId = _authController.user?.uid;
    
    if (collectorId == null || collectorId.isEmpty) {
      developer.log('Collector ID is null or empty', name: 'AssignedTasksScreen');
      return Stream.value([]);
    }

    developer.log('Fetching tasks for collector: $collectorId with filter: $_filterStatus', 
        name: 'AssignedTasksScreen');

    // Simple query - just filter by collectorId and order by assignedAt
    // Then filter by status in memory to avoid composite index requirement
    return _firestore
        .collection('assigned_tasks')
        .where('collectorId', isEqualTo: collectorId)
        .orderBy('assignedAt', descending: true)
        .snapshots()
        .handleError((error) {
          developer.log('Firestore query error: $error', name: 'AssignedTasksScreen');
        })
        .map((snapshot) {
          developer.log('Received ${snapshot.docs.length} documents from Firestore', 
              name: 'AssignedTasksScreen');
          
          var tasks = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            developer.log('Task ${doc.id}: status=${data['status']}, userName=${data['userName']}', 
                name: 'AssignedTasksScreen');
            return {
              'id': doc.id,
              ...data,
            };
          }).toList();

          // Apply status filter in memory
          if (_filterStatus != 'all') {
            tasks = tasks.where((task) => task['status'] == _filterStatus).toList();
            developer.log('After filtering by $_filterStatus: ${tasks.length} tasks', 
                name: 'AssignedTasksScreen');
          }

          return tasks;
        });
  }

  Widget _buildTaskItem(Map<String, dynamic> task) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheduledDate = task['scheduledDate'] != null
        ? (task['scheduledDate'] as Timestamp).toDate()
        : DateTime.now();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          developer.log('Opening task details for: ${task['id']}', name: 'AssignedTasksScreen');
          Get.to(() => TaskDetailsScreen(task: task));
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getTaskColor(task['status']).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getTaskIcon(task['status']),
                  color: _getTaskColor(task['status']),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task['userName'] ?? 'Unknown User',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getTaskColor(task['status']).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getTaskStatusText(task['status']),
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _getTaskColor(task['status']),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      task['address'] ?? 'No address provided',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM dd, yyyy HH:mm').format(scheduledDate),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getWasteTypeColor(task['wasteType']).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getWasteTypeText(task['wasteType']),
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _getWasteTypeColor(task['wasteType']),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
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
            'No Tasks Found',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _filterStatus == 'all' 
                ? 'You don\'t have any assigned tasks yet'
                : 'No $_filterStatus tasks found',
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getTaskColor(String? status) {
    switch (status?.toLowerCase()) {
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

  IconData _getTaskIcon(String? status) {
    switch (status?.toLowerCase()) {
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

  String _getTaskStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'assigned':
        return 'Assigned';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      default:
        return status ?? 'Unknown';
    }
  }

  String _getWasteTypeText(String? type) {
    switch (type?.toLowerCase()) {
      case 'general':
        return 'General';
      case 'recyclable':
        return 'Recyclable';
      case 'organic':
        return 'Organic';
      case 'hazardous':
        return 'Hazardous';
      default:
        return type ?? 'Unknown';
    }
  }

  Color _getWasteTypeColor(String? type) {
    switch (type?.toLowerCase()) {
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