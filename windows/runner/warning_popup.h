#ifndef RUNNER_WARNING_POPUP_H_
#define RUNNER_WARNING_POPUP_H_

#include <windows.h>
#include <dwrite_2.h>

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
  HFONT label_font_ = nullptr;
  HFONT button_font_ = nullptr;

  // DirectWrite objects used only to render text that may contain color
  // emoji (title and button labels). Plain GDI (HFONT/DrawTextW above) can
  // only draw glyphs in a single solid color, so it silently renders color
  // emoji fonts as plain white/mono outlines. Any of these may be null if
  // DirectWrite setup fails on a given system; callers must fall back to
  // plain DrawTextW in that case.
  IDWriteFactory2* dwrite_factory_ = nullptr;
  IDWriteGdiInterop* gdi_interop_ = nullptr;
  IDWriteRenderingParams* dwrite_rendering_params_ = nullptr;
  IDWriteBitmapRenderTarget* dwrite_bitmap_target_ = nullptr;
  IDWriteTextFormat* dwrite_title_format_ = nullptr;
  IDWriteTextFormat* dwrite_button_format_ = nullptr;

  // Draws `text` color-emoji-aware into `rect` on `dc`, compositing through
  // DirectWrite's GDI-interop color glyph path. Returns false (drawing
  // nothing) if DirectWrite is unavailable or the draw fails, so the caller
  // can fall back to plain DrawTextW.
  bool DrawColorText(HDC dc, const RECT& rect, const std::wstring& text,
                     IDWriteTextFormat* format, COLORREF color,
                     DWRITE_TEXT_ALIGNMENT align,
                     DWRITE_PARAGRAPH_ALIGNMENT valign,
                     DWRITE_WORD_WRAPPING wrapping);
};

#endif  // RUNNER_WARNING_POPUP_H_
