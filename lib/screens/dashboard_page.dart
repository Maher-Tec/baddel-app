import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../core/detection_engine.dart';
import '../core/feedback_stats.dart';
import '../core/keyboard_layout.dart';
import '../core/personality.dart';
import '../core/typing_buffer.dart';
import '../platform/keyboard_event_decoder.dart';
import '../platform/keyboard_hook.dart';
import '../settings/app_settings.dart';
import '../services/tray_service.dart';
import '../widgets/layout_profile_selector.dart';

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


class _HookTestPageState extends State<HookTestPage> with TrayListener, WindowListener {
  final TrayService _trayService = const TrayService();
  late final KeyboardHookClient _hook;
  StreamSubscription<KeyboardHookEvent>? _subscription;
  StreamSubscription<void>? _manualFixSubscription;
  StreamSubscription<String>? _debugSubscription;
  StreamSubscription<String>? _warningActionSubscription;
  KeyboardHookEvent? _lastEvent;
  String? _error;
  int _eventCount = 0;
  bool _isRunning = false;
  bool _contentionTestMode = false;
  bool _detectionPaused = false;

  final TextEditingController _testInputController = TextEditingController();
  String _testConvertedOutput = '';
  final List<String> _debugMessages = [];
  final TypingBuffer _typingBuffer = TypingBuffer();
  Timer? _detectionPauseTimer;
  int? _typingWindow;
  DetectionResult? _lastDetection;
  String? _lastWarningTitle;
  String _warningApp = 'Unknown app';
  FeedbackStats? _feedbackStats;
  int _consecutiveMistakeStreak = 0;
  DateTime? _lastMistakeTime;
  int _warningSelectionUnits = 0;
  int _warningTrailingUnits = 0;


  @override
  void initState() {
    super.initState();
    unawaited(_loadFeedbackStats());
    _detectionPaused = widget.settings.detectionPaused;
    _hook = KeyboardHookClient();
    _subscription = _hook.events.listen((event) {
      if (!mounted) return;
      _processTypingEvent(event);
      setState(() {
        _lastEvent = event;
        _eventCount++;
      });
    });
    _manualFixSubscription = _hook.manualFixRequests.listen((_) {
      if (_lastDetection != null) {
        _correctSelection(
          detection: _lastDetection,
          selectionUnits: _warningSelectionUnits,
          trailingUnits: _warningTrailingUnits,
        );
      } else {
        _correctSelection();
      }
    });

    _debugSubscription = _hook.debugMessages.listen((message) {
      if (!mounted) return;
      setState(() => _addDebugMessage(message));
    });
    _warningActionSubscription = _hook.warningActions.listen(
      _handleWarningAction,
    );
    if (widget.enableDesktopShell) {
      trayManager.addListener(this);
      windowManager.addListener(this);

      unawaited(_initializeDesktopShell());
    }
  }

  Future<void> _loadFeedbackStats() async {
    final stats = await FeedbackStats.load();
    if (mounted) setState(() => _feedbackStats = stats);
  }

  Future<void> _initializeDesktopShell() async {
    await windowManager.setPreventClose(true);
    final executableDirectory = File(Platform.resolvedExecutable).parent.path;
    final bundledIcon = '$executableDirectory\\data\\flutter_assets\\windows\\runner\\resources\\app_icon.ico';
    final iconPath = File(bundledIcon).existsSync() ? bundledIcon : 'windows\\runner\\resources\\app_icon.ico';
    await _trayService.initialize(
      iconPath: iconPath,
      tooltip: 'Baddel! Keyboard language helper',
    );
    await _updateTrayMenu();
  }

