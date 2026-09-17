import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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

/// Owns the hook/tray lifecycle, keystroke handling, detection engine state,
/// warning-popup action handling, and debug-log bookkeeping for the
/// dashboard. UI-only state (such as the selected navigation section) stays
/// on the [State] that hosts this controller.
class DashboardController extends ChangeNotifier {
  DashboardController({required this.settings, required this.enableDesktopShell, this.onShowMessage}) {
    _detectionPaused = settings.detectionPaused;
    _hook = KeyboardHookClient();
    _subscription = _hook.events.listen((event) {
      if (_disposed) return;
      _processTypingEvent(event);
      _lastEvent = event;
      _eventCount++;
      notifyListeners();
    });
    _manualFixSubscription = _hook.manualFixRequests.listen((_) {
      if (_lastDetection != null) {
        unawaited(
          _correctSelection(
            detection: _lastDetection,
            selectionUnits: _warningSelectionUnits,
            trailingUnits: _warningTrailingUnits,
          ),
        );
      } else {
        unawaited(_correctSelection());
      }
    });
    _debugSubscription = _hook.debugMessages.listen((message) {
      if (_disposed) return;
      _addDebugMessage(message);
      notifyListeners();
    });
    _warningActionSubscription = _hook.warningActions.listen(handleWarningAction);
    unawaited(_loadFeedbackStats());
  }

  final AppSettings settings;
  final bool enableDesktopShell;

  /// Invoked when a transient message should be surfaced to the user (for
  /// example via a [SnackBar]). The controller has no [BuildContext], so the
  /// caller is responsible for actually presenting the message.
  final void Function(String message)? onShowMessage;

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

  final TextEditingController testInputController = TextEditingController();
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

  bool _disposed = false;

  KeyboardHookClient get hook => _hook;
  KeyboardHookEvent? get lastEvent => _lastEvent;
  String? get error => _error;
  int get eventCount => _eventCount;
  bool get isRunning => _isRunning;
  bool get contentionTestMode => _contentionTestMode;
  bool get detectionPaused => _detectionPaused;
  String get testConvertedOutput => _testConvertedOutput;
  List<String> get debugMessages => _debugMessages;
  DetectionResult? get lastDetection => _lastDetection;
  String? get lastWarningTitle => _lastWarningTitle;

  Future<void> _loadFeedbackStats() async {
    final stats = await FeedbackStats.load();
    if (_disposed) return;
    _feedbackStats = stats;
    notifyListeners();
  }

  Future<void> initializeDesktopShell() async {
    await windowManager.setPreventClose(true);
    final executableDirectory = File(Platform.resolvedExecutable).parent.path;
    final bundledIcon =
        '$executableDirectory\\data\\flutter_assets\\windows\\runner\\resources\\app_icon.ico';
    final iconPath = File(bundledIcon).existsSync()
        ? bundledIcon
        : 'windows\\runner\\resources\\app_icon.ico';
    await _trayService.initialize(
      iconPath: iconPath,
      tooltip: 'Baddel! Keyboard language helper',
    );
    await _updateTrayMenu();
  }

  Future<void> _updateTrayMenu() async {
    await _trayService.updateMenu(paused: _detectionPaused);
  }

  Future<void> exitApplication() async {
    await _hook.stop();
    await _trayService.destroy();
    await windowManager.setPreventClose(false);

    await windowManager.destroy();
  }

