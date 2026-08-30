#include "warning_popup.h"

#include <windowsx.h>

#include <utility>

namespace {
constexpr wchar_t kWarningPopupClass[] = L"BaddelWarningPopup";
constexpr int kPopupWidth = 450;
constexpr int kPopupHeight = 195;

void FillRectangle(HDC context, const RECT& rectangle, COLORREF color) {
  HBRUSH brush = CreateSolidBrush(color);
  FillRect(context, &rectangle, brush);
  DeleteObject(brush);
}

void DrawPill(HDC context, const RECT& rectangle, COLORREF fill_color,
              COLORREF border_color, int radius = 14) {
  HBRUSH brush = CreateSolidBrush(fill_color);
  HPEN pen = CreatePen(PS_SOLID, 1, border_color);
  HGDIOBJ old_brush = SelectObject(context, brush);
  HGDIOBJ old_pen = SelectObject(context, pen);
  RoundRect(context, rectangle.left, rectangle.top, rectangle.right,
            rectangle.bottom, radius, radius);
  SelectObject(context, old_brush);
  SelectObject(context, old_pen);
  DeleteObject(brush);
  DeleteObject(pen);
}

bool ContainsPoint(const RECT& rectangle, POINT point) {
  return PtInRect(&rectangle, point) != FALSE;
}
}  // namespace

WarningPopup::WarningPopup() {
  WNDCLASSW window_class = {};
  window_class.lpfnWndProc = WindowProc;
  window_class.hInstance = GetModuleHandle(nullptr);
  window_class.lpszClassName = kWarningPopupClass;
  window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
  RegisterClassW(&window_class);

  window_ = CreateWindowExW(
      WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
      kWarningPopupClass, L"", WS_POPUP, 0, 0, kPopupWidth, kPopupHeight,
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  title_font_ = CreateFontW(-19, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
                            DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                            CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                            DEFAULT_PITCH, L"Segoe UI");
  body_font_ = CreateFontW(-17, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
                           DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                           CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                           DEFAULT_PITCH, L"Segoe UI");
  button_font_ = CreateFontW(-14, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
                             DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                             CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                             DEFAULT_PITCH, L"Segoe UI");
}

WarningPopup::~WarningPopup() {
  if (window_ != nullptr) {
    DestroyWindow(window_);
  }
  DeleteObject(title_font_);
  DeleteObject(body_font_);
  DeleteObject(button_font_);
}

void WarningPopup::SetActionHandler(ActionHandler handler) {
  action_handler_ = std::move(handler);
}

bool WarningPopup::Show(const std::wstring& title,
                        const std::wstring& suggestion, int confidence,
                        HWND target_window) {
  if (window_ == nullptr) {
    return false;
  }
  title_ = title;
  suggestion_ = suggestion;
  confidence_ = confidence;

  HMONITOR monitor = MonitorFromWindow(
      target_window, MONITOR_DEFAULTTONEAREST);
  MONITORINFO monitor_info = {};
  monitor_info.cbSize = sizeof(MONITORINFO);
  GetMonitorInfoW(monitor, &monitor_info);
  const int x = monitor_info.rcWork.right - kPopupWidth - 24;
  const int y = monitor_info.rcWork.bottom - kPopupHeight - 24;

  HRGN rgn = CreateRoundRectRgn(0, 0, kPopupWidth + 1, kPopupHeight + 1, 20, 20);
  SetWindowRgn(window_, rgn, TRUE);

  SetWindowPos(window_, HWND_TOPMOST, x, y, kPopupWidth, kPopupHeight,
               SWP_NOACTIVATE | SWP_SHOWWINDOW);
  AnimateWindow(window_, 120, AW_SLIDE | AW_VER_NEGATIVE | AW_ACTIVATE);
  InvalidateRect(window_, nullptr, TRUE);
  return true;
}

void WarningPopup::Hide() {
  if (window_ != nullptr) {
    ShowWindow(window_, SW_HIDE);
  }
}

LRESULT CALLBACK WarningPopup::WindowProc(HWND window, UINT message,
                                          WPARAM wparam, LPARAM lparam) {
  WarningPopup* popup = reinterpret_cast<WarningPopup*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
  if (message == WM_NCCREATE) {
    const auto* create = reinterpret_cast<const CREATESTRUCT*>(lparam);
    popup = static_cast<WarningPopup*>(create->lpCreateParams);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(popup));
  }
  return popup == nullptr
             ? DefWindowProc(window, message, wparam, lparam)
             : popup->HandleMessage(window, message, wparam, lparam);
}