  Future<void> _updateTrayMenu() async {

    await _trayService.updateMenu(paused: _detectionPaused);
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
      unawaited(_setDetectionPaused(!_detectionPaused));
    } else if (menuItem.key == 'exit') {
      unawaited(_exitApplication());
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

  Future<void> _exitApplication() async {
    await _hook.stop();
    await _trayService.destroy();
    await windowManager.setPreventClose(false);

    await windowManager.destroy();
  }

  Future<void> _handleWarningAction(String action) async {
    if (!mounted) return;
    if (action == 'fix') {
      final detection = _lastDetection;
      final selectionUnits = _warningSelectionUnits;
      final trailingUnits = _warningTrailingUnits;
      if (detection == null) return;
      _detectionPauseTimer?.cancel();
      _typingBuffer.reset();
      await _correctSelection(
        detection: detection,
        selectionUnits: selectionUnits,
        trailingUnits: trailingUnits,
      );
    } else if (action == 'dismiss') {
      _detectionPauseTimer?.cancel();
      _typingBuffer.reset();
      setState(() {
        _lastDetection = null;
        _lastWarningTitle = null;
        _addDebugMessage('Phase 4 warning dismissed');
      });
      await _feedbackStats?.recordDismissal(_warningApp);

    } else if (action == 'pause') {
      await _setDetectionPaused(true);
    }
  }

  void _addDebugMessage(String message) {
    _debugMessages.add(message);
    if (_debugMessages.length > 100) _debugMessages.removeAt(0);
  }

  Future<void> _copyDebugLog() async {
    await Clipboard.setData(ClipboardData(text: _debugMessages.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Complete debug log copied.')),
    );

  }

  void _invalidateActiveWarning() {
    if (_lastDetection == null) return;
    _hook.hideWarningPopup();
    setState(() {
      _lastDetection = null;
      _lastWarningTitle = null;
      _warningSelectionUnits = 0;

      _warningTrailingUnits = 0;
    });
  }

  void _processTypingEvent(KeyboardHookEvent event) {
    if (!event.keyDown || event.injected || _detectionPaused) return;

    if (_typingWindow != event.foregroundWindow) {
      _typingWindow = event.foregroundWindow;
      _typingBuffer.reset();
      _detectionPauseTimer?.cancel();
      if (!widget.settings.isTargetApp(event.processName)) {
        _hook.hideWarningPopup();
      }
    }
    if (!widget.settings.isDetectionEnabled(event.processName)) return;
    if (KeyboardEventDecoder.resetsBuffer(event)) {
      _invalidateActiveWarning();
      _typingBuffer.reset();
      _detectionPauseTimer?.cancel();
      return;
    }
    if (KeyboardEventDecoder.isBackspace(event)) {
      _typingBuffer.backspace();
      return;

    }

    final character = KeyboardEventDecoder.decode(event);
    if (character == null) return;
    _invalidateActiveWarning();
    _typingBuffer.append(character, asSingleCaretUnit: true);
    final boundary = character.trim().isEmpty;
    if (_typingBuffer.shouldEvaluate(atWordBoundary: boundary)) {
      _evaluateTypingBuffer('length/boundary');
    }

    _detectionPauseTimer?.cancel();
    if (_typingBuffer.length >= 4) {
      _detectionPauseTimer = Timer(const Duration(milliseconds: 1500), () {

        if (mounted) _evaluateTypingBuffer('pause');
      });
    }
  }

  void _evaluateTypingBuffer(String trigger) {
    if (_typingBuffer.isEmpty) return;
    final endsTypingBurst = trigger == 'pause';
    final bufferedText = _typingBuffer.value;
    _typingBuffer.markEvaluated();
    final app = _lastEvent?.processName ?? 'Unknown app';
    final result = DetectionEngine(
      layoutProfile: widget.settings.layoutProfile,
      warningThreshold: _feedbackStats?.warningThresholdFor(app) ?? 0.82,
    ).detect(bufferedText);

    if (result == null) {
      if (endsTypingBurst) _typingBuffer.reset();
      return;
    }

    final percent = (result.confidence * 100).round();
    if (result.shouldWarn) {
      final now = DateTime.now();
      if (_lastMistakeTime != null && now.difference(_lastMistakeTime!) < const Duration(seconds: 90)) {
        _consecutiveMistakeStreak++;
      } else {
        _consecutiveMistakeStreak = 1;
      }
      _lastMistakeTime = now;
    }
    final funnyTitle = TunisianPersonality.getMessage(
      mode: widget.settings.personalityMode,
      suggestedLanguage: result.suggestedLanguage,
      typedLength: bufferedText.length,
      streak: _consecutiveMistakeStreak,
    );
    setState(() {
      _addDebugMessage(
        'Phase 3 detector ($trigger): $percent% confidence, ${result.shouldWarn ? 'warning' : 'no warning'}',
      );

      if (result.shouldWarn) {
        _lastDetection = result;
        _lastWarningTitle = funnyTitle;
        _warningApp = app;
        _warningSelectionUnits = _typingBuffer.contentCaretUnitCount;
        _warningTrailingUnits = _typingBuffer.trailingCaretUnitCount;
      }
    });
    if (endsTypingBurst) {
      _detectionPauseTimer?.cancel();
      if (!result.shouldWarn) _typingBuffer.reset();
    }
    if (result.shouldWarn) {

      _hook
          .showWarningPopup(
            title: funnyTitle,
            suggestion: result.suggestion,
            confidence: percent,
          )
          .then((shown) {
            if (!mounted || shown) return;
            setState(
              () => _addDebugMessage('Phase 4 popup could not be shown'),
            );
          })
          .catchError((Object error) {

            if (!mounted) return;
            setState(() => _addDebugMessage('Phase 4 popup error: $error'));
          });
    }
  }

  Future<void> _correctSelection({
    DetectionResult? detection,
    int selectionUnits = 0,
    int trailingUnits = 0,
  }) async {
    try {
      final selected = detection == null
          ? await _hook.captureSelection()
          : await _hook.captureDetectedText(
              expected: detection.original,
              selectionUnits: selectionUnits,
              trailingUnits: trailingUnits,
            );
      if (selected.isEmpty) return;
      if (detection != null && selected != detection.original) return;
      setState(
        () => _addDebugMessage(
          '2/7 Selection text returned to Flutter (${selected.length} chars)',
        ),

      );
      final hasArabic = RegExp(r'[\u0600-\u06ff]').hasMatch(selected);
      final direction = hasArabic ? LayoutDirection.arabicToUs : LayoutDirection.usToArabic;
      final replacement = KeyboardLayout.convert(selected, direction);
      setState(
        () => _addDebugMessage(
          '3/7 Converted using ${hasArabic ? 'Arabic â†’ US' : 'US â†’ Arabic'} (${replacement.length} chars)',
        ),
      );
      final pasted = await _hook.pasteReplacement(replacement);

      if (pasted && mounted) {
        await _feedbackStats?.recordFix(_warningApp);
        setState(() {
          _lastDetection = null;
          _lastWarningTitle = null;
        });
      }
      if (!pasted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Baddel could not replace the selection.'),
          ),
        );
      }
    } on PlatformException catch (error) {
      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'No text selection found.')),
        );
      }
    }
  }

  Future<void> _toggleHook() async {
    setState(() => _error = null);
    try {
      if (_isRunning) {
        await _hook.stop();
        if (mounted) setState(() => _isRunning = false);
      } else {
        final started = await _hook.start();
        if (mounted) setState(() => _isRunning = started);
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _setContentionTestMode(bool enabled) async {
    await _hook.setClipboardRestoreDelay(
      Duration(milliseconds: enabled ? 2000 : 200),

    );
    if (mounted) setState(() => _contentionTestMode = enabled);
  }

  Future<void> _setDetectionPaused(bool paused) async {
    _detectionPauseTimer?.cancel();
    _typingBuffer.reset();
    if (paused) await _hook.hideWarningPopup();

    if (!mounted) return;
    await widget.settings.setDetectionPaused(paused);
    if (!mounted) return;
    setState(() {
      _detectionPaused = paused;
      _lastDetection = null;
      _lastWarningTitle = null;
      _addDebugMessage(
        paused ? 'Phase 4 detection paused' : 'Phase 4 detection resumed',
      );
    });
    if (widget.enableDesktopShell) await _updateTrayMenu();
  }

  Future<void> _setAppDetectionEnabled(String processName, bool enabled) async {
    await widget.settings.setAppDetectionEnabled(processName, enabled);
    if (!mounted) return;

    setState(() {
      _addDebugMessage(
        'Detection ${enabled ? 'enabled' : 'disabled'} for $processName',
      );
    });
  }

  void _runTestConversion(String text) {
    if (text.isEmpty) {
      setState(() => _testConvertedOutput = '');
      return;
    }
    final hasArabic = RegExp(r'[\u0600-\u06ff]').hasMatch(text);
    final direction = hasArabic ? LayoutDirection.arabicToUs : LayoutDirection.usToArabic;
    final converted = KeyboardLayout.convert(text, direction);
    setState(() => _testConvertedOutput = converted);
  }

  void _showAddCustomAppDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => _AddCustomAppDialog(
        settings: widget.settings,
        hook: _hook,
      ),

    );
  }

  @override
  void dispose() {
    _testInputController.dispose();

    if (widget.enableDesktopShell) {
      trayManager.removeListener(this);
      windowManager.removeListener(this);
    }
    _subscription?.cancel();
    _manualFixSubscription?.cancel();
    _debugSubscription?.cancel();
    _warningActionSubscription?.cancel();
    _detectionPauseTimer?.cancel();
    _hook.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = _lastEvent;
    final isTarget = event != null && widget.settings.isTargetApp(event.processName);
    final detectionEnabled = event != null && widget.settings.isDetectionEnabled(event.processName);

    final isDevMode = widget.settings.developerModeEnabled;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(

                        'Your keyboard\'s little mistake detector.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF0D9488), fontWeight: FontWeight.bold),
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
                        onTap: () => widget.settings.setDeveloperModeEnabled(false),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: !isDevMode ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),

                            boxShadow: !isDevMode
                                ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))]

                                : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.sentiment_satisfied_alt_rounded,
                                size: 16,
                                color: !isDevMode ? const Color(0xFF0F766E) : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Simple',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: !isDevMode ? const Color(0xFF0F766E) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      InkWell(

                        onTap: () => widget.settings.setDeveloperModeEnabled(true),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDevMode ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: isDevMode
                                ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))]
                                : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.code_rounded,
                                size: 16,
                                color: isDevMode ? const Color(0xFF0F766E) : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Developer',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDevMode ? const Color(0xFF0F766E) : const Color(0xFF64748B),


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
                      builder: (context) => const _AboutBaddelDialog(),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF99F6E4)),

                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_rounded, size: 16, color: Color(0xFF0F766E)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: _isRunning ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),

                    borderRadius: BorderRadius.circular(20),

                    border: Border.all(
                      color: _isRunning ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: _isRunning ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isRunning ? 'Active & Watching' : 'Hook Inactive',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _isRunning ? const Color(0xFF047857) : const Color(0xFF64748B),
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
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                                        color: Colors.black.withValues(alpha: 0.3),
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                              onTap: _toggleHook,
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 18,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: _isRunning
                                        ? [const Color(0xFFE11D48), const Color(0xFFF43F5E)]
                                        : [const Color(0xFF0D9488), const Color(0xFF14B8A6)],
                                  ),
                                  borderRadius: BorderRadius.circular(18),

                                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_isRunning ? const Color(0xFFF43F5E) : const Color(0xFF14B8A6))
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
                                      _isRunning ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _isRunning ? 'Stop hook' : 'Start hook',
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
                      Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
                      const SizedBox(height: 18),
                      // Keycap Shortcut Badges
                      Wrap(
                        spacing: 14,
                        runSpacing: 10,
                        children: const [
                          _MacKeycapBadge(
                            keys: ['Ctrl', 'Alt', 'B'],
                            action: 'Fix Selection',
                            description: 'Instant manual correction',
                          ),
                          _MacKeycapBadge(

                            keys: ['Ctrl', 'Alt', 'Z'],
                            action: 'Baddel Safe Undo',
                            description: 'Restores original typed text',
                          ),
                          _MacKeycapBadge(
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

                // Active Warning Card (If triggered)
                if (_lastDetection != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
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
                                _lastWarningTitle ?? 'Baddel! ðŸ˜‚ Ù†Ø³ÙŠØª Ø§Ù„ÙƒÙ„Ø§ÙÙŠÙŠ ÙŠØ§ Ù…Ø¹Ù„Ù…ØŸ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,

                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFB45309),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                'Confidence: ${(_lastDetection!.confidence * 100).round()}%',
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
                            const Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFFD97706)),

                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Check the popup notification to fix â€” your text is kept private here.',
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
                              child: const Icon(Icons.touch_app_rounded, color: Color(0xFF0284C7), size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Interactive Test Sandbox (Ø¬Ø±Ù‘Ø¨ Ù‡ÙˆÙ†ÙŠ)',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Test conversion live in-app',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],

                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _testInputController,
                                onChanged: _runTestConversion,
                                decoration: InputDecoration(
                                  hintText: 'Type text here (e.g. "ghk" for "Ø¹Ù„ÙŠ" or "Ù…Ø±Ø­Ø¨Ø§" in EN)...',

                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                  prefixIcon: const Icon(Icons.keyboard_outlined, color: Color(0xFF0F766E)),
                                ),
                              ),

                            ),
                            if (_testInputController.text.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              IconButton(
                                tooltip: 'Clear',
                                onPressed: () {
                                  _testInputController.clear();
                                  _runTestConversion('');
                                },
                                icon: const Icon(Icons.clear_rounded, color: Color(0xFF64748B)),
                              ),
                            ],
                          ],
                        ),
                        if (_testConvertedOutput.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDFA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF99F6E4)),
                            ),
                            child: Row(
                              children: [

                                const Icon(Icons.arrow_forward_rounded, color: Color(0xFF0D9488), size: 18),
                                const SizedBox(width: 10),
                                const Text(
                                  'Converted result: ',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF0F766E), fontWeight: FontWeight.bold),
                                ),
                                SelectableText(
                                  _testConvertedOutput,

                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: _testConvertedOutput));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Copied converted text to clipboard!')),
                                    );
                                  },
                                  icon: const Icon(Icons.copy_rounded, size: 16),
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
                                onChanged: (profile) => widget.settings.setLayoutProfile(profile),
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
                                    child: const Icon(Icons.theater_comedy_rounded, color: Color(0xFFE11D48), size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Personality & Humor',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),

                              ),
                              const SizedBox(height: 14),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    children: [
                                      for (final mode in PersonalityMode.values)
                                        _ModernPersonaCard(
                                          mode: mode,
                                          isSelected: widget.settings.personalityMode == mode,
                                          onTap: () => widget.settings.setPersonalityMode(mode),
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

                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [

                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE0E7FF),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Icon(Icons.query_stats_rounded, color: Color(0xFF4F46E5), size: 20),
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
                                            _StatusMetricChip(
                                              label: 'Status',
                                              value: _isRunning ? 'Running' : 'Stopped',
                                              isPositive: _isRunning,
                                            ),
                                            _StatusMetricChip(
                                              label: 'Events received: $_eventCount',
                                              value: '$_eventCount events',
                                            ),
                                            _StatusMetricChip(
                                              label: 'Target app',
                                              value: isTarget ? 'Yes' : 'No',
                                              isPositive: isTarget,
                                            ),
                                            _StatusMetricChip(
                                              label: 'Popup detection',
                                              value: detectionEnabled ? 'Enabled' : 'Disabled',
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
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                    child: const Icon(Icons.apps_rounded, color: Color(0xFF15803D), size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Apps',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    ),
                                    onPressed: _showAddCustomAppDialog,
                                    icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                    label: const Text('Add Custom App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Choose where automatic warnings appear. Add any app like WhatsApp or AntiGravity!',
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                              ),
                              const SizedBox(height: 14),

                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Column(
                                    children: [
                                      for (final app in widget.settings.allTargetApps)
                                        _AppSettingRow(
                                          app: app,
                                          isEnabled: widget.settings.detectionEnabledApps.contains(app.processName),
                                          onChanged: (enabled) => _setAppDetectionEnabled(app.processName, enabled),
                                          onRemove: app.isCustom
                                              ? () => widget.settings.removeCustomApp(app.processName)
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

                                    color: _detectionPaused ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: SwitchListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                                  secondary: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _detectionPaused ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _detectionPaused ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                                      color: _detectionPaused ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                                    ),
                                  ),
                                  title: const Text(
                                    'Pause keyboard-language detection',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  subtitle: const Text(
                                    'Pausing hides warnings but leaves the manual correction shortcut available.',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                  value: _detectionPaused,

                                  onChanged: _setDetectionPaused,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Privacy Guarantee Card
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: const Color(0xFFBBF7D0)),
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
                                        crossAxisAlignment: CrossAxisAlignment.start,

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
                                child: const Icon(Icons.terminal_rounded, color: Color(0xFF475569), size: 20),

                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Developer diagnostics',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    'Debug log and clipboard contention diagnostics',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Clipboard contention test mode', style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: const Text(
                              'Uses a 2-second restore window so you can copy new content and verify Baddel does not overwrite it.',
                              style: TextStyle(fontSize: 12),
                            ),

                            value: _contentionTestMode,
                            onChanged: _setContentionTestMode,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Text(_error!, style: const TextStyle(color: Colors.red)),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Debug log',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: _debugMessages.isEmpty ? null : _copyDebugLog,
                                icon: const Icon(Icons.copy_all_rounded, size: 16),

                                label: const Text('Copy all'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,

                            constraints: const BoxConstraints(minHeight: 200, maxHeight: 380),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF1E293B)),
                            ),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                _debugMessages.isEmpty ? 'No debug messages yet.' : _debugMessages.join('\n'),
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
                    'Baddel! v1.1.0 â€¢ Designed & Developed with â¤ï¸ by Maher Ahmed',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
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

class _AddCustomAppDialog extends StatefulWidget {

  const _AddCustomAppDialog({
    required this.settings,
    required this.hook,
  });

  final AppSettings settings;
  final KeyboardHookClient hook;

  @override

  State<_AddCustomAppDialog> createState() => _AddCustomAppDialogState();
}

class _AddCustomAppDialogState extends State<_AddCustomAppDialog> {
  final TextEditingController _processController = TextEditingController();
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, String>> _runningApps = [];
  List<Map<String, String>> _filteredApps = [];
  bool _isLoadingRunning = true;
  int _selectedTab = 0; // 0: Running Apps, 1: Popular Presets, 2: Manual Input

  final List<Map<String, String>> _popularApps = const [
    {'process': 'whatsapp.exe', 'label': 'WhatsApp', 'cat': 'Messaging'},
    {'process': 'antigravity.exe', 'label': 'AntiGravity', 'cat': 'IDE / AI'},
    {'process': 'telegram.exe', 'label': 'Telegram', 'cat': 'Messaging'},
    {'process': 'discord.exe', 'label': 'Discord', 'cat': 'Chat'},
    {'process': 'slack.exe', 'label': 'Slack', 'cat': 'Work Chat'},
    {'process': 'brave.exe', 'label': 'Brave Browser', 'cat': 'Browser'},
    {'process': 'firefox.exe', 'label': 'Firefox', 'cat': 'Browser'},
    {'process': 'msedge.exe', 'label': 'Microsoft Edge', 'cat': 'Browser'},
    {'process': 'obsidian.exe', 'label': 'Obsidian', 'cat': 'Notes'},
    {'process': 'notion.exe', 'label': 'Notion', 'cat': 'Notes'},
  ];


  @override
  void initState() {
    super.initState();
    _fetchRunningApps();
  }

  Future<void> _fetchRunningApps() async {
    final apps = await widget.hook.getRunningApps();
    if (!mounted) return;
    setState(() {
      _runningApps = apps;
      _filterApps(_searchController.text);
      _isLoadingRunning = false;

    });
  }

  void _filterApps(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      _filteredApps = List.from(_runningApps);
    } else {
      _filteredApps = _runningApps.where((app) {
        final title = app['title']!.toLowerCase();
        final proc = app['processName']!.toLowerCase();

        return title.contains(q) || proc.contains(q);
      }).toList();
    }
  }

  @override
  void dispose() {
    _processController.dispose();
    _labelController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _addApp(String process, String label, String cat) {
    widget.settings.addCustomApp(
      processName: process,
      label: label,
      category: cat,
    );
    Navigator.of(context).pop();
  }

  IconData _getAppIcon(String processName) {
    final proc = processName.toLowerCase();
    if (proc.contains('whatsapp') || proc.contains('telegram') || proc.contains('discord') || proc.contains('slack')) {

      return Icons.chat_rounded;
    }
    if (proc.contains('chrome') || proc.contains('browser') || proc.contains('firefox') || proc.contains('edge') || proc.contains('brave')) {
      return Icons.public_rounded;
    }
    if (proc.contains('code') || proc.contains('antigravity') || proc.contains('studio') || proc.contains('idea')) {
      return Icons.code_rounded;
    }
    if (proc.contains('terminal') || proc.contains('cmd') || proc.contains('powershell')) {
      return Icons.terminal_rounded;
    }
    return Icons.laptop_windows_rounded;

  }

  Color _getAppIconBg(String processName) {
    final proc = processName.toLowerCase();
    if (proc.contains('whatsapp') || proc.contains('telegram')) return const Color(0xFFDCFCE7);
    if (proc.contains('chrome') || proc.contains('browser') || proc.contains('brave')) return const Color(0xFFE0F2FE);
    if (proc.contains('code') || proc.contains('antigravity')) return const Color(0xFFE0E7FF);
    return const Color(0xFFF1F5F9);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 650,
        height: 580,
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dialog Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.add_to_photos_rounded, color: Color(0xFF0F766E), size: 24),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Protected Application',

                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Choose from live PC apps, popular presets, or enter a process name.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(

                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tab Selector Chips
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(

                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedTab = 0),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _selectedTab == 0
                              ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 18,
                              color: _selectedTab == 0 ? const Color(0xFF0F766E) : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Running PC Apps (${_runningApps.length})',

                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _selectedTab == 0 ? const Color(0xFF0F766E) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),

                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedTab = 1),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _selectedTab == 1
                              ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))]
                              : null,
                        ),
                        child: Row(

                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.stars_rounded,
                              size: 18,
                              color: _selectedTab == 1 ? const Color(0xFF0F766E) : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Popular Presets',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _selectedTab == 1 ? const Color(0xFF0F766E) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedTab = 2),
                      borderRadius: BorderRadius.circular(10),

                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 2 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _selectedTab == 2

                              ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              size: 18,
                              color: _selectedTab == 2 ? const Color(0xFF0F766E) : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Manual Input',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _selectedTab == 2 ? const Color(0xFF0F766E) : const Color(0xFF64748B),
                              ),

                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Tab Content 0: Running Apps
            if (_selectedTab == 0) ...[
              // Search Input & Refresh Button
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _filterApps(val)),
                      decoration: InputDecoration(
                        hintText: 'Search running PC apps (e.g. "WhatsApp", "Chrome")...',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),

                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF0F766E)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),

                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      setState(() => _isLoadingRunning = true);
                      _fetchRunningApps();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Refresh'),

                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Spacious Running Apps List View
              Expanded(
                child: _isLoadingRunning
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 14),
                            Text('Scanning active desktop applications...', style: TextStyle(color: Color(0xFF64748B))),
                          ],
                        ),
                      )
                    : _filteredApps.isEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),

                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),

                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.screen_search_desktop_rounded, size: 48, color: Color(0xFF94A3B8)),
                                const SizedBox(height: 12),
                                const Text(
                                  'No matching running apps found.',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF334155)),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Launch your app on Windows and click Refresh above.',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),

                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: ListView.separated(
                                padding: const EdgeInsets.all(10),
                                itemCount: _filteredApps.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final app = _filteredApps[index];
                                  final proc = app['processName']!;
                                  final title = app['title']!;
                                  final isAlreadyAdded = widget.settings.isTargetApp(proc);
                                  final displayTitle = title.split('-').first.trim();

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isAlreadyAdded ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                                      ),
                                      boxShadow: const [
                                        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
                                      ],
                                    ),


                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: _getAppIconBg(proc),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(_getAppIcon(proc), size: 22, color: const Color(0xFF0F172A)),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      title.length > 45 ? '${title.substring(0, 45)}...' : title,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                        color: Color(0xFF0F172A),
                                                      ),

                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFE2E8F0),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      proc,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                        color: Color(0xFF475569),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),

                                                  const Text(

                                                    'â— Running',
                                                    style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        isAlreadyAdded
                                            ? Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFDCFCE7),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: const Row(
                                                  children: [
                                                    Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      'Protected',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,

                                                        color: Color(0xFF16A34A),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : FilledButton.icon(
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: const Color(0xFF0F766E),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                ),
                                                onPressed: () => _addApp(
                                                  proc,
                                                  displayTitle.isEmpty ? proc : displayTitle,
                                                  'Running PC App',
                                                ),
                                                icon: const Icon(Icons.add_rounded, size: 18),
                                                label: const Text('Add App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              ),

                                      ],
                                    ),
                                  );

                                },
                              ),
                            ),
                          ),
              ),
            ],

            // Tab Content 1: Popular Presets
            if (_selectedTab == 1) ...[
              const Text(
                'Click any popular application to add protection immediately:',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final app in _popularApps) ...[
                        InkWell(
                          onTap: () => _addApp(app['process']!, app['label']!, app['cat']!),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(

                            width: 180,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _getAppIconBg(app['process']!),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(_getAppIcon(app['process']!), size: 20, color: const Color(0xFF0F172A)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(

                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        app['label']!,

                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        app['process']!,
                                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            // Tab Content 2: Manual Input
            if (_selectedTab == 2) ...[
              const Text(
                'Type the executable name of any application installed on your PC:',

                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _processController,
                decoration: InputDecoration(
                  labelText: 'Process Name (e.g. whatsapp.exe or antigravity)',
                  hintText: 'antigravity.exe',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.app_shortcut_rounded, color: Color(0xFF0F766E)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _labelController,
                decoration: InputDecoration(
                  labelText: 'Display Label (Optional)',
                  hintText: 'AntiGravity AI',

                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.label_outline_rounded, color: Color(0xFF0F766E)),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,

                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
                  onPressed: () {
                    if (_processController.text.trim().isNotEmpty) {
                      _addApp(
                        _processController.text,
                        _labelController.text,
                        'Custom App',
                      );
                    }
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Add Application', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModernPersonaCard extends StatelessWidget {

  const _ModernPersonaCard({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  final PersonalityMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sampleQuote = TunisianPersonality.getMessage(mode: mode, indexSeed: 0);

    Color accentColor;
    IconData icon;

    String badgeEmoji;

    switch (mode) {
      case PersonalityMode.weldElHouma:
        accentColor = const Color(0xFFE11D48);
        icon = Icons.local_fire_department_rounded;
        badgeEmoji = 'ðŸŒ¶ï¸';
        break;
      case PersonalityMode.devTanbir:

        accentColor = const Color(0xFF0284C7);
        icon = Icons.terminal_rounded;
        badgeEmoji = 'ðŸ’»';
        break;
      case PersonalityMode.tunisianFunny:
        accentColor = const Color(0xFFD97706);
        icon = Icons.sentiment_very_satisfied_rounded;
        badgeEmoji = 'ðŸ˜‚';
        break;
      case PersonalityMode.classic:
        accentColor = const Color(0xFF475569);
        icon = Icons.tune_rounded;
        badgeEmoji = 'ðŸ‘”';
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.06) : Colors.white,

          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accentColor : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,

        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected ? accentColor : accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),

                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isSelected ? Colors.white : accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              mode.label,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF334155),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          const SizedBox(width: 6),
                          Text(badgeEmoji, style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        mode.description,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),

                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? accentColor : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? accentColor : const Color(0xFFCBD5E1),
                      width: 2,
                    ),
                  ),
                  child: isSelected ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
                ),

              ],
            ),
            if (isSelected) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sample: "$sampleQuote"',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                        overflow: TextOverflow.ellipsis,

                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );

  }
}

class _AppSettingRow extends StatelessWidget {
  const _AppSettingRow({
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
    } else if (app.processName.contains('chrome') || app.processName.contains('browser') || app.processName.contains('firefox') || app.processName.contains('edge') || app.processName.contains('brave')) {
      iconBg = const Color(0xFFE0F2FE);
      icon = Icons.public_rounded;
    } else if (app.processName.contains('code') || app.processName.contains('antigravity') || app.processName.contains('studio')) {
      iconBg = const Color(0xFFE0E7FF);
      icon = Icons.code_rounded;
    } else if (app.processName.contains('terminal') || app.processName.contains('cmd')) {
      iconBg = const Color(0xFFF1F5F9);
      icon = Icons.terminal_rounded;
    } else if (app.processName.contains('whatsapp') || app.processName.contains('telegram') || app.processName.contains('discord') || app.processName.contains('slack')) {
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
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
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
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        '${app.category} Â· ${app.processName}',
        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),

      ),
      value: isEnabled,
      onChanged: onChanged,
    );
  }
}


