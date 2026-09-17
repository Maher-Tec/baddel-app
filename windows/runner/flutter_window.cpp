#include "flutter_window.h"

#include <algorithm>
#include <optional>
#include <string>
#include <chrono>
#include <cstring>
#include <cwctype>
#include <thread>
#include <utility>
#include <vector>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <UIAutomation.h>
#include <wrl/client.h>

#include "flutter/generated_plugin_registrant.h"

namespace {
constexpr char kKeyboardChannel[] = "baddel/keyboard_hook";

void DebugLog(const std::string& message) {
  OutputDebugStringA(("Baddel: " + message + "\n").c_str());
}

bool IsExtendedKeyboardKey(WORD virtual_key) {
  switch (virtual_key) {
    case VK_PRIOR:
    case VK_NEXT:
    case VK_END:
    case VK_HOME:
    case VK_LEFT:
    case VK_UP:
    case VK_RIGHT:
    case VK_DOWN:
    case VK_INSERT:
    case VK_DELETE:
      return true;
    default:
      return false;
  }
}

UINT SendKey(WORD virtual_key, bool key_up = false) {
  INPUT input = {};
  input.type = INPUT_KEYBOARD;
  input.ki.wVk = virtual_key;
  input.ki.dwFlags = (key_up ? KEYEVENTF_KEYUP : 0) |
                     (IsExtendedKeyboardKey(virtual_key)
                          ? KEYEVENTF_EXTENDEDKEY
                          : 0);
  return SendInput(1, &input, sizeof(INPUT));
}

bool SendUnicodeText(const std::wstring& text) {
  if (text.empty()) return false;
  std::vector<INPUT> inputs;
  inputs.reserve(text.size() * 2);
  for (const wchar_t character : text) {
    INPUT down = {};
    down.type = INPUT_KEYBOARD;
    down.ki.wScan = character;
    down.ki.dwFlags = KEYEVENTF_UNICODE;
    inputs.push_back(down);

    INPUT up = down;
    up.ki.dwFlags |= KEYEVENTF_KEYUP;
    inputs.push_back(up);
  }
  return SendInput(static_cast<UINT>(inputs.size()), inputs.data(),
                   sizeof(INPUT)) == inputs.size();
}

int CountWords(const std::wstring& text) {
  int count = 0;
  bool inside_word = false;
  for (const wchar_t character : text) {
    if (std::iswspace(character)) {
      inside_word = false;
    } else if (!inside_word) {
      inside_word = true;
      ++count;
    }
  }
  return count;
}

bool OpenClipboardWithRetry(HWND owner, int attempts = 10) {
  for (int attempt = 0; attempt < attempts; ++attempt) {
    if (OpenClipboard(owner)) {
      return true;
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(20));
  }
  return false;
}

std::string ForegroundProcessName(HWND window) {
  if (window == nullptr) {
    return {};
  }

  DWORD process_id = 0;
  GetWindowThreadProcessId(window, &process_id);

  // Check if window is a UWP ApplicationFrameWindow (e.g. WhatsApp Desktop Store App)
  wchar_t class_name[256] = {};
  if (GetClassNameW(window, class_name, 256) > 0) {
    if (std::wstring(class_name) == L"ApplicationFrameWindow") {
      HWND inner_child = FindWindowExW(window, nullptr, L"Windows.UI.Core.CoreWindow", nullptr);
      if (inner_child != nullptr) {
        DWORD inner_pid = 0;
        GetWindowThreadProcessId(inner_child, &inner_pid);
        if (inner_pid != 0) {
          process_id = inner_pid;
        }
      }
    }
  }

  HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE,
                               process_id);
  if (process == nullptr) {
    return {};
  }

  wchar_t path[MAX_PATH];
  DWORD path_length = MAX_PATH;
  const bool succeeded = QueryFullProcessImageNameW(
      process, 0, path, &path_length) != FALSE;
  CloseHandle(process);
  if (!succeeded) {
    return {};
  }

  std::wstring full_path(path, path_length);
  const size_t separator = full_path.find_last_of(L"\\/");
  const std::wstring filename = separator == std::wstring::npos
                                    ? full_path
                                    : full_path.substr(separator + 1);
  if (filename.empty()) {
    return {};
  }

  const int utf8_length = WideCharToMultiByte(
      CP_UTF8, 0, filename.data(), static_cast<int>(filename.size()), nullptr,
      0, nullptr, nullptr);
  if (utf8_length <= 0) {
    return {};
  }

  std::string utf8_name(utf8_length, '\0');
  WideCharToMultiByte(CP_UTF8, 0, filename.data(),
                      static_cast<int>(filename.size()), utf8_name.data(),
                      utf8_length, nullptr, nullptr);
  return utf8_name;
}

std::string WideToUtf8(const std::wstring& value) {
  if (value.empty()) {
    return {};
  }
  const int length = WideCharToMultiByte(
      CP_UTF8, 0, value.data(), static_cast<int>(value.size()), nullptr, 0,
      nullptr, nullptr);
  std::string utf8(length, '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.data(),
                      static_cast<int>(value.size()), utf8.data(), length,
                      nullptr, nullptr);
  return utf8;
}

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) {
    return {};
  }
  const int length = MultiByteToWideChar(
      CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
      static_cast<int>(value.size()), nullptr, 0);
  if (length <= 0) {
    return {};
  }
  std::wstring wide(length, L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                      static_cast<int>(value.size()), wide.data(), length);
  return wide;
}

std::optional<std::wstring> ReadClipboardText() {
  HANDLE unicode_data = GetClipboardData(CF_UNICODETEXT);
  if (unicode_data != nullptr) {
    const auto* text = static_cast<const wchar_t*>(GlobalLock(unicode_data));
    if (text != nullptr) {
      const std::wstring value(text);
      GlobalUnlock(unicode_data);
      return value;
    }
  }

  HANDLE ansi_data = GetClipboardData(CF_TEXT);
  if (ansi_data == nullptr) {
    return std::nullopt;
  }
  const auto* text = static_cast<const char*>(GlobalLock(ansi_data));
  if (text == nullptr) {
    return std::nullopt;
  }
  const int wide_length = MultiByteToWideChar(CP_ACP, 0, text, -1, nullptr, 0);
  std::wstring value(wide_length > 0 ? wide_length : 0, L'\0');
  if (wide_length > 1) {
    MultiByteToWideChar(CP_ACP, 0, text, -1, value.data(), wide_length);
    value.pop_back();
  }
  GlobalUnlock(ansi_data);
  return value;
}

