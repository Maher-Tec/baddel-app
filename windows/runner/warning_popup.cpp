#include "warning_popup.h"

#include <windowsx.h>

#include <utility>

namespace {
constexpr wchar_t kWarningPopupClass[] = L"BaddelWarningPopup";
constexpr int kPopupWidth = 420;
constexpr int kPopupHeight = 244;

// Minimal IDWriteTextRenderer that draws each glyph run through
// IDWriteFactory2::TranslateColorGlyphRun so color-emoji layers (e.g.
// Segoe UI Emoji's COLR/CPAL glyphs) render in their real palette colors
// instead of a single solid text color. Falls back to a plain single-color
// draw for any run TranslateColorGlyphRun reports has no color layers.
class ColorGlyphRenderer : public IDWriteTextRenderer {
 public:
  ColorGlyphRenderer(IDWriteFactory2* factory,
                     IDWriteBitmapRenderTarget* target,
                     IDWriteRenderingParams* rendering_params,
                     COLORREF fallback_color)
      : factory_(factory),
        target_(target),
        rendering_params_(rendering_params),
        fallback_color_(fallback_color) {}

  // IUnknown
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** object) override {
    if (iid == __uuidof(IUnknown) || iid == __uuidof(IDWritePixelSnapping) ||
        iid == __uuidof(IDWriteTextRenderer)) {
      *object = this;
      return S_OK;
    }
    *object = nullptr;
    return E_NOINTERFACE;
  }
  ULONG STDMETHODCALLTYPE AddRef() override { return 1; }
  ULONG STDMETHODCALLTYPE Release() override { return 1; }

