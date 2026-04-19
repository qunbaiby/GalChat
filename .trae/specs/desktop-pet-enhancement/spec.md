# Desktop Pet Enhancement Spec

## Why
目前桌宠玩法较为基础，缺乏与主线剧情（情感阶段、性格演化、记忆）的深度绑定。同时，原有的简单文本显示方式不够生动，缺少语音反馈和灵动的气泡表现。为了让桌宠更具沉浸感和陪伴感，需要同步主游戏的 AI 上下文设定，并引入动态气泡 UI 与豆包语音（TTS）支持。

## What Changes
- 优化桌宠提示词，使其全面继承主游戏的背景、性格、记忆和情感阶段设定（但不共享聊天记录）。
- 重构桌宠的对话 UI，移除原有的底部文字框，改为角色头顶动态生成的气泡列表。
- 气泡支持打字机效果、动作描写绿色高亮（如 `（微笑）`），并能通过 `[SPLIT]` 拆分为多个独立堆叠的气泡（最多同时显示3个，带有平滑上移动画）。
- 接入豆包语音（TTS），在生成气泡文字的同时播放对应的语音。
- 分析 `Pyrrha.gd` 源码，提取可用的进阶玩法设计（如窗口监控、主动搭话、视觉感知等），为后续开发提供参考方案。

## Impact
- Affected specs: `desktop-pet-system`
- Affected code:
  - `e:\GalChat_APP\scripts\templates\prompts\desktop_pet.txt`
  - `e:\GalChat_APP\scenes\ui\desktop_pet\desktop_pet.tscn`
  - `e:\GalChat_APP\scripts\ui\desktop_pet\desktop_pet.gd`

## ADDED Requirements
### Requirement: Dynamic Chat Bubble UI
The system SHALL display AI responses in floating, stacked chat bubbles above the pet.
#### Scenario: Multi-segment response
- **WHEN** the AI replies with multiple sentences separated by `[SPLIT]`
- **THEN** multiple bubbles are instantiated sequentially, with older bubbles animating upwards. Text types out character by character.

### Requirement: Doubao TTS Integration
The system SHALL play generated audio for each text segment.

## MODIFIED Requirements
### Requirement: Desktop Pet AI Context
The desktop pet AI prompt SHALL include comprehensive relationship and memory context, matching the main game, while maintaining an isolated short-term chat history array specifically for the desktop session.
