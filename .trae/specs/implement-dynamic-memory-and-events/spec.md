# Implement Dynamic Memory and Events Spec

## Why
目前游戏在长线陪伴感和日程安排的趣味性上还有提升空间。为了增强 Luna 的“在意感”并打破单轮聊天的割裂感，我们需要引入“动态记忆与玩家画像系统”；为了填补日程安排过程中的枯燥感，我们需要引入“基于日程安排的动态文字冒险事件”。这两个系统将极大增强游戏的沉浸感和可玩性。

## What Changes
- **动态记忆系统 (Dynamic Memory System)**
  - 新增 `memory_manager.gd` 模块，负责管理玩家画像和关键实体的本地存储。
  - 在大模型聊天返回后，后台静默触发一次记忆提取（可选频率或单独的 Prompt 管道），将关键信息存入 `GameDataManager.profile.memories`。
  - 在生成日常聊天、主动问候等 Prompt 时，注入相关的记忆上下文。
- **日程动态事件系统 (Schedule Dynamic Events)**
  - 新增 `schedule_event_manager.gd` 模块和 `schedule_event_panel.tscn` UI 界面。
  - 在 `schedule_execution_panel.gd` 的课程推进逻辑中，按一定概率（如 20%）触发突发事件。
  - 触发事件时，暂停进度，调用大模型结合当前课程和 Luna 状态生成事件描述及 2 个选项。
  - 玩家选择后，大模型生成结果并转化为实际属性增减。

## Impact
- Affected specs: Chat System, Schedule System, Save/Load System.
- Affected code:
  - `scripts/autoload/game_data_manager.gd` (注册新 Manager)
  - `scripts/api/deepseek_client.gd` (增加记忆提取和事件生成的 API)
  - `scripts/ui/activity/schedule_execution_panel.gd` (集成事件触发机制)
  - `scripts/data/character_profile.gd` (增加记忆存储结构)

## ADDED Requirements
### Requirement: Dynamic Memory Extraction and Recall
The system SHALL quietly extract key entities (likes, dislikes, recent activities) from user messages and store them. When generating future responses, the system SHALL include these memories in the system prompt so the character can proactively mention them.

#### Scenario: Success case
- **WHEN** user says "我明天要早起去开会"
- **THEN** system extracts {"event": "明天早起开会"} and next day's morning greeting includes a reference to the meeting.

### Requirement: Schedule Dynamic Events
The system SHALL occasionally pause the schedule execution to present an AI-generated event related to the current activity.

#### Scenario: Success case
- **WHEN** schedule progresses to slot 3
- **THEN** 20% chance to pause, show a narrative event with 2 choices. After selection, apply stat changes and resume schedule.