  // IDWritePixelSnapping
  HRESULT STDMETHODCALLTYPE IsPixelSnappingDisabled(void*, BOOL* is_disabled) override {
    *is_disabled = FALSE;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE GetCurrentTransform(void*, DWRITE_MATRIX* transform) override {
    *transform = {1, 0, 0, 1, 0, 0};
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE GetPixelsPerDip(void*, FLOAT* pixels_per_dip) override {
    *pixels_per_dip = 1.0f;
    return S_OK;
  }

  // IDWriteTextRenderer
  HRESULT STDMETHODCALLTYPE DrawGlyphRun(
      void*, FLOAT baseline_x, FLOAT baseline_y,
      DWRITE_MEASURING_MODE measuring_mode, DWRITE_GLYPH_RUN const* glyph_run,
      DWRITE_GLYPH_RUN_DESCRIPTION const*, IUnknown*) override {
    IDWriteColorGlyphRunEnumerator* layers = nullptr;
    const HRESULT translate_result = factory_->TranslateColorGlyphRun(
        baseline_x, baseline_y, glyph_run, nullptr, measuring_mode, nullptr,
        0, &layers);
    if (translate_result == DWRITE_E_NOCOLOR || layers == nullptr) {
      return target_->DrawGlyphRun(baseline_x, baseline_y, measuring_mode,
                                   glyph_run, rendering_params_,
                                   fallback_color_, nullptr);
    }
    if (FAILED(translate_result)) return translate_result;

    HRESULT result = S_OK;
    for (;;) {
      BOOL has_run = FALSE;
      result = layers->MoveNext(&has_run);
      if (FAILED(result) || !has_run) break;

      const DWRITE_COLOR_GLYPH_RUN* layer = nullptr;
      result = layers->GetCurrentRun(&layer);
      if (FAILED(result)) break;

      const COLORREF layer_color =
          layer->paletteIndex == 0xFFFF
              ? fallback_color_
              : RGB(static_cast<BYTE>(layer->runColor.r * 255),
                    static_cast<BYTE>(layer->runColor.g * 255),
                    static_cast<BYTE>(layer->runColor.b * 255));
      result = target_->DrawGlyphRun(
          layer->baselineOriginX, layer->baselineOriginY, measuring_mode,
          &layer->glyphRun, rendering_params_, layer_color, nullptr);
      if (FAILED(result)) break;
    }
    layers->Release();
    return result;
  }
  HRESULT STDMETHODCALLTYPE DrawUnderline(void*, FLOAT, FLOAT,
                                          DWRITE_UNDERLINE const*,
                                          IUnknown*) override {
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE DrawStrikethrough(void*, FLOAT, FLOAT,
                                              DWRITE_STRIKETHROUGH const*,
                                              IUnknown*) override {
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE DrawInlineObject(void*, FLOAT, FLOAT,
                                             IDWriteInlineObject*, BOOL, BOOL,
                                             IUnknown*) override {
    return S_OK;
  }

 private:
  IDWriteFactory2* factory_;
  IDWriteBitmapRenderTarget* target_;
  IDWriteRenderingParams* rendering_params_;
  COLORREF fallback_color_;
};

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

  // DirectWrite setup for color-emoji-aware text (title, buttons). Any
  // failure here leaves the relevant pointer null; DrawColorText checks for
  // that and callers fall back to plain GDI DrawTextW, so this can never
  // break the popup even on a system where DirectWrite is unavailable.
  if (SUCCEEDED(DWriteCreateFactory(
          DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory2),
          reinterpret_cast<IUnknown**>(&dwrite_factory_))) &&
      dwrite_factory_ != nullptr) {
    dwrite_factory_->GetGdiInterop(&gdi_interop_);
    dwrite_factory_->CreateRenderingParams(&dwrite_rendering_params_);
    if (gdi_interop_ != nullptr) {
      gdi_interop_->CreateBitmapRenderTarget(nullptr, kPopupWidth,
                                             kPopupHeight,
                                             &dwrite_bitmap_target_);
    }
    dwrite_factory_->CreateTextFormat(
        L"Segoe UI", nullptr, DWRITE_FONT_WEIGHT_BOLD,
        DWRITE_FONT_STYLE_NORMAL, DWRITE_FONT_STRETCH_NORMAL, 16.0f, L"",
        &dwrite_title_format_);
    dwrite_factory_->CreateTextFormat(
        L"Segoe UI", nullptr, DWRITE_FONT_WEIGHT_BOLD,
        DWRITE_FONT_STYLE_NORMAL, DWRITE_FONT_STRETCH_NORMAL, 13.0f, L"",
        &dwrite_button_format_);
  }
}

WarningPopup::~WarningPopup() {
  if (window_ != nullptr) DestroyWindow(window_);
  DeleteObject(title_font_);
  DeleteObject(body_font_);
  DeleteObject(label_font_);
  DeleteObject(button_font_);

  if (dwrite_button_format_ != nullptr) dwrite_button_format_->Release();
  if (dwrite_title_format_ != nullptr) dwrite_title_format_->Release();
  if (dwrite_bitmap_target_ != nullptr) dwrite_bitmap_target_->Release();
  if (dwrite_rendering_params_ != nullptr) dwrite_rendering_params_->Release();
  if (gdi_interop_ != nullptr) gdi_interop_->Release();
  if (dwrite_factory_ != nullptr) dwrite_factory_->Release();
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
    // Keep focus in the app where the user is typing. Activating this helper
    // window makes the native selection check fail when they press Correct.
    AnimateWindow(window_, 140, AW_SLIDE | AW_VER_NEGATIVE);
  }
  InvalidateRect(window_, nullptr, TRUE);
  return true;
}

void WarningPopup::Hide() {
  if (window_ != nullptr) ShowWindow(window_, SW_HIDE);
}

bool WarningPopup::DrawColorText(HDC dc, const RECT& rect,
                                 const std::wstring& text,
                                 IDWriteTextFormat* format, COLORREF color,
                                 DWRITE_TEXT_ALIGNMENT align,
                                 DWRITE_PARAGRAPH_ALIGNMENT valign,
                                 DWRITE_WORD_WRAPPING wrapping) {
  if (dwrite_factory_ == nullptr || dwrite_bitmap_target_ == nullptr ||
      format == nullptr || text.empty()) {
    return false;
  }

  IDWriteTextLayout* layout = nullptr;
  const HRESULT layout_result = dwrite_factory_->CreateTextLayout(
      text.c_str(), static_cast<UINT32>(text.size()), format,
      static_cast<FLOAT>(rect.right - rect.left),
      static_cast<FLOAT>(rect.bottom - rect.top), &layout);
  if (FAILED(layout_result) || layout == nullptr) return false;

  layout->SetTextAlignment(align);
  layout->SetParagraphAlignment(valign);
  layout->SetWordWrapping(wrapping);

  // The bitmap render target owns its own private surface, not `dc`'s
  // bitmap, so copy the popup's current painted content into it first —
  // otherwise the color glyph layers would composite onto a blank surface
  // and erase whatever is already drawn behind the text.
  HDC target_dc = dwrite_bitmap_target_->GetMemoryDC();
  BitBlt(target_dc, 0, 0, kPopupWidth, kPopupHeight, dc, 0, 0, SRCCOPY);

  ColorGlyphRenderer renderer(dwrite_factory_, dwrite_bitmap_target_,
                              dwrite_rendering_params_, color);
  const HRESULT draw_result =
      layout->Draw(nullptr, &renderer, static_cast<FLOAT>(rect.left),
                   static_cast<FLOAT>(rect.top));
  layout->Release();
  if (FAILED(draw_result)) return false;

  BitBlt(dc, 0, 0, kPopupWidth, kPopupHeight, target_dc, 0, 0, SRCCOPY);
  return true;
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
  RECT header = {0, 0, kPopupWidth, 72};
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
  MoveToEx(dc, 0, 72, nullptr);
  LineTo(dc, kPopupWidth, 72);
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
  RECT title_rect = {46, 12, kPopupWidth - 38, 62};
  const std::wstring display_title =
      title_.empty()
          ? L"Baddel! \U0001F602 \u0646\u0633\u064A\u062A \u0627\u0644\u0643\u0644\u0627\u0641\u064A\u064A\u061F"
          : title_;
  if (!DrawColorText(dc, title_rect, display_title, dwrite_title_format_,
                     RGB(235, 240, 255), DWRITE_TEXT_ALIGNMENT_LEADING,
                     DWRITE_PARAGRAPH_ALIGNMENT_NEAR,
                     DWRITE_WORD_WRAPPING_WRAP)) {
    DrawTextW(dc, display_title.c_str(), -1, &title_rect,
              DT_LEFT | DT_WORDBREAK | DT_END_ELLIPSIS);
  }

  // ── Drag grip (top-right corner of header) ────────────────────────────────
  SetTextColor(dc, RGB(80, 105, 130));
  SelectObject(dc, label_font_);
  RECT grip = {kPopupWidth - 30, 24, kPopupWidth - 8, 48};
  DrawTextW(dc, L"⠿", -1, &grip, DT_CENTER | DT_VCENTER | DT_SINGLELINE);

  // ── Body: suggestion text ─────────────────────────────────────────────────
  SelectObject(dc, body_font_);
  SetTextColor(dc, RGB(40, 50, 70));
  RECT sug = {16, 80, kPopupWidth - 16, 142};
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
  RECT conf_label_rect = {16, 146, kPopupWidth - 16, 162};
  DrawTextW(dc, conf_label.c_str(), -1, &conf_label_rect,
            DT_LEFT | DT_SINGLELINE);

  // Progress bar track + fill
  RECT bar_track = {16, 164, kPopupWidth - 16, 172};
  DrawProgressBar(dc, bar_track, confidence_, bar_color);

  // ── Buttons row ───────────────────────────────────────────────────────────
  // [ 🚀 Fasakh & Baddel ]   [ 🙈 5allini ]   [ ⏸ Pause ]
  fix_button_     = {16,  188, 210, 228};
  dismiss_button_ = {218, 188, 316, 228};
  pause_button_   = {324, 188, 404, 228};

  // Fix (primary – cyan)
  DrawRounded(dc, fix_button_, kFixFill, kFixFillDark, 1, 14);
  // Dismiss (dark navy ghost)
  DrawRounded(dc, dismiss_button_, kDismissFill, RGB(70, 90, 120), 1, 14);
  // Pause (slightly lighter navy)
  DrawRounded(dc, pause_button_, kPauseFill, RGB(60, 80, 110), 1, 14);

  SelectObject(dc, button_font_);

  // Fix label
  SetTextColor(dc, RGB(255, 255, 255));
  if (!DrawColorText(dc, fix_button_, L"\U0001F680 Correct it",
                     dwrite_button_format_, RGB(255, 255, 255),
                     DWRITE_TEXT_ALIGNMENT_CENTER,
                     DWRITE_PARAGRAPH_ALIGNMENT_CENTER,
                     DWRITE_WORD_WRAPPING_NO_WRAP)) {
    DrawTextW(dc, L"\U0001F680 Correct it", -1, &fix_button_,
              DT_CENTER | DT_VCENTER | DT_SINGLELINE);
  }

  // Dismiss label
  SetTextColor(dc, kDismissText);
  if (!DrawColorText(dc, dismiss_button_, L"\U0001F648 5allini",
                     dwrite_button_format_, kDismissText,
                     DWRITE_TEXT_ALIGNMENT_CENTER,
                     DWRITE_PARAGRAPH_ALIGNMENT_CENTER,
                     DWRITE_WORD_WRAPPING_NO_WRAP)) {
    DrawTextW(dc, L"\U0001F648 5allini", -1, &dismiss_button_,
              DT_CENTER | DT_VCENTER | DT_SINGLELINE);
  }

  // Pause label
  SetTextColor(dc, kPauseText);
  if (!DrawColorText(dc, pause_button_, L"\u23F8 Pause", dwrite_button_format_,
                     kPauseText, DWRITE_TEXT_ALIGNMENT_CENTER,
                     DWRITE_PARAGRAPH_ALIGNMENT_CENTER,
                     DWRITE_WORD_WRAPPING_NO_WRAP)) {
    DrawTextW(dc, L"\u23F8 Pause", -1, &pause_button_,
              DT_CENTER | DT_VCENTER | DT_SINGLELINE);
  }

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
