import 'dart:async';

import 'package:flutter/services.dart';

/// A low-level keyboard event received from the Windows runner.
class KeyboardHookEvent {
  const KeyboardHookEvent({
    required this.virtualKey,
    required this.scanCode,
    required this.flags,
    required this.time,
    required this.foregroundWindow,
    required this.processName,
    required this.languageId,
    required this.keyDown,
    required this.injected,
    required this.controlDown,
    required this.altDown,
    required this.shiftDown,
  });

  final int virtualKey;
  final int scanCode;
  final int flags;
  final int time;
  final int foregroundWindow;
  final String processName;
  final int languageId;
  final bool keyDown;
  final bool injected;
  final bool controlDown;
  final bool altDown;
  final bool shiftDown;

  factory KeyboardHookEvent.fromMap(Map<Object?, Object?> map) {
    return KeyboardHookEvent(
      virtualKey: map['virtualKey'] as int,
      scanCode: map['scanCode'] as int,
      flags: map['flags'] as int,
      time: map['time'] as int,
      foregroundWindow: map['foregroundWindow'] as int? ?? 0,
      processName: map['processName'] as String? ?? '',
      languageId: map['languageId'] as int? ?? 0,
      keyDown: map['keyDown'] as bool? ?? true,
      injected: map['injected'] as bool? ?? false,
      controlDown: map['controlDown'] as bool? ?? false,
      altDown: map['altDown'] as bool? ?? false,
      shiftDown: map['shiftDown'] as bool? ?? false,
    );
  }
}

class TargetApps {
  const TargetApps._();

  static const Set<String> processNames = {
    'notepad.exe',
    'chrome.exe',
    'code.exe',
    'windowsterminal.exe',
    'winword.exe',
    'wordpad.exe',
  };

  static bool contains(String processName) =>
      processNames.contains(processName.toLowerCase());
}

/// Flutter-side boundary for the Windows low-level keyboard hook.
class KeyboardHookClient {
  KeyboardHookClient({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('baddel/keyboard_hook') {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  final MethodChannel _channel;
  final StreamController<KeyboardHookEvent> _events =
      StreamController<KeyboardHookEvent>.broadcast();
  final StreamController<void> _manualFixRequests =
      StreamController<void>.broadcast();
  final StreamController<String> _debugMessages =
      StreamController<String>.broadcast();
  final StreamController<String> _warningActions =
      StreamController<String>.broadcast();

  Stream<KeyboardHookEvent> get events => _events.stream;
  Stream<void> get manualFixRequests => _manualFixRequests.stream;
  Stream<String> get debugMessages => _debugMessages.stream;
  Stream<String> get warningActions => _warningActions.stream;

  Future<bool> start() async =>
      await _channel.invokeMethod<bool>('start') ?? false;

  Future<void> stop() => _channel.invokeMethod<void>('stop');

  Future<String> captureSelection() async =>
      await _channel.invokeMethod<String>('captureSelection') ?? '';

  Future<String> captureDetectedText({
    required String expected,
    required int selectionUnits,
    required int trailingUnits,
  }) async =>
      await _channel.invokeMethod<String>('captureDetectedText', {
        'expected': expected,
        'selectionUnits': selectionUnits,
        'trailingUnits': trailingUnits,
      }) ??
      '';

  Future<bool> pasteReplacement(String replacement) async =>
      await _channel.invokeMethod<bool>('pasteReplacement', replacement) ??
      false;

  Future<void> setClipboardRestoreDelay(Duration delay) => _channel
      .invokeMethod<void>('setClipboardRestoreDelay', delay.inMilliseconds);

  Future<bool> showWarningPopup({
    required String suggestion,
    required int confidence,
    String? title,
  }) async =>
      await _channel.invokeMethod<bool>('showWarningPopup', {
        'suggestion': suggestion,
        'confidence': confidence,
        if (title != null) 'title': title,
      }) ??
      false;

  Future<void> hideWarningPopup() =>
      _channel.invokeMethod<void>('hideWarningPopup');

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'keyEvent' && call.arguments is Map) {
      final map = Map<Object?, Object?>.from(call.arguments as Map);
      _events.add(KeyboardHookEvent.fromMap(map));
    } else if (call.method == 'manualFixRequested') {
      _manualFixRequests.add(null);
    } else if (call.method == 'debugMessage' && call.arguments is String) {
      _debugMessages.add(call.arguments as String);
    } else if (call.method == 'warningAction' && call.arguments is String) {
      _warningActions.add(call.arguments as String);
    }
  }

  Future<void> dispose() async {
    await stop();
    await _events.close();
    await _manualFixRequests.close();
    await _debugMessages.close();
    await _warningActions.close();
  }
}