bool IsSafeClipboardSnapshotFormat(UINT format) {
  switch (format) {
    case CF_TEXT:
    case CF_OEMTEXT:
    case CF_UNICODETEXT:
    case CF_LOCALE:
    case CF_DIB:
    case CF_DIBV5:
      return true;
  }

  if (format < 0xC000) {
    return false;
  }

  wchar_t name[128] = {};
  if (GetClipboardFormatNameW(format, name, 128) <= 0) {
    return false;
  }
  const std::wstring format_name(name);
  return format_name == L"Rich Text Format" ||
         format_name == L"HTML Format" || format_name == L"PNG" ||
         format_name == L"image/png";
}

enum class UiAutomationSelectionResult { kUnavailable, kSelected, kFailed };

UiAutomationSelectionResult SelectDetectedRangeWithUiAutomation(
    int selection_units, int trailing_units, const std::wstring& expected,
    std::wstring* selected_text) {
  const HRESULT initialize_result =
      CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  const bool should_uninitialize = SUCCEEDED(initialize_result);
  if (FAILED(initialize_result) && initialize_result != RPC_E_CHANGED_MODE) {
    return UiAutomationSelectionResult::kUnavailable;
  }

  Microsoft::WRL::ComPtr<IUIAutomation> automation;
  Microsoft::WRL::ComPtr<IUIAutomationElement> focused_element;
  Microsoft::WRL::ComPtr<IUnknown> pattern_unknown;
  Microsoft::WRL::ComPtr<IUIAutomationTextPattern2> text_pattern;
  Microsoft::WRL::ComPtr<IUIAutomationTextPattern> legacy_text_pattern;
  Microsoft::WRL::ComPtr<IUIAutomationTextRangeArray> selection_ranges;
  Microsoft::WRL::ComPtr<IUIAutomationTextRange> caret_range;
  Microsoft::WRL::ComPtr<IUIAutomationTextRange> attempt_range;

  const auto finish = [&](UiAutomationSelectionResult selection_result) {
    if (should_uninitialize) CoUninitialize();
    return selection_result;
  };

  HRESULT result = CoCreateInstance(CLSID_CUIAutomation, nullptr,
                                    CLSCTX_INPROC_SERVER,
                                    IID_PPV_ARGS(automation.GetAddressOf()));
  if (FAILED(result) || automation == nullptr) {
    return finish(UiAutomationSelectionResult::kUnavailable);
  }
  result = automation->GetFocusedElement(focused_element.GetAddressOf());
  if (FAILED(result) || focused_element == nullptr) {
    return finish(UiAutomationSelectionResult::kUnavailable);
  }
  result = focused_element->GetCurrentPattern(
      UIA_TextPattern2Id, pattern_unknown.GetAddressOf());
  if (SUCCEEDED(result) && pattern_unknown != nullptr) {
    result = pattern_unknown.As(&text_pattern);
    if (SUCCEEDED(result) && text_pattern != nullptr) {
      BOOL caret_is_active = FALSE;
      result = text_pattern->GetCaretRange(&caret_is_active,
                                           caret_range.GetAddressOf());
      if (FAILED(result) || !caret_is_active) {
        caret_range.Reset();
      }
    }
  }

  // Older providers, including many RichEdit controls, expose TextPattern v1
  // only. With no selection they return one degenerate range at the caret.
  if (caret_range == nullptr) {
    text_pattern.Reset();
    pattern_unknown.Reset();
    result = focused_element->GetCurrentPattern(
        UIA_TextPatternId, pattern_unknown.ReleaseAndGetAddressOf());
    if (FAILED(result) || pattern_unknown == nullptr) {
      return finish(UiAutomationSelectionResult::kUnavailable);
    }
    result = pattern_unknown.As(&legacy_text_pattern);
    if (FAILED(result) || legacy_text_pattern == nullptr) {
      return finish(UiAutomationSelectionResult::kUnavailable);
    }
    result = legacy_text_pattern->GetSelection(selection_ranges.GetAddressOf());
    if (FAILED(result) || selection_ranges == nullptr) {
      return finish(UiAutomationSelectionResult::kUnavailable);
    }
    int range_count = 0;
    result = selection_ranges->get_Length(&range_count);
    if (FAILED(result) || range_count != 1) {
      return finish(UiAutomationSelectionResult::kUnavailable);
    }
    result = selection_ranges->GetElement(0, caret_range.ReleaseAndGetAddressOf());
    if (FAILED(result) || caret_range == nullptr) {
      return finish(UiAutomationSelectionResult::kUnavailable);
    }
    int endpoint_comparison = 0;
    result = caret_range->CompareEndpoints(
        TextPatternRangeEndpoint_Start, caret_range.Get(),
        TextPatternRangeEndpoint_End, &endpoint_comparison);
    if (FAILED(result) || endpoint_comparison != 0) {
      return finish(UiAutomationSelectionResult::kUnavailable);
    }
  }

  // VS Code's UI Automation provider can count a soft-wrap/bidi boundary as
  // one extra character. Start with the recorded position, then try the two
  // adjacent positions. We only select a candidate when its text is exactly
  // what Dart detected, so this calibration cannot replace unrelated text.
  std::wstring closest_text;
  bool had_candidate = false;
  for (const int trailing_adjustment : {0, 1, -1}) {
    const int actual_trailing = trailing_units + trailing_adjustment;
    if (actual_trailing < 0) continue;
    result = caret_range->Clone(attempt_range.ReleaseAndGetAddressOf());
    if (FAILED(result) || attempt_range == nullptr) continue;

    int moved = 0;
    if (actual_trailing > 0) {
      result = attempt_range->Move(TextUnit_Character, -actual_trailing,
                                   &moved);
      if (FAILED(result) || moved != -actual_trailing) {
        attempt_range.Reset();
        continue;
      }
    }
    result = attempt_range->MoveEndpointByUnit(
        TextPatternRangeEndpoint_Start, TextUnit_Character, -selection_units,
        &moved);
    if (FAILED(result) || moved != -selection_units) {
      attempt_range.Reset();
      continue;
    }

    BSTR range_text = nullptr;
    result = attempt_range->GetText(-1, &range_text);
    std::wstring candidate;
    if (SUCCEEDED(result) && range_text != nullptr) candidate = range_text;
    if (range_text != nullptr) SysFreeString(range_text);
    if (!had_candidate) {
      closest_text = candidate;
      had_candidate = true;
    }
    if (candidate == expected) {
      if (selected_text != nullptr) *selected_text = candidate;
      result = attempt_range->Select();
      return finish(SUCCEEDED(result) ? UiAutomationSelectionResult::kSelected
                                      : UiAutomationSelectionResult::kFailed);
    }
    attempt_range.Reset();
  }

  if (selected_text != nullptr) *selected_text = closest_text;
  // No candidate's text matched `expected`, so `.Select()` was never called
  // and nothing changed on screen: this is always a failure to select the
  // exact detected range, whether or not a (mismatched) candidate existed.
  return finish(UiAutomationSelectionResult::kFailed);
}

