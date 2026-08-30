#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/method_channel.h>
#include <flutter/flutter_view_controller.h>

#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "win32_window.h"
#include "keyboard_hook.h"
#include "warning_popup.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  struct ClipboardFormatSnapshot {
    UINT format;
    std::vector<unsigned char> bytes;
  };

  std::optional<std::wstring> CaptureSelectedText();
  std::optional<std::wstring> CaptureDetectedText(
      const std::wstring& expected, int selection_units, int trailing_units);
  bool AcceptDetectedSelection(const std::wstring& selected,
                               const std::wstring& expected);
  bool RevalidateSelectionBeforePaste();
  bool PasteReplacement(const std::string& replacement);
  bool UndoLastCorrection();
  void ClearLastCorrection();
  bool SaveClipboardSnapshot();
  void RestoreClipboardSnapshot(bool respect_contention = false);
  void ClearClipboardSnapshot();
  void EmitDebug(const std::string& message);

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  KeyboardHook keyboard_hook_;
  WarningPopup warning_popup_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      keyboard_channel_;
  std::optional<std::wstring> original_clipboard_text_;
  bool original_clipboard_had_text_ = false;
  std::vector<ClipboardFormatSnapshot> original_clipboard_formats_;
  bool clipboard_snapshot_available_ = false;
  DWORD replacement_clipboard_sequence_ = 0;
  DWORD clipboard_restore_delay_ms_ = 200;
  std::string last_capture_status_ = "Idle";
  HWND last_foreground_window_ = nullptr;
  std::optional<std::wstring> captured_selection_text_;
  std::wstring detected_selection_prefix_;
  std::wstring detected_selection_suffix_;
  std::optional<std::wstring> last_correction_original_;
  std::optional<std::wstring> last_correction_replacement_;
  HWND last_correction_window_ = nullptr;
  ULONGLONG last_correction_time_ = 0;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
