import 'dart:math';
import 'detection_engine.dart';

enum PersonalityMode {
  weldElHouma,
  devTanbir,
  tunisianFunny,
  classic;

  String get label {
    switch (this) {
      case PersonalityMode.weldElHouma:
        return 'Weld El Houma (🌶️ ولد الحومة)';
      case PersonalityMode.devTanbir:
        return 'Dev Tanbir (💻 تنبير ديفلوبور)';
      case PersonalityMode.tunisianFunny:
        return 'Tunisian Friendly (😂 فدلاك)';
      case PersonalityMode.classic:
        return 'Classic (👔 رسمي)';
    }
  }

  String get description {
    switch (this) {
      case PersonalityMode.weldElHouma:
        return 'Pure street humor, louage jokes, and spicy Tunisian memes';
      case PersonalityMode.devTanbir:
        return 'Coder sarcasm, git/regex roasts, and developer jokes';
      case PersonalityMode.tunisianFunny:
        return 'Friendly, cheerful Tunisian expressions';
      case PersonalityMode.classic:
        return 'Polite and straightforward layout notifications';
    }
  }
}

class TunisianPersonality {
  const TunisianPersonality._();

  static const List<String> _weldElHoumaMessages = [
    'Baddel! 🛵 الكلافيي هرب عليك كيف لواج صفاقس!',
    'Baddel! ☕ صب قهوة، راك دخلت في حيط يا معلم!',
    'Baddel! 😂 حتى الهريسة الحارة ما تعملش هكا في الكلافيي!',
    'Baddel! 🥖 خبز وماء، والكلافيي المقلوب لا!',
    'Baddel! ⚽ شبيك شايط في التوش؟ بدّل اللغة!',
    'Baddel! 🛵 تي بدّل يا ولدي، راك شلّختها!',
    'Baddel! 🇹🇳 الكلافيي شادد قنية وبدّل اللغة!',
    'Baddel! 🤦‍♂️ تي ركّز يهديك، الكلافيي داخل في حيط!',
    'Baddel! 🫖 كاس تاي منعنع وبدّل الكلافيي يرحم والديك!',
    'Baddel! 🚕 تاكسيستي ومانيش مروّح، والكلافيي مقلوب!',
    'Baddel! 🥪 كسكاج لبلابي مريّقل وبدّل الكلافيي!',
    'Baddel! 🏖️ عوّم في الشط وماتعومش في الكلافيي!',
    'Baddel! 🛵 شادد ليسار وتكتب باليمين؟ بدّل اللغة!',
    'Baddel! 🌶️ هريسة عربي في الكلافيي يا معلم!',
    'Baddel! 📢 اسمع كلام عمك وبدّل الكلافيي!',
    'Baddel! 😂 حتى الفريب مافيهوش سلعة كيف هكا!',
    'Baddel! ⚽ ضربة جزاء ضايعة في الكلافيي!',
    'Baddel! 🛵 وين حارق بالكلافيي يا صاحبي؟',
    'Baddel! 😂 تي شنية الكتيبة هاذي يا زين؟',
    'Baddel! 🛵 رد بالك، الكلافيي خارج عالطريق!',
    'Baddel! ☕ قوم اعمل قهوة وارجع جرّب من جديد!',
    'Baddel! 🤦‍♂️ ياخي الكلافيي متاع جاركم؟',
    'Baddel! 😂 آش تعمل يا معلم؟ حلّ عينيك!',
    'Baddel! 🥖 حتى الباقات تفهم أكثر من الكلافيي توا!',
    'Baddel! 🌶️ هريسة زايدة شوية في الكتيبة هاذي!',
    'Baddel! 🚕 يا شوفير بدّل الاتجاه، موش اللغة هاذي!',
    'Baddel! 🚌 الكلافيي هزّك محطة غالطة!',
    'Baddel! 😂 ياخي تكتب وإلا تحل في شفرة؟',
    'Baddel! 🫖 اشرب تاي وعاود شوف شنية عامل!',
    'Baddel! ⚽ VAR قالك اللغة غالطة!',
    'Baddel! 📢 يا ناس شكون يبدلّو الكلافيي؟',
    'Baddel! 🤣 الكلافيي عمل عليك دورة شرفية!',
    'Baddel! 🚦 قف يا معلم، راك ماشي باللغة الغالطة!',
    'Baddel! 🧿 عين وصابت الكلافيي وإلا شنوة؟',
    'Baddel! 😂 تي برا بدّل قبل ما تزيد تفضحنا!',
    'Baddel! 🛵 كلافييك سبقك وإنت مازلت غادي!',
    'Baddel! 🤦 ياخي مخك English وكلافييك عربي؟',
    'Baddel! 😂 شد صحيح، الكلافيي فقد السيطرة!',
    'Baddel! 🏖️ مخك في البحر والكلافيي وحدو يخدم!',
    'Baddel! 🥪 ملا كسكروت حروف عملتو!',
    'Baddel! 🧱 حيط رسمي يا معلم... بدّل!',
    'Baddel! 😂 برا صلّحها قبل ما يشوفها حد!',
  ];

