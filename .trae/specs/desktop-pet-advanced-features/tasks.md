# Tasks
- [x] Task 1: 创建 `window_monitor.gd` 工具类：通过 `OS.execute()` 调用 PowerShell 脚本（如 `powershell -command "(Get-Process | Where-Object {$_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -ne ''} | Select-Object MainWindowTitle).MainWindowTitle"` 或者使用更底层的 C# / C++ 扩展，考虑到这里是 GDScript，可以先用基础的 `OS.execute` 轮询）获取当前前台窗口标题。
- [x] Task 2: 在 `desktop_pet.gd` 中实现监控循环（定时器）：每隔2-3秒调用 `window_monitor`，维护当前停留窗口的名称和停留时间 `_time_since_last_switch`。
- [x] Task 3: 实现防频繁打扰机制：维护一个全局反应冷却时间（如 `_last_reaction_tick`），防止桌宠在短时间内连续发消息。
- [x] Task 4: 实现整点报时功能（Hourly Chime）：在定时器循环中增加 `_check_hourly_chime()` 检查。若当前分钟在 `0~2` 之间，且本小时未报时过，则根据当前时间段（清晨、中午、晚上、深夜）请求 AI 生成特定上下文的整点报时文案，并通过气泡弹出。
- [x] Task 5: 实现主动聊天功能（Proactive Chat）：当 `_time_since_last_switch` 超过设定的闲置时间（如 180 秒），且不在冷却期内，提取当前窗口名称，作为上下文（如“玩家正在看《某某视频》”）发送给 AI 模型，请求生成一段主动的问候或吐槽。

# Task Dependencies
- [Task 2] depends on [Task 1]
- [Task 4] depends on [Task 2]
- [Task 5] depends on [Task 3]
