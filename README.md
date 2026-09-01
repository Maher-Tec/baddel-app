<p align="center">
  <img src="assets/logo/logo.png" width="180" alt="Baddel logo" />
</p>

<h1 align="center">Baddel!</h1>

<p align="center">Privacy-first Arabic and English keyboard layout helper for Windows.</p>

<p align="center">
  <a href="https://github.com/Maher-Tec/baddel-app/releases/latest">Download</a> ·
  <a href="https://github.com/Maher-Tec/baddel-app/actions/workflows/windows-ci.yml">CI builds</a>
</p>

## What is Baddel?

Baddel detects when text was typed with the wrong keyboard layout and offers a one-click correction. It works locally on Windows and includes Tunisian personality modes for its warning messages.

## Install in 30 seconds

1. Open the [latest release](https://github.com/Maher-Tec/baddel-app/releases/latest).
2. Download `BaddelSetup.exe`.
3. Run the installer and launch Baddel.
4. Choose the apps Baddel should monitor during onboarding.

If no installer is attached yet, use the Windows build artifact from the [CI Actions page](https://github.com/Maher-Tec/baddel-app/actions).

## Features

- Detects Arabic-layout and English-layout typing mistakes.
- Supports US QWERTY and French AZERTY profiles.
- Handles short phrases and common Tunisian Arabizi patterns such as `3lech` and `ma5demch`.
- Provides one-click popup correction and manual `Ctrl + Alt + B` correction.
- Includes `Ctrl + Alt + Z` safe undo for recent Baddel replacements.
- Supports per-application enable/disable controls.
- Includes four Tunisian personality modes.
- Shows local feedback statistics for fixes and dismissed warnings.
- Runs a silent, non-blocking update check against the GitHub release manifest.

## Supported applications

| Application | Default behavior |
| --- | --- |
| Notepad | Automatic detection enabled |
| Google Chrome | Automatic detection enabled |
| Microsoft Word | Automatic detection enabled |
| WordPad | Automatic detection enabled |
| VS Code | Manual correction only |
| Windows Terminal | Manual correction only |

More applications can be added from the dashboard. Password managers and remote desktop apps remain excluded for safety.

## Privacy

Baddel analyzes text locally in memory and never uploads typed content. It does not store the text being corrected. The optional feedback loop stores only action metadata (fix or dismissal), application name, and timestamp locally so the dashboard can show statistics. Records older than 90 days are removed.

## Build from source

Requirements:

- Flutter SDK
- Windows 10/11
- Visual Studio 2022 with Desktop development with C++

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

The output is created in `build/windows/x64/runner/Release`.

## CI and releases

Every push or pull request to `master` runs tests, analysis, and a Windows release build through [GitHub Actions](.github/workflows/windows-ci.yml). Successful builds are uploaded as workflow artifacts.

For a public release:

```powershell
git tag v1.1.0
git push origin v1.1.0
```

Then create a GitHub Release for the tag and attach `BaddelSetup.exe`. Update [version.json](version.json) whenever a newer release is published.

## License

MIT License. See the repository for the full source and license details.
