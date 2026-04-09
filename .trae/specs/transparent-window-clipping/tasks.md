# Tasks
- [x] Task 1: 实现核心裁剪算法 `_update_mouse_passthrough`
  - [x] SubTask 1.1: 在 `desktop_pet.gd` 中新增 `_update_mouse_passthrough` 函数。
  - [x] SubTask 1.2: 获取 `PetContainer`、`HBoxContainer` 以及 `SpeechBubble` (当可见时) 的 `get_global_rect()`，为了点击体验稍微 `grow(5)` 放宽边界。
  - [x] SubTask 1.3: 实现零宽桥接 (zero-width bridge) 算法，把多个独立的矩形连接成一个闭合的 `PackedVector2Array` 传递给 `DisplayServer.window_set_mouse_passthrough`。
- [x] Task 2: 在适当时机触发更新
  - [x] SubTask 2.1: 在 `_ready()` 中使用 `call_deferred("_update_mouse_passthrough")`。
  - [x] SubTask 2.2: 在 `_ready()` 中监听 `speech_bubble.visibility_changed` 信号，使其绑定到 `_update_mouse_passthrough`。
  - [x] SubTask 2.3: （可选）如果在发送消息或者动画切换时有窗口大小变动，确保触发 `_update_mouse_passthrough()`（当前布局下不涉及变动，仅由可见性控制）。

# Task Dependencies
- [Task 2] depends on [Task 1]
