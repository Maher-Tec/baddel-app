#include "keyboard_hook.h"

#include <algorithm>

KeyboardHook* KeyboardHook::active_instance_ = nullptr;

KeyboardHook::~KeyboardHook() { Stop(); }

bool KeyboardHook::Start(HWND notify_window) {
  if (thread_ != nullptr || notify_window == nullptr) {
    return false;
  }

  notify_window_ = notify_window;
  ready_event_ = CreateEvent(nullptr, TRUE, FALSE, nullptr);
  stop_event_ = CreateEvent(nullptr, TRUE, FALSE, nullptr);
  if (ready_event_ == nullptr || stop_event_ == nullptr) {
    Stop();
    return false;
  }

  thread_ = CreateThread(
      nullptr, 0,
      [](LPVOID parameter) -> DWORD {
        auto* self = static_cast<KeyboardHook*>(parameter);
        self->RunHookThread(self->notify_window_);
        return 0;
      },
      this, 0, &thread_id_);
  if (thread_ == nullptr) {
    Stop();
    return false;
  }

  WaitForSingleObject(ready_event_, 2000);
  const bool started = running_.load();
  if (!started) {
    Stop();
  }
  return started;
}

void KeyboardHook::Stop() {
  if (thread_ != nullptr) {
    SetEvent(stop_event_);
    PostThreadMessage(thread_id_, WM_QUIT, 0, 0);
    WaitForSingleObject(thread_, 2000);
    CloseHandle(thread_);
    thread_ = nullptr;
  }
  if (ready_event_ != nullptr) {
    CloseHandle(ready_event_);
    ready_event_ = nullptr;
  }
  if (stop_event_ != nullptr) {
    CloseHandle(stop_event_);
    stop_event_ = nullptr;
  }
  thread_id_ = 0;
  notify_window_ = nullptr;
  running_.store(false);
  std::lock_guard<std::mutex> lock(mutex_);
  events_.clear();
}

std::vector<KeyboardHookEvent> KeyboardHook::DrainEvents() {
  std::lock_guard<std::mutex> lock(mutex_);
  std::vector<KeyboardHookEvent> events;
  events.swap(events_);
  return events;
}

void KeyboardHook::RunHookThread(HWND notify_window) {
  active_instance_ = this;
  hook_ = SetWindowsHookEx(WH_KEYBOARD_LL, HookProc, GetModuleHandle(nullptr), 0);
  SetEvent(ready_event_);
  if (hook_ == nullptr) {
    active_instance_ = nullptr;
    return;
  }
  running_.store(true);

  MSG message;
  while (WaitForSingleObject(stop_event_, 0) == WAIT_TIMEOUT &&
         GetMessage(&message, nullptr, 0, 0) > 0) {
    TranslateMessage(&message);
    DispatchMessage(&message);
  }

  UnhookWindowsHookEx(hook_);
  hook_ = nullptr;
  running_.store(false);
  active_instance_ = nullptr;
}

LRESULT CALLBACK KeyboardHook::HookProc(int code, WPARAM wparam, LPARAM lparam) {
  if (code == HC_ACTION && active_instance_ != nullptr &&
      (wparam == WM_KEYDOWN || wparam == WM_SYSKEYDOWN ||
       wparam == WM_KEYUP || wparam == WM_SYSKEYUP)) {
    const auto* data = reinterpret_cast<const KBDLLHOOKSTRUCT*>(lparam);
    const HWND foreground_window = GetForegroundWindow();
    const bool key_down = wparam == WM_KEYDOWN || wparam == WM_SYSKEYDOWN;
    const DWORD foreground_thread_id =
        GetWindowThreadProcessId(foreground_window, nullptr);
    const HKL keyboard_layout = GetKeyboardLayout(foreground_thread_id);
    const WORD language_id = LOWORD(
        reinterpret_cast<ULONG_PTR>(keyboard_layout));
    switch (data->vkCode) {
      case VK_LCONTROL:
      case VK_RCONTROL:
      case VK_CONTROL:
        active_instance_->control_down_ = key_down;
        break;
      case VK_LMENU:
      case VK_RMENU:
      case VK_MENU:
        active_instance_->alt_down_ = key_down;
        break;
      case VK_LSHIFT:
      case VK_RSHIFT:
      case VK_SHIFT:
        active_instance_->shift_down_ = key_down;
        break;
    }

    {
      std::lock_guard<std::mutex> lock(active_instance_->mutex_);
      active_instance_->events_.push_back(
          {data->vkCode, data->scanCode, data->flags, data->time,
           foreground_window, language_id, key_down,
           (data->flags & LLKHF_INJECTED) != 0,
           active_instance_->control_down_, active_instance_->alt_down_,
           active_instance_->shift_down_});
    }
    PostMessage(active_instance_->notify_window_, kKeyboardHookEventMessage, 0,
                0);

    if (key_down && data->vkCode == 'B' &&
        active_instance_->control_down_ && active_instance_->alt_down_) {
      active_instance_->manual_fix_pending_ = true;
    }
    if (key_down && data->vkCode == 'Z' &&
        active_instance_->control_down_ && active_instance_->alt_down_) {
      active_instance_->manual_undo_pending_ = true;
    }

    if (active_instance_->manual_fix_pending_) {
      // Suppress both halves of B so the target app cannot execute its own
      // Ctrl+Alt+B command while Baddel waits for the modifiers to be released.
      if (data->vkCode == 'B') {
        return 1;
      }

      if (!active_instance_->control_down_ && !active_instance_->alt_down_ &&
          !active_instance_->shift_down_) {
        active_instance_->manual_fix_pending_ = false;
        PostMessage(active_instance_->notify_window_, kManualFixMessage, 0, 0);
      }
    }

    if (active_instance_->manual_undo_pending_) {
      if (data->vkCode == 'Z') {
        return 1;
      }

      if (!active_instance_->control_down_ && !active_instance_->alt_down_ &&
          !active_instance_->shift_down_) {
        active_instance_->manual_undo_pending_ = false;
        PostMessage(active_instance_->notify_window_, kManualUndoMessage, 0, 0);
      }
    }
  }
  return CallNextHookEx(nullptr, code, wparam, lparam);
}
