import 'package:flutter/material.dart';

import '../../core/personality.dart';

class PersonalityChoice extends StatelessWidget {
  const PersonalityChoice({
    super.key,
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final PersonalityMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (mode) {
      PersonalityMode.weldElHouma => Icons.local_fire_department_rounded,
      PersonalityMode.devTanbir => Icons.terminal_rounded,
      PersonalityMode.tunisianFunny => Icons.sentiment_very_satisfied_rounded,
      PersonalityMode.classic => Icons.notifications_none_rounded,
    };
    return Material(
      color: selected ? const Color(0xFFFFEEF1) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? const Color(0xFFE85D75)
                  : const Color(0xFFD9E2EC),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : icon,
                size: 17,
                color: selected
                    ? const Color(0xFFE23D5B)
                    : const Color(0xFF627D98),
              ),
              const SizedBox(width: 6),
              Text(
                mode.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? const Color(0xFFE23D5B)
                      : const Color(0xFF334E68),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
