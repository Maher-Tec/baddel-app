import 'package:flutter/material.dart';

class HeroFact extends StatelessWidget {
  const HeroFact({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF55D6BE)),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: Color(0xFFD9EAF7)),
        ),
      ],
    );
  }
}