std::optional<std::wstring> ReadSelectedTextWithUiAutomation() {
  const HRESULT initialize_result =
      CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  const bool should_uninitialize = SUCCEEDED(initialize_result);
  if (FAILED(initialize_result) && initialize_result != RPC_E_CHANGED_MODE) {
    return std::nullopt;
  }

  IUIAutomation* automation = nullptr;
  IUIAutomationElement* focused_element = nullptr;
  IUnknown* pattern_unknown = nullptr;
  IUIAutomationTextPattern* text_pattern = nullptr;
  IUIAutomationTextRangeArray* selection_ranges = nullptr;
  IUIAutomationTextRange* selection_range = nullptr;
  const auto finish = [&](std::optional<std::wstring> value) {
    if (selection_range != nullptr) selection_range->Release();
    if (selection_ranges != nullptr) selection_ranges->Release();
    if (text_pattern != nullptr) text_pattern->Release();
    if (pattern_unknown != nullptr) pattern_unknown->Release();
    if (focused_element != nullptr) focused_element->Release();
    if (automation != nullptr) automation->Release();
    if (should_uninitialize) CoUninitialize();
    return value;
  };

  if (FAILED(CoCreateInstance(CLSID_CUIAutomation, nullptr,
                              CLSCTX_INPROC_SERVER,
                              IID_PPV_ARGS(&automation))) ||
      automation == nullptr ||
      FAILED(automation->GetFocusedElement(&focused_element)) ||
      focused_element == nullptr ||
      FAILED(focused_element->GetCurrentPattern(
          UIA_TextPatternId, &pattern_unknown)) ||
      pattern_unknown == nullptr ||
      FAILED(pattern_unknown->QueryInterface(IID_PPV_ARGS(&text_pattern))) ||
      text_pattern == nullptr ||
      FAILED(text_pattern->GetSelection(&selection_ranges)) ||
      selection_ranges == nullptr) {
    return finish(std::nullopt);
  }
  int range_count = 0;
  if (FAILED(selection_ranges->get_Length(&range_count)) || range_count != 1 ||
      FAILED(selection_ranges->GetElement(0, &selection_range)) ||
      selection_range == nullptr) {
    return finish(std::nullopt);
  }
  BSTR text = nullptr;
  const HRESULT text_result = selection_range->GetText(-1, &text);
  std::optional<std::wstring> value;
  if (SUCCEEDED(text_result) && text != nullptr && SysStringLen(text) > 0) {
    value = std::wstring(text, SysStringLen(text));
  }
  if (text != nullptr) SysFreeString(text);
  return finish(value);
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  keyboard_channel_ = std::make_unique<
      flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), kKeyboardChannel,
      &flutter::StandardMethodCodec::GetInstance());
  keyboard_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() == "start") {
          result->Success(flutter::EncodableValue(
              keyboard_hook_.Start(GetHandle())));
        } else if (call.method_name() == "stop") {
          keyboard_hook_.Stop();
          result->Success();
        } else if (call.method_name() == "isRunning") {
          result->Success(flutter::EncodableValue(keyboard_hook_.IsRunning()));
        } else if (call.method_name() == "captureSelection") {
          const auto selected = CaptureSelectedText();
          if (!selected.has_value()) {
            result->Error("CAPTURE_FAILED", last_capture_status_);
            return;
          }
          const int utf8_length = WideCharToMultiByte(
              CP_UTF8, 0, selected->data(), static_cast<int>(selected->size()),
              nullptr, 0, nullptr, nullptr);
          std::string utf8(utf8_length, '\0');
          WideCharToMultiByte(CP_UTF8, 0, selected->data(),
                              static_cast<int>(selected->size()), utf8.data(),
                              utf8_length, nullptr, nullptr);
          result->Success(flutter::EncodableValue(utf8));
        } else if (call.method_name() == "captureDetectedText") {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments == nullptr) {
            result->Error("INVALID_DETECTION",
                          "Detected-text arguments are missing.");
            return;
          }
          const auto expected_iterator =
              arguments->find(flutter::EncodableValue("expected"));
          const auto selection_units_iterator =
              arguments->find(flutter::EncodableValue("selectionUnits"));
          const auto trailing_units_iterator =
              arguments->find(flutter::EncodableValue("trailingUnits"));
          if (expected_iterator == arguments->end() ||
              selection_units_iterator == arguments->end() ||
              trailing_units_iterator == arguments->end()) {
            result->Error("INVALID_DETECTION",
                          "Expected text and caret-unit counts are required.");
            return;
          }
          const auto* expected_utf8 =
              std::get_if<std::string>(&expected_iterator->second);
          const auto* selection_units =
              std::get_if<int32_t>(&selection_units_iterator->second);
          const auto* trailing_units =
              std::get_if<int32_t>(&trailing_units_iterator->second);
          if (expected_utf8 == nullptr || expected_utf8->empty() ||
              selection_units == nullptr || *selection_units <= 0 ||
              *selection_units > 1000 || trailing_units == nullptr ||
              *trailing_units < 0 || *trailing_units > 16) {
            result->Error("INVALID_DETECTION",
                          "Detected-text arguments are invalid.");
            return;
          }
          const auto selected = CaptureDetectedText(
              Utf8ToWide(*expected_utf8), static_cast<int>(*selection_units),
              static_cast<int>(*trailing_units));
          if (!selected.has_value()) {
            result->Error(
                "DETECTION_CHANGED",
                "The detected text is no longer immediately before the caret.");
            return;
          }
          result->Success(flutter::EncodableValue(WideToUtf8(*selected)));
        } else if (call.method_name() == "pasteReplacement") {
          const auto* argument = std::get_if<std::string>(call.arguments());
          result->Success(flutter::EncodableValue(
              argument != nullptr && PasteReplacement(*argument)));
        } else if (call.method_name() == "setClipboardRestoreDelay") {
          const auto* milliseconds = std::get_if<int32_t>(call.arguments());
          if (milliseconds == nullptr || *milliseconds < 100 ||
              *milliseconds > 5000) {
            result->Error("INVALID_DELAY",
                          "Restore delay must be between 100 and 5000 ms.");
          } else {
            clipboard_restore_delay_ms_ = static_cast<DWORD>(*milliseconds);
            EmitDebug("Phase 0C restore delay set to " +
                      std::to_string(clipboard_restore_delay_ms_) + " ms");
            result->Success();
          }
        } else if (call.method_name() == "showWarningPopup") {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments == nullptr) {
            result->Error("INVALID_WARNING", "Warning arguments are missing.");
            return;
          }
          const auto title_iterator =
              arguments->find(flutter::EncodableValue("title"));
          const auto suggestion_iterator =
              arguments->find(flutter::EncodableValue("suggestion"));
          const auto confidence_iterator =
              arguments->find(flutter::EncodableValue("confidence"));
          if (suggestion_iterator == arguments->end() ||
              confidence_iterator == arguments->end()) {
            result->Error("INVALID_WARNING",
                          "Suggestion and confidence are required.");
            return;
          }
          std::wstring title_wide;
          if (title_iterator != arguments->end()) {
            if (const auto* title_utf8 =
                    std::get_if<std::string>(&title_iterator->second)) {
              title_wide = Utf8ToWide(*title_utf8);
            }
          }
          const auto* suggestion =
              std::get_if<std::string>(&suggestion_iterator->second);
          int confidence = 0;
          if (const auto* confidence32 =
                  std::get_if<int32_t>(&confidence_iterator->second)) {
            confidence = *confidence32;
          } else if (const auto* confidence64 =
                         std::get_if<int64_t>(&confidence_iterator->second)) {
            confidence = static_cast<int>(*confidence64);
          } else {
            result->Error("INVALID_WARNING", "Confidence must be an integer.");
            return;
          }
          if (suggestion == nullptr || suggestion->empty()) {
            result->Error("INVALID_WARNING", "Suggestion cannot be empty.");
            return;
          }
          confidence = (std::max)(0, (std::min)(100, confidence));
          result->Success(flutter::EncodableValue(warning_popup_.Show(
              title_wide, Utf8ToWide(*suggestion), confidence,
              last_foreground_window_)));
        } else if (call.method_name() == "hideWarningPopup") {
          warning_popup_.Hide();
          result->Success();
        } else if (call.method_name() == "getRunningApps") {
          std::vector<flutter::EncodableValue> list;
          EnumWindows([](HWND hwnd, LPARAM lparam) -> BOOL {
            auto* list_ptr = reinterpret_cast<std::vector<flutter::EncodableValue>*>(lparam);
            if (!IsWindowVisible(hwnd)) return TRUE;

            const int title_length = GetWindowTextLengthW(hwnd);
            if (title_length <= 0) return TRUE;

            LONG_PTR ex_style = GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
            if ((ex_style & WS_EX_TOOLWINDOW) && !(ex_style & WS_EX_APPWINDOW)) {
              return TRUE;
            }

            wchar_t title_buf[512] = {};
            GetWindowTextW(hwnd, title_buf, 512);
            std::string title = WideToUtf8(title_buf);
            if (title.empty() || title == "Program Manager" || title == "Windows Shell Experience Host") {
              return TRUE;
            }

            std::string proc_name = ForegroundProcessName(hwnd);
            if (proc_name.empty() || proc_name == "badeli.exe" || proc_name == "explorer.exe") {
              return TRUE;
            }

            std::string proc_lower = proc_name;
            std::transform(proc_lower.begin(), proc_lower.end(), proc_lower.begin(),
                           [](unsigned char c) { return static_cast<char>(std::tolower(c)); });

            bool already_added = false;
            for (const auto& item : *list_ptr) {
              if (const auto* map = std::get_if<flutter::EncodableMap>(&item)) {
                auto it = map->find(flutter::EncodableValue("processName"));
                if (it != map->end()) {
                  if (const auto* name = std::get_if<std::string>(&it->second)) {
                    if (*name == proc_lower) {
                      already_added = true;
                      break;
                    }
                  }
                }
              }
            }

            if (!already_added) {
              flutter::EncodableMap map;
              map[flutter::EncodableValue("processName")] = flutter::EncodableValue(proc_lower);
              map[flutter::EncodableValue("title")] = flutter::EncodableValue(title);
              list_ptr->push_back(flutter::EncodableValue(map));
            }

            return TRUE;
          }, reinterpret_cast<LPARAM>(&list));

          result->Success(flutter::EncodableValue(list));
        } else {
          result->NotImplemented();
        }
      });
  warning_popup_.SetActionHandler([this](WarningPopupAction action) {
    if (!keyboard_channel_) {
      return;
    }
    const char* action_name = "dismiss";
    if (action == WarningPopupAction::kFixSelection) {
      action_name = "fix";
    } else if (action == WarningPopupAction::kPause) {
      action_name = "pause";
    }
    keyboard_channel_->InvokeMethod(
        "warningAction",
        std::make_unique<flutter::EncodableValue>(action_name));
  });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  EmitDebug("Manual shortcut will be handled by the low-level hook");

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  warning_popup_.Hide();
  warning_popup_.SetActionHandler(nullptr);
  RestoreClipboardSnapshot();
  keyboard_hook_.Stop();
  keyboard_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case kManualUndoMessage:
      EmitDebug("Undo shortcut detected by low-level hook");
      UndoLastCorrection();
      return 0;
    case kManualFixMessage:
      if (keyboard_channel_) {
        EmitDebug("1/7 Shortcut detected by low-level hook");
        keyboard_channel_->InvokeMethod("manualFixRequested", nullptr);
        return 0;
      }
      break;
    case kKeyboardHookEventMessage: {
      if (keyboard_channel_) {
        for (const auto& event : keyboard_hook_.DrainEvents()) {
          if (event.foreground_window != GetHandle()) {
            last_foreground_window_ = event.foreground_window;
          }
          flutter::EncodableMap payload;
          payload[flutter::EncodableValue("virtualKey")] =
              flutter::EncodableValue(static_cast<int64_t>(event.virtual_key));
          payload[flutter::EncodableValue("scanCode")] =
              flutter::EncodableValue(static_cast<int64_t>(event.scan_code));
          payload[flutter::EncodableValue("flags")] =
              flutter::EncodableValue(static_cast<int64_t>(event.flags));
          payload[flutter::EncodableValue("time")] =
              flutter::EncodableValue(static_cast<int64_t>(event.time));
          payload[flutter::EncodableValue("foregroundWindow")] =
              flutter::EncodableValue(static_cast<int64_t>(
                  reinterpret_cast<intptr_t>(event.foreground_window)));
          payload[flutter::EncodableValue("processName")] =
              flutter::EncodableValue(ForegroundProcessName(
                  event.foreground_window));
          payload[flutter::EncodableValue("languageId")] =
              flutter::EncodableValue(static_cast<int32_t>(event.language_id));
          payload[flutter::EncodableValue("keyDown")] =
              flutter::EncodableValue(event.key_down);
          payload[flutter::EncodableValue("injected")] =
              flutter::EncodableValue(event.injected);
          payload[flutter::EncodableValue("controlDown")] =
              flutter::EncodableValue(event.control_down);
          payload[flutter::EncodableValue("altDown")] =
              flutter::EncodableValue(event.alt_down);
          payload[flutter::EncodableValue("shiftDown")] =
              flutter::EncodableValue(event.shift_down);
          keyboard_channel_->InvokeMethod(
              "keyEvent", std::make_unique<flutter::EncodableValue>(payload));
        }
      }
      return 0;
    }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

