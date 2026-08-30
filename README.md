<p align="center">
  <img src="assets/logo/logo.png" width="180" alt="Baddel Logo" />
  <h1 align="center">🇹🇳 Baddel! (بدّل)</h1>
  <p align="center">
    <strong>Smart Tunisian Keyboard Language Helper & Layout Fixer for Windows</strong>
  </p>
  <p align="center">
    <a href="https://github.com/badeli/baddel/releases"><img src="https://img.shields.io/badge/Download-BaddelSetup.exe-0D9488?style=for-the-badge&logo=windows" alt="Download Windows Installer"></a>
    <img src="https://img.shields.io/badge/Platform-Windows%2010%2F11-0078D4?style=for-the-badge&logo=windows" alt="Windows Support">
    <img src="https://img.shields.io/badge/Privacy-100%25%20Offline-10B981?style=for-the-badge&logo=shield" alt="Privacy First">
  </p>
</p>

---

## 🌟 What is Baddel!?

**Baddel!** is a smart, privacy-first desktop application that monitors your typing in real-time across Windows applications. When it detects that you typed English words on an active Arabic keyboard layout (or vice-versa), it floats a **modern rounded toast overlay** with hilarious Tunisian roasts and offers **1-click automatic layout correction**.

No more deleting paragraphs or rewriting lost thoughts — hit `Ctrl+Alt+B` or click **🚀 Fasakh & Baddel**!

---

## ✨ Features

- **🛡️ 100% Privacy-First Architecture**: Analyzes text strictly in local volatile RAM. **Zero cloud calls**, **zero keylogging**, and **zero files saved**. Sensitive apps (password managers, remote desktops) are automatically excluded.
- **🪟 Modern Floating Toast Overlay**: Sleek Win32 top-level toast window featuring frosted rounded corners, smooth entrance micro-animations, and cute pill action buttons:
  - `[ 🚀 Fasakh & Baddel ]` — Instant automatic replacement
  - `[ 🙈 5allini ]` — Dismiss warning
  - `[ ⏸️ Pause ]` — Temporarily pause detection
- **🇹🇳 4 Authentic Tunisian Humor Banks**:
  - 🌶️ **Weld El Houma (`ولد الحومة`)**: Street banter, louage jokes, coffee roasts, and harissa memes.
  - 💻 **Dev Tanbir (`تنبير ديفلوبور`)**: Developer roasts, Git commits, Docker crashes, and StackOverflow roasts.
  - 😂 **Tunisian Friendly (`فدلاك`)**: Cheerful everyday Tunisian Arabizi and Arabic banter.
  - 👔 **Classic (`رسمي`)**: Polite, direct notifications.
- **🧠 Escalating Patience Engine**: Tracks rapid consecutive typing mistakes. Repeat mistakes escalate Baddel's roast level until it surrenders (*"Baddel! 💀 أنا نستقيل"*).
- **📜 Long-Typing Roasts**: Special roasts triggered when 25+ characters are typed before noticing the layout mismatch (*"Baddel! 💀 Bro wrote the whole README in the wrong layout"*).
- **⌨️ Keyboard Shortcuts**:
  - `Ctrl + Alt + B` — Instant selection capture & conversion
  - `Ctrl + Alt + Z` — Baddel safe fallback undo (restores original text within 2 minutes)
  - `Ctrl + Z` — Native editor undo
- **🎯 In-App Interactive Test Sandbox (`جرّب هوني`)**: Test layout conversions live right inside the app interface.

---

## 📱 Supported Applications

| Application | Category | Auto-Detection Default |
| :--- | :--- | :---: |
| **Notepad** | Plain Text | ✅ Enabled |
| **Google Chrome** | Web Browser | ✅ Enabled |
| **Microsoft Word** | Word Processor | ✅ Enabled |
| **WordPad** | Rich Text | ✅ Enabled |
| **VS Code** | Developer IDE | ⏸️ Manual (Ctrl+Alt+B) |
| **Windows Terminal** | Command Line | ⏸️ Manual (Ctrl+Alt+B) |

---

## 🚀 Quickstart & Installation

### Option 1: Windows Setup Installer (Recommended)
1. Download **[`BaddelSetup.exe`](https://github.com/badeli/baddel/releases/latest)** from the Releases section.
2. Run the installer.
3. Select optional Desktop shortcut and *"Launch Baddel! when Windows starts"* settings.
4. Enjoy smart layout detection!

### Option 2: Build from Source
Requirements: [Flutter SDK](https://flutter.dev), Visual Studio 2022 (C++ Desktop development).

```bash
# Clone the repository
git clone https://github.com/badeli/baddel.git
cd baddel

# Install dependencies & run test suite
flutter pub get
flutter test

# Run in debug mode
flutter run -d windows

# Build standalone release binary
flutter build windows --release
```

---

## 📜 License & Privacy

Distributed under the MIT License. Text analysis is conducted 100% locally on your machine.
