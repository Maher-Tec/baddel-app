import 'package:flutter/material.dart';

import '../core/keyboard_layout.dart';
import '../core/personality.dart';
import '../settings/app_settings.dart';
import '../widgets/layout_profile_selector.dart';

class PrivacyOnboardingPage extends StatefulWidget {
  const PrivacyOnboardingPage({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<PrivacyOnboardingPage> createState() => _PrivacyOnboardingPageState();
}

class _PrivacyOnboardingPageState extends State<PrivacyOnboardingPage> {
  int _step = 0;
  late KeyboardLayoutProfile _layout = widget.settings.layoutProfile;
  late PersonalityMode _personality = widget.settings.personalityMode;
  late final Set<String> _selectedApps = {
    ...widget.settings.detectionEnabledApps,
  };

  Future<void> _continue() async {
    if (_step == 1) {
      await widget.settings.setLayoutProfile(_layout);
    }
    if (_step == 2) {
      for (final app in widget.settings.allTargetApps) {
        await widget.settings.setAppDetectionEnabled(
          app.processName,
          _selectedApps.contains(app.processName),
        );
      }
    }
    if (_step == 3) {
      await widget.settings.setPersonalityMode(_personality);
      await widget.settings.completeOnboarding();
      return;
    }
    setState(() => _step++);
  }

  Future<void> _addCustomApp() async {
    final app = await showDialog<_CustomAppDetails>(
      context: context,
      builder: (context) => const _AddAppDuringSetupDialog(),
    );
    if (app == null || !mounted) return;

    await widget.settings.addCustomApp(
      processName: app.processName,
      label: app.label,
      category: app.category,
    );
    if (!mounted) return;

    final normalized = app.processName.toLowerCase().endsWith('.exe')
        ? app.processName.toLowerCase()
        : '${app.processName.toLowerCase()}.exe';
    setState(() => _selectedApps.add(normalized));
  }

  @override
  Widget build(BuildContext context) {
    const titles = [
      'Your typing, on the right language.',
      'Which keyboard do you use?',
      'Where should Baddel help?',
      'You are ready to go.',
    ];
    const subtitles = [
      'Baddel notices a wrong keyboard layout and gives you a quick fix.',
      'This makes the suggested correction accurate.',
      'Baddel only watches the apps you choose.',
      'These choices can be changed anytime from the dashboard.',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFD9E2EC)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF102A43).withValues(alpha: 0.08),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/logo/logo.png',
                          width: 58,
                          height: 58,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Baddel!',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF102A43),
                              ),
                            ),
                            Text(
                              'A calm keyboard language helper',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF627D98),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Step ${_step + 1} of 4',
                        style: const TextStyle(color: Color(0xFF829AB1)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (_step + 1) / 4,
                      minHeight: 7,
                      color: const Color(0xFF12A585),
                      backgroundColor: const Color(0xFFE7EDF3),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Icon(_stepIcon, size: 38, color: const Color(0xFF087F68)),
                  const SizedBox(height: 14),
                  Text(
                    titles[_step],
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF102A43),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitles[_step],
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Color(0xFF627D98),
                    ),
                  ),
                  const SizedBox(height: 26),
                  _buildStep(),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      if (_step > 0)
                        TextButton.icon(
                          onPressed: () => setState(() => _step--),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Back'),
                        ),
                      const Spacer(),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0B8F6A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _continue,
                        icon: Icon(
                          _step == 3
                              ? Icons.check_circle_rounded
                              : Icons.arrow_forward_rounded,
                        ),
                        label: Text(
                          _step == 0
                              ? 'Start setup'
                              : _step == 3
                              ? 'Open Baddel'
                              : 'Continue',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData get _stepIcon => switch (_step) {
    0 => Icons.shield_outlined,
    1 => Icons.keyboard_alt_rounded,
    2 => Icons.apps_rounded,
    _ => Icons.verified_rounded,
  };

  Widget _buildStep() => switch (_step) {
    0 => const _WelcomeExplanation(),
    1 => LayoutProfileSelector(
      profile: _layout,
      onChanged: (layout) => setState(() => _layout = layout),
    ),
    2 => Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _addCustomApp,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add an app'),
          ),
        ),
        const SizedBox(height: 10),
        ...widget.settings.allTargetApps.map(
          (app) => _AppChoice(
            label: app.label,
            category: app.category,
            selected: _selectedApps.contains(app.processName),
            onTap: () => setState(() {
              if (!_selectedApps.add(app.processName)) {
                _selectedApps.remove(app.processName);
              }
            }),
          ),
        ),
      ],
    ),
    _ => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _InfoStrip(
          icon: Icons.lock_rounded,
          text:
              'Your typing stays on this computer. Baddel does not upload or save it.',
        ),
        const SizedBox(height: 18),
        const Text(
          'Choose a notification style',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF334E68),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PersonalityMode.values
              .map(
                (mode) => ChoiceChip(
                  label: Text(mode.label),
                  selected: _personality == mode,
                  onSelected: (_) => setState(() => _personality = mode),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 10),
        Text(
          _personality.description,
          style: const TextStyle(color: Color(0xFF627D98)),
        ),
      ],
    ),
  };
}

