import 'package:flutter/material.dart';

class DashboardBottomNav extends StatelessWidget {
  const DashboardBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onChanged,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.apps_outlined), label: 'Apps'),
        NavigationDestination(
          icon: Icon(Icons.tune_outlined),
          label: 'Settings',
        ),
        NavigationDestination(
          icon: Icon(Icons.lock_outline_rounded),
          label: 'Privacy',
        ),
      ],
    );
  }
}
