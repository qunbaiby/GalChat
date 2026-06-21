# Debug Session: desktop-pet-window-restore
- **Status**: [OPEN]
- **Issue**: 主界面最小化后，点击桌宠除“主界面”与“关闭桌宠”外的任意按钮，主界面仍会被意外唤起。
- **Debug Server**: http://127.0.0.1:7777/event
- **Log File**: .dbg/trae-debug-log-desktop-pet-window-restore.ndjson

## Reproduction Steps
1. 启动主界面并打开桌宠。
2. 将主界面最小化，仅保留桌宠。
3. 点击桌宠中的“音乐 / 桌宠设置 / 聊天 / 番茄钟 / 静音30分”等任意按钮。
4. 观察主界面是否被自动恢复。

## Hypotheses & Verification
| ID | Hypothesis | Likelihood | Effort | Evidence |
|----|------------|------------|--------|----------|
| A | 桌宠额外 Window 在主窗口最小化时触发系统级父窗口恢复 | High | Medium | Confirmed |
| B | 某条脚本在非“主界面”按钮链路里主动调用了 root show / windowed 恢复 | Medium | Low | Rejected |
| C | 桌宠按钮触发了全局焦点/关闭请求相关分支，间接恢复主窗口 | Medium | Medium | Rejected |
| D | root Window 的 visible/mode/unfocusable 状态在点击期间被改回可聚焦 | High | Low | Partially confirmed but not root cause |

## Log Evidence
- 日志第 7 行：点击 `桌宠设置` 前，主窗口处于 `root_mode = 1`，说明用户复现时主界面确实是最小化态。
- 日志第 8 行：未经过 `主界面` 按钮链路，主窗口直接变成 `root_mode = 0`，说明恢复首先发生在系统/窗口层。
- 日志第 9 行：`unfocusable` 从 `true -> false` 发生在主窗口已恢复之后，是连锁结果，不是首发原因。
- 本次未出现 `D:main-window-pressed` 与 `E:main-notification` 日志，排除了“主界面按钮合法恢复链”和“主场景关闭请求链”。

## Verification Conclusion
- 根因确认：Windows/Godot 对最小化的主窗口与桌宠原生 Window 存在系统级关联，点击桌宠控件会先恢复最小化父窗口。
- 修复方向：桌宠存在时不再让主窗口停留在 `MODE_MINIMIZED`，而是立即转成 `hide + unfocusable`；仅保留 `主界面` 按钮与 `关闭桌宠` 两条合法恢复链。
