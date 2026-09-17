import 'package:flutter_test/flutter_test.dart';

import 'package:badeli/core/typing_buffer.dart';

void main() {
  test('evaluates at a word boundary after five characters', () {
    final buffer = TypingBuffer();
    buffer.append('abcde');

    expect(buffer.shouldEvaluate(atWordBoundary: false), isFalse);
    buffer.append(' ');
    expect(buffer.shouldEvaluate(atWordBoundary: true), isTrue);
  });

  test('evaluates at twelve characters without a boundary', () {
    final buffer = TypingBuffer();
    buffer.append('abcdefghijkl');

    expect(buffer.shouldEvaluate(atWordBoundary: false), isTrue);
  });

  test('supports backspace, reset, and the privacy memory cap', () {
    final buffer = TypingBuffer(maxLength: 5);
    buffer.append('123456');
    expect(buffer.value, '23456');

    buffer.backspace();
    expect(buffer.value, '2345');

    buffer.reset();
    expect(buffer.isEmpty, isTrue);
  });

  test('tracks real text characters for a multi-character keyboard key', () {
    final buffer = TypingBuffer();
    buffer.append('لا');
    buffer.append('م');
    buffer.append(' ');

    expect(buffer.value, 'لام ');
    expect(buffer.contentCaretUnitCount, 3);
    expect(buffer.trailingCaretUnitCount, 1);

    buffer.backspace();
    expect(buffer.value, 'لام');
    expect(buffer.caretUnitCount, 3);
  });
}
