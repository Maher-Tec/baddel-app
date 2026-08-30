import 'keyboard_layout.dart';

enum SuggestedLanguage { english, arabic }

class DetectionResult {
  const DetectionResult({
    required this.original,
    required this.suggestion,
    required this.suggestedLanguage,
    required this.confidence,
    required this.reason,
  });

  final String original;
  final String suggestion;
  final SuggestedLanguage suggestedLanguage;
  final double confidence;
  final String reason;

  bool get shouldWarn => confidence >= 0.72;
}

class DetectionEngine {
  const DetectionEngine();

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

  DetectionResult? detect(String input) {
    final text = input.trim();
    if (text.length < 4) return null;

    final arabicCount = RegExp(r'[\u0600-\u06ff]').allMatches(text).length;
    final latinCount = RegExp(r'[A-Za-z]').allMatches(text).length;
    if (arabicCount == 0 && latinCount == 0) return null;
    if (arabicCount > 0 && latinCount > 0) return null;

    if (arabicCount > latinCount) {
      final suggestion = KeyboardLayout.convert(
        text,
        LayoutDirection.arabicToUs,
      );
      final score = _scoreEnglish(suggestion);
      return DetectionResult(
        original: text,
        suggestion: suggestion,
        suggestedLanguage: SuggestedLanguage.english,
        confidence: score,
        reason: 'Arabic-layout keys resemble English words',
      );
    }

    final suggestion = KeyboardLayout.convert(text, LayoutDirection.usToArabic);
    final score = _scoreArabic(suggestion);
    return DetectionResult(
      original: text,
      suggestion: suggestion,
      suggestedLanguage: SuggestedLanguage.arabic,
      confidence: score,
      reason: 'English-layout keys resemble Arabic words',
    );
  }

  double _scoreEnglish(String text) {
    final words = RegExp(
      r'[A-Za-z]+',
    ).allMatches(text.toLowerCase()).map((match) => match.group(0)!).toList();
    return _score(words, _englishWords, _englishBigrams);
  }

  double _scoreArabic(String text) {
    final words = RegExp(
      r'[\u0600-\u06ff]+',
    ).allMatches(text).map((match) => match.group(0)!).toList();
    return _score(words, _arabicWords, _arabicBigrams);
  }

  double _score(
    List<String> words,
    Set<String> dictionary,
    Set<String> bigrams,
  ) {
    if (words.isEmpty) return 0;
    final knownWords = words.where(dictionary.contains).length;
    final dictionaryScore = (knownWords / 2).clamp(0.0, 1.0);

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
    final score = dictionaryScore * 0.7 + bigramScore * 0.3;
    return score.clamp(0.0, 0.99);
  }
}
