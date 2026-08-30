import '../core/keyboard_layout.dart';
import 'keyboard_hook.dart';

class KeyboardEventDecoder {
  const KeyboardEventDecoder._();

  static const int backspaceKey = 0x08;
  static const int tabKey = 0x09;
  static const int enterKey = 0x0D;
  static const int escapeKey = 0x1B;
  static const int pageUpKey = 0x21;
  static const int pageDownKey = 0x22;
  static const int endKey = 0x23;
  static const int homeKey = 0x24;
  static const int leftKey = 0x25;
  static const int upKey = 0x26;
  static const int rightKey = 0x27;
  static const int downKey = 0x28;
  static const int insertKey = 0x2D;
  static const int deleteKey = 0x2E;

  static bool isBackspace(KeyboardHookEvent event) =>
      event.virtualKey == backspaceKey;

  static bool resetsBuffer(KeyboardHookEvent event) =>
      event.controlDown ||
      event.altDown ||
      event.virtualKey == tabKey ||
      event.virtualKey == enterKey ||
      event.virtualKey == escapeKey ||
      (event.virtualKey >= pageUpKey && event.virtualKey <= downKey) ||
      event.virtualKey == insertKey ||
      event.virtualKey == deleteKey;

  static String? decode(KeyboardHookEvent event) {
    if (!event.keyDown ||
        event.injected ||
        event.controlDown ||
        event.altDown) {
      return null;
    }

    final key = _usKey(event.virtualKey);
    if (key == null) return null;
    if (!_isArabicLanguage(event.languageId)) return key;
    return KeyboardLayout.convert(key, LayoutDirection.usToArabic);
  }

  static bool _isArabicLanguage(int languageId) =>
      (languageId & 0x03ff) == 0x01;

  static String? _usKey(int virtualKey) {
    if (virtualKey >= 0x41 && virtualKey <= 0x5A) {
      return String.fromCharCode(virtualKey + 0x20);
    }
    if (virtualKey >= 0x30 && virtualKey <= 0x39) {
      return String.fromCharCode(virtualKey);
    }
    return const {
      0x20: ' ',
      0xBA: ';',
      0xBC: ',',
      0xBD: '-',
      0xBE: '.',
      0xBF: '/',
      0xBB: '=',
      0xDB: '[',
      0xDD: ']',
      0xDE: "'",
    }[virtualKey];
  }
}