class _WelcomeExplanation extends StatelessWidget {
  const _WelcomeExplanation();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _InfoStrip(
          icon: Icons.auto_fix_high_rounded,
          text: 'When text looks wrong, Baddel suggests the intended language.',
        ),
        SizedBox(height: 10),
        _InfoStrip(
          icon: Icons.keyboard_command_key_rounded,
          text: 'Use Ctrl + Alt + B anytime to fix selected text manually.',
        ),
        SizedBox(height: 10),
        _InfoStrip(
          icon: Icons.lock_outline_rounded,
          text: 'Everything works locally and privately on your PC.',
        ),
      ],
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FAF7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF087F68)),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(height: 1.35, color: Color(0xFF334E68)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomAppDetails {
  const _CustomAppDetails({
    required this.processName,
    required this.label,
    required this.category,
  });

  final String processName;
  final String label;
  final String category;
}

class _AddAppDuringSetupDialog extends StatefulWidget {
  const _AddAppDuringSetupDialog();

  @override
  State<_AddAppDuringSetupDialog> createState() =>
      _AddAppDuringSetupDialogState();
}

class _AddAppDuringSetupDialogState extends State<_AddAppDuringSetupDialog> {
  final _nameController = TextEditingController();
  final _processController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _processController.dispose();
    super.dispose();
  }

  void _save() {
    final processName = _processController.text.trim();
    if (processName.isEmpty) {
      setState(
        () => _error = 'Enter the app executable, for example WhatsApp.exe.',
      );
      return;
    }
    final label = _nameController.text.trim();
    Navigator.of(context).pop(
      _CustomAppDetails(
        processName: processName,
        label: label.isEmpty ? processName.replaceAll('.exe', '') : label,
        category: 'Custom app',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add an app'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the name of the Windows executable that Baddel should watch.',
              style: TextStyle(color: Color(0xFF627D98)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'App name (optional)',
                hintText: 'WhatsApp',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _processController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Executable name',
                hintText: 'WhatsApp.exe',
                errorText: _error,
              ),
              onSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add app'),
        ),
      ],
    );
  }
}

class _AppChoice extends StatelessWidget {
  const _AppChoice({
    required this.label,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? const Color(0xFFE7F7F3) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? const Color(0xFF12A585)
                    : const Color(0xFFD9E2EC),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                  color: selected
                      ? const Color(0xFF087F68)
                      : const Color(0xFF829AB1),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF243B53),
                        ),
                      ),
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF627D98),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  selected ? 'On' : 'Off',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? const Color(0xFF087F68)
                        : const Color(0xFF829AB1),
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