class _MacKeycapBadge extends StatelessWidget {
  const _MacKeycapBadge({
    required this.keys,
    required this.action,
    required this.description,
  });

  final List<String> keys;
  final String action;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),

        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    offset: Offset(0, 2),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: Text(
                keys[i],
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F766E),

                ),
              ),
            ),
            if (i < keys.length - 1)

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '+',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
          ],
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                action,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Text(
                description,
                style: const TextStyle(
                  color: Color(0xFF99F6E4),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusMetricChip extends StatelessWidget {
  const _StatusMetricChip({
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
      badgeColor = isPositive! ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9);
      textColor = isPositive! ? const Color(0xFF047857) : const Color(0xFF64748B);
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
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
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

class _AboutBaddelDialog extends StatelessWidget {
  const _AboutBaddelDialog();

  Future<void> _launchUrl(String urlString) async {
    final Uri uri = Uri.parse(urlString);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }


  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),

                child: Image.asset(
                  'assets/logo/logo.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Baddel! (Ø¨Ø¯Ù‘Ù„)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Smart Tunisian Keyboard Layout Helper',
              style: TextStyle(fontSize: 13, color: Color(0xFF0D9488), fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),

                borderRadius: BorderRadius.circular(16),

                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.code_rounded, color: Color(0xFF0F766E), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Created & Developed by',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Maher Ahmed',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF0F766E)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),

                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () => _launchUrl('https://maher-ahmed.netlify.app/'),
                    icon: const Icon(Icons.language_rounded, size: 16, color: Color(0xFF0F766E)),
                    label: const Text(
                      'Visit Portfolio (maher-ahmed.netlify.app)',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 16, color: Color(0xFF10B981)),
                SizedBox(width: 6),
                Text(
                  '100% Offline â€¢ Zero Data Stored â€¢ Volatile Memory Only',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),

              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
