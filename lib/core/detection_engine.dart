import 'keyboard_layout.dart';

enum SuggestedLanguage { english, arabic }

class DetectionResult {
  const DetectionResult({
    required this.original,
    required this.suggestion,
    required this.suggestedLanguage,
    required this.confidence,
    required this.reason,
    this.warningThreshold = 0.82,
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
    this.warningThreshold = 0.82,
  });

  final KeyboardLayoutProfile layoutProfile;
  final double warningThreshold;

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
    return _score(words, {..._englishWords, ..._shortEnglishWords}, _englishBigrams);
  }

  double _scoreArabic(String text) {
    final words = RegExp(
      r'[\u0600-\u06ff]+',
    ).allMatches(text).map((match) => match.group(0)!).toList();
    return _score(words, {..._arabicWords, ..._shortArabicWords}, _arabicBigrams);
  }

  double _score(
    List<String> words,
    Set<String> dictionary,
    Set<String> bigrams,
  ) {
    if (words.isEmpty) return 0;
    final knownWords = words.where(dictionary.contains).length;
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
    final exactWordBoost = knownWords == words.length ? 0.35 : 0.0;
    final score = dictionaryScore * 0.55 + bigramScore * 0.1 + exactWordBoost;
    return score.clamp(0.0, 0.99);
  }

  bool _looksLikeTunisianArabizi(String text) {
    final lower = text.toLowerCase();
    if (RegExp(r'[3579]').hasMatch(lower)) return true;
    final words = RegExp(r'[a-z]+').allMatches(lower).map((m) => m.group(0)!);
    const markers = {
      'w', 'ya', 'ena', 'ani', 'chnowa', '3lech', 'ma5demch', 'mrigel',
      'barsha', 'behi', 'sbeh',
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
