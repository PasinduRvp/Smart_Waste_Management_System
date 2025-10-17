import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smart_waste_management/controllers/auth_controller.dart';
import 'package:smart_waste_management/navigation/nav_tab.dart';
import 'package:smart_waste_management/navigation/role_bottom_navigation.dart';
import 'package:smart_waste_management/views/resident/payment_process_screen.dart';
import 'package:smart_waste_management/views/resident/pickup_history_screen.dart';
import 'package:smart_waste_management/views/resident/resident_home_page.dart';
import 'package:smart_waste_management/views/resident/resident_profile_page.dart';

class ResidentHomeScreen extends StatefulWidget {
  const ResidentHomeScreen({super.key});

  @override
  State<ResidentHomeScreen> createState() => _ResidentHomeScreenState();
}

class _ResidentHomeScreenState extends State<ResidentHomeScreen> {
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
        page: const ResidentHomePage(),
      ),
      NavTab(
        label: 'History',
        icon: Icons.history_rounded,
        page: const PickupHistoryScreen(),
      ),
      NavTab(
        label: 'Payments',
        icon: Icons.payment_rounded,
        page: const PaymentProcessScreen(),
      ),
      NavTab(
        label: 'Profile',
        icon: Icons.person_rounded,
        page: const ResidentProfilePage(),
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