std::optional<std::wstring> FlutterWindow::CaptureSelectedText() {
  captured_selection_text_.reset();
  selection_captured_by_ui_automation_ = false;
  if (const auto selected = ReadSelectedTextWithUiAutomation();
      selected.has_value()) {
    captured_selection_text_ = *selected;
    selection_captured_by_ui_automation_ = true;
    EmitDebug("Phase 4 selected text read directly with UI Automation");
    return selected;
  }
  if (!SaveClipboardSnapshot()) {
    last_capture_status_ = "Could not open the clipboard before Ctrl+C.";
    EmitDebug(last_capture_status_);
    return std::nullopt;
  }
  last_capture_status_ = "Clipboard saved; sending Ctrl+C.";
  EmitDebug(last_capture_status_);

  // Clear the live clipboard after snapshotting it. Some applications leave
  // the clipboard unchanged when Ctrl+C is sent without a selection; without
  // this sentinel state, stale clipboard text could be mistaken for a capture.
  if (!OpenClipboardWithRetry(GetHandle(), 50)) {
    last_capture_status_ =
        "Clipboard was saved, but could not be cleared before Ctrl+C.";
    EmitDebug(last_capture_status_);
    RestoreClipboardSnapshot();
    return std::nullopt;
  }
  EmptyClipboard();
  CloseClipboard();

  // The low-level hook dispatches this request only after all shortcut
  // modifiers have been physically released.
  std::this_thread::sleep_for(std::chrono::milliseconds(30));
  EmitDebug("Foreground before copy: " +
            ForegroundProcessName(GetForegroundWindow()));
  EmitDebug("Remembered selection target: " +
            ForegroundProcessName(last_foreground_window_));

  SendKey(VK_CONTROL);
  std::this_thread::sleep_for(std::chrono::milliseconds(30));
  SendKey('C');
  std::this_thread::sleep_for(std::chrono::milliseconds(30));
  SendKey('C', true);
  std::this_thread::sleep_for(std::chrono::milliseconds(30));
  SendKey(VK_CONTROL, true);
  std::this_thread::sleep_for(std::chrono::milliseconds(150));

  if (!OpenClipboardWithRetry(GetHandle())) {
    last_capture_status_ = "Ctrl+C sent, but the clipboard could not be opened.";
    EmitDebug(last_capture_status_);
    RestoreClipboardSnapshot();
    return std::nullopt;
  }
  std::optional<std::wstring> selected;
  for (int attempt = 0; attempt < 10 && !selected.has_value(); ++attempt) {
    selected = ReadClipboardText();
    if (!selected.has_value()) {
      CloseClipboard();
      std::this_thread::sleep_for(std::chrono::milliseconds(50));
      if (!OpenClipboardWithRetry(GetHandle())) {
        break;
      }
    }
  }
  CloseClipboard();
  if (!selected.has_value() || selected->empty()) {
    last_capture_status_ =
        "Selection copy completed, but no non-empty text was found in the clipboard.";
    EmitDebug(last_capture_status_);
    RestoreClipboardSnapshot();
    return std::nullopt;
  }
  last_capture_status_ = "Selection captured successfully.";
  EmitDebug(last_capture_status_);
  captured_selection_text_ = *selected;
  return selected;
}