  static const List<String> _devTanbirMessages = [
    'Baddel! 💀 Works on my keyboard.',
    'Baddel! 🐛 Feature or wrong layout?',
    'Baddel! 🚨 KeyboardException: WrongLayout',
    'Baddel! 🔥 Bro deployed the wrong alphabet.',
    'Baddel! 🧑‍💻 LGTM ❌ Baddel first.',
    'Baddel! 💾 Commit rejected: clavier m9aleb.',
    'Baddel! 🐙 GitHub Copilot left the chat.',
    'Baddel! 🤖 Even ChatGPT needs more context for this.',
    'Baddel! 📦 npm ERR! keyboard layout mismatch',
    'Baddel! 🐳 Bro containerized the wrong language.',
    'Baddel! 🔀 git checkout correct-layout',
    'Baddel! 🧠 Brain.dart and Keyboard.dart are out of sync.',
    'Baddel! ⚠️ NullPointerException: brain.layout',
    'Baddel! 🔧 Have you tried turning your clavier off and on again?',
    'Baddel! 🧪 Unit test failed: expected English, got طلاسم.',
    'Baddel! 🚀 Production can wait. Baddel first.',
    'Baddel! 🐛 Cannot reproduce... oh wait, wrong keyboard.',
    'Baddel! 💻 sudo baddel --now',
    'Baddel! 🔄 git reset --hard HEAD~keyboard',
    'Baddel! 📡 200 OK, language still wrong.',
    'Baddel! 🧑‍💻 Your keyboard needs a pull request.',
    'Baddel! 💀 Senior code, junior keyboard.',
    'Baddel! 🧠 Cache cleared. Clavier still m9aleb.',
    'Baddel! 🐍 Python can\'t save you from this one.',
    'Baddel! ☕ One coffee away from switching layouts.',
    'Baddel! 🗄️ SELECT * FROM keyboard WHERE layout = \'correct\';',
    'Baddel! 🔥 Hotfix required: keyboard language.',
    'Baddel! 🧑‍💻 TODO: baddel el clavier.',
    'Baddel! 🧯 This is beyond StackOverflow.',
    'Baddel! 🤖 Copilot suggestion: baddel ya bro.',
    'Baddel! 🫠 Compiler: "ena chda5alni?"',
    'Baddel! 💀 QA rejected this alphabet.',
    'Baddel! 🧪 Expected: English. Actual: يا لطيف.',
    'Baddel! 🖥️ Layer 8 issue detected: clavier.',
    'Baddel! 🐛 Not a bug. Okay... maybe a human bug.',
    'Baddel! 🔁 while (layoutWrong) { baddel(); }',
    'Baddel! 🤖 AI couldn\'t decode your regex... switch layout!',
    'Baddel! 💀 Ctrl+Alt+B is faster than deleting commit history',
    'Baddel! ☕ Git commit -m "fixed keyboard language mistake"',
    'Baddel! 🧠 Segmentation fault in keyboard layout!',
    'Baddel! 🚀 404: Layout Not Found, switch your keyboard!',
  ];

