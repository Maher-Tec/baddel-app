import 'package:flutter/material.dart';

import 'quick_badge.dart';

class HomeQuickBar extends StatelessWidget {
  const HomeQuickBar({super.key, required this.layout, required this.enabledApps});
  final String layout;
  final int enabledApps;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        QuickBadge(icon: Icons.language_rounded, label: layout),
        QuickBadge(
          icon: Icons.apps_rounded,
          label: '$enabledApps protected apps',
        ),
        const QuickBadge(
          icon: Icons.undo_rounded,
          label: 'Safe undo: Ctrl + Alt + Z',
        ),
      ],
    );
  }
}
