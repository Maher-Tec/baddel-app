# Baddel! — بدّل — Technical Spec v2

Revised after review. Three changes matter most and reshape everything else: (1) automatic text replacement is now its own feasibility question, not an assumed mechanism; (2) privacy is now an architectural rule, not a limitation we note and move past; (3) phases are reordered so Windows integration is proven *before* any detection-engine work, so we don't tune Arabic bigrams for days only to discover the OS integration needs a redesign.

---
## 1. Architecture spine (define this before writing any phase's code)

```
InputSource → TypingBuffer → DetectionEngine → CorrectionService
```

- **InputSource**: anything that emits keystroke/focus events. Starts as the Dart/FFI hook (Option A); can be swapped for the native-helper client (Option B, see §2) without touching anything downstream.
- **TypingBuffer**: per-focused-window rolling buffer + chunking logic (§5). Consumes InputSource events, emits "evaluate this chunk" events.
- **DetectionEngine**: pure function of a chunk → confidence + suggested correction. No side effects, no OS calls — trivially testable (§8).
- **CorrectionService**: the *only* component allowed to touch the OS to read/replace text. Everything upstream is OS-agnostic.

Keeping `CorrectionService` as a single, isolated boundary is what makes §3 (the safe-replacement redesign) contained — nothing else in the pipeline needs to know or care how replacement actually happens.

---

## 2. Hook architecture (unchanged from v1, still Option A → Option B)

`WH_KEYBOARD_LL` needs a real Win32 message loop; Dart FFI callbacks are latency-sensitive and Windows will silently unhook a slow callback. Try pure Flutter/`win32` FFI first (Option A); fall back to a thin native C#/C++ helper over a local named pipe/socket (Option B) only if Phase 0 shows instability or input lag. This decision doesn't change based on the rest of the revisions below.

---

## 3. 🔴 Correction mechanism — redesigned (was the biggest risk)

**Problem with v1:** `Ctrl+Shift+Home` selects to the start of the document/field, not "the last N characters" — and repeated-Backspace assumes the tracked buffer still matches the real document state, which breaks the moment the user moves the cursor, clicks elsewhere, uses autocomplete, undoes something, or selects text manually. None of that is safe to assume.

**Redesign: split correction into two genuinely different features, not one mechanism with two triggers.**