  Future<void> handleWarningAction(String action) async {
    if (_disposed) return;
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
      _lastDetection = null;
      _lastWarningTitle = null;
      _addDebugMessage('Phase 4 warning dismissed');
      notifyListeners();
      await _feedbackStats?.recordDismissal(_warningApp);
    } else if (action == 'pause') {
      await setDetectionPaused(true);
    }
  }

  void _addDebugMessage(String message) {
    _debugMessages.add(message);
    if (_debugMessages.length > 100) _debugMessages.removeAt(0);
  }

  void _trace(String message) {
    final stamp = DateTime.now().toIso8601String().substring(11, 23);
    _addDebugMessage('[trace $stamp] $message');
  }

  Future<void> copyDebugLog() async {
    await Clipboard.setData(ClipboardData(text: _debugMessages.join('\n')));
    if (_disposed) return;
    onShowMessage?.call('Complete debug log copied.');
  }

  void _invalidateActiveWarning() {
    if (_lastDetection == null) return;
    _hook.hideWarningPopup();
    _lastDetection = null;
    _lastWarningTitle = null;
    _warningSelectionUnits = 0;

    _warningTrailingUnits = 0;
    notifyListeners();
  }

  void _processTypingEvent(KeyboardHookEvent event) {
    _trace(
      'hook keyDown=${event.keyDown} injected=${event.injected} '
      'vk=${event.virtualKey} scan=${event.scanCode} flags=${event.flags} '
      'mods=ctrl:${event.controlDown},alt:${event.altDown},shift:${event.shiftDown} '
      'hwnd=${event.foregroundWindow} app="${event.processName}" '
      'bufferBefore="${_typingBuffer.value}" len=${_typingBuffer.length} '
      'paused=$_detectionPaused activeWarning=${_lastDetection != null}',
    );
    if (!event.keyDown || event.injected || _detectionPaused) return;

    if (_typingWindow != event.foregroundWindow) {
      _trace(
        'window changed $_typingWindow -> ${event.foregroundWindow}; resetting buffer/warning',
      );
      _invalidateActiveWarning();
      _typingWindow = event.foregroundWindow;
      _typingBuffer.reset();
      _detectionPauseTimer?.cancel();
      if (!settings.isTargetApp(event.processName)) {
        _hook.hideWarningPopup();
      }
    }
    if (!settings.isDetectionEnabled(event.processName)) {
      _trace('ignored: detection disabled for app "${event.processName}"');
      return;
    }
    if (KeyboardEventDecoder.resetsBuffer(event)) {
      _trace('buffer reset key detected');
      _invalidateActiveWarning();
      _typingBuffer.reset();
      _detectionPauseTimer?.cancel();
      return;
    }
    if (KeyboardEventDecoder.isBackspace(event)) {
      _typingBuffer.backspace();
      _trace(
        'backspace -> buffer="${_typingBuffer.value}" len=${_typingBuffer.length}',
      );
      return;
    }

    final character = KeyboardEventDecoder.decode(event);
    if (character == null) {
      _trace('decoder returned null');
      return;
    }
    // Keep an active warning visible while the user continues the same typing
    // burst. It is cleared by Fix, Dismiss, navigation, or a new app window.
    // The native UI Automation range is measured in actual text characters,
    // not physical key presses. Some Arabic keys emit more than one character
    // (for example "لا"), so preserve their real character count here.
    _typingBuffer.append(character);
    final boundary = character.trim().isEmpty;
    _trace(
      'decoded="${_escapeDebug(character)}" boundary=$boundary '
      'bufferAfter="${_escapeDebug(_typingBuffer.value)}" '
      'len=${_typingBuffer.length} caretUnits=${_typingBuffer.caretUnitCount} '
      'shouldEvaluate=${_typingBuffer.shouldEvaluate(atWordBoundary: boundary)}',
    );
    if (_typingBuffer.shouldEvaluate(atWordBoundary: boundary)) {
      _evaluateTypingBuffer('length/boundary');
    }

    _detectionPauseTimer?.cancel();
    if (_typingBuffer.length >= 4) {
      _detectionPauseTimer = Timer(const Duration(milliseconds: 900), () {
        if (!_disposed) _evaluateTypingBuffer('pause');
      });
    }
  }

  String _escapeDebug(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('\r', '\\r')
      .replaceAll('\n', '\\n')
      .replaceAll('\t', '\\t');

  void _evaluateTypingBuffer(String trigger) {
    if (_typingBuffer.isEmpty) {
      _trace('evaluate trigger=$trigger skipped: empty buffer');
      return;
    }
    final endsTypingBurst = trigger == 'pause';
    final bufferedText = _typingBuffer.value;
    final hadActiveWarning = _lastDetection != null;
    _typingBuffer.markEvaluated();
    final app = _lastEvent?.processName ?? 'Unknown app';
    final result = DetectionEngine(
      layoutProfile: settings.layoutProfile,
      warningThreshold: _feedbackStats?.warningThresholdFor(app) ?? 0.82,
    ).detect(bufferedText);

    _trace(
      'evaluate trigger=$trigger text="${_escapeDebug(bufferedText)}" '
      'len=${bufferedText.length} app="$app" '
      'result=${result == null ? 'null' : '${(result.confidence * 100).round()}% '
                'warn=${result.shouldWarn} suggestion="${_escapeDebug(result.suggestion)}" '
                'language=${result.suggestedLanguage.name} reason="${result.reason}" '
                'threshold=${(result.warningThreshold * 100).round()}%'} '
      'activeBefore=${_lastDetection != null}',
    );

    if (result == null) {
      if (endsTypingBurst) _typingBuffer.reset();
      return;
    }

    final percent = (result.confidence * 100).round();
    // Only treat this as a *new* mistake (bump the streak, pick a fresh
    // personality message) the first time this warning becomes active.
    // Re-evaluating the same ongoing warning on every subsequent keystroke
    // must not re-trigger either, or the streak inflates within seconds of
    // continuous typing and the popup message changes on every character.
    final isNewWarning = result.shouldWarn && !hadActiveWarning;
    if (isNewWarning) {
      final now = DateTime.now();
      if (_lastMistakeTime != null &&
          now.difference(_lastMistakeTime!) < const Duration(seconds: 90)) {
        _consecutiveMistakeStreak++;
      } else {
        _consecutiveMistakeStreak = 1;
      }
      _trace(
        'warning state updated selectionUnits=$_warningSelectionUnits '
        'trailingUnits=$_warningTrailingUnits popupSuggestion="${_escapeDebug(result.suggestion)}"',
      );
      _lastMistakeTime = now;
    }
    final funnyTitle = isNewWarning || _lastWarningTitle == null
        ? TunisianPersonality.getMessage(
            mode: settings.personalityMode,
            suggestedLanguage: result.suggestedLanguage,
            typedLength: bufferedText.length,
            streak: _consecutiveMistakeStreak,
          )
        : _lastWarningTitle!;
    _addDebugMessage(
      'Phase 3 detector ($trigger): $percent% confidence, ${result.shouldWarn ? 'warning' : 'no warning'}',
    );

    // Once a warning has been shown, keep it actionable while the user
    // finishes typing. The score can dip as more words are added, but the
    // converted suggestion and selection range must continue to grow.
    if (result.shouldWarn || hadActiveWarning) {
      _lastDetection = result;
      _lastWarningTitle = funnyTitle;
      _warningApp = app;
      _warningSelectionUnits = _typingBuffer.contentCaretUnitCount;
      _warningTrailingUnits = _typingBuffer.trailingCaretUnitCount;
    }
    notifyListeners();
    if (endsTypingBurst && (!result.shouldWarn && _lastDetection == null)) {
      _detectionPauseTimer?.cancel();
      _typingBuffer.reset();
    }
    if (result.shouldWarn || hadActiveWarning) {
      _trace(
        'popup refresh requested activeBefore=$hadActiveWarning '
        'currentWarning=${result.shouldWarn} suggestionLength=${result.suggestion.length}',
      );

      _hook
          .showWarningPopup(
            title: funnyTitle,
            suggestion: result.suggestion,
            confidence: percent,
          )
          .then((shown) {
            _trace('popup update completed shown=$shown');
            if (_disposed || shown) return;
            _addDebugMessage('Phase 4 popup could not be shown');
            notifyListeners();
          })
          .catchError((Object error) {
            if (_disposed) return;
            _addDebugMessage('Phase 4 popup error: $error');
            notifyListeners();
          });
    }
  }

  Future<void> _correctSelection({
    DetectionResult? detection,
    int selectionUnits = 0,
    int trailingUnits = 0,
  }) async {
    // A failed attempt here means the detected text can never be corrected
    // by retrying with the same stale detection (the app/window/caret has
    // already moved on) — so on any failure below, drop the dead detection
    // state instead of leaving it stuck, or the next real mistake won't get
    // a fresh popup.
    void giveUpOnDetection(String debugMessage, String userMessage) {
      _addDebugMessage(debugMessage);
      if (detection != null) {
        _invalidateActiveWarning();
        _detectionPauseTimer?.cancel();
        _typingBuffer.reset();
      }
      if (!_disposed) onShowMessage?.call(userMessage);
    }

    try {
      final selected = detection == null
          ? await _hook.captureSelection()
          : await _hook.captureDetectedText(
              expected: detection.original,
              selectionUnits: selectionUnits,
              trailingUnits: trailingUnits,
            );
      if (selected.isEmpty) {
        giveUpOnDetection(
          '2/7 Correction refused: no matching text selection found',
          "Baddel couldn't find the exact text to fix — make sure the app is still focused and try again.",
        );
        return;
      }
      if (detection != null && selected != detection.original) {
        giveUpOnDetection(
          '2/7 Correction refused: selected text did not match the detected phrase',
          "Baddel couldn't safely select the exact text to fix — try selecting it manually.",
        );
        return;
      }
      _addDebugMessage(
        '2/7 Selection text returned to Flutter (${selected.length} chars)',
      );
      notifyListeners();
      final hasArabic = RegExp(r'[؀-ۿ]').hasMatch(selected);
      final direction = hasArabic
          ? LayoutDirection.arabicToUs
          : LayoutDirection.usToArabic;
      final replacement = KeyboardLayout.convert(selected, direction);
      _addDebugMessage(
        '3/7 Converted using ${hasArabic ? 'Arabic → US' : 'US → Arabic'} (${replacement.length} chars)',
      );
      notifyListeners();
      final pasted = await _hook.pasteReplacement(replacement);

      if (pasted && !_disposed) {
        await _feedbackStats?.recordFix(_warningApp);
        _lastDetection = null;
        _lastWarningTitle = null;
        notifyListeners();
      }
      if (!pasted && !_disposed) {
        giveUpOnDetection(
          '2/7 Correction refused: paste failed',
          'Baddel could not replace the selection.',
        );
      }
    } on PlatformException catch (error) {
      final userMessage = error.code == 'DETECTION_CHANGED'
          ? "You switched apps before Baddel could fix that, so the warning was cleared."
          : (error.message ?? 'No text selection found.');
      giveUpOnDetection('2/7 Correction refused: ${error.message}', userMessage);
    }
  }

  Future<void> toggleHook() async {
    _error = null;
    notifyListeners();
    try {
      if (_isRunning) {
        await _hook.stop();
        if (!_disposed) {
          _isRunning = false;
          notifyListeners();
        }
      } else {
        final started = await _hook.start();
        if (!_disposed) {
          _isRunning = started;
          notifyListeners();
        }
      }
    } catch (error) {
      if (!_disposed) {
        _error = '$error';
        notifyListeners();
      }
    }
  }

  Future<void> setContentionTestMode(bool enabled) async {
    await _hook.setClipboardRestoreDelay(
      Duration(milliseconds: enabled ? 2000 : 200),
    );
    if (!_disposed) {
      _contentionTestMode = enabled;
      notifyListeners();
    }
  }

  Future<void> setDetectionPaused(bool paused) async {
    _detectionPauseTimer?.cancel();
    _typingBuffer.reset();
    if (paused) await _hook.hideWarningPopup();

    if (_disposed) return;
    await settings.setDetectionPaused(paused);
    if (_disposed) return;
    _detectionPaused = paused;
    _lastDetection = null;
    _lastWarningTitle = null;
    _addDebugMessage(
      paused ? 'Phase 4 detection paused' : 'Phase 4 detection resumed',
    );
    notifyListeners();
    if (enableDesktopShell) await _updateTrayMenu();
  }

  Future<void> setAppDetectionEnabled(String processName, bool enabled) async {
    await settings.setAppDetectionEnabled(processName, enabled);
    if (_disposed) return;

    _addDebugMessage(
      'Detection ${enabled ? 'enabled' : 'disabled'} for $processName',
    );
    notifyListeners();
  }

  void runTestConversion(String text) {
    if (text.isEmpty) {
      _testConvertedOutput = '';
      notifyListeners();
      return;
    }
    final hasArabic = RegExp(r'[؀-ۿ]').hasMatch(text);
    final direction = hasArabic
        ? LayoutDirection.arabicToUs
        : LayoutDirection.usToArabic;
    final converted = KeyboardLayout.convert(text, direction);
    _testConvertedOutput = converted;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    testInputController.dispose();
    _subscription?.cancel();
    _manualFixSubscription?.cancel();
    _debugSubscription?.cancel();
    _warningActionSubscription?.cancel();
    _detectionPauseTimer?.cancel();
    _hook.dispose();
    super.dispose();
  }
}
