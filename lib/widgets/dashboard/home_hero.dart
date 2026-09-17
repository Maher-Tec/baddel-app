import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'hero_fact.dart';

class HomeHero extends StatelessWidget {
  const HomeHero({
    super.key,
    required this.running,
    required this.paused,
    required this.enabledApps,
    required this.onToggle,
  });

  final bool running;
  final bool paused;
  final int enabledApps;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF073B4C), Color(0xFF075D6E), Color(0xFF087F86)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF073B4C).withValues(alpha: 0.18),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        paused
                            ? 'PAUSED'
                            : running
                            ? 'PROTECTION ACTIVE'
                            : 'KEYBOARD PROTECTION',
                        style: const TextStyle(
                          fontSize: 10,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFA9F3E4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 13),
                    Text(
                      paused
                          ? 'Detection is paused'
                          : running
                          ? 'Your typing is protected'
                          : 'Ready when you are',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      running
                          ? 'Baddel is quietly watching $enabledApps selected apps and will help when the keyboard language is wrong.'
                          : 'Start protection once and Baddel will stay out of the way until you need it.',
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: Color(0xFFCDE7E2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Wrap(
                      spacing: 14,
                      runSpacing: 8,
                      children: [
                        HeroFact(
                          icon: Icons.keyboard_command_key_rounded,
                          text: 'Ctrl + Alt + B quick fix',
                        ),
                        HeroFact(
                          icon: Icons.lock_outline_rounded,
                          text: '100% local and private',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (running && !paused) ...[
                const SizedBox(width: 18),
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Lottie.asset(
                      'assets/Shield Guard Lock.json',
                      repeat: false,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: running
                      ? const Color(0xFFE85D75)
                      : const Color(0xFF12B99A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 19,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: onToggle,
                icon: Icon(
                  running ? Icons.stop_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(
                  running ? 'Stop protection' : 'Start protection',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: -60,
          top: -75,
          child: IgnorePointer(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF55D6BE).withValues(alpha: 0.08),
              ),
            ),
          ),
        ),
        Positioned(
          right: 135,
          bottom: -85,
          child: IgnorePointer(
            child: Container(
              width: 175,
              height: 175,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.07),
                  width: 26,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
