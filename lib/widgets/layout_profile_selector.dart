import 'package:flutter/material.dart';

import '../core/keyboard_layout.dart';

class LayoutProfileSelector extends StatelessWidget {
  const LayoutProfileSelector({
    super.key,
    required this.profile,
    required this.onChanged,
  });

  final KeyboardLayoutProfile profile;
  final ValueChanged<KeyboardLayoutProfile> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Keyboard layout',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF334E68),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: KeyboardLayoutProfile.values.map((option) {
            final selected = option == profile;
            return _LayoutOption(
              label: _label(option),
              detail: _detail(option),
              icon: _icon(option),
              selected: selected,
              onTap: () => onChanged(option),
            );
          }).toList(),
        ),
      ],
    );
  }

  static String _label(KeyboardLayoutProfile value) => switch (value) {
    KeyboardLayoutProfile.usQwerty => 'US QWERTY',
    KeyboardLayoutProfile.frenchAzerty => 'French AZERTY',
    KeyboardLayoutProfile.arabic101 => 'Arabic 101',
    KeyboardLayoutProfile.arabicPhonetic => 'Arabic Phonetic',
  };

  static String _detail(KeyboardLayoutProfile value) => switch (value) {
    KeyboardLayoutProfile.usQwerty => 'English keys',
    KeyboardLayoutProfile.frenchAzerty => 'French keys',
    KeyboardLayoutProfile.arabic101 => 'Standard Arabic',
    KeyboardLayoutProfile.arabicPhonetic => 'Arabizi typing',
  };

  static IconData _icon(KeyboardLayoutProfile value) => switch (value) {
    KeyboardLayoutProfile.usQwerty => Icons.language_rounded,
    KeyboardLayoutProfile.frenchAzerty => Icons.translate_rounded,
    KeyboardLayoutProfile.arabic101 => Icons.keyboard_alt_rounded,
    KeyboardLayoutProfile.arabicPhonetic => Icons.record_voice_over_rounded,
  };
}

class _LayoutOption extends StatelessWidget {
  const _LayoutOption({
    required this.label,
    required this.detail,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String detail;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 196,
      child: Material(
        color: selected ? const Color(0xFFE7F7F3) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? const Color(0xFF12A585)
                    : const Color(0xFFD9E2EC),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_circle_rounded : icon,
                  size: 20,
                  color: selected
                      ? const Color(0xFF087F68)
                      : const Color(0xFF627D98),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF243B53),
                        ),
                      ),
                      Text(
                        detail,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF829AB1),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