  static const List<String> _funnyArabicActiveMessages = [
    'Baddel! 😂 ياخي تحاول تكتب English بالسحر؟',
    'Baddel! 🤦‍♂️ العربي خدام، والإنقليزي في مخك!',
    'Baddel! 👀 لحظة... إنت تقصد English موش هكا؟',
    'Baddel! 🧩 الحروف هاذم ما ركّبوش يا معلم!',
    'Baddel! 👽 Houston, we have a clavier problem.',
    'Baddel! 😂 Google Translate استقال بعد الكتيبة هاذي.',
    'Baddel! 🪄 هاري بوتر طلب منك التعويذة هاذي.',
    'Baddel! 📜 فكّينا حجر رشيد، أما هاذي صعيبة!',
    'Baddel! 🤣 حتى أنا قريتها مرتين وما فهمت شي!',
    'Baddel! 🧠 مخك English، صوابعك Arabic.',
    'Baddel! 🔤 الحروف صحيحة... اللغة هي اللي غالطة 😂',
    'Baddel! 🤦‍♂️ تي بالراحة، بدّل وبعد كمّل!',
    'Baddel! 😂 راك عامل remix عربي إنقليزي!',
    'Baddel! 🧐 نستدعاو خبير خطوط وإلا تبدّل وحدك؟',
    'Baddel! 👽 NASA قاعدة تحاول تفك الكود متاعك.',
    'Baddel! 🗿 علماء الآثار يحبّوا يعرفوا موقع الكتيبة.',
    'Baddel! 😭 كنت باش نفهمك... وبعد شفت الكلافيي.',
    'Baddel! 😂 Bro invented Arabic 2.0.',
    'Baddel! 🧠 Brain says EN, keyboard says AR.',
    'Baddel! 📡 Signal behi, clavier ghalet.',
    'Baddel! 😂 Rak tiktib bel chinwa ya bro',
    'Baddel! 🤦‍♂️ نسيت الكلافيي يا معلم؟',
    'Baddel! 😅 Ti baddel el langue ya sa7bi',
    'Baddel! 🇹🇳 واش قاعد تخلّض؟ بدّل الكلافيي!',
    'Baddel! 🚀 Clavier 3la 9ad 7alou w enti zedt 3lih',
    'Baddel! 😂 Za3ma chnowa hedha? Baddel el clavier!',
    'Baddel! 🤦 D5alt fi 7it ya m3allem!',
  ];

  static const List<String> _funnyEnglishActiveMessages = [
    'Baddel! 😂 مخك عربي والكلافيي عامل فيها London.',
    'Baddel! 🇬🇧 ياخي الكلافيي هاجر لبريطانيا؟',
    'Baddel! 🤦‍♂️ تحب عربي؟ الكلافيي ما يعرفش!',
    'Baddel! 🧠 Brain says AR, keyboard says EN.',
    'Baddel! 😂 Clavier y7eb ya7ki English bel 9owa.',
    'Baddel! 🫠 Ya bro, Arabic.exe is not running.',
    'Baddel! 🔤 QWERTY شدّك وما حبش يسيبك!',
    'Baddel! 👀 نستناو في العربي... ما جاش.',
    'Baddel! 😂 العربي في عطلة اليوم وإلا شنوة؟',
    'Baddel! 🛫 الكلافيي سافر London وإنت ما في بالكش.',
    'Baddel! 📢 رجّع العربي يا معلم!',
    'Baddel! 🤣 Clavier: English. Brain: تونسي 100%.',
    'Baddel! 🧩 الحروف هاذم موش اللي طلبتهم صوابعك!',
    'Baddel! 🤦‍♂️ بدّل قبل ما تولّي تحكي Shakespeare.',
    'Baddel! ☕ قهوة عربي، كلافيي إنقليزي... اختار موقفك!',
    'Baddel! 😂 حتى QWERTY مستغرب منك.',
    'Baddel! 😂 Clavier fl\'arbi w enti tiktib fl\'anglais?',
    'Baddel! 🇹🇳 بدّل يا معلم راك تكتب بالعربي',
    'Baddel! 🤦‍♂️ Clavier mezelt nassih fl\'arbi!',
    'Baddel! 😅 Chbina d5alna fi chanti ya bro?',
    'Baddel! ☕ برا بدّل الكلافيي وارجع اخدم',
    'Baddel! 🇹🇳 بدّل اللغة يهديك، الكلافيي مازال بالعربي',
  ];

  static const List<String> _funnyGeneralMessages = [
    'Baddel! 😂 يا معلم ركّز!',
    'Baddel! 👀 Clavier check!',
    'Baddel! 🤦 Wrong way, sa7bi!',
    'Baddel! 🔄 بدّل وكمّل!',
    'Baddel! 😂 Clavier m9aleb!',
    'Baddel! 🧠 Brain ≠ Keyboard',
    'Baddel! 🚨 Clavier alert!',
    'Baddel! 😭 موش هكا يا غالي!',
    'Baddel! 👀 Fi9 bel clavier!',
    'Baddel! 😂 Ya bro... seriously?',
    'Baddel! 🔤 Wrong alphabet, sa7bi!',
    'Baddel! 🤌 تي بدّل!',
    'Baddel! 🫠 Again?!',
    'Baddel! 😂 عاودناها؟',
    'Baddel! 🚦 Stop. Baddel. Continue.',
    'Baddel! ⚡ ثانيتين وبدّل!',
    'Baddel! 🤦‍♂️ Clavier ya weldi!',
    'Baddel! 😎 Baddel w kamel.',
  ];