bool FlutterWindow::AcceptDetectedSelection(const std::wstring& selected,
                                            const std::wstring& expected) {
  detected_selection_prefix_.clear();
  detected_selection_suffix_.clear();
  if (selected == expected) {
    return true;
  }

  // VS Code's "emptySelectionClipboard" copies the whole line plus CRLF when
  // no selection exists. Never accept such a copy as selection evidence.
  if (selected.find(L'\r') != std::wstring::npos ||
      selected.find(L'\n') != std::wstring::npos) {
    return false;
  }

  constexpr size_t kMaxPreservedContextCharacters = 256;
  if (selected.size() <= expected.size() ||
      selected.size() - expected.size() > kMaxPreservedContextCharacters) {
    return false;
  }
  const size_t match = selected.find(expected);
  if (match == std::wstring::npos ||
      selected.find(expected, match + 1) != std::wstring::npos) {
    return false;
  }

  detected_selection_prefix_ = selected.substr(0, match);
  detected_selection_suffix_ = selected.substr(match + expected.size());
  EmitDebug("Phase 4 uniquely revalidated detection inside broader selection; "
            "preserving " +
            std::to_string(detected_selection_prefix_.size()) +
            " prefix and " +
            std::to_string(detected_selection_suffix_.size()) +
            " suffix characters");
  return true;
}

