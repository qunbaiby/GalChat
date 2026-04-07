# Weekly Schedule System Spec

## Why
目前游戏中的“行程安排”是点击后立刻执行并结算收益，缺乏策略感和期待感。参考《火山的女儿》的经典养成设计，将活动改为“按周安排”的机制，玩家需要提前安排好未来7天的日程，确认无误后进入一段专属的“执行展示”阶段，每天推进一次日程并结算收益。这样可以大幅提升养成的仪式感和可玩性。

## What Changes
- **日程列表机制 (Schedule Queue)**：
  - 在行程面板 (`activity_panel.tscn`) 新增一个包含 7 个槽位的日程队列 UI。
  - 玩家点击左侧/下方的课程列表时，课程会被添加到日程队列的空槽位中。
  - 玩家点击已安排的槽位时，会将其从队列中移除（撤销）。
- **日程执行界面 (Schedule Execution Panel)**：
  - 新增 `schedule_execution_panel.tscn` 场景。
  - 当 7 个槽位排满后，玩家点击“执行安排”按钮，进入此界面。
  - 该界面将按天（1 到 7）逐一展示当前执行的课程、结算收益（如：体能活力 +20）。
  - 玩家每次点击按钮/屏幕，向前推进一天。
- **机制调整 (Mechanics)**：
  - 将原有的单次扣除“精力 (Energy)”的机制淡化或重构，以“每周 7 次行动机会”作为主要限制。
  - `activity_manager.gd` 不再在单次点击时立刻生效，而是提供批量/逐次结算的支持。

## Impact
- Affected specs: 行程面板的交互逻辑 (`activity_panel.gd`)。
- Affected code: `activity_panel.tscn`, `activity_panel.gd`, 新增 `schedule_execution_panel.tscn`。

## ADDED Requirements
### Requirement: 七日行程安排
The system SHALL allow players to queue up to 7 activities before executing them.
- **WHEN** user clicks an activity in the list
- **THEN** the activity is added to the next available slot in the schedule queue.
- **WHEN** user clicks a filled slot in the schedule queue
- **THEN** the activity is removed from that slot.

### Requirement: 逐日执行反馈
The system SHALL present a step-by-step execution sequence for the 7 scheduled activities.
- **WHEN** the 7-day schedule is full and user clicks "Execute"
- **THEN** the game transitions to an execution panel showing Day 1's activity.
- **WHEN** the user clicks to proceed
- **THEN** the game processes Day 1's activity, applies stats, shows the result, and moves to Day 2, until Day 7 is completed.

## MODIFIED Requirements
### Requirement: 课程点击逻辑
**Reason**: 改变了原有的即时执行逻辑。
**Migration**: `activity_panel.gd` 中 `_on_activity_pressed` 将不再直接调用 `activity_manager.execute_activity`，而是向数组中添加数据，并在 UI 上更新槽位。