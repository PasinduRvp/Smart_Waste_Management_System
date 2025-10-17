import 'package:flutter/material.dart';

class NavTab {
  final String label;
  final IconData icon;
  final Widget page;

  const NavTab({
    required this.label,
    required this.icon,
    required this.page,
  });
}
