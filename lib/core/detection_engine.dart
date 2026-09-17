import 'keyboard_layout.dart';

enum SuggestedLanguage { english, arabic }

/// Shared with [DetectionEngine.warningThreshold] so the two defaults can't
/// drift apart.
const double defaultWarningThreshold = 0.82;

class DetectionResult {
  const DetectionResult({
    required this.original,
    required this.suggestion,
    required this.suggestedLanguage,
    required this.confidence,
    required this.reason,
    this.warningThreshold = defaultWarningThreshold,
  });

  final String original;
  final String suggestion;
  final SuggestedLanguage suggestedLanguage;
  final double confidence;
  final String reason;
  final double warningThreshold;

  // Keep the warning threshold conservative so ordinary names, brand words,
  // and short messages are less likely to produce an unwanted popup.
  bool get shouldWarn => confidence >= warningThreshold;
}

class DetectionEngine {
  const DetectionEngine({
    this.layoutProfile = KeyboardLayoutProfile.usQwerty,
    this.warningThreshold = defaultWarningThreshold,
  });

  final KeyboardLayoutProfile layoutProfile;
  final double warningThreshold;

  // Sentence-shape gate (_scoreEnglish): a run of text is only treated as a
  // deliberate English sentence, rather than a coincidence, once it clears
  // all three of these bars.
  static const int _sentenceShapeMinWords = 4;
  static const double _sentenceShapeEnglishRatio = 0.8;
  static const int _sentenceShapeMinConnectors = 1;
  // Confidence floor applied once text is confirmed to have English
  // sentence shape, or a clear-enough phrase shape despite dictionary
  // misses (see _score) — never let either case score below this.
  static const double _clearPhraseFloor = 0.84;

  // _looksLikeEnglishWord: a word needs at least one vowel but not an
  // implausibly vowel-heavy ratio, and no implausible run of consonants, to
  // look like real English.
  static const double _vowelRatioMax = 2 / 3;
  static const int _consonantRunLength = 5;

  // _score: dictionary/bigram weighting and the boosts applied when most or
  // all words are recognized.
  static const double _dictionaryWeight = 0.55;
  static const double _bigramWeight = 0.1;
  static const double _exactWordBoost = 0.35;
  static const int _nearCompleteMinKnownWords = 3;
  static const double _nearCompleteDictionaryRatio = 0.75;
  static const double _nearCompleteBoost = 0.35;
  static const int _toleranceMinWords = 4;
  static const int _toleranceMinKnownWords = 3;
  static const double _toleranceMinDictionaryRatio = 0.6;
  static const double _scoreClampMax = 0.99;

  // _isKnownWord: fuzzy (edit-distance) matching only applies to words long
  // enough that a one-letter typo is meaningfully distinguishable from a
  // different short word.
  static const int _fuzzyMinWordLength = 4;
  static const int _fuzzyMaxEditDistance = 1;

  static const Set<String> _englishWords = {
    'a',
    'and',
    'are',
    'baddel',
    'change',
    'clipboard',
    'code',
    'correct',
    'english',
    'forgot',
    'good',
    'hello',
    'here',
    'i',
    'in',
    'is',
    'it',
    'keyboard',
    'language',
    'my',
    'name',
    'of',
    'test',
    'text',
    'the',
    'this',
    'to',
    'we',
    'word',
    'work',
    'working',
    'write',
    'you',
    'your',
  };

  static const Set<String> _arabicWords = {
    'أنا',
    'اختبار',
    'اكتب',
    'اللغة',
    'السلام',
    'العربية',
    'على',
    'في',
    'كلمة',
    'لغة',
    'لوحة',
    'مرحبا',
    'مفاتيح',
    'من',
    'نسي',
    'نسيت',
    'هذا',
    'هذه',
    'هو',
    'هي',
    'يا',
  };

  static const Set<String> _englishBigrams = {
    'th',
    'he',
    'in',
    'er',
    'an',
    're',
    'on',
    'at',
    'en',
    'nd',
    'ti',
    'es',
    'or',
    'te',
    'of',
    'ed',
    'is',
    'it',
    'al',
    'ar',
    'st',
    'to',
    'nt',
    'ng',
    'se',
    'ha',
    'as',
    'ou',
    'io',
    'le',
    've',
    'co',
    'me',
    'de',
    'hi',
    'ri',
    'ro',
    'ic',
    'ne',
    'ea',
    'ra',
    'ce',
    'li',
    'ch',
  };

