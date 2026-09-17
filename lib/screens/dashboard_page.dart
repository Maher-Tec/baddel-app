import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../core/keyboard_layout.dart';
import '../core/personality.dart';
import '../settings/app_settings.dart';
import '../widgets/layout_profile_selector.dart';
import 'dashboard_controller.dart';
import '../widgets/dashboard/about_baddel_dialog.dart';
import '../widgets/dashboard/add_custom_app_dialog.dart';
import '../widgets/dashboard/app_setting_row.dart';
import '../widgets/dashboard/conversion_preview.dart';
import '../widgets/dashboard/dashboard_bottom_nav.dart';
import '../widgets/dashboard/dashboard_rail.dart';
import '../widgets/dashboard/home_action_card.dart';
import '../widgets/dashboard/home_hero.dart';
import '../widgets/dashboard/home_mode_button.dart';
import '../widgets/dashboard/home_panel.dart';
import '../widgets/dashboard/home_quick_bar.dart';
import '../widgets/dashboard/home_status_pill.dart';
import '../widgets/dashboard/mac_keycap_badge.dart';
import '../widgets/dashboard/modern_persona_card.dart';
import '../widgets/dashboard/personality_choice.dart';
import '../widgets/dashboard/quick_status_card.dart';
import '../widgets/dashboard/section_intro.dart';
import '../widgets/dashboard/status_metric_chip.dart';
import '../widgets/baddel_toast.dart';

class HookTestPage extends StatefulWidget {
  const HookTestPage({
    super.key,
    required this.settings,
    this.enableDesktopShell = true,
  });

  final AppSettings settings;
  final bool enableDesktopShell;

  @override
  State<HookTestPage> createState() => _HookTestPageState();
}