LRESULT WarningPopup::HandleMessage(HWND window, UINT message, WPARAM wparam,
                                    LPARAM lparam) {
  switch (message) {
    case WM_MOUSEACTIVATE:
      return MA_NOACTIVATE;
    case WM_PAINT:
      Paint(window);
      return 0;
    case WM_ERASEBKGND:
      return 1;
    case WM_LBUTTONUP: {
      POINT point = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      HandleClick(point);
      return 0;
    }
  }
  return DefWindowProc(window, message, wparam, lparam);
}

void WarningPopup::Paint(HWND window) {
  PAINTSTRUCT paint = {};
  HDC context = BeginPaint(window, &paint);
  RECT client = {};
  GetClientRect(window, &client);

  // Background & border
  FillRectangle(context, client, RGB(252, 252, 250));
  HPEN border_pen = CreatePen(PS_SOLID, 2, RGB(0, 180, 216));
  HGDIOBJ old_border_pen = SelectObject(context, border_pen);
  HGDIOBJ old_brush = SelectObject(context, GetStockObject(NULL_BRUSH));
  RoundRect(context, client.left, client.top, client.right - 1,
            client.bottom - 1, 20, 20);
  SelectObject(context, old_brush);
  SelectObject(context, old_border_pen);
  DeleteObject(border_pen);

  SetBkMode(context, TRANSPARENT);

  // Title
  RECT title = {18, 14, kPopupWidth - 18, 42};
  SelectObject(context, title_font_);
  SetTextColor(context, RGB(20, 25, 35));
  const std::wstring display_title =
      title_.empty() ? L"Baddel! \U0001F602 \u0646\u0633\u064A\u062A \u0627\u0644\u0643\u0644\u0627\u0641\u064A\u064A\u061F" : title_;
  DrawTextW(context, display_title.c_str(), -1,
            &title, DT_LEFT | DT_SINGLELINE | DT_END_ELLIPSIS);

  // Suggestion body
  RECT suggestion = {18, 48, kPopupWidth - 18, 105};
  SelectObject(context, body_font_);
  SetTextColor(context, RGB(40, 45, 55));
  DrawTextW(context, suggestion_.c_str(), -1, &suggestion,
            DT_LEFT | DT_WORDBREAK | DT_END_ELLIPSIS);

  // Confidence
  const std::wstring confidence =
      L"Confidence: " + std::to_wstring(confidence_) + L"% \U0001F3AF";
  RECT confidence_rectangle = {18, 107, kPopupWidth - 18, 128};
  SetTextColor(context, RGB(100, 115, 125));
  DrawTextW(context, confidence.c_str(), -1, &confidence_rectangle,
            DT_LEFT | DT_SINGLELINE);

  // Rounded Pill Action Buttons
  fix_button_ = {18, 142, 200, 178};
  dismiss_button_ = {210, 142, 326, 178};
  pause_button_ = {336, 142, 432, 178};

  DrawPill(context, fix_button_, RGB(0, 160, 195), RGB(0, 140, 175), 14);
  DrawPill(context, dismiss_button_, RGB(240, 243, 246), RGB(215, 222, 228), 14);
  DrawPill(context, pause_button_, RGB(240, 243, 246), RGB(215, 222, 228), 14);

  SelectObject(context, button_font_);
  SetTextColor(context, RGB(255, 255, 255));
  DrawTextW(context, L"\U0001F680 Fasakh & Baddel", -1, &fix_button_,
            DT_CENTER | DT_VCENTER | DT_SINGLELINE);

  SetTextColor(context, RGB(40, 45, 55));
  DrawTextW(context, L"\U0001F648 5allini", -1, &dismiss_button_,
            DT_CENTER | DT_VCENTER | DT_SINGLELINE);
  DrawTextW(context, L"\u23F8\uFE0F Pause", -1, &pause_button_,
            DT_CENTER | DT_VCENTER | DT_SINGLELINE);

  EndPaint(window, &paint);
}

void WarningPopup::HandleClick(POINT point) {
  WarningPopupAction action;
  if (ContainsPoint(fix_button_, point)) {
    action = WarningPopupAction::kFixSelection;
  } else if (ContainsPoint(dismiss_button_, point)) {
    action = WarningPopupAction::kDismiss;
  } else if (ContainsPoint(pause_button_, point)) {
    action = WarningPopupAction::kPause;
  } else {
    return;
  }
  Hide();
  if (action_handler_) {
    action_handler_(action);
  }
}
