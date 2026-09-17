import 'package:flutter/material.dart';

import '../../settings/app_settings.dart';

class AppSettingRow extends StatelessWidget {
  const AppSettingRow({
    super.key,
    required this.app,
    required this.isEnabled,
    required this.onChanged,
    this.onRemove,
  });

  final BaddelTargetApp app;
  final bool isEnabled;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    Color iconBg;
    IconData icon;

    if (app.processName == 'notepad.exe') {
      iconBg = const Color(0xFFFEF3C7);
      icon = Icons.edit_note_rounded;
    } else if (app.processName.contains('chrome') ||
        app.processName.contains('browser') ||
        app.processName.contains('firefox') ||
        app.processName.contains('edge') ||
        app.processName.contains('brave')) {
      iconBg = const Color(0xFFE0F2FE);
      icon = Icons.public_rounded;
    } else if (app.processName.contains('code') ||
        app.processName.contains('antigravity') ||
        app.processName.contains('studio')) {
      iconBg = const Color(0xFFE0E7FF);
      icon = Icons.code_rounded;
    } else if (app.processName.contains('terminal') ||
        app.processName.contains('cmd')) {
      iconBg = const Color(0xFFF1F5F9);
      icon = Icons.terminal_rounded;
    } else if (app.processName.contains('whatsapp') ||
        app.processName.contains('telegram') ||
        app.processName.contains('discord') ||
        app.processName.contains('slack')) {
      iconBg = const Color(0xFFDCFCE7);
      icon = Icons.chat_rounded;
    } else if (app.processName == 'winword.exe') {
      iconBg = const Color(0xFFDBEAFE);
      icon = Icons.description_rounded;
    } else {
      iconBg = const Color(0xFFF3E8FF);
      icon = Icons.apps_rounded;
    }

    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      secondary: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          if (onRemove != null)
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFEF4444),
                size: 20,
              ),
              tooltip: 'Remove Custom App',
              onPressed: onRemove,
            ),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF0F172A)),
          ),
        ],
      ),

      title: Row(
        children: [
          Text(
            app.label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF0F172A),
            ),
          ),
          if (app.isCustom) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFCCFBF1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Custom',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F766E),
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        '${app.category} · ${app.processName}',
        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
      ),
      value: isEnabled,
      onChanged: onChanged,
    );
  }
}
