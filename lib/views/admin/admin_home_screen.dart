import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smart_waste_management/controllers/auth_controller.dart';
import 'package:smart_waste_management/navigation/nav_tab.dart';
import 'package:smart_waste_management/navigation/role_bottom_navigation.dart';
import 'package:smart_waste_management/views/shared/profile_page.dart';
import 'package:smart_waste_management/views/admin/admin_dashboard_page.dart';
import 'package:smart_waste_management/views/admin/manage_pickups_screen.dart';
import 'package:smart_waste_management/views/admin/analytics_dashboard_screen.dart';
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;
  final AuthController authController = Get.find();

  late final List<NavTab> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      NavTab(
        label: 'Dashboard',
        icon: Icons.dashboard_rounded,
        page: const AdminDashboardPage(),
      ),
      NavTab(
        label: 'Pickups',
        icon: Icons.assignment_rounded,
        page: const ManagePickupsScreen(),
      ),
      NavTab(
        label: 'Analytics',
        icon: Icons.analytics_rounded,
        page: const AnalyticsDashboardScreen(),
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