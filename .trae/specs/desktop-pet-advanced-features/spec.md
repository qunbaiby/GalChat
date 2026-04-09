# Desktop Pet Advanced Features Spec

## Why
目前桌宠虽然有了对话和语音功能，但还缺乏足够的自主性和对用户当前行为的感知能力，显得较为被动。为了提升桌宠的陪伴感，使其更像一个活在用户电脑里的智能生命，需要引入基于 `gameplay_analysis_pyrrha.md` 分析报告中的主动聊天、窗口监控和整点报时功能。

## What Changes
- **窗口监控 (Window Monitoring)**：在桌宠内部实现定时器轮询，通过调用操作系统的命令行工具（如 Windows 下的 PowerShell 脚本）获取当前前台窗口的进程名和标题。
- **状态维护与过滤**：维护当前活跃窗口的状态，设置事件冷却时间（Cooldown）以防频繁触发对话。
- **主动聊天 (Proactive Chat)**：当用户在某个应用停留时间过长（如闲置或专注工作超过一定时间）时，桌宠会主动发起话题。
- **整点报时 (Hourly Chime)**：利用内部的监控循环，在到达整点（允许一定的容错范围，如0-2分钟）时，结合当前时间段（清晨、午后、深夜等）主动进行报时和关怀。

## Impact
- Affected specs: `desktop-pet-enhancement`
- Affected code:
  - `e:\GalChat_APP\scripts\ui\desktop_pet\desktop_pet.gd`
  - 新增 `e:\GalChat_APP\scripts\utils\window_monitor.gd` (负责与系统交互获取窗口信息)

## ADDED Requirements
### Requirement: Background Window Monitoring
The system SHALL periodically (e.g., every 2 seconds) query the OS for the active foreground window title and process name.

### Requirement: Hourly Chime
The desktop pet SHALL proactively initiate a dialogue at the top of every hour.
#### Scenario: Midnight Chime
- **WHEN** the system time reaches 00:00 (with a 2-minute tolerance)
- **THEN** the pet automatically generates and displays a chat bubble reminding the user to rest, using the current relationship context.

### Requirement: Proactive Interaction
The desktop pet SHALL initiate conversation when the user has been idle or focused on a single app for a prolonged period.
#### Scenario: Long focus session
- **WHEN** the user stays in an application (e.g., "Visual Studio Code") for more than 5 minutes
- **THEN** the pet triggers a prompt request to the LLM mentioning the app name, and displays the generated proactive greeting.