### 3a. Manual correction (V1, low risk — build this first)
User selects the wrong-layout text themselves (they know exactly what's wrong), presses the hotkey. `CorrectionService` does the clipboard round-trip (§6) on the **existing selection** — no tracking, no assumptions, no invalidation logic needed. This is the whole of Phase 2.

### 3b. Automatic correction (needs its own feasibility spike — Phase 5, not assumed)
Only attempt automatic replacement when we can *prove* the document context hasn't changed since detection:

- `CorrectionService` snapshots a **correction token** at detection time: the chunk text, its length, the foreground `hwnd`, and (where available via UI Automation / `IAccessible`) the caret position and control ID.
- Before executing "Fix," re-validate the token: same `hwnd` still foreground, same control still focused, and — where obtainable — caret position is consistent with "the chunk is still exactly what's immediately before the caret." If *any* of these fail, or if the required info isn't obtainable for that app, **refuse to auto-correct** and fall back to: highlight/notify the user to select the text manually and use the Phase 2 hotkey instead.
- This means auto-fix will not work in every app in V1 — that's fine. Ship it as "auto-fix where we can safely verify context, manual hotkey everywhere else," and say so in the UI rather than silently risking a bad replacement.
- Investigate Windows **UI Automation (UIA)** (`IUIAutomation` COM interface) as the safer path to get real caret/selection info in apps that support it, instead of inferring from keystroke counts. This is worth a dedicated 1-2 day spike before committing to Phase 5's design.

### 3c. Undo safety net (new, added to V1 scope)
Whenever `CorrectionService` performs any replacement (manual or automatic), it should:
- Rely on the fact that the replacement happens via a real simulated `Ctrl+V`, which most apps register as one undo-able action — so native `Ctrl+Z` should already undo it in well-behaved apps. **Verify this per target app in testing** (§8); don't assume it universally.
  - As a backstop, `CorrectionService` may keep its own last-correction snapshot (pre-correction text plus a revalidatable correction context) and expose an explicit **"Undo last Baddel correction"** action from the tray/popup. This fallback is available only while that context can still be safely revalidated: same target window/control, compatible caret or selection state where obtainable, and no intervening edit that could make the original location ambiguous. If the context cannot be revalidated, do not attempt position tracking or a guessed restore; rely on native `Ctrl+Z` and report that the explicit fallback is unavailable.

---

## 4. 🔴 Privacy — now an architectural rule, not a noted limitation

Hard rules, enforced in code review / tests, not just documentation:
- **Never persist raw keystrokes or buffer contents to disk**, in any build configuration, including debug/logging builds shipped to anyone outside the dev machine.
- **Never transmit buffer contents over any network interface** — V1 has no backend, so this should be true by construction, but keep it true as a standing rule if V2 ever adds cloud features.
- **No production logging of buffer contents.** Debug logging during development is fine but must be compiled out (or feature-flagged off) in release builds — enforce with a lint/test that greps release builds for accidental `print(buffer...)` calls.
- `TypingBuffer` contents live in memory only and are cleared on: reset (§5), app quit, and sleep/lock (clear on `WM_WTSSESSION_CHANGE` lock event, so nothing lingers in memory across a lock screen).

**Onboarding screen (new, add to Phase 6):**
```
🔒 Baddel works locally

Nothing you type is uploaded.
Nothing you type is stored.
Detection can be paused anytime.
Apps can be excluded.
```
Shown on first run, and reachable later from settings — this matters a lot if the project goes public on GitHub, since "background keystroke observer" is technically a keylogger's shape even though the purpose is benign, and being upfront about it is both the right call and good trust-building marketing.

---

## 5. 🟠 Exclusions — defaults changed

- **Default-excluded** (can't accidentally leave these on): password managers, Remote Desktop (`mstsc.exe`), other explicitly security-sensitive apps.
- **Terminals/IDEs (`cmd.exe`, `powershell.exe`, `WindowsTerminal.exe`, VS Code, etc.) are no longer default-excluded** — this is exactly the audience that code-switches AR/EN constantly and where detection is genuinely useful.
- Instead: **automatic popup detection is off by default in terminal/IDE processes** (configurable per-app in settings), while the **manual correction hotkey remains available everywhere**, including terminals. This avoids interrupting someone mid-command with a false positive on `ls`, `cd`, variable names, etc., while still letting them fix a genuinely wrong-layout line on demand.

---

## 6. Text capture & replacement mechanism (clipboard round-trip — unchanged mechanics, now scoped to §3a/3b)

```
1. Save current clipboard contents (text + format) to restore later.
2. For manual mode: operate on the existing user selection directly.
   For automatic mode: only proceed if the correction token (§3b) is
   still valid; otherwise abort and prompt for manual selection instead.
3. Simulate Ctrl+C, read clipboard.
4. Run the AR<->EN remap (§7) on that text.
5. Write corrected text to clipboard, simulate Ctrl+V.
6. Attempt to restore the original clipboard contents after a provisional ~200-300ms delay. Do not assume restoration is always faithful: detect clipboard contention or unsupported formats, preserve the user's current clipboard when restoration would overwrite newer content, and surface a clear failure state for the reliability behavior defined in Phase 0C.
7. Store the pre-correction snapshot for the "Undo last correction" action (§3c).
```

---

## 7. Keyboard mapping table (unchanged from v1 — still needs real-layout verification in Phase 0)

```
US QWERTY key  →  Arabic (101) character
─────────────────────────────────────────
q → ض      w → ص      e → ث      r → ق      t → ف
y → غ      u → ع      i → ه      o → خ      p → ح
[ → ج      ] → د

a → ش      s → س      d → ي      f → ب      g → ل
h → ا      j → ت      k → ن      l → م      ; → ك
' → ط

z → ئ      x → ء      c → ؤ      v → ر      b → لا
n → ى      m → ة      , → و      . → ز      / → ظ
```
Numbers/punctuation stay 1:1 for V1 — only letter keys remap, so URLs/emails/code mid-sentence don't get mangled. The `لا` key (one key → two Arabic characters) needs explicit multi-char handling in the reverse map, not a naive 1:1 inversion.

```dart
const Map<String, String> kUsToArabic = {
  'q': 'ض', 'w': 'ص', 'e': 'ث', 'r': 'ق', 't': 'ف',
  'y': 'غ', 'u': 'ع', 'i': 'ه', 'o': 'خ', 'p': 'ح',
  '[': 'ج', ']': 'د',
  'a': 'ش', 's': 'س', 'd': 'ي', 'f': 'ب', 'g': 'ل',
  'h': 'ا', 'j': 'ت', 'k': 'ن', 'l': 'م', ';': 'ك', "'": 'ط',
  'z': 'ئ', 'x': 'ء', 'c': 'ؤ', 'v': 'ر', 'b': 'لا',
  'n': 'ى', 'm': 'ة', ',': 'و', '.': 'ز', '/': 'ظ',
};
final Map<String, String> kArabicToUs = _invert(kUsToArabic); // handle 'لا' as explicit 2-char case
```

---

## 8. Chunking & trigger logic (unchanged from v1)

- Evaluate when: `length >= 8` + word boundary, OR `length >= 12` regardless, OR 1.5s pause after `length >= 4`.
- Reset unconditionally on Enter/Tab/focus change/submit; cap buffer at ~200 chars, trimming from the front.
- Low confidence → keep accumulating silently. Medium → passive cue only. High → popup, then reset regardless of user choice.

---

## 9. 🟠 Detection engine — same design, now explicitly deferred until after feasibility

The scoring design from v1 stands (dictionary + bigram + script-consistency weighted score, decision by `delta` between as-typed and remapped scores, thresholds from calibration rather than guessed) — but it is **not built until Phase 3**, after Phases 0-2 prove the OS integration and manual-correction path work end to end. See §11 for the reordered phase table and rationale.

### 🟢 Calibration dataset — expanded with Tunisian usage
The v1 plan (~50 real Arabic / ~50 real English / ~50 wrong-layout) undersells what actually needs to be in the set for this specific audience. Add a fourth category: **Tunisian/Franco-Arabic dev chat that should never trigger a false positive**, e.g.:
```
chnowa · bara · behi · hahaha · hhhhh · 3lech · 9adech
cv · salut · inchallah · Flutter · API · NodeJS · npm install
"cv bro 3lech flutter ma5demch 😂"
```
A generic AR/EN dictionary alone would likely flag lines like that as garbage in *both* directions and either misfire or degrade the confidence signal. Getting this category right is plausibly the actual differentiator over generic layout-switchers, more than the personality packs are — worth treating calibration-set size/quality here as core work, not a nice-to-have.

---

## 10. 🟢 Scope discipline (kept exactly as in v1 — reaffirmed, not changed)
No history beyond in-session counters. No cloud, no accounts. AR/EN only. Windows only. Resist adding French/Russian/AI/sync/themes until V1 actually works well end to end.

---

## 11. Reordered phases (feasibility before detection, replacing v1's phase order)

| Phase | Goal | Success condition |
|---|---|---|
| **0 — Feasibility** | Windows keyboard integration (Option A hook) across the explicit target-app set: **Notepad, Chrome, VS Code, Windows Terminal, and Word (or another rich-text editor)** | Stable typing observed in every target app with no perceptible input lag |
| **0B — Conversion** | AR ↔ EN remap correctness | Conversion is deterministic and correct across the calibration set's non-detection cases, including the `لا` edge case |
| **0C — Clipboard reliability spike** | Verify the clipboard save/restore round-trip before building the manual-correction UI | Plain text, formatted text, images, and clipboard contention are handled safely; the original clipboard is restored or failure is surfaced without corrupting user data |
| **1 — Manual Fix** | Select → hotkey → corrected (§3a) | Works reliably across all target apps — **this alone is a shippable, useful app** |
| **2 — Undo safety net** | Verify native undo + build explicit "Undo last correction" fallback (§3c) | Undo works in every target app, one way or the other |
| **3 — Detector** | Confidence engine (§9), calibrated on the expanded dataset | Very low false-positive rate, especially on Tunisian dev-chat examples |
| **4 — Funny popup** | Automatic suggestion UI | Smooth, non-annoying UX; passive/high-confidence tiers behave as designed |
| **5 — Safe auto-fix** | Correction-token validation + auto-replace (§3b), UIA spike included | Cannot corrupt unrelated text; safely no-ops (falls back to manual) when context can't be verified |
| **6 — Product polish** | Tray/settings/personality/exclusions/onboarding privacy screen (§4) | Release-quality |
| **7 — Release** | Installer + GitHub + docs | Someone else can install and use it unaided |

**Key milestone, called out explicitly:** at the end of **Phase 1**, Baddel is already a useful, shippable tool — "select wrong-layout text, hit `Ctrl+Alt+B`, it's fixed" — independent of whether the smarter automatic detection (Phases 3-5) takes longer than expected. Treat Phase 1 as a real release checkpoint, not just an internal milestone.

---

## 12. Testing strategy per phase (updated)

- **Phase 0:** manual checklist across **Notepad, Chrome, VS Code, Windows Terminal, and Word (or another rich-text editor)**; instrument actual hook callback latency (Windows silently disables slow hooks).
- **Phase 0B:** unit tests on `remap()` — multi-char `لا` case, punctuation/digit passthrough, mixed-script input, empty string.
- **Phase 0C:** clipboard reliability spike covering plain text, formatted text, images, and contention from another clipboard writer during save/replace/restore; explicitly verify behavior when the original clipboard cannot be faithfully restored within the provisional 200–300 ms window.
- **Phase 1:** integration test of the manual hotkey → clipboard round-trip across all target apps; explicitly test that unrelated clipboard content is restored correctly.
- **Phase 2:** per-app verification that `Ctrl+Z` undoes a Baddel correction natively; for apps where it doesn't, verify the explicit "Undo last correction" action works.
- **Phase 3:** automated regression test asserting the calibration set's `delta` values land on the correct side of tuned thresholds — including the Tunisian dev-chat subset staying below the trigger threshold.
- **Phase 5:** targeted tests for the correction-token invalidation logic — cursor moved, focus changed, extra keystrokes typed — confirming auto-fix correctly refuses rather than guesses in each case.

---

## 13. Non-goals (unchanged)
No persistent typing history/analytics beyond an in-session counter. No cloud sync, no accounts. AR/EN only. No macOS/Linux. Password-field detection in Chromium/Electron/UWP remains a known, documented V1 gap — mitigated by the (now narrower) default-exclusion list and the fact that automatic correction only fires where context can be safely verified.

---

## 14. Positioning note (kept from review)
Lead with the personality, not the tech: **"Baddel! 😂 You forgot your keyboard again."** — not "AI keyboard corrector." The Tunisian/Arabic humor plus genuine local-privacy story is the actual hook; the detection engine is what makes the joke land reliably, not the headline feature.
