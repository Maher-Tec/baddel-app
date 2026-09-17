import 'package:flutter/material.dart';

class DashboardRail extends StatelessWidget {
  const DashboardRail({super.key, required this.selectedIndex, required this.onChanged});

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 218,
      color: Colors.white,
      child: NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: onChanged,
        extended: true,
        minExtendedWidth: 218,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE1F7F0),
        leading: const Padding(
          padding: EdgeInsets.fromLTRB(16, 22, 16, 14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'WORKSPACE',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w800,
                color: Color(0xFF829AB1),
              ),
            ),
          ),
        ),
        destinations: const [
          NavigationRailDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: Text('Home'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps_rounded),
            label: Text('Protected apps'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune_rounded),
            label: Text('Settings'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.lock_outline_rounded),
            selectedIcon: Icon(Icons.lock_rounded),
            label: Text('Privacy & control'),
          ),
        ],
      ),
    );
  }
}
