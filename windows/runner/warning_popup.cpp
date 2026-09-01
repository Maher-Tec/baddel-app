#include "warning_popup.h"

#include <windowsx.h>

#include <utility>

namespace {
constexpr wchar_t kWarningPopupClass[] = L"BaddelWarningPopup";
constexpr int kPopupWidth = 420;
constexpr int kPopupHeight = 220;

// Color palette
constexpr COLORREF kHeaderBg      = RGB(15,  20,  35);   // deep navy
constexpr COLORREF kHeaderAccent  = RGB(0,   190, 230);  // cyan accent
constexpr COLORREF kBodyBg        = RGB(248, 249, 252);  // near-white
constexpr COLORREF kBodyBgDark    = RGB(238, 241, 248);  // slightly darker strip
constexpr COLORREF kBorderColor   = RGB(0,   190, 230);  // cyan border
constexpr COLORREF kFixFill       = RGB(0,   175, 215);
constexpr COLORREF kFixFillDark   = RGB(0,   145, 185);
constexpr COLORREF kDismissFill   = RGB(50,  60,  80);
constexpr COLORREF kDismissText   = RGB(200, 210, 225);
constexpr COLORREF kPauseFill     = RGB(35,  42,  60);
constexpr COLORREF kPauseText     = RGB(180, 195, 215);
constexpr COLORREF kBarTrack      = RGB(215, 220, 230);
constexpr COLORREF kBarFillLow    = RGB(80,  200, 120);
constexpr COLORREF kBarFillMed    = RGB(255, 190, 40);
constexpr COLORREF kBarFillHigh   = RGB(0,   190, 230);

void FillRectangle(HDC dc, const RECT& r, COLORREF c) {
  HBRUSH b = CreateSolidBrush(c);
  FillRect(dc, &r, b);
  DeleteObject(b);
}

void DrawRounded(HDC dc, const RECT& r, COLORREF fill, COLORREF border,
                 int pen_w, int radius) {
  HBRUSH br = CreateSolidBrush(fill);
  HPEN   pn = CreatePen(PS_SOLID, pen_w, border);
  auto old_br = SelectObject(dc, br);
  auto old_pn = SelectObject(dc, pn);
  RoundRect(dc, r.left, r.top, r.right, r.bottom, radius, radius);
  SelectObject(dc, old_br);
  SelectObject(dc, old_pn);
  DeleteObject(br);
  DeleteObject(pn);
}

// Draw a horizontal progress bar with rounded track
void DrawProgressBar(HDC dc, const RECT& track, int percent,
                     COLORREF bar_color) {
  // Track background
  DrawRounded(dc, track, kBarTrack, kBarTrack, 1, 6);
  // Filled portion
  int filled_w = (track.right - track.left) * percent / 100;
  if (filled_w > 4) {
    RECT filled = {track.left, track.top, track.left + filled_w, track.bottom};
    DrawRounded(dc, filled, bar_color, bar_color, 1, 6);
  }
}

bool ContainsPoint(const RECT& r, POINT p) {
  return PtInRect(&r, p) != FALSE;
}
}  // namespace

