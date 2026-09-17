class TypingBuffer {
  TypingBuffer({this.maxLength = 1000});

  final int maxLength;
  String _value = '';
  final List<String> _caretUnits = [];
  int _lastEvaluatedLength = 0;

  String get value => _value;
  int get length => _value.length;
  bool get isEmpty => _value.isEmpty;
  int get caretUnitCount => _caretUnits.length;
  int get trailingCaretUnitCount {
    var count = 0;
    for (var index = _caretUnits.length - 1; index >= 0; index--) {
      if (_caretUnits[index].trim().isNotEmpty) break;
      count++;
    }
    return count;
  }

  int get contentCaretUnitCount => caretUnitCount - trailingCaretUnitCount;

  void append(String text, {bool asSingleCaretUnit = false}) {
    if (text.isEmpty) return;
    _value += text;
    _caretUnits.addAll(asSingleCaretUnit ? [text] : text.split(''));
    if (_value.length > maxLength) {
      var excessLength = _value.length - maxLength;
      var removedCount = 0;
      var removedLength = 0;
      while (removedLength < excessLength && removedCount < _caretUnits.length) {
        removedLength += _caretUnits[removedCount].length;
        removedCount++;
      }
      _caretUnits.removeRange(0, removedCount);
      _value = _value.substring(removedLength);
    }
  }

  void backspace() {
    if (_caretUnits.isEmpty) return;
    final removed = _caretUnits.removeLast();
    _value = _value.substring(0, _value.length - removed.length);
    if (_lastEvaluatedLength > _value.length) {
      _lastEvaluatedLength = _value.length;
    }
  }

  bool shouldEvaluate({required bool atWordBoundary}) {
    if (_value.length >= 12 && _value.length > _lastEvaluatedLength) {
      return true;
    }
    return atWordBoundary &&
        _value.trim().length >= 5 &&
        _value.length > _lastEvaluatedLength;
  }

  void markEvaluated() => _lastEvaluatedLength = _value.length;

  void reset() {
    _value = '';
    _caretUnits.clear();
    _lastEvaluatedLength = 0;
  }
}