bool FlutterWindow::RevalidateSelectionBeforePaste() {
  if (!captured_selection_text_.has_value() ||
      captured_selection_text_->empty()) {
    EmitDebug("5/7 Paste refused: no captured selection to revalidate");
    return false;
  }
  if (GetForegroundWindow() != last_foreground_window_) {
    EmitDebug("5/7 Paste refused: foreground window changed");
    return false;
  }
  if (selection_captured_by_ui_automation_) {
    // UI Automation supplied the exact selected range directly. Do not ask
    // VS Code to copy it again: Electron can leave its clipboard busy or
    // empty for a long selection even though the text range is still valid.
    EmitDebug("5/7 UI Automation range accepted without clipboard recopy");
    return true;
  }

  // Use the already-saved clipboard snapshot. Clearing the live clipboard
  // prevents stale data from looking like a successful second Ctrl+C.
  if (!OpenClipboardWithRetry(GetHandle(), 50)) {
    EmitDebug("5/7 Paste refused: clipboard busy during revalidation");
    return false;
  }
  EmptyClipboard();
  CloseClipboard();

  SendKey(VK_CONTROL);
  std::this_thread::sleep_for(std::chrono::milliseconds(30));
  SendKey('C');
  std::this_thread::sleep_for(std::chrono::milliseconds(30));
  SendKey('C', true);
  std::this_thread::sleep_for(std::chrono::milliseconds(30));
  SendKey(VK_CONTROL, true);
  std::this_thread::sleep_for(std::chrono::milliseconds(200));

  if (!OpenClipboardWithRetry(GetHandle(), 50)) {
    EmitDebug("5/7 Paste refused: could not read revalidated selection");
    return false;
  }
  const auto selected = ReadClipboardText();
  CloseClipboard();
  if (!selected.has_value() || *selected != *captured_selection_text_) {
    EmitDebug("5/7 Paste refused: selection collapsed or changed");
    return false;
  }
  EmitDebug("5/7 Selection revalidated immediately before replacement");
  return true;
}

std::optional<std::wstring> FlutterWindow::CaptureDetectedText(
    const std::wstring& expected, int selection_units, int trailing_units) {
  detected_selection_prefix_.clear();
  detected_selection_suffix_.clear();
  selection_captured_by_ui_automation_ = false;
  const HWND target = last_foreground_window_;
  if (target == nullptr || !IsWindow(target) || GetForegroundWindow() != target) {
    EmitDebug("Phase 4 fix refused: target window is no longer foreground");
    return std::nullopt;
  }

  std::wstring automation_selection;
  const auto automation_result = SelectDetectedRangeWithUiAutomation(
      selection_units, trailing_units, expected, &automation_selection);
  if (automation_result == UiAutomationSelectionResult::kSelected) {
    EmitDebug("Phase 4 selected logical caret range with UI Automation");
    if (AcceptDetectedSelection(automation_selection, expected)) {
      captured_selection_text_ = automation_selection;
      selection_captured_by_ui_automation_ = true;
      EmitDebug("Phase 4 UI Automation range read and validated directly");
      return expected;
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(40));
    const auto selected = CaptureSelectedText();
    if (selected.has_value() && AcceptDetectedSelection(*selected, expected)) {
      EmitDebug("Phase 4 UI Automation selection exactly revalidated");
      return expected;
    }
    if (selected.has_value()) {
      EmitDebug("Phase 4 UI Automation captured " +
                std::to_string(selected->size()) + " characters; expected " +
                std::to_string(expected.size()));
      RestoreClipboardSnapshot();
    }
    captured_selection_text_.reset();
    EmitDebug("Phase 4 UI Automation left a degenerate or mismatched range; "
              "using line-range fallback");
  } else if (automation_result == UiAutomationSelectionResult::kFailed) {
    EmitDebug("Phase 4 UI Automation could not move the complete caret range; "
              "using line-range fallback");
  } else {
    EmitDebug("Phase 4 UI Automation unavailable; using line-range fallback");
  }

  // In VS Code a wrapped line is not necessarily a logical line. Shift+Home
  // therefore stops at the visual row and cannot capture a long sentence.
  // Select the detected number of words instead; Ctrl+Shift+Left follows text
  // boundaries rather than the visible wrapping. The captured result is still
  // checked against `expected` before any replacement can happen.
  //
  // This also applies when UI Automation was available but kFailed to move
  // the exact calibrated range (long/wrapped selections routinely land here,
  // not just when the provider is altogether unavailable) - only a genuine
  // kSelected means the exact range was already found and pasted above.
  const int word_count = CountWords(expected);
  if (automation_result != UiAutomationSelectionResult::kSelected &&
      word_count >= 2) {
    SendKey(VK_CONTROL);
    SendKey(VK_SHIFT);
    for (int index = 0; index < word_count; ++index) {
      SendKey(VK_LEFT);
      std::this_thread::sleep_for(std::chrono::milliseconds(12));
    }
    SendKey(VK_SHIFT, true);
    SendKey(VK_CONTROL, true);
    std::this_thread::sleep_for(std::chrono::milliseconds(80));

    const auto word_selection = CaptureSelectedText();
    if (word_selection.has_value() &&
        AcceptDetectedSelection(*word_selection, expected)) {
      EmitDebug("Phase 4 word-range uniquely revalidated detection");
      return expected;
    }
    if (word_selection.has_value()) {
      EmitDebug("Phase 4 word range captured " +
                std::to_string(word_selection->size()) +
                " characters but did not uniquely contain detection");
      RestoreClipboardSnapshot();
    }
    captured_selection_text_.reset();
  }

  // Shift+Home creates a real selection from the caret to the logical line
  // start without depending on left/right visual movement in bidi text. A
  // failed UI Automation Select can leave the caret at its moved start range,
  // so normalize it to the logical line end first.
  SendKey(VK_END);
  SendKey(VK_END, true);
  std::this_thread::sleep_for(std::chrono::milliseconds(40));
  SendKey(VK_SHIFT);
  std::this_thread::sleep_for(std::chrono::milliseconds(30));
  SendKey(VK_HOME);
  std::this_thread::sleep_for(std::chrono::milliseconds(30));
  SendKey(VK_HOME, true);
  std::this_thread::sleep_for(std::chrono::milliseconds(30));
  SendKey(VK_SHIFT, true);
  std::this_thread::sleep_for(std::chrono::milliseconds(100));

  const auto line_selection = CaptureSelectedText();
  if (line_selection.has_value() &&
      AcceptDetectedSelection(*line_selection, expected)) {
    EmitDebug("Phase 4 line range uniquely revalidated detection");
    return expected;
  }
  if (line_selection.has_value()) {
    EmitDebug("Phase 4 line range captured " +
              std::to_string(line_selection->size()) +
              " characters but did not uniquely contain detection");
    RestoreClipboardSnapshot();
  }
  captured_selection_text_.reset();
  SendKey(VK_END);
  SendKey(VK_END, true);
  EmitDebug("Phase 4 fix refused: no safe logical selection was available");
  return std::nullopt;
}

