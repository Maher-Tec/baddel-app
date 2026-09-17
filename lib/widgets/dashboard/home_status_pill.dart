import 'package:flutter/material.dart';

class HomeStatusPill extends StatelessWidget {
  const HomeStatusPill({super.key, required this.running});
  final bool running;

  @override
  Widget build(BuildContext context) {
    final color = running ? const Color(0xFF0B8F6A) : const Color(0xFF627D98);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            running ? 'Protection active' : 'Protection off',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