WarningPopup::WarningPopup() {
  WNDCLASSW wc = {};
  wc.lpfnWndProc   = WindowProc;
  wc.hInstance     = GetModuleHandle(nullptr);
  wc.lpszClassName = kWarningPopupClass;
  wc.hCursor       = LoadCursor(nullptr, IDC_ARROW);
  RegisterClassW(&wc);

  window_ = CreateWindowExW(
      WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
      kWarningPopupClass, L"", WS_POPUP, 0, 0, kPopupWidth, kPopupHeight,
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  // Fonts
  title_font_ = CreateFontW(-16, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
                             DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                             CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                             DEFAULT_PITCH, L"Segoe UI");
  body_font_  = CreateFontW(-14, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
                             DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                             CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                             DEFAULT_PITCH, L"Segoe UI");
  label_font_ = CreateFontW(-12, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
                             DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                             CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                             DEFAULT_PITCH, L"Segoe UI Variable");
  button_font_ = CreateFontW(-13, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
                              DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                              CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                              DEFAULT_PITCH, L"Segoe UI");
}

WarningPopup::~WarningPopup() {
  if (window_ != nullptr) DestroyWindow(window_);
  DeleteObject(title_font_);
  DeleteObject(body_font_);
  DeleteObject(label_font_);
  DeleteObject(button_font_);
}

void WarningPopup::SetActionHandler(ActionHandler handler) {
  action_handler_ = std::move(handler);
}

bool WarningPopup::Show(const std::wstring& title,
                        const std::wstring& suggestion, int confidence,
                        HWND target_window) {
  if (window_ == nullptr) return false;
  title_      = title;
  suggestion_ = suggestion;
  confidence_ = confidence;

  HMONITOR monitor = MonitorFromWindow(target_window, MONITOR_DEFAULTTONEAREST);
  MONITORINFO mi   = {};
  mi.cbSize        = sizeof(MONITORINFO);
  GetMonitorInfoW(monitor, &mi);

  // Position bottom-right, keep previous position if already visible & moved
  RECT cur = {};
  GetWindowRect(window_, &cur);
  bool visible = IsWindowVisible(window_) != FALSE;
  int x, y;
  if (visible) {
    // Keep wherever the user dragged it
    x = cur.left;
    y = cur.top;
  } else {
    x = mi.rcWork.right  - kPopupWidth  - 24;
    y = mi.rcWork.bottom - kPopupHeight - 24;
  }

  // Rounded window region (corner radius 18)
  HRGN rgn = CreateRoundRectRgn(0, 0, kPopupWidth + 1, kPopupHeight + 1, 22, 22);
  SetWindowRgn(window_, rgn, TRUE);

  SetWindowPos(window_, HWND_TOPMOST, x, y, kPopupWidth, kPopupHeight,
               SWP_NOACTIVATE | SWP_SHOWWINDOW);
  if (!visible) {
    AnimateWindow(window_, 140, AW_SLIDE | AW_VER_NEGATIVE | AW_ACTIVATE);
  }
  InvalidateRect(window_, nullptr, TRUE);
  return true;
}

void WarningPopup::Hide() {
  if (window_ != nullptr) ShowWindow(window_, SW_HIDE);
}

LRESULT CALLBACK WarningPopup::WindowProc(HWND window, UINT message,
                                          WPARAM wparam, LPARAM lparam) {
  WarningPopup* popup = reinterpret_cast<WarningPopup*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
  if (message == WM_NCCREATE) {
    const auto* cs = reinterpret_cast<const CREATESTRUCT*>(lparam);
    popup = static_cast<WarningPopup*>(cs->lpCreateParams);
    SetWindowLongPtr(window, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(popup));
  }
  return popup == nullptr ? DefWindowProc(window, message, wparam, lparam)
                          : popup->HandleMessage(window, message, wparam, lparam);
}

LRESULT WarningPopup::HandleMessage(HWND window, UINT message, WPARAM wparam,
                                    LPARAM lparam) {
  switch (message) {
    case WM_MOUSEACTIVATE:
      return MA_NOACTIVATE;

    case WM_NCHITTEST: {
      POINT sp = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      POINT cp = sp;
      ScreenToClient(window, &cp);
      if (ContainsPoint(fix_button_, cp) ||
          ContainsPoint(dismiss_button_, cp) ||
          ContainsPoint(pause_button_, cp)) {
        return HTCLIENT;
      }
      return HTCAPTION;  // whole header/body drags the window
    }

    case WM_PAINT:
      Paint(window);
      return 0;

    case WM_ERASEBKGND:
      return 1;

    case WM_LBUTTONUP: {
      POINT pt = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      HandleClick(pt);
      return 0;
    }
  }
  return DefWindowProc(window, message, wparam, lparam);
}

void WarningPopup::Paint(HWND window) {
  PAINTSTRUCT ps = {};
  HDC real_dc    = BeginPaint(window, &ps);
  RECT client    = {};
  GetClientRect(window, &client);

  // ── Double buffer ──────────────────────────────────────────────────────────
  HDC dc     = CreateCompatibleDC(real_dc);
  HBITMAP bm = CreateCompatibleBitmap(real_dc, kPopupWidth, kPopupHeight);
  auto old_bm = SelectObject(dc, bm);

  // ── Outer card background ──────────────────────────────────────────────────
  FillRectangle(dc, client, kBodyBg);

  // ── Dark header band (top 58 px) ───────────────────────────────────────────
  RECT header = {0, 0, kPopupWidth, 58};
  FillRectangle(dc, header, kHeaderBg);

  // Cyan accent strip at very top (4 px)
  RECT accent_strip = {0, 0, kPopupWidth, 4};
  FillRectangle(dc, accent_strip, kHeaderAccent);

  // ── Outer rounded border ───────────────────────────────────────────────────
  SetBkMode(dc, TRANSPARENT);
  HPEN border_pen = CreatePen(PS_SOLID, 2, kBorderColor);
  auto old_pen    = SelectObject(dc, border_pen);
  auto old_brush  = SelectObject(dc, GetStockObject(NULL_BRUSH));
  RoundRect(dc, 0, 0, kPopupWidth, kPopupHeight, 22, 22);
  SelectObject(dc, old_brush);
  SelectObject(dc, old_pen);
  DeleteObject(border_pen);

  // Separate header from body with a thin accent line
  HPEN sep_pen = CreatePen(PS_SOLID, 1, kHeaderAccent);
  old_pen      = SelectObject(dc, sep_pen);
  MoveToEx(dc, 0, 58, nullptr);
  LineTo(dc, kPopupWidth, 58);
  SelectObject(dc, old_pen);
  DeleteObject(sep_pen);

  // ── Logo / badge dot (left of title) ──────────────────────────────────────
  RECT dot = {14, 18, 36, 40};
  DrawRounded(dc, dot, kHeaderAccent, kHeaderAccent, 1, 20);
  SetBkMode(dc, TRANSPARENT);
  SetTextColor(dc, kHeaderBg);
  SelectObject(dc, button_font_);
  DrawTextW(dc, L"B", -1, &dot, DT_CENTER | DT_VCENTER | DT_SINGLELINE);

  // ── Title (white on dark) ──────────────────────────────────────────────────
  SelectObject(dc, title_font_);
  SetTextColor(dc, RGB(235, 240, 255));
  RECT title_rect = {46, 17, kPopupWidth - 36, 41};
  const std::wstring display_title =
      title_.empty()
          ? L"Baddel! \U0001F602 \u0646\u0633\u064A\u062A \u0627\u0644\u0643\u0644\u0627\u0641\u064A\u064A\u061F"
          : title_;
  DrawTextW(dc, display_title.c_str(), -1, &title_rect,
            DT_LEFT | DT_SINGLELINE | DT_END_ELLIPSIS);

  // ── Drag grip (top-right corner of header) ────────────────────────────────
  SetTextColor(dc, RGB(80, 105, 130));
  SelectObject(dc, label_font_);
  RECT grip = {kPopupWidth - 30, 18, kPopupWidth - 8, 42};
  DrawTextW(dc, L"⠿", -1, &grip, DT_CENTER | DT_VCENTER | DT_SINGLELINE);

  // ── Body: suggestion text ─────────────────────────────────────────────────
  SelectObject(dc, body_font_);
  SetTextColor(dc, RGB(40, 50, 70));
  RECT sug = {16, 66, kPopupWidth - 16, 118};
  DrawTextW(dc, suggestion_.c_str(), -1, &sug,
            DT_LEFT | DT_WORDBREAK | DT_END_ELLIPSIS);

  // ── Confidence row ────────────────────────────────────────────────────────
  // Pick bar color by confidence level
  COLORREF bar_color = (confidence_ < 50) ? kBarFillLow
                     : (confidence_ < 75) ? kBarFillMed
                                          : kBarFillHigh;

  // Label
  const std::wstring conf_label =
      std::to_wstring(confidence_) + L"% confidence";
  SelectObject(dc, label_font_);
  SetTextColor(dc, RGB(100, 115, 135));
  RECT conf_label_rect = {16, 120, kPopupWidth - 16, 136};
  DrawTextW(dc, conf_label.c_str(), -1, &conf_label_rect,
            DT_LEFT | DT_SINGLELINE);

  // Progress bar track + fill
  RECT bar_track = {16, 138, kPopupWidth - 16, 146};
  DrawProgressBar(dc, bar_track, confidence_, bar_color);

  // ── Buttons row ───────────────────────────────────────────────────────────
  // [ 🚀 Fasakh & Baddel ]   [ 🙈 5allini ]   [ ⏸ Pause ]
  fix_button_     = {16,  158, 210, 198};
  dismiss_button_ = {218, 158, 316, 198};
  pause_button_   = {324, 158, 404, 198};

  // Fix (primary – cyan)
  DrawRounded(dc, fix_button_, kFixFill, kFixFillDark, 1, 14);
  // Dismiss (dark navy ghost)
  DrawRounded(dc, dismiss_button_, kDismissFill, RGB(70, 90, 120), 1, 14);
  // Pause (slightly lighter navy)
  DrawRounded(dc, pause_button_, kPauseFill, RGB(60, 80, 110), 1, 14);

  SelectObject(dc, button_font_);

  // Fix label
  SetTextColor(dc, RGB(255, 255, 255));
  DrawTextW(dc, L"\U0001F680 Fasakh", -1, &fix_button_,
            DT_CENTER | DT_VCENTER | DT_SINGLELINE);

  // Dismiss label
  SetTextColor(dc, kDismissText);
  DrawTextW(dc, L"\U0001F648 5allini", -1, &dismiss_button_,
            DT_CENTER | DT_VCENTER | DT_SINGLELINE);

  // Pause label
  SetTextColor(dc, kPauseText);
  DrawTextW(dc, L"\u23F8 Pause", -1, &pause_button_,
            DT_CENTER | DT_VCENTER | DT_SINGLELINE);

  // ── Blit double buffer → screen ───────────────────────────────────────────
  BitBlt(real_dc, 0, 0, kPopupWidth, kPopupHeight, dc, 0, 0, SRCCOPY);
  SelectObject(dc, old_bm);
  DeleteObject(bm);
  DeleteDC(dc);

  EndPaint(window, &ps);
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
  if (action_handler_) action_handler_(action);
}