bool FlutterWindow::SaveClipboardSnapshot() {
  if (!OpenClipboardWithRetry(GetHandle())) {
    return false;
  }

  constexpr SIZE_T kMaxFormatBytes = 64 * 1024 * 1024;
  constexpr SIZE_T kMaxSnapshotBytes = 128 * 1024 * 1024;
  ClearClipboardSnapshot();
  clipboard_snapshot_available_ = true;
  replacement_clipboard_sequence_ = 0;

  original_clipboard_had_text_ = false;
  original_clipboard_text_.reset();
  const auto text = ReadClipboardText();
  if (text.has_value()) {
    original_clipboard_text_ = *text;
    original_clipboard_had_text_ = true;
  }

  SIZE_T total_bytes = 0;
  int skipped_formats = 0;
  UINT format = 0;
  while ((format = EnumClipboardFormats(format)) != 0) {
    if (!IsSafeClipboardSnapshotFormat(format)) {
      skipped_formats++;
      continue;
    }
    HANDLE data = GetClipboardData(format);
    const SIZE_T size = data == nullptr ? 0 : GlobalSize(data);
    if (size == 0 || size > kMaxFormatBytes ||
        total_bytes + size > kMaxSnapshotBytes) {
      skipped_formats++;
      continue;
    }

    const void* source = GlobalLock(data);
    if (source == nullptr) {
      skipped_formats++;
      continue;
    }
    ClipboardFormatSnapshot snapshot;
    snapshot.format = format;
    snapshot.bytes.resize(size);
    memcpy(snapshot.bytes.data(), source, size);
    GlobalUnlock(data);
    total_bytes += size;
    original_clipboard_formats_.push_back(std::move(snapshot));
  }
  CloseClipboard();

  EmitDebug("Phase 0C snapshot: saved " +
            std::to_string(original_clipboard_formats_.size()) +
            " formats (" + std::to_string(total_bytes) + " bytes), skipped " +
            std::to_string(skipped_formats));
  return true;
}

void FlutterWindow::RestoreClipboardSnapshot(bool respect_contention) {
  if (!clipboard_snapshot_available_) {
    return;
  }

  if (respect_contention && replacement_clipboard_sequence_ != 0 &&
      GetClipboardSequenceNumber() != replacement_clipboard_sequence_) {
    EmitDebug(
        "Phase 0C contention: clipboard changed externally; restore skipped");
    ClearClipboardSnapshot();
    return;
  }

  if (!OpenClipboardWithRetry(GetHandle())) {
    EmitDebug("Phase 0C restore failed: clipboard is busy");
    return;
  }
  EmptyClipboard();

  int restored_formats = 0;
  for (const auto& snapshot : original_clipboard_formats_) {
    HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE, snapshot.bytes.size());
    if (memory == nullptr) {
      continue;
    }
    void* destination = GlobalLock(memory);
    if (destination == nullptr) {
      GlobalFree(memory);
      continue;
    }
    memcpy(destination, snapshot.bytes.data(), snapshot.bytes.size());
    GlobalUnlock(memory);
    if (SetClipboardData(snapshot.format, memory) != nullptr) {
      restored_formats++;
    } else {
      GlobalFree(memory);
    }
  }
  CloseClipboard();

  EmitDebug("Phase 0C restore: restored " +
            std::to_string(restored_formats) + " of " +
            std::to_string(original_clipboard_formats_.size()) + " formats");
  ClearClipboardSnapshot();
}

void FlutterWindow::ClearClipboardSnapshot() {
  original_clipboard_formats_.clear();
  original_clipboard_text_.reset();
  original_clipboard_had_text_ = false;
  clipboard_snapshot_available_ = false;
  replacement_clipboard_sequence_ = 0;
}

