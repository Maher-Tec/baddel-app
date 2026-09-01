import 'package:flutter/material.dart';

import '../core/feedback_stats.dart';

class FeedbackStatsCard extends StatelessWidget {
  const FeedbackStatsCard({super.key, required this.stats});

  final FeedbackStats stats;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: stats,
      builder: (context, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.insights_rounded, color: Color(0xFF0F766E), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your Baddel stats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('${stats.fixesThisWeek} fixes this week · ${stats.dismissalsThisWeek} dismissed'),
                    Text('Most active: ${stats.mostActiveApp}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
