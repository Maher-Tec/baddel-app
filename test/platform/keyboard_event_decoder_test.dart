import 'package:flutter_test/flutter_test.dart';

import 'package:badeli/platform/keyboard_event_decoder.dart';
import 'package:badeli/platform/keyboard_hook.dart';

KeyboardHookEvent event(int virtualKey, {bool control = false}) {
  return KeyboardHookEvent(
    virtualKey: virtualKey,
    scanCode: 0,
    flags: 0,
    time: 0,
    foregroundWindow: 1,
    processName: 'code.exe',
    languageId: 0,
    keyDown: true,
    injected: false,
    controlDown: control,
    altDown: false,
    shiftDown: false,
  );
}

void main() {
  test('navigation and shortcut keys reset the typing buffer', () {
    expect(KeyboardEventDecoder.resetsBuffer(event(0x25)), isTrue);
    expect(KeyboardEventDecoder.resetsBuffer(event(0x24)), isTrue);
    expect(
      KeyboardEventDecoder.resetsBuffer(event(0x41, control: true)),
      isTrue,
    );
    expect(KeyboardEventDecoder.resetsBuffer(event(0x41)), isFalse);
  });
}
