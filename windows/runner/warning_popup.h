#ifndef RUNNER_WARNING_POPUP_H_
#define RUNNER_WARNING_POPUP_H_

#include <windows.h>

#include <functional>
#include <string>

enum class WarningPopupAction { kFixSelection, kDismiss, kPause };

class WarningPopup {
 public:
  using ActionHandler = std::function<void(WarningPopupAction)>;

  WarningPopup();
  ~WarningPopup();

  WarningPopup(const WarningPopup&) = delete;
  WarningPopup& operator=(const WarningPopup&) = delete;

  void SetActionHandler(ActionHandler handler);
  bool Show(const std::wstring& title, const std::wstring& suggestion,
            int confidence, HWND target_window);
  void Hide();

 private:
  static LRESULT CALLBACK WindowProc(HWND window, UINT message, WPARAM wparam,
                                     LPARAM lparam);
  LRESULT HandleMessage(HWND window, UINT message, WPARAM wparam,
                        LPARAM lparam);
  void Paint(HWND window);
  void HandleClick(POINT point);

  HWND window_ = nullptr;
  std::wstring title_;
  std::wstring suggestion_;
  int confidence_ = 0;
  ActionHandler action_handler_;
  RECT fix_button_ = {};
  RECT dismiss_button_ = {};
  RECT pause_button_ = {};
  HFONT title_font_ = nullptr;
  HFONT body_font_ = nullptr;
  HFONT button_font_ = nullptr;
};

#endif  // RUNNER_WARNING_POPUP_H_
