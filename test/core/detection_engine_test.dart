import 'package:flutter_test/flutter_test.dart';

import 'package:badeli/core/detection_engine.dart';
import 'package:badeli/core/keyboard_layout.dart';

void main() {
  const detector = DetectionEngine();

  test('detects English typed while the Arabic layout is active', () {
    const intended = 'hello this is code';
    final typed = KeyboardLayout.convert(intended, LayoutDirection.usToArabic);

    final result = detector.detect(typed);

    expect(result, isNotNull);
    expect(result!.shouldWarn, isTrue);
    expect(result.suggestedLanguage, SuggestedLanguage.english);
    expect(result.suggestion, intended);
  });

  test('detects a clear phrase when one converted word has a typo', () {
    final typed = KeyboardLayout.convert(
      'herllo my name is maher',
      LayoutDirection.usToArabic,
    );

    final result = detector.detect(typed);

    expect(result, isNotNull);
    expect(result!.shouldWarn, isTrue);
    expect(result.suggestion, 'herllo my name is maher');
  });

  test('warns for a clear phrase with a short typo and an unknown name', () {
    const intended = 'hello mny name is maher';
    final typed = KeyboardLayout.convert(intended, LayoutDirection.usToArabic);

    final result = detector.detect(typed);

    expect(result, isNotNull);
    expect(result!.shouldWarn, isTrue);
    expect(result.confidence, greaterThanOrEqualTo(0.82));
    expect(result.suggestion, intended);
  });

  test('warns again for a new common phrase after a correction', () {
    const intended = 'nothing apear next i mean';
    final typed = KeyboardLayout.convert(intended, LayoutDirection.usToArabic);

    final result = detector.detect(typed);

    expect(result, isNotNull);
    expect(result!.shouldWarn, isTrue);
    expect(result.suggestion, intended);
  });

  test('warns for a common follow-up phrase with small typos', () {
    const intended = 'im so happy to have you in mmy lige';
    final typed = KeyboardLayout.convert(intended, LayoutDirection.usToArabic);

    final result = detector.detect(typed);

    expect(result, isNotNull);
    expect(result!.shouldWarn, isTrue);
    expect(result.suggestion, intended);
  });

  test('detects Arabic typed while the English layout is active', () {
    const intended = 'مرحبا في من';
    final typed = KeyboardLayout.convert(intended, LayoutDirection.arabicToUs);

    final result = detector.detect(typed);

    expect(result, isNotNull);
    expect(result!.shouldWarn, isTrue);
    expect(result.suggestedLanguage, SuggestedLanguage.arabic);
    expect(result.suggestion, intended);
  });

  test('does not warn on ordinary English', () {
    final result = detector.detect('hello this is code');

    expect(result, isNotNull);
    expect(result!.shouldWarn, isFalse);
  });

  test('does not warn on Tunisian Franco-Arabic developer chat', () {
    final result = detector.detect('3lech flutter ma5demch');

    expect(result, isNotNull);
    expect(result!.shouldWarn, isFalse);
  });

  test('detects a short English phrase in the wrong layout', () {
    final typed = KeyboardLayout.convert('hi', LayoutDirection.usToArabic);

    final result = detector.detect(typed);

    expect(result, isNotNull);
    expect(result!.shouldWarn, isTrue);
    expect(result.suggestion, 'hi');
  });

  test('detects a short Arabic phrase in the wrong layout', () {
    const intended = '\u0641\u064a';
    final typed = KeyboardLayout.convert(intended, LayoutDirection.arabicToUs);

    final result = detector.detect(typed);

    expect(result, isNotNull);
    expect(result!.shouldWarn, isTrue);
    expect(result.suggestion, intended);
  });

  test('does not warn on Tunisian Arabizi with numeric consonants', () {
    final result = detector.detect('3lech ma5demch');

    expect(result, isNotNull);
    expect(result!.shouldWarn, isFalse);
    expect(result.reason, contains('Arabizi'));
  });
}
