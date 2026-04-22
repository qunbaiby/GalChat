# Fix Pet Dialogue Chaos Spec

## Why
目前桌宠的回复存在前言不搭后语、时间认知严重错乱（中午说晚安）等问题。这主要是因为 `desktop_pet.txt` 提示词模板中存在大量与“睡觉、好困”相关的具象示例，严重污染了大模型在白天的判断逻辑；同时，部分动态语境约束不够严厉，导致大模型在拼接多段对话时逻辑断裂。

## What Changes
- 移除 `desktop_pet.txt` 中的所有具象对话示例（如“好困”、“晚安”等），替换为纯结构的抽象格式说明，彻底消除提示词污染。
- 在 `desktop_pet.gd` 中提取统一的 `_get_time_constraint` 方法，为所有的主动聊天（戳一戳、应用监控、整点报时）注入**强硬的时间约束**（如：白天绝对禁止说“晚安”或“好困”）。
- 精简并强化分段策略中的规则描述，杜绝连续括号和括号缺失。

## Impact
- Affected specs: 桌宠交互系统提示词构建、主动聊天逻辑。
- Affected code:
  - `scripts/templates/prompts/desktop_pet.txt`
  - `scripts/ui/desktop_pet/desktop_pet.gd`

## MODIFIED Requirements
### Requirement: 桌宠主动对话的时间与逻辑连贯性
The system SHALL ensure the desktop pet's proactive chats strictly adhere to the real-world time of day and never output sleepy/night-time greetings during the day.
The system SHALL output correctly formatted split dialogues without any missing or redundant action brackets.