# Tasks

- [x] Task 1: 准备 UI 结构 - 修改 `activity_panel.tscn` 以支持日程队列
  - [x] SubTask 1.1: 在 `activity_panel.tscn` 中新增一个区域（如 `HBoxContainer`），内部包含 7 个空的槽位（例如用 `Button` 或带有边框的 `ColorRect` + `Label`）。
  - [x] SubTask 1.2: 在该区域下方添加一个“执行安排”按钮（默认禁用）。
  - [x] SubTask 1.3: 更新 `activity_panel.gd`，引入一个数组 `scheduled_activities` 记录已选课程的 ID，并新增刷新这 7 个槽位显示的逻辑。

- [x] Task 2: 交互逻辑 - 添加与移除日程
  - [x] SubTask 2.1: 修改 `activity_panel.gd` 中课程列表按钮的点击事件 `_on_activity_pressed`，将所选课程 ID 追加到 `scheduled_activities` 中（最大 7 个），并更新槽位 UI。
  - [x] SubTask 2.2: 为 7 个槽位添加点击事件。如果槽位内有已安排的课程，点击后将其从数组中移除，并重新渲染 7 个槽位。
  - [x] SubTask 2.3: 当 `scheduled_activities` 满 7 个时，启用“执行安排”按钮，否则禁用。

- [x] Task 3: 准备执行界面 - 创建 `schedule_execution_panel.tscn`
  - [x] SubTask 3.1: 创建一个新的 UI 场景 `assets/scenes/ui/schedule_execution_panel.tscn`。
  - [x] SubTask 3.2: 界面应包含：“当前天数（第 X 天）”的 Label、当前正在执行的“课程名称”Label、以及用于展示收益结果的文本区域。
  - [x] SubTask 3.3: 添加一个占据全屏或在下方的巨大按钮（“继续”或“点击继续”），用于推进下一天的行程。

- [x] Task 4: 执行逻辑 - 逐日结算
  - [x] SubTask 4.1: 在 `schedule_execution_panel.gd` 中实现一个 `start_execution(activities: Array)` 方法，接收玩家安排的 7 个课程 ID，初始化当前天数 `current_day = 1`。
  - [x] SubTask 4.2: 当玩家点击“继续”时，调用 `ActivityManager.execute_activity` 执行第 `current_day` 天的课程，将结果文字显示在界面上，并将 `current_day` 加 1。
  - [x] SubTask 4.3: 如果 `current_day` 超过 7，显示“本周安排执行完毕”，并将按钮文本改为“完成”。再次点击时关闭面板，并重新打开或返回主界面。

- [x] Task 5: 整合与联调
  - [x] SubTask 5.1: 在 `activity_panel.gd` 中，当玩家点击“执行安排”时，隐藏或销毁当前面板，并实例化/显示 `schedule_execution_panel.tscn`，传入那 7 个选定的课程。
  - [x] SubTask 5.2: 在执行完毕后，确保 `activity_panel` 的队列被清空，为下周做准备。
  - [x] SubTask 5.3: 为了平衡系统，如果“精力 (Energy)”系统暂时不被强调，可以在 `activity_manager.gd` 的 `execute_activity` 中移除精力的硬性限制，或者在跨周时恢复精力，保持执行的顺畅。

# Task Dependencies
- [Task 2] depends on [Task 1]
- [Task 3] depends on [Task 2]
- [Task 4] depends on [Task 3]
- [Task 5] depends on [Task 4]