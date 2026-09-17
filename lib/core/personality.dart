import 'dart:math';

import 'detection_engine.dart';

enum PersonalityMode {
  weldElHouma,
  devTanbir,
  tunisianFunny,
  classic;

  String get label => switch (this) {
    PersonalityMode.weldElHouma => 'Weld El Houma 🌶️',
    PersonalityMode.devTanbir => 'Dev Tanbir 💻',
    PersonalityMode.tunisianFunny => 'Tunisian Friendly 😄',
    PersonalityMode.classic => 'Classic 🔔',
  };

  String get description => switch (this) {
    PersonalityMode.weldElHouma => 'Spicy Tunisian street humor',
    PersonalityMode.devTanbir => 'Coder jokes and developer roasts',
    PersonalityMode.tunisianFunny => 'Warm and cheerful Tunisian expressions',
    PersonalityMode.classic => 'Simple, polite notifications',
  };
}

class TunisianPersonality {
  const TunisianPersonality._();

  static const _weldElHoumaMessages = [
    'Baddel! 🌶️ الكلافي هرب عليك يا معلّم!',
    'Baddel! ☕ صب قهوة وبدّل اللغة يا صاحبي.',
    'Baddel! 😂 حتى الهريسة ما تعملش هكّا في الكلافي!',
    'Baddel! 🚕 الكلافي شدّ طريق غالطة.',
  ];

  static const _devTanbirMessages = [
    'Baddel! 💻 Works on my keyboard… after switching the layout.',
    'Baddel! 🐛 KeyboardException: WrongLayout',
    'Baddel! 🚀 Production can wait. Switch the keyboard first.',
    'Baddel! 🤖 Copilot suggests: baddel ya bro.',
  ];

  static const _englishSuggestionMessages = [
    'Baddel! 😄 تحاول تكتب English بالسحر؟',
    'Baddel! 👀 Your brain says English, the keyboard says Arabic.',
    'Baddel! 🧩 الحروف صحيحة، اللغة هي الغالطة.',
  ];

  static const _arabicSuggestionMessages = [
    'Baddel! 😄 مخّك عربي والكلافي English.',
    'Baddel! 👀 العربية تستنّى فيك تبدّل اللغة.',
    'Baddel! 🔤 QWERTY دخل في الحيط يا صاحبي.',
  ];

  static const _friendlyMessages = [
    'Baddel! 😊 بدّل اللغة وكمّل مرتاح.',
    'Baddel! 👋 Clavier check يا صاحبي!',
    'Baddel! 🔄 Wrong layout—one click fixes it.',
  ];

  static const _classicMessages = [
    'Baddel! Your keyboard language may be incorrect.',
    'Baddel! Check your active keyboard layout.',
    'Baddel! Language mismatch detected.',
  ];

  static const _longTypingMessages = [
    'Baddel! 📖 Bro wrote the whole README in the wrong layout.',
    'Baddel! 🏆 Respect—you committed to the wrong layout.',
    'Baddel! 📰 Breaking news: the keyboard language is still wrong.',
  ];

  static const _level2Messages = [
    'Baddel! 🔁 عاودناها؟ بدّل اللغة يا صاحبي.',
    'Baddel! 😅 Again? One quick switch and you are good.',
  ];

  static const _level3Messages = [
    'Baddel! 🫠 حكينا في الموضوع هذا يا معلّم.',
    'Baddel! 🛑 Stop, look at the keyboard language.',
  ];

  static const _level4Messages = [
    'Baddel! 🏳️ أنا نستقيل… بدّلها وحدك توّا.',
    'Baddel! 😭 The keyboard has officially won.',
  ];

  static final Random _random = Random();

  static String getMessage({
    PersonalityMode mode = PersonalityMode.weldElHouma,
    SuggestedLanguage? suggestedLanguage,
    int typedLength = 0,
    int streak = 1,
    int? indexSeed,
  }) {
    if (mode == PersonalityMode.classic) {
      return _pick(_classicMessages, indexSeed);
    }
    if (typedLength >= 25) return _pick(_longTypingMessages, indexSeed);
    if (streak >= 4) return _pick(_level4Messages, indexSeed);
    if (streak == 3) return _pick(_level3Messages, indexSeed);
    if (streak == 2) return _pick(_level2Messages, indexSeed);

    return switch (mode) {
      PersonalityMode.weldElHouma => _pick(_weldElHoumaMessages, indexSeed),
      PersonalityMode.devTanbir => _pick(_devTanbirMessages, indexSeed),
      PersonalityMode.tunisianFunny
          when suggestedLanguage == SuggestedLanguage.english =>
        _pick(_englishSuggestionMessages, indexSeed),
      PersonalityMode.tunisianFunny
          when suggestedLanguage == SuggestedLanguage.arabic =>
        _pick(_arabicSuggestionMessages, indexSeed),
      PersonalityMode.tunisianFunny => _pick(_friendlyMessages, indexSeed),
      PersonalityMode.classic => _pick(_classicMessages, indexSeed),
    };
  }

  static String _pick(List<String> messages, int? seed) {
    if (seed != null) return messages[seed.abs() % messages.length];
    return messages[_random.nextInt(messages.length)];
  }
}
