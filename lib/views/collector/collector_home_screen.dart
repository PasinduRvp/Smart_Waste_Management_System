import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smart_waste_management/controllers/auth_controller.dart';
import 'package:smart_waste_management/navigation/nav_tab.dart';
import 'package:smart_waste_management/navigation/role_bottom_navigation.dart';
import 'package:smart_waste_management/views/collector/assigned_tasks_screen.dart';
import 'package:smart_waste_management/views/collector/collector_home_page.dart';
import 'package:smart_waste_management/views/shared/profile_page.dart';

class CollectorHomeScreen extends StatefulWidget {
  const CollectorHomeScreen({super.key});

  @override
  State<CollectorHomeScreen> createState() => _CollectorHomeScreenState();
}

class _CollectorHomeScreenState extends State<CollectorHomeScreen> {
  int _currentIndex = 0;
  final AuthController authController = Get.find();

  late final List<NavTab> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      NavTab(
        label: 'Home',
        icon: Icons.home_rounded,
        page: const CollectorHomePage(),
      ),
      NavTab(
        label: 'History',
        icon: Icons.history_rounded,
        page: const AssignedTasksScreen(),
      ),
      NavTab(
        label: 'Profile',
        icon: Icons.person_rounded,
        page: const ProfilePage(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : const Color(0xFFF5F5F5),
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs.map((tab) => tab.page).toList(),
      ),
      bottomNavigationBar: RoleBottomNavigation(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        tabs: _tabs,
      ),
    );
  }
}