class _HookTestPageState extends State<HookTestPage>
    with TrayListener, WindowListener {
  late final DashboardController _controller;
  int _selectedSection = 0;

  @override
  void initState() {
    super.initState();
    _controller = DashboardController(
      settings: widget.settings,
      enableDesktopShell: widget.enableDesktopShell,
      onShowMessage: (message) {
        if (!mounted) return;
        showBaddelToast(context, message);
      },
    )..addListener(_onControllerChanged);
    if (widget.enableDesktopShell) {
      trayManager.addListener(this);
      windowManager.addListener(this);

      unawaited(_controller.initializeDesktopShell());
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(_showWindow());
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show') {
      unawaited(_showWindow());
    } else if (menuItem.key == 'pause') {
      unawaited(_controller.setDetectionPaused(!_controller.detectionPaused));
    } else if (menuItem.key == 'exit') {
      unawaited(_controller.exitApplication());
    }
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onWindowClose() {
    unawaited(windowManager.hide());
  }

  void _showAddCustomAppDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AddCustomAppDialog(
        settings: widget.settings,
        hook: _controller.hook,
      ),
    );
  }

  @override
  void dispose() {
    if (widget.enableDesktopShell) {
      trayManager.removeListener(this);
      windowManager.removeListener(this);
    }
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildFocusedDashboard(context);
  }

  Widget _buildFocusedDashboard(BuildContext context) {
    final isDevMode = widget.settings.developerModeEnabled;
    final enabledApps = widget.settings.detectionEnabledApps.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        toolbarHeight: 76,
        titleSpacing: 30,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Image.asset('assets/logo/logo.png', width: 44, height: 44),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Baddel!', style: TextStyle(fontWeight: FontWeight.w900)),
                Text(
                  'Your keyboard language companion',
                  style: TextStyle(fontSize: 12, color: Color(0xFF627D98)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          HomeModeButton(
            label: isDevMode ? 'Developer' : 'Simple',
            icon: isDevMode ? Icons.code_rounded : Icons.auto_awesome_rounded,
            selected: isDevMode,
            onTap: () {
              setState(() {
                unawaited(widget.settings.setDeveloperModeEnabled(!isDevMode));
              });
            },
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => unawaited(widget.settings.restartOnboarding()),
            icon: const Icon(Icons.menu_book_rounded, size: 18),
            label: const Text('Setup guide'),
          ),
          const SizedBox(width: 16),
          Padding(
            padding: const EdgeInsets.only(right: 28),
            child: HomeStatusPill(running: _controller.isRunning),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final showRail = constraints.maxWidth >= 820;
          final content = _buildDashboardSection(enabledApps, isDevMode);
          if (!showRail) {
            return Column(
              children: [
                Expanded(child: content),
                DashboardBottomNav(
                  selectedIndex: _selectedSection,
                  onChanged: (index) =>
                      setState(() => _selectedSection = index),
                ),
              ],
            );
          }
          return Row(
            children: [
              DashboardRail(
                selectedIndex: _selectedSection,
                onChanged: (index) => setState(() => _selectedSection = index),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDashboardSection(int enabledApps, bool isDevMode) {
    final page = switch (_selectedSection) {
      0 => _buildHomeSection(enabledApps),
      1 => _buildAppsSection(enabledApps),
      2 => _buildSettingsSection(),
      _ => _buildPrivacySection(isDevMode),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: SingleChildScrollView(
        key: ValueKey(_selectedSection),
        padding: const EdgeInsets.fromLTRB(32, 30, 32, 36),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: page,
          ),
        ),
      ),
    );
  }

  Widget _buildHomeSection(int enabledApps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeHero(
          running: _controller.isRunning,
          paused: _controller.detectionPaused,
          enabledApps: enabledApps,
          onToggle: _controller.toggleHook,
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            HomeActionCard(
              icon: Icons.keyboard_alt_rounded,
              title: _layoutProfileLabel(widget.settings.layoutProfile),
              subtitle: 'Keyboard layout',
              onTap: () => setState(() => _selectedSection = 2),
            ),
            HomeActionCard(
              icon: Icons.apps_rounded,
              title: '$enabledApps protected apps',
              subtitle: 'Manage where Baddel helps',
              onTap: () => setState(() => _selectedSection = 1),
            ),
            HomeActionCard(
              icon: Icons.lock_rounded,
              title: 'Private by design',
              subtitle: 'Everything stays on your PC',
              onTap: () => setState(() => _selectedSection = 3),
            ),
          ],
        ),
        const SizedBox(height: 22),
        HomePanel(
          title: 'Try Baddel',
          subtitle:
              'Type a word using the wrong layout and see the correction.',
          icon: Icons.auto_fix_high_rounded,
          child: Column(
            children: [
              TextField(
                controller: _controller.testInputController,
                onChanged: _controller.runTestConversion,
                decoration: InputDecoration(
                  hintText: 'Try typing with the wrong keyboard layout...',
                  prefixIcon: const Icon(Icons.edit_rounded),
                  suffixIcon: _controller.testInputController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          onPressed: () {
                            _controller.testInputController.clear();
                            _controller.runTestConversion('');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              if (_controller.testConvertedOutput.isNotEmpty) ...[
                const SizedBox(height: 12),
                ConversionPreview(text: _controller.testConvertedOutput),
              ],
            ],
          ),
        ),
        if (_controller.lastDetection != null) ...[
          const SizedBox(height: 16),
          HomePanel(
            title: 'Correction ready',
            subtitle:
                '${(_controller.lastDetection!.confidence * 100).round()}% confidence',
            icon: Icons.check_circle_rounded,
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    _controller.lastDetection!.suggestion,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                FilledButton(
                  onPressed: () => _controller.handleWarningAction('fix'),
                  child: const Text('Fix text'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAppsSection(int enabledApps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionIntro(
          icon: Icons.apps_rounded,
          title: 'Protected apps',
          subtitle: 'Choose exactly where Baddel can show automatic warnings.',
        ),
        const SizedBox(height: 20),
        HomePanel(
          title: '$enabledApps apps protected',
          subtitle: 'You can change this any time.',
          icon: Icons.verified_rounded,
          trailing: FilledButton.icon(
            onPressed: _showAddCustomAppDialog,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add an app'),
          ),
          child: Column(
            children: [
              for (final app in widget.settings.allTargetApps)
                AppSettingRow(
                  app: app,
                  isEnabled: widget.settings.detectionEnabledApps.contains(
                    app.processName,
                  ),
                  onChanged: (enabled) =>
                      _controller.setAppDetectionEnabled(app.processName, enabled),
                  onRemove: app.isCustom
                      ? () => widget.settings.removeCustomApp(app.processName)
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionIntro(
          icon: Icons.tune_rounded,
          title: 'Make Baddel yours',
          subtitle:
              'Choose the keyboard layout and voice that feel right for you.',
        ),
        const SizedBox(height: 20),
        HomePanel(
          title: 'Keyboard layout',
          subtitle:
              'This tells Baddel how to recognize and correct typed text.',
          icon: Icons.keyboard_rounded,
          child: LayoutProfileSelector(
            profile: widget.settings.layoutProfile,
            onChanged: widget.settings.setLayoutProfile,
          ),
        ),
        const SizedBox(height: 16),
        HomePanel(
          title: 'Popup personality',
          subtitle: 'Choose the style of Baddel’s helpful messages.',
          icon: Icons.mood_rounded,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: PersonalityMode.values
                .map(
                  (mode) => PersonalityChoice(
                    mode: mode,
                    selected: mode == widget.settings.personalityMode,
                    onTap: () => widget.settings.setPersonalityMode(mode),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacySection(bool isDevMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionIntro(
          icon: Icons.lock_rounded,
          title: 'Privacy & control',
          subtitle:
              'Baddel analyzes text locally and never keeps your typing history.',
        ),
        const SizedBox(height: 20),
        HomePanel(
          title: 'Automatic detection',
          subtitle: 'You stay in control at all times.',
          icon: _controller.detectionPaused
              ? Icons.pause_circle_rounded
              : Icons.play_circle_rounded,
          child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Pause automatic detection',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'The Ctrl + Alt + B manual correction shortcut will still work.',
            ),
            value: _controller.detectionPaused,
            onChanged: _controller.setDetectionPaused,
          ),
        ),
        const SizedBox(height: 16),
        const HomePanel(
          title: 'Private by design',
          subtitle: 'No uploads. No cloud account. No typing history.',
          icon: Icons.verified_user_rounded,
          child: Text(
            'Password managers and remote-desktop windows are excluded automatically. Your text stays on this computer.',
            style: TextStyle(height: 1.5, color: Color(0xFF486581)),
          ),
        ),
        if (isDevMode) ...[
          const SizedBox(height: 16),
          HomePanel(
            title: 'Developer diagnostics',
            subtitle: '${_controller.eventCount} keyboard events received this session.',
            icon: Icons.terminal_rounded,
            trailing: FilledButton.tonalIcon(
              onPressed: _controller.debugMessages.isEmpty ? null : _controller.copyDebugLog,
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy log'),
            ),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 260),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF102A43),
                borderRadius: BorderRadius.circular(14),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _controller.debugMessages.isEmpty
                      ? 'Waiting for keyboard activity...'
                      : _controller.debugMessages.reversed.take(50).join('\n'),
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 11,
                    color: Color(0xFFD9EAF7),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Kept temporarily while the focused workspace replaces the original page.
  // ignore: unused_element
  Widget _buildRedesignedHome(BuildContext context) {
    final isDevMode = widget.settings.developerModeEnabled;
    final enabledApps = widget.settings.detectionEnabledApps.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(76),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: SafeArea(
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/logo/logo.png',
                    width: 46,
                    height: 46,
                  ),
                ),
                const SizedBox(width: 13),
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Baddel!',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF102A43),
                        ),
                      ),
                      Text(
                        'Your keyboard language companion',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF627D98),
                        ),
                      ),
                    ],
                  ),
                ),
                HomeModeButton(
                  label: 'Simple',
                  icon: Icons.auto_awesome_rounded,
                  selected: !isDevMode,
                  onTap: () => widget.settings.setDeveloperModeEnabled(false),
                ),
                const SizedBox(width: 6),
                HomeModeButton(
                  label: 'Developer',
                  icon: Icons.code_rounded,
                  selected: isDevMode,
                  onTap: () => widget.settings.setDeveloperModeEnabled(true),
                ),
                const SizedBox(width: 6),
                HomeModeButton(
                  label: 'Setup guide',
                  icon: Icons.menu_book_rounded,
                  selected: false,
                  onTap: () {
                    unawaited(widget.settings.restartOnboarding());
                  },
                ),
                const SizedBox(width: 14),
                HomeStatusPill(running: _controller.isRunning),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 34),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HomeHero(
                  running: _controller.isRunning,
                  paused: _controller.detectionPaused,
                  enabledApps: enabledApps,
                  onToggle: _controller.toggleHook,
                ),
                const SizedBox(height: 18),
                HomeQuickBar(
                  layout: _layoutProfileLabel(widget.settings.layoutProfile),
                  enabledApps: enabledApps,
                ),
                const SizedBox(height: 22),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 900;
                    final personalize = Column(
                      children: [
                        HomePanel(
                          title: 'Try Baddel',
                          subtitle:
                              'See the conversion before using it in another app.',
                          icon: Icons.keyboard_alt_rounded,
                          child: Column(
                            children: [
                              TextField(
                                controller: _controller.testInputController,
                                onChanged: _controller.runTestConversion,
                                decoration: InputDecoration(
                                  hintText:
                                      'Type with the wrong keyboard layout…',
                                  prefixIcon: const Icon(Icons.edit_rounded),
                                  suffixIcon: _controller.testInputController.text.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Clear',
                                          onPressed: () {
                                            _controller.testInputController.clear();
                                            _controller.runTestConversion('');
                                          },
                                          icon: const Icon(Icons.close_rounded),
                                        ),
                                ),
                              ),
                              if (_controller.testConvertedOutput.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFFCF6),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFA7E8CD),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: Color(0xFF0B8F6A),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: SelectableText(
                                          _controller.testConvertedOutput,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        HomePanel(
                          title: 'Make it yours',
                          subtitle:
                              'Choose your keyboard and Baddel personality.',
                          icon: Icons.tune_rounded,
                          child: Column(
                            children: [
                              LayoutProfileSelector(
                                profile: widget.settings.layoutProfile,
                                onChanged: (profile) =>
                                    widget.settings.setLayoutProfile(profile),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Popup personality',
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
                                children: PersonalityMode.values
                                    .map(
                                      (mode) => PersonalityChoice(
                                        mode: mode,
                                        selected:
                                            mode ==
                                            widget.settings.personalityMode,
                                        onTap: () => widget.settings
                                            .setPersonalityMode(mode),
                                      ),
                                    )
                                    .toList(),
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  widget.settings.personalityMode.description,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF627D98),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_controller.lastDetection != null) ...[
                          const SizedBox(height: 16),
                          HomePanel(
                            title: 'Correction ready',
                            subtitle:
                                '${(_controller.lastDetection!.confidence * 100).round()}% confidence',
                            icon: Icons.auto_fix_high_rounded,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SelectableText(
                                  _controller.lastDetection!.suggestion,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    FilledButton.icon(
                                      onPressed: () =>
                                          _controller.handleWarningAction('fix'),
                                      icon: const Icon(Icons.check_rounded),
                                      label: const Text('Fix text'),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: () =>
                                          _controller.handleWarningAction('dismiss'),
                                      child: const Text('Dismiss'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );

                    final apps = Column(
                      children: [
                        HomePanel(
                          title: 'Protected apps',
                          subtitle:
                              '$enabledApps apps enabled for automatic warnings.',
                          icon: Icons.apps_rounded,
                          trailing: FilledButton.tonalIcon(
                            onPressed: _showAddCustomAppDialog,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Add app'),
                          ),
                          child: Column(
                            children: [
                              for (final app in widget.settings.allTargetApps)
                                AppSettingRow(
                                  app: app,
                                  isEnabled: widget
                                      .settings
                                      .detectionEnabledApps
                                      .contains(app.processName),
                                  onChanged: (enabled) =>
                                      _controller.setAppDetectionEnabled(
                                        app.processName,
                                        enabled,
                                      ),
                                  onRemove: app.isCustom
                                      ? () => widget.settings.removeCustomApp(
                                          app.processName,
                                        )
                                      : null,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        HomePanel(
                          title: 'Privacy & control',
                          subtitle: 'Everything stays on this computer.',
                          icon: Icons.lock_rounded,
                          child: Column(
                            children: [
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Pause automatic detection',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: const Text(
                                  'Manual Ctrl + Alt + B correction remains available.',
                                ),
                                value: _controller.detectionPaused,
                                onChanged: _controller.setDetectionPaused,
                              ),
                              const Divider(),
                              const ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  Icons.verified_user_rounded,
                                  color: Color(0xFF0B8F6A),
                                ),
                                title: Text(
                                  'Private by design',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                  'No uploads, no typing history, and sensitive windows are excluded.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );

                    if (!wide) {
                      return Column(
                        children: [
                          personalize,
                          const SizedBox(height: 16),
                          apps,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: personalize),
                        const SizedBox(width: 18),
                        Expanded(flex: 6, child: apps),
                      ],
                    );
                  },
                ),
                if (isDevMode) ...[
                  const SizedBox(height: 18),
                  HomePanel(
                    title: 'Developer diagnostics',
                    subtitle:
                        '${_controller.eventCount} keyboard events received this session.',
                    icon: Icons.terminal_rounded,
                    trailing: FilledButton.tonalIcon(
                      onPressed: _controller.debugMessages.isEmpty ? null : _controller.copyDebugLog,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy log'),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Events received: ${_controller.eventCount}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 240),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF102A43),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              _controller.debugMessages.isEmpty
                                  ? 'Waiting for keyboard activity…'
                                  : _controller.debugMessages.reversed.take(50).join('\n'),
                              style: const TextStyle(
                                fontFamily: 'Consolas',
                                fontSize: 11,
                                color: Color(0xFFD9EAF7),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Baddel! v1.2.0  •  Built with care in Tunisia 🇹🇳',
                    style: TextStyle(fontSize: 12, color: Color(0xFF829AB1)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildLegacyDashboard(BuildContext context) {
    final event = _controller.lastEvent;
    final isTarget =
        event != null && widget.settings.isTargetApp(event.processName);
    final detectionEnabled =
        event != null && widget.settings.isDetectionEnabled(event.processName);

    final isDevMode = widget.settings.developerModeEnabled;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: SafeArea(
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F766E).withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/logo/logo.png',
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Baddel! Keyboard Language Helper',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        'Your keyboard\'s little mistake detector.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF0D9488),
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                // Mode Toggle Button (Simple vs Developer)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () =>
                            widget.settings.setDeveloperModeEnabled(false),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: !isDevMode
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),

                            boxShadow: !isDevMode
                                ? [
                                    const BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.sentiment_satisfied_alt_rounded,
                                size: 16,
                                color: !isDevMode
                                    ? const Color(0xFF0F766E)
                                    : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Simple',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: !isDevMode
                                      ? const Color(0xFF0F766E)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () =>
                            widget.settings.setDeveloperModeEnabled(true),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDevMode
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: isDevMode
                                ? [
                                    const BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.code_rounded,
                                size: 16,
                                color: isDevMode
                                    ? const Color(0xFF0F766E)
                                    : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Developer',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDevMode
                                      ? const Color(0xFF0F766E)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // About Developer Button
                InkWell(
                  onTap: () {
                    showDialog<void>(
                      context: context,
                      builder: (context) => const AboutBaddelDialog(),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF99F6E4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_rounded,
                          size: 16,
                          color: Color(0xFF0F766E),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Maher Ahmed',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _controller.isRunning
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFF1F5F9),

                    borderRadius: BorderRadius.circular(20),

                    border: Border.all(
                      color: _controller.isRunning
                          ? const Color(0xFFA7F3D0)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: _controller.isRunning
                              ? const Color(0xFF10B981)
                              : const Color(0xFF94A3B8),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _controller.isRunning ? 'Active & Watching' : 'Hook Inactive',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _controller.isRunning
                              ? const Color(0xFF047857)
                              : const Color(0xFF64748B),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'Control center',
                    style: TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // Clean Hero Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF042F2E),
                        Color(0xFF0F766E),
                        Color(0xFF0369A1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F766E).withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: Image.asset(
                                      'assets/logo/logo.png',
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Keyboard language protection',
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Baddel watches enabled apps for text typed with the wrong keyboard layout. Manual correction is always available with Ctrl+Alt+B.',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFFCCFBF1),
                                          height: 1.45,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),

                          // Big Power Switch
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _controller.toggleHook,
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 18,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: _controller.isRunning
                                        ? [
                                            const Color(0xFFE11D48),
                                            const Color(0xFFF43F5E),
                                          ]
                                        : [
                                            const Color(0xFF0D9488),
                                            const Color(0xFF14B8A6),
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(18),

                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          (_controller.isRunning
                                                  ? const Color(0xFFF43F5E)
                                                  : const Color(0xFF14B8A6))
                                              .withValues(alpha: 0.45),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _controller.isRunning
                                          ? Icons.stop_circle_rounded
                                          : Icons.play_circle_fill_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _controller.isRunning ? 'Stop hook' : 'Start hook',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Container(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      const SizedBox(height: 18),
                      // Keycap Shortcut Badges
                      Wrap(
                        spacing: 14,
                        runSpacing: 10,
                        children: const [
                          MacKeycapBadge(
                            keys: ['Ctrl', 'Alt', 'B'],
                            action: 'Fix Selection',
                            description: 'Instant manual correction',
                          ),
                          MacKeycapBadge(
                            keys: ['Ctrl', 'Alt', 'Z'],
                            action: 'Baddel Safe Undo',
                            description: 'Restores original typed text',
                          ),
                          MacKeycapBadge(
                            keys: ['Ctrl', 'Z'],
                            action: 'Native Undo',
                            description: 'Standard editor undo',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    QuickStatusCard(
                      icon: Icons.shield_rounded,
                      title: 'Protection',
                      value: _controller.isRunning ? 'Watching' : 'Ready to start',
                      caption: _controller.isRunning
                          ? 'Your selected apps are covered'
                          : 'Start the hook to begin',
                      color: Color(0xFF0F766E),
                    ),
                    QuickStatusCard(
                      icon: Icons.keyboard_rounded,
                      title: 'Layout',
                      value: _layoutProfileLabel(widget.settings.layoutProfile),
                      caption: 'Current keyboard profile',
                      color: Color(0xFF2563EB),
                    ),
                    QuickStatusCard(
                      icon: Icons.bolt_rounded,
                      title: 'Quick fix',
                      value: 'Ctrl + Alt + B',
                      caption: 'Correct selected text instantly',
                      color: Color(0xFFD97706),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Active Warning Card (If triggered)
                if (_controller.lastDetection != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFF59E0B),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFF59E0B,
                          ).withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDE68A),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.sentiment_very_satisfied_rounded,

                                color: Color(0xFFB45309),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _controller.lastWarningTitle ??
                                    'Baddel! \u{1F604} \u0646\u0633\u064A\u062A \u0627\u0644\u0643\u0644\u0627\u0641\u064A \u064A\u0627 \u0645\u0639\u0644\u0645\u061F',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,

                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFB45309),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                'Confidence: ${(_controller.lastDetection!.confidence * 100).round()}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.lock_outline_rounded,
                              size: 14,
                              color: Color(0xFFD97706),
                            ),

                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Check the popup notification to fix — your text is kept private here.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFB45309),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Live Interactive Sandbox ("Jarreb Houni")
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.touch_app_rounded,
                                color: Color(0xFF0284C7),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Interactive Test Sandbox (جرّب هوني)',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Test conversion live in-app',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller.testInputController,
                                onChanged: _controller.runTestConversion,
                                decoration: InputDecoration(
                                  hintText:
                                      'Type text here (e.g. "ghk" for "علي" or "مرحبا" in EN)...',

                                  hintStyle: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 14,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.keyboard_outlined,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                              ),
                            ),
                            if (_controller.testInputController.text.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              IconButton(
                                tooltip: 'Clear',
                                onPressed: () {
                                  _controller.testInputController.clear();
                                  _controller.runTestConversion('');
                                },
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (_controller.testConvertedOutput.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDFA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF99F6E4),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Color(0xFF0D9488),
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Converted result: ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF0F766E),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SelectableText(
                                  _controller.testConvertedOutput,

                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: _controller.testConvertedOutput),
                                    );
                                    showBaddelToast(
                                      context,
                                      'Copied converted text to clipboard!',
                                      icon: Icons.copy_rounded,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.copy_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Copy'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 2-Column Responsive Dashboard
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 840;
                    return Flex(
                      direction: isWide ? Axis.horizontal : Axis.vertical,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Personality
                        Expanded(
                          flex: isWide ? 6 : 0,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LayoutProfileSelector(
                                profile: widget.settings.layoutProfile,
                                onChanged: (profile) =>
                                    widget.settings.setLayoutProfile(profile),
                              ),
                              const SizedBox(height: 20),

                              // Personality Section Header
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEE2E2),

                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.theater_comedy_rounded,
                                      color: Color(0xFFE11D48),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Personality & Humor',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF0F172A),
                                          fontSize: 18,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Choose the humor style for popup warnings and suggestion cards.',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    children: [
                                      for (final mode in PersonalityMode.values)
                                        ModernPersonaCard(
                                          mode: mode,
                                          isSelected:
                                              widget.settings.personalityMode ==
                                              mode,
                                          onTap: () => widget.settings
                                              .setPersonalityMode(mode),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Developer diagnostics / session info (Visible only in Dev Mode)
                              if (isDevMode)
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE0E7FF),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Icon(
                                                Icons.query_stats_rounded,
                                                color: Color(0xFF4F46E5),
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            const Text(
                                              'Developer Live Activity',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 10,
                                          children: [
                                            StatusMetricChip(
                                              label: 'Status',
                                              value: _controller.isRunning
                                                  ? 'Running'
                                                  : 'Stopped',
                                              isPositive: _controller.isRunning,
                                            ),
                                            StatusMetricChip(
                                              label:
                                                  'Events received: ${_controller.eventCount}',
                                              value: '${_controller.eventCount} events',
                                            ),
                                            StatusMetricChip(
                                              label: 'Target app',
                                              value: isTarget ? 'Yes' : 'No',
                                              isPositive: isTarget,
                                            ),
                                            StatusMetricChip(
                                              label: 'Popup detection',
                                              value: detectionEnabled
                                                  ? 'Enabled'
                                                  : 'Disabled',
                                              isPositive: detectionEnabled,
                                            ),
                                          ],
                                        ),
                                        if (event != null) ...[
                                          const SizedBox(height: 14),
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8FAFC),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: const Color(0xFFE2E8F0),
                                              ),
                                            ),
                                            child: Text(
                                              'VK: ${event.virtualKey}  Scan: ${event.scanCode}  Time: ${event.time}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF64748B),
                                                fontFamily: 'Consolas',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        if (isWide) const SizedBox(width: 24),
                        if (!isWide) const SizedBox(height: 24),

                        // Right Column: Protected Applications & Custom App Add
                        Expanded(
                          flex: isWide ? 5 : 0,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Apps Header & Add Button
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.apps_rounded,
                                      color: Color(0xFF15803D),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Apps',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,

                                          color: const Color(0xFF0F172A),
                                          fontSize: 18,
                                        ),
                                  ),
                                  const Spacer(),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F766E),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                    ),
                                    onPressed: _showAddCustomAppDialog,
                                    icon: const Icon(
                                      Icons.add_circle_outline_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Add Custom App',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Choose where automatic warnings appear. Add any app like WhatsApp or AntiGravity!',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 14),

                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Column(
                                    children: [
                                      for (final app
                                          in widget.settings.allTargetApps)
                                        AppSettingRow(
                                          app: app,
                                          isEnabled: widget
                                              .settings
                                              .detectionEnabledApps
                                              .contains(app.processName),
                                          onChanged: (enabled) =>
                                              _controller.setAppDetectionEnabled(
                                                app.processName,
                                                enabled,
                                              ),
                                          onRemove: app.isCustom
                                              ? () => widget.settings
                                                    .removeCustomApp(
                                                      app.processName,
                                                    )
                                              : null,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Global Pause Switch Card
                              Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),

                                  side: BorderSide(
                                    color: _controller.detectionPaused
                                        ? const Color(0xFFFCA5A5)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: SwitchListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 6,
                                  ),
                                  secondary: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _controller.detectionPaused
                                          ? const Color(0xFFFEE2E2)
                                          : const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _controller.detectionPaused
                                          ? Icons.pause_circle_filled_rounded
                                          : Icons.play_circle_filled_rounded,
                                      color: _controller.detectionPaused
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF16A34A),
                                    ),
                                  ),
                                  title: const Text(
                                    'Pause keyboard-language detection',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    'Pausing hides warnings but leaves the manual correction shortcut available.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  value: _controller.detectionPaused,

                                  onChanged: _controller.setDetectionPaused,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Privacy Guarantee Card
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFFBBF7D0),
                                  ),
                                ),
                                child: const Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.verified_user_rounded,
                                      color: Color(0xFF16A34A),
                                      size: 24,
                                    ),
                                    SizedBox(width: 14),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,

                                        children: [
                                          Text(
                                            'Privacy Guarantee',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Color(0xFF166534),
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Privacy: text is analyzed locally, is never uploaded, and is not stored. Password managers and remote-desktop windows are always excluded.',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: Color(0xFF15803D),
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Collapsible Developer Diagnostics (Visible in Dev Mode)
                if (isDevMode)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),

                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.terminal_rounded,
                                  color: Color(0xFF475569),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Developer diagnostics',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Debug log and clipboard contention diagnostics',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Clipboard contention test mode',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: const Text(
                              'Uses a 2-second restore window so you can copy new content and verify Baddel does not overwrite it.',
                              style: TextStyle(fontSize: 12),
                            ),

                            value: _controller.contentionTestMode,
                            onChanged: _controller.setContentionTestMode,
                          ),
                          if (_controller.error != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _controller.error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Debug log',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: _controller.debugMessages.isEmpty
                                    ? null
                                    : _controller.copyDebugLog,
                                icon: const Icon(
                                  Icons.copy_all_rounded,
                                  size: 16,
                                ),

                                label: const Text('Copy all'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,

                            constraints: const BoxConstraints(
                              minHeight: 200,
                              maxHeight: 380,
                            ),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                _controller.debugMessages.isEmpty
                                    ? 'No debug messages yet.'
                                    : _controller.debugMessages.join('\n'),
                                style: const TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontSize: 12.5,
                                  fontFamily: 'Consolas',
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 36),
                const Center(
                  child: Text(
                    'Baddel! v1.2.0 • Designed & Developed with ❤️ by Maher Ahmed',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _layoutProfileLabel(KeyboardLayoutProfile profile) => switch (profile) {
  KeyboardLayoutProfile.usQwerty => 'US QWERTY',
  KeyboardLayoutProfile.frenchAzerty => 'French AZERTY',
  KeyboardLayoutProfile.arabic101 => 'Arabic 101',
  KeyboardLayoutProfile.arabicPhonetic => 'Arabic Phonetic',
};
