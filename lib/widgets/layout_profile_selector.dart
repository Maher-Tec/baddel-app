import 'package:flutter/material.dart';

import '../core/keyboard_layout.dart';

class LayoutProfileSelector extends StatelessWidget {
  const LayoutProfileSelector({super.key, required this.profile, required this.onChanged});

  final KeyboardLayoutProfile profile;
  final ValueChanged<KeyboardLayoutProfile> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.keyboard_alt_rounded, color: Color(0xFF0F766E)),
        title: const Text('Keyboard layout profile', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_label(profile)),
        trailing: DropdownButton<KeyboardLayoutProfile>(
          value: profile,
          underline: const SizedBox.shrink(),
          items: const [
            DropdownMenuItem(value: KeyboardLayoutProfile.usQwerty, child: Text('US QWERTY')),
            DropdownMenuItem(value: KeyboardLayoutProfile.frenchAzerty, child: Text('French AZERTY')),
            DropdownMenuItem(value: KeyboardLayoutProfile.arabic101, child: Text('Arabic 101')),
            DropdownMenuItem(value: KeyboardLayoutProfile.arabicPhonetic, child: Text('Arabic Phonetic')),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }

  String _label(KeyboardLayoutProfile value) => switch (value) {
        KeyboardLayoutProfile.usQwerty => 'US QWERTY',
        KeyboardLayoutProfile.frenchAzerty => 'French AZERTY',
        KeyboardLayoutProfile.arabic101 => 'Arabic 101',
        KeyboardLayoutProfile.arabicPhonetic => 'Arabic Phonetic',
      };
}