  static const List<String> _longTypingMessages = [
    'Baddel! 💀 يا معلم كتبت باراغراف كامل وما فقتش؟! 😂',
    'Baddel! 😂 وصلت للفصل الثاني والكلافيي مازال غالط!',
    'Baddel! 📚 رواية باهية، أما باللغة الغالطة!',
    'Baddel! 🤦‍♂️ توة بعد الكتيبة هاذي الكل فقت؟',
    'Baddel! 🏆 مبروك! Record جديد في الكلافيي المقلوب.',
    'Baddel! 💀 Bro wrote the whole README in the wrong layout.',
    'Baddel! 🧑‍💻 47 characters later... wrong layout detected.',
    'Baddel! 😂 الكلافيي عطاك برشا فرص باش تفيق.',
    'Baddel! 📜 حتى أنا تعبت وأنا نتفرج فيك تكتب.',
    'Baddel! 🤣 ياخي ناوي تكمل الكتاب قبل ما تبدّل؟',
    'Baddel! 🫡 Respect. You committed to the wrong layout.',
    'Baddel! 💀 At this point just publish it.',
    'Baddel! 🧠 Your brain noticed 3 business days later.',
    'Baddel! 📰 Breaking news: user finally notices keyboard.',
  ];

  static const List<String> _escalationLevel2Messages = [
    'Baddel! 😂 عاودناها؟',
    'Baddel! 🫠 Again?! Fi9 ya bro!',
    'Baddel! 👀 ماك لتوة ما بدلتش الكلافيي؟',
    'Baddel! 🤦‍♂️ رانا في نفس الحكاية يا معلم!',
    'Baddel! 🔁 while (true) { ghalet(); }',
  ];

  static const List<String> _escalationLevel3Messages = [
    'Baddel! 🤦‍♂️ يا معلم حكينا في الموضوع هذا!',
    'Baddel! 💀 تي صوابعك مبرمجين هكا ولا بالعاني؟',
    'Baddel! 📢 رانا للمرة الثالثة نبهو فيك!',
    'Baddel! 🔥 Stop. Look at your keyboard.',
    'Baddel! 😭 مخي حبس وأنا نتبع فيك!',
  ];

  static const List<String> _escalationLevel4Messages = [
    'Baddel! 💀 أنا نستقيل.',
    'Baddel! 🪦 الله يرحم الكلافيي.',
    'Baddel! 🚑 اطلبوا الإسعاف للكلافيي!',
    'Baddel! 🤖 Process killed: user is hopeless.',
    'Baddel! 🏳️ رفعت الراية البيضاء.',
  ];

  static const List<String> _classicMessages = [
    'Baddel! You forgot your keyboard language',
    'Baddel! بدّل لغة لوحة المفاتيح',
    'Baddel! Check your active keyboard layout',
    'Baddel! Layout switch suggested',
    'Baddel! Language mismatch detected',
    'Baddel! Switch keyboard language (Ctrl+Alt+B)',
    'Baddel! الرجاء التحقق من لغة الإدخال',
  ];

  static final Random _random = Random();

  /// Gets a varied Tunisian warning message according to personality mode,
  /// mistake streak level, and typing burst length.
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

    // Long typing roast (30+ chars typed in wrong layout)
    if (typedLength >= 25 && (mode == PersonalityMode.weldElHouma || mode == PersonalityMode.devTanbir || mode == PersonalityMode.tunisianFunny)) {
      return _pick(_longTypingMessages, indexSeed);
    }

    // Escalating patience system when user repeats mistakes rapidly
    if (streak >= 4) {
      return _pick(_escalationLevel4Messages, indexSeed);
    } else if (streak == 3) {
      return _pick(_escalationLevel3Messages, indexSeed);
    } else if (streak == 2) {
      return _pick(_escalationLevel2Messages, indexSeed);
    }

    switch (mode) {
      case PersonalityMode.weldElHouma:
        return _pick(_weldElHoumaMessages, indexSeed);

      case PersonalityMode.devTanbir:
        return _pick(_devTanbirMessages, indexSeed);

      case PersonalityMode.classic:
        return _pick(_classicMessages, indexSeed);

      case PersonalityMode.tunisianFunny:
        if (suggestedLanguage == SuggestedLanguage.english) {
          // User typed Arabic keys intending English
          return _pick(_funnyArabicActiveMessages, indexSeed);
        } else if (suggestedLanguage == SuggestedLanguage.arabic) {
          // User typed English keys intending Arabic
          return _pick(_funnyEnglishActiveMessages, indexSeed);
        }
        return _pick(_funnyGeneralMessages, indexSeed);
    }
  }

  static String _pick(List<String> list, int? seed) {
    if (list.isEmpty) return 'Baddel! 😂 بدّل الكلافيي!';
    if (seed != null) {
      return list[seed.abs() % list.length];
    }
    return list[_random.nextInt(list.length)];
  }
}