  static const Set<String> _arabicBigrams = {
    'ال',
    'لل',
    'في',
    'من',
    'عل',
    'ية',
    'ات',
    'ان',
    'ها',
    'ون',
    'ين',
    'ما',
    'لا',
    'با',
    'مر',
    'رح',
    'حب',
    'ذا',
    'هو',
    'كل',
    'لم',
  };

  static const Set<String> _shortEnglishWords = {'go', 'hi', 'no', 'ok', 'yes'};

  static const Set<String> _shortArabicWords = {
    '\u0641\u064a', // fi
    '\u0645\u0646', // min
    '\u0647\u0648', // houwa
    '\u0647\u064a', // hiya
    '\u064a\u0627', // ya
  };

  DetectionResult? detect(String input) {
    final text = input.trim();
    if (text.length < 2) return null;

    final arabicCount = RegExp(r'[\u0600-\u06ff]').allMatches(text).length;
    final latinCount = RegExp(r'[A-Za-z]').allMatches(text).length;
    if (arabicCount == 0 && latinCount == 0) return null;
    if (arabicCount > 0 && latinCount > 0) return null;

    // Tunisian Arabizi uses Latin letters and digits (3, 5, 7, 9) on
    // purpose. It should not be interpreted as a mistyped Arabic layout.
    if (latinCount > 0 && _looksLikeTunisianArabizi(text)) {
      return _noWarning(
        text,
        SuggestedLanguage.arabic,
        'Tunisian Arabizi is already using the intended Latin layout',
      );
    }

    if (arabicCount > latinCount) {
      final suggestion = KeyboardLayout.convertForProfile(
        text,
        LayoutDirection.arabicToUs,
        layoutProfile,
      );
      final score = _scoreEnglish(suggestion);
      return DetectionResult(
        original: text,
        suggestion: suggestion,
        suggestedLanguage: SuggestedLanguage.english,
        confidence: score,
        reason: 'Arabic-layout keys resemble English words',
        warningThreshold: warningThreshold,
      );
    }

    final suggestion = KeyboardLayout.convertForProfile(
      text,
      LayoutDirection.usToArabic,
      layoutProfile,
    );
    final score = _scoreArabic(suggestion);
    return DetectionResult(
      original: text,
      suggestion: suggestion,
      suggestedLanguage: SuggestedLanguage.arabic,
      confidence: score,
      reason: 'English-layout keys resemble Arabic words',
      warningThreshold: warningThreshold,
    );
  }

  double _scoreEnglish(String text) {
    final words = RegExp(
      r'[A-Za-z]+',
    ).allMatches(text.toLowerCase()).map((match) => match.group(0)!).toList();
    final score = _score(words, {
      ..._englishWords,
      ..._shortEnglishWords,
    }, _englishBigrams);
    // A small dictionary is useful for precision, but it must not be the
    // deciding factor for every real sentence. Wrong-layout text preserves
    // spaces, word boundaries, and the spelling shape of English even when
    // names or ordinary words are absent from our local word list.
    //
    // Require both an English-looking sentence and at least one connector
    // word (for example "to", "you", "in", or "i") to avoid warning on
    // arbitrary Arabic text that happens to convert to Latin characters.
    final englishLikeWords = words.where(_looksLikeEnglishWord).length;
    final connectorWords = words.where(_isEnglishConnector).length;
    final hasEnglishSentenceShape =
        words.length >= _sentenceShapeMinWords &&
        englishLikeWords / words.length >= _sentenceShapeEnglishRatio &&
        connectorWords >= _sentenceShapeMinConnectors;
    if (hasEnglishSentenceShape && score < _clearPhraseFloor) {
      return _clearPhraseFloor;
    }
    return score;
  }

  bool _looksLikeEnglishWord(String word) {
    if (word.length < 2) return word == 'i' || _shortEnglishWords.contains(word);
    final vowels = RegExp(r'[aeiouy]').allMatches(word).length;
    if (vowels == 0 || vowels / word.length > _vowelRatioMax) return false;
    // Five consecutive consonants are unusual in ordinary English words but
    // common in random layout conversions.
    return !RegExp('[^aeiouy]{$_consonantRunLength,}').hasMatch(word);
  }

  bool _isEnglishConnector(String word) => const {
    'a', 'and', 'are', 'i', 'im', 'in', 'is', 'it', 'my', 'of', 'the',
    'this', 'to', 'we', 'you', 'your',
  }.contains(word);

