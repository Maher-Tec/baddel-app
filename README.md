<p align="center">
  <img src="assets/logo/logo.png" width="180" alt="Baddel logo" />
</p>

<h1 align="center">Baddel!</h1>

<p align="center">A free, open-source, privacy-first keyboard layout helper for Windows.</p>

<p align="center">
  <a href="https://github.com/Maher-Tec/baddel-app/releases/latest/download/BaddelSetup.exe"><strong>⬇ Download BaddelSetup.exe</strong></a> ·
  <a href="https://github.com/Maher-Tec/baddel-app/releases/latest">All releases</a> ·
  <a href="https://github.com/Maher-Tec/baddel-app/actions/workflows/windows-ci.yml">Build status</a> ·
  <a href="#license">License</a>
</p>

<p align="center">
  <img alt="Windows CI" src="https://github.com/Maher-Tec/baddel-app/actions/workflows/windows-ci.yml/badge.svg" />
  <img alt="Latest release" src="https://img.shields.io/github/v/release/Maher-Tec/baddel-app" />
  <img alt="License" src="https://img.shields.io/badge/license-MIT-blue.svg" />
</p>

---

## What is Baddel?

Everyone who types in more than one language on the same keyboard knows this moment: you start typing, look up, and see `ndrf hgd` instead of `مرحبا` — because your keyboard was still set to the wrong language. Baddel watches for exactly that pattern and offers a one-click fix, entirely on your own machine.

**Example:** you meant to type `مرحبا` in Arabic, but your Windows keyboard layout was still set to English, so what actually landed on screen was `ndrf`. Baddel recognizes that `ndrf` is what `مرحبا` looks like when typed on the wrong layout, pops up a small correction popup, and replaces it for you with one click (or `Ctrl+Alt+B`) — no need to select the text, switch layout, and retype it yourself.

Baddel currently detects mismatches between **English (US QWERTY)** and **Arabic** layouts, with light support for Tunisian Arabizi (`3lech`, `ma5demch`, …) so it doesn't wrongly flag that as a mistake.

## Install in 30 seconds