bool FlutterWindow::PasteReplacement(const std::string& replacement) {
  const std::wstring preserved_prefix = detected_selection_prefix_;
  const std::wstring preserved_suffix = detected_selection_suffix_;
  detected_selection_prefix_.clear();
  detected_selection_suffix_.clear();
  const HWND correction_window = last_foreground_window_;
  const bool replace_with_unicode_input = selection_captured_by_ui_automation_;
  if (!RevalidateSelectionBeforePaste()) {
    RestoreClipboardSnapshot();
    return false;
  }
  const int wide_length = MultiByteToWideChar(
      CP_UTF8, 0, replacement.data(), static_cast<int>(replacement.size()),
      nullptr, 0);
  std::wstring wide(wide_length, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, replacement.data(),
                      static_cast<int>(replacement.size()), wide.data(),
                      wide_length);
  if (!preserved_prefix.empty() || !preserved_suffix.empty()) {
    wide = preserved_prefix + wide + preserved_suffix;
    EmitDebug("Phase 4 composing replacement with preserved bidi context");
  }
  if (replace_with_unicode_input) {
    // A verified UI Automation selection is already active. Unicode input
    // replaces that selection atomically in VS Code, avoiding a separate
    // Backspace that could delete text if clipboard paste is delayed.
    if (!SendUnicodeText(wide)) {
      EmitDebug("5/7 Direct Unicode replacement could not be sent");
      return false;
    }
    last_correction_original_ = captured_selection_text_;
    last_correction_replacement_ = wide;
    last_correction_window_ = correction_window;
    last_correction_time_ = GetTickCount64();
    selection_captured_by_ui_automation_ = false;
    ClearClipboardSnapshot();
    EmitDebug("6/7 Direct Unicode replacement sent without deleting text first");
    return true;
  }
  if (!OpenClipboardWithRetry(GetHandle())) {
    EmitDebug("5/7 Paste failed: could not open clipboard");
    RestoreClipboardSnapshot();
    return false;
  }
  EmptyClipboard();
  const size_t bytes = (wide.size() + 1) * sizeof(wchar_t);
  HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE, bytes);
  if (memory == nullptr) {
    EmitDebug("5/7 Paste failed: could not allocate clipboard memory");
    CloseClipboard();
    RestoreClipboardSnapshot();
    return false;
  }
  auto* destination = static_cast<wchar_t*>(GlobalLock(memory));
  if (destination == nullptr) {
    EmitDebug("5/7 Paste failed: could not lock clipboard memory");
    GlobalFree(memory);
    CloseClipboard();
    RestoreClipboardSnapshot();
    return false;
  }
  memcpy(destination, wide.c_str(), bytes);
  GlobalUnlock(memory);
  if (SetClipboardData(CF_UNICODETEXT, memory) == nullptr) {
    // Per Win32 docs, ownership of |memory| only transfers to the system on
    // success. On failure the caller retains it and must free it.
    EmitDebug("5/7 Paste failed: could not set clipboard data");
    GlobalFree(memory);
    CloseClipboard();
    RestoreClipboardSnapshot();
    return false;
  }
  CloseClipboard();
  replacement_clipboard_sequence_ = GetClipboardSequenceNumber();

  // Explicit deletion avoids Chromium/Electron collapsing a bidi selection
  // and treating Ctrl+V as an insertion at the active visual caret.
  UINT injected_events = 0;
  constexpr UINT kExpectedInjectedEvents = 6;
  injected_events += SendKey(VK_BACK);
  injected_events += SendKey(VK_BACK, true);
  std::this_thread::sleep_for(std::chrono::milliseconds(25));
  injected_events += SendKey(VK_CONTROL);
  injected_events += SendKey('V');
  injected_events += SendKey('V', true);
  injected_events += SendKey(VK_CONTROL, true);
  if (injected_events != kExpectedInjectedEvents) {
    EmitDebug("5/7 SendInput injected " + std::to_string(injected_events) +
              " of " + std::to_string(kExpectedInjectedEvents) +
              " expected backspace/paste events");
  }
  if (captured_selection_text_.has_value()) {
    last_correction_original_ = *captured_selection_text_;
    last_correction_replacement_ = wide;
    last_correction_window_ = correction_window;
    last_correction_time_ = GetTickCount64();
    EmitDebug("Phase 2 undo context stored for " +
              ForegroundProcessName(last_correction_window_));
  }
  std::this_thread::sleep_for(
      std::chrono::milliseconds(clipboard_restore_delay_ms_));
  RestoreClipboardSnapshot(true);
  EmitDebug("6/7 Replacement pasted; 7/7 clipboard restore attempted");
  return true;
}

bool FlutterWindow::UndoLastCorrection() {
  constexpr ULONGLONG kUndoContextLifetimeMs = 2 * 60 * 1000;
  if (!last_correction_original_.has_value() ||
      !last_correction_replacement_.has_value() ||
      last_correction_window_ == nullptr) {
    EmitDebug("Phase 2 undo unavailable: no Baddel correction is stored");
    return false;
  }
  if (GetTickCount64() - last_correction_time_ > kUndoContextLifetimeMs) {
    EmitDebug("Phase 2 undo unavailable: correction context expired");
    ClearLastCorrection();
    return false;
  }
  if (GetForegroundWindow() != last_correction_window_) {
    EmitDebug("Phase 2 undo refused: foreground window changed");
    return false;
  }

  const std::wstring original = *last_correction_original_;
  const std::wstring replacement = *last_correction_replacement_;
  const auto selected = CaptureSelectedText();
  if (!selected.has_value()) {
    EmitDebug("Phase 2 undo refused: no corrected text is selected");
    return false;
  }
  if (*selected != replacement) {
    EmitDebug("Phase 2 undo refused: selection no longer matches correction");
    RestoreClipboardSnapshot();
    return false;
  }

  const bool restored = PasteReplacement(WideToUtf8(original));
  if (restored) {
    ClearLastCorrection();
    EmitDebug("Phase 2 undo completed after exact-selection revalidation");
  }
  return restored;
}

void FlutterWindow::ClearLastCorrection() {
  last_correction_original_.reset();
  last_correction_replacement_.reset();
  last_correction_window_ = nullptr;
  last_correction_time_ = 0;
}

void FlutterWindow::EmitDebug(const std::string& message) {
  DebugLog(message);
  if (keyboard_channel_) {
    keyboard_channel_->InvokeMethod(
        "debugMessage", std::make_unique<flutter::EncodableValue>(message));
  }
}
