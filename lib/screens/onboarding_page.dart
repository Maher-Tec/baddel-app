import 'package:flutter/material.dart';

import '../core/personality.dart';
import '../settings/app_settings.dart';

class PrivacyOnboardingPage extends StatefulWidget {
  const PrivacyOnboardingPage({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<PrivacyOnboardingPage> createState() => _PrivacyOnboardingPageState();
}

class _PrivacyOnboardingPageState extends State<PrivacyOnboardingPage> {
  int _step = 0;
  late final Set<String> _selectedApps = {...widget.settings.detectionEnabledApps};
  PersonalityMode _personality = PersonalityMode.weldElHouma;

  Future<void> _next() async {
    if (_step == 1) {
      for (final app in widget.settings.allTargetApps) {
        await widget.settings.setAppDetectionEnabled(
          app.processName,
          _selectedApps.contains(app.processName),
        );
      }
    }
    if (_step == 2) {
      await widget.settings.setPersonalityMode(_personality);
    }
    if (_step == 3) {
      await widget.settings.completeOnboarding();
      return;
    }
    setState(() => _step++);
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Welcome to Baddel!', 'Choose your apps', 'Choose your style', 'You are ready!'];
    final subtitles = [
      'Your keyboard\'s little mistake detector.',
      'Baddel watches only the apps you choose.',
      'Pick how Baddel talks to you.',
      'Baddel is watching ðŸ‘€',
    ];
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset('assets/logo/logo.png', width: 72, height: 72),
                      ),
                      const SizedBox(width: 20),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(titles[_step], style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Text(subtitles[_step], style: const TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold)),
                      ])),
                    ]),
                    const SizedBox(height: 22),
                    Row(children: List.generate(4, (index) => Expanded(child: Container(
                      height: 5,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(color: index <= _step ? const Color(0xFF0F766E) : const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(5)),
                    )))),
                    const SizedBox(height: 28),
                    _buildStep(context),
                    const SizedBox(height: 28),
                    Row(children: [
                      if (_step > 0) TextButton(onPressed: () => setState(() => _step--), child: const Text('Back')),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _next,
                        icon: Icon(_step == 3 ? Icons.check_circle_rounded : Icons.arrow_forward_rounded),
                        label: Text(_step == 3 ? 'Start using Baddel' : 'Continue'),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    if (_step == 0) {
      return const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _PrivacyPromise(icon: Icons.cloud_off_rounded, title: 'Private by design', text: 'Your typing stays on this computer. Baddel never uploads your text.'),
        _PrivacyPromise(icon: Icons.keyboard_rounded, title: 'One-click fixes', text: 'When your keyboard layout is wrong, Baddel catches it and fixes the text.'),
        _PrivacyPromise(icon: Icons.tune_rounded, title: 'You stay in control', text: 'Choose the apps Baddel watches, and pause detection anytime.'),
      ]);
    }
    if (_step == 1) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widget.settings.allTargetApps.map((app) => CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _selectedApps.contains(app.processName),
        title: Text(app.label),
        subtitle: Text(app.category),
        onChanged: (enabled) => setState(() => enabled == true ? _selectedApps.add(app.processName) : _selectedApps.remove(app.processName)),
      )).toList());
    }
    if (_step == 2) {
      return Column(children: PersonalityMode.values.map((mode) {
        final selected = _personality == mode;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: selected ? const Color(0xFFECFEFF) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: selected ? const Color(0xFF0F766E) : const Color(0xFFE2E8F0)),
          ),
          child: ListTile(
            leading: Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: const Color(0xFF0F766E)),
            title: Text(mode.label),
            subtitle: Text(mode.description),
            onTap: () => setState(() => _personality = mode),
          ),
        );
      }).toList());
    }
    return const Center(child: Column(children: [
      Icon(Icons.visibility_rounded, size: 72, color: Color(0xFF0F766E)),
      SizedBox(height: 16),
      Text('You can change these choices later from Settings.', textAlign: TextAlign.center),
    ]));
  }
}

class _PrivacyPromise extends StatelessWidget {
  const _PrivacyPromise({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFCCFBF1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF0F766E), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