1. **[Download BaddelSetup.exe](https://github.com/Maher-Tec/baddel-app/releases/latest/download/BaddelSetup.exe)** — always the latest release.
2. Run the installer and launch Baddel.
3. During onboarding, choose your keyboard layout and which apps Baddel should watch.
4. Keep typing normally — Baddel only speaks up when it's confident you hit the wrong layout.

Prefer to verify the build yourself first? Every version is built and tested in public via [GitHub Actions](https://github.com/Maher-Tec/baddel-app/actions/workflows/windows-ci.yml), and you can also [build from source](#build-from-source) below.

## Features

- Detects Arabic-layout and English-layout typing mistakes as you type.
- Supports US QWERTY and French AZERTY physical layouts.
- Recognizes Tunisian Arabizi patterns (`3lech`, `ma5demch`, …) and leaves them alone.
- One-click popup correction, or manual correction with `Ctrl+Alt+B`.
- `Ctrl+Alt+Z` safely undoes the most recent Baddel correction.
- Per-application enable/disable — pick exactly which apps Baddel watches.
- Four Tunisian-flavored personality modes for the warning messages, if you want some humor with your corrections.
- Local-only feedback stats (how many fixes/dismissals, by app) shown on your own dashboard.
- Silent, non-blocking update check against the GitHub release manifest — never phones home with your text.

## Supported applications

| Application | Default behavior |
| --- | --- |
| Notepad | Automatic detection enabled |
| Google Chrome | Automatic detection enabled |
| Microsoft Word | Automatic detection enabled |
| WordPad | Automatic detection enabled |
| VS Code | Manual correction only |
| Windows Terminal | Manual correction only |

Add any other app from the dashboard. Password managers and remote desktop apps (Bitwarden, 1Password, KeePass, LastPass, `mstsc.exe`) are always excluded and cannot be re-enabled, so Baddel never reads what you type into them.

## Privacy

- All detection runs **locally, in memory** — nothing is ever uploaded.
- Baddel does **not** store the text it analyzes or corrects.
- The optional feedback log stores only: which action you took (fix/dismiss), the app name, and a timestamp — never the text itself. Entries older than 90 days are deleted automatically.
- The only network call Baddel makes is a silent check against the public GitHub release manifest to see if a newer version exists.

## How it works (for contributors)

Baddel is a small pipeline, entry point at [`lib/main.dart`](lib/main.dart):

```text
Windows low-level keyboard hook (C++, windows/runner/flutter_window.cpp)
        │  raw key events, decoded per-app keyboard layout
        ▼
TypingBuffer (lib/core/typing_buffer.dart)
        │  accumulates recent keystrokes into a rolling text window
        ▼
DetectionEngine (lib/core/detection_engine.dart)
        │  converts the buffer through the other layout's key map
        │  (lib/core/keyboard_layout.dart) and scores it against a small
        │  dictionary + bigram model to decide if it looks like a real
        │  word/phrase that just landed in the wrong alphabet
        ▼
TunisianPersonality (lib/core/personality.dart)
        │  picks a warning message/tone for the popup
        ▼
Native warning popup + one-click paste replacement
   (windows/runner/warning_popup.cpp, flutter_window.cpp)
```

Project layout:

| Path | What's there |
| --- | --- |
| `lib/core/` | Pure-Dart detection logic: typing buffer, layout conversion, scoring, personality messages, feedback stats. No Flutter/UI imports — easy to unit test. |
| `lib/platform/` | Dart-side bridge to the native keyboard hook (method/event channels). |
| `lib/screens/`, `lib/widgets/` | The dashboard UI: `DashboardController` owns state and native calls, the UI widgets under `lib/widgets/dashboard/` are presentation-only. |
| `lib/settings/` | Persisted user settings (`AppSettings`) — target apps, personality mode, layout profile. |
| `windows/runner/` | The native Windows glue: the low-level keyboard hook, clipboard/paste replacement, UI Automation-based text selection, and the warning popup window. |
| `test/` | Dart unit/widget tests, mirroring the `lib/` structure. |

If you want to change the detection heuristics, `lib/core/detection_engine.dart` is fully unit-tested and has no platform dependencies — a good first place to experiment. If you want to change how corrections are applied on screen, that logic lives in `windows/runner/flutter_window.cpp`.

## Build from source

Requirements:

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (see `environment.sdk` in `pubspec.yaml` for the required version)
- Windows 10/11
- Visual Studio 2022 with the "Desktop development with C++" workload

```powershell
git clone https://github.com/Maher-Tec/baddel-app.git
cd baddel-app
flutter pub get
flutter test
flutter analyze
flutter run -d windows
```

Build a standalone Windows release:

```powershell
flutter build windows --release
```

The output is created in `build/windows/x64/runner/Release` (ship the whole folder — `badeli.exe` needs its sibling `.dll` files alongside it).

## Contributing

Issues and pull requests are welcome.

- Run `flutter analyze` and `flutter test` before opening a PR — both must be clean; CI enforces this too.
- Keep `lib/core/` free of Flutter/UI/platform imports so it stays trivially testable.
- For anything touching `windows/runner/*.cpp` (the keyboard hook, clipboard, or UI Automation code), please explain the manual testing you did in the PR description — this code injects synthetic input and reads other apps' clipboards, so it's worth extra care and it's hard to cover with automated tests.
- Small, focused PRs are easier to review than large ones.

## CI and releases

Every push or pull request to `master` runs `flutter analyze`, `flutter test`, and a Windows release build through [GitHub Actions](.github/workflows/windows-ci.yml). Successful builds are uploaded as downloadable workflow artifacts even without a tagged release.

Pushing a tag matching `v*` additionally builds the Inno Setup installer and publishes it as a [GitHub Release](https://github.com/Maher-Tec/baddel-app/releases) automatically:

```powershell
git tag vX.Y.Z
git push origin vX.Y.Z
```

Remember to update [`version.json`](version.json) and the `version:` field in `pubspec.yaml` to match before tagging — the app's in-app update check reads `version.json` from `master`.

## License

MIT License — see [LICENSE](LICENSE). Free to use, modify, and redistribute.
