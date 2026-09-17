import 'package:flutter/material.dart';

class StatusMetricChip extends StatelessWidget {
  const StatusMetricChip({
    super.key,
    required this.label,
    required this.value,
    this.isPositive,
  });

  final String label;
  final String value;
  final bool? isPositive;

  @override
  Widget build(BuildContext context) {
    Color? badgeColor;
    Color? textColor;
    if (isPositive != null) {
      badgeColor = isPositive!
          ? const Color(0xFFECFDF5)
          : const Color(0xFFF1F5F9);
      textColor = isPositive!
          ? const Color(0xFF047857)
          : const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: badgeColor ?? const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),

          if (value.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor ?? const Color(0xFF0F172A),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
