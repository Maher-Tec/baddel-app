#ifndef RUNNER_KEYBOARD_HOOK_H_
#define RUNNER_KEYBOARD_HOOK_H_

#include <windows.h>

#include <atomic>
#include <mutex>
#include <vector>

constexpr UINT kKeyboardHookEventMessage = WM_APP + 1;
constexpr UINT kManualFixMessage = WM_APP + 2;
constexpr UINT kManualUndoMessage = WM_APP + 3;

struct KeyboardHookEvent {
  DWORD virtual_key;
  DWORD scan_code;
  DWORD flags;
  DWORD time;
  HWND foreground_window;
  WORD language_id;
  bool key_down;
  bool injected;
  bool control_down;
  bool alt_down;
  bool shift_down;
};

class KeyboardHook {
 public:
  KeyboardHook() = default;
  ~KeyboardHook();

  KeyboardHook(const KeyboardHook&) = delete;
  KeyboardHook& operator=(const KeyboardHook&) = delete;

  bool Start(HWND notify_window);
  void Stop();
  bool IsRunning() const { return running_.load(); }
  std::vector<KeyboardHookEvent> DrainEvents();

 private:
  static LRESULT CALLBACK HookProc(int code, WPARAM wparam, LPARAM lparam);
  void RunHookThread(HWND notify_window);

  std::mutex mutex_;
  std::vector<KeyboardHookEvent> events_;
  HANDLE ready_event_ = nullptr;
  HANDLE stop_event_ = nullptr;
  HHOOK hook_ = nullptr;
  DWORD thread_id_ = 0;
  HANDLE thread_ = nullptr;
  HWND notify_window_ = nullptr;
  std::atomic<bool> running_ = false;
  bool control_down_ = false;
  bool alt_down_ = false;
  bool shift_down_ = false;
  bool manual_fix_pending_ = false;
  bool manual_undo_pending_ = false;

  static KeyboardHook* active_instance_;
};

#endif  // RUNNER_KEYBOARD_HOOK_H_