  double _scoreArabic(String text) {
    final words = RegExp(
      r'[\u0600-\u06ff]+',
    ).allMatches(text).map((match) => match.group(0)!).toList();
    return _score(words, {
      ..._arabicWords,
      ..._shortArabicWords,
    }, _arabicBigrams);
  }

  double _score(
    List<String> words,
    Set<String> dictionary,
    Set<String> bigrams,
  ) {
    if (words.isEmpty) return 0;
    final knownWords = words
        .where((word) => _isKnownWord(word, dictionary))
        .length;
    final dictionaryScore = knownWords / words.length;

    final letters = words.join();
    var bigramMatches = 0;
    var bigramCount = 0;
    for (var index = 0; index + 1 < letters.length; index++) {
      bigramCount++;
      if (bigrams.contains(letters.substring(index, index + 2))) {
        bigramMatches++;
      }
    }
    final bigramScore = bigramCount == 0 ? 0.0 : bigramMatches / bigramCount;
    // Exact short words need a meaningful score; the old /2 divisor made
    // useful inputs such as "hi" and Arabic "في" impossible to detect.
    final exactWordBoost = knownWords == words.length
        ? _exactWordBoost
        : 0.0;
    // Names and new words are often absent from the dictionary. If nearly
    // every token around one such word is known, keep the phrase detectable.
    final nearCompleteBoost =
        knownWords >= _nearCompleteMinKnownWords &&
            dictionaryScore >= _nearCompleteDictionaryRatio
        ? _nearCompleteBoost
        : 0.0;
    final score =
        dictionaryScore * _dictionaryWeight +
        bigramScore * _bigramWeight +
        (exactWordBoost > nearCompleteBoost
            ? exactWordBoost
            : nearCompleteBoost);
    // A wrong keyboard layout often comes with one accidental physical key
    // press, and names are deliberately absent from this small dictionary.
    // Do not make a clear sentence invisible just because one or two tokens
    // are imperfect: "hello mny name is maher" still has a very clear shape.
    final hasClearPhraseDespiteErrors =
        words.length >= _toleranceMinWords &&
        knownWords >= _toleranceMinKnownWords &&
        dictionaryScore >= _toleranceMinDictionaryRatio;
    final toleratedScore = hasClearPhraseDespiteErrors && score < _clearPhraseFloor
        ? _clearPhraseFloor
        : score;
    return toleratedScore.clamp(0.0, _scoreClampMax);
  }

  bool _isKnownWord(String word, Set<String> dictionary) {
    if (dictionary.contains(word)) return true;
    // A single wrong physical key should not hide an otherwise very clear
    // layout mistake. Only apply fuzzy matching to useful-length words so
    // short names and abbreviations do not trigger warnings accidentally.
    if (word.length < _fuzzyMinWordLength) return false;
    return dictionary.any(
      (candidate) =>
          candidate.length >= _fuzzyMinWordLength &&
          _editDistance(word, candidate) <= _fuzzyMaxEditDistance,
    );
  }

  int _editDistance(String left, String right) {
    final previous = List<int>.generate(right.length + 1, (index) => index);
    for (var i = 1; i <= left.length; i++) {
      var diagonal = previous[0];
      previous[0] = i;
      for (var j = 1; j <= right.length; j++) {
        final above = previous[j];
        final cost = left[i - 1] == right[j - 1] ? 0 : 1;
        previous[j] = [
          previous[j] + 1,
          previous[j - 1] + 1,
          diagonal + cost,
        ].reduce((a, b) => a < b ? a : b);
        diagonal = above;
      }
    }
    return previous[right.length];
  }

  bool _looksLikeTunisianArabizi(String text) {
    final lower = text.toLowerCase();
    if (RegExp(r'[3579]').hasMatch(lower)) return true;
    final words = RegExp(r'[a-z]+').allMatches(lower).map((m) => m.group(0)!);
    const markers = {
      'w',
      'ya',
      'ena',
      'ani',
      'chnowa',
      '3lech',
      'ma5demch',
      'mrigel',
      'barsha',
      'behi',
      'sbeh',
    };
    return words.any(markers.contains);
  }

  DetectionResult _noWarning(
    String text,
    SuggestedLanguage language,
    String reason,
  ) {
    return DetectionResult(
      original: text,
      suggestion: text,
      suggestedLanguage: language,
      confidence: 0,
      reason: reason,
    );
  }
}
