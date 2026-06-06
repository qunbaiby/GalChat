# 新增手机固定聊天模式 Spec

## Why
当前手机聊天是完全自由开放的 AI 对话。为了更好地控制游戏剧情节奏，需要引入“固定聊天模式”。在该模式下，玩家无法自由输入文本，也不会调用 AI，而是通过预设的固定对话选项推进剧情。这使得开发者可以精准投放特定的剧情信息（如图片、系统提示等），增强剧情体验。

## What Changes
- 新增 `MobileFixedChatManager` 全局管理器，用于加载和管理固定聊天剧本状态。
- 新增一段固定聊天剧本（静邀请玩家带 Luna 去图书馆）。
- 在 `DebugPanel` 中添加自由对话模式的开关，以及触发固定剧本的测试按钮。
- 在 `MobileChatPanel` 中适配固定聊天模式：
  - 关闭自由对话时，禁用输入框输入。
  - 轮到玩家发言时，在输入框上方显示固定选项。
  - 选择选项后，文本填入输入框，点击发送推进固定剧情。
- 在 `MainScene` 的微聊按钮上增加未读固定消息红点和晃动动画。
- 在 `mobile_contact_list` 中为有固定消息的角色添加红点提示。

## Impact
- Affected specs: 手机微聊系统, 主界面状态, 调试面板。
- Affected code:
  - `mobile_chat_panel.gd` & `.tscn`
  - `mobile_contact_list.gd` & `.tscn`
  - `main_scene.gd` & `.tscn`
  - `debug_panel.gd` & `.tscn`
  - 新增 `mobile_fixed_chat_manager.gd`
  - 新增 `jing_piano_practice_invite.json`

## ADDED Requirements
### Requirement: 固定聊天触发与表现
- **WHEN** 固定剧情被触发时
- **THEN** 主界面微聊按钮出现红点并晃动，联系人列表中对应角色出现红点。
- **WHEN** 进入该角色的聊天面板时
- **THEN** 根据剧本自动播放对方的消息。
- **WHEN** 轮到玩家选项时
- **THEN** 输入框上方显示选项，玩家选择后，内容填入输入框，点击发送继续。
- **WHEN** 剧本结束时
- **THEN** 发送系统消息“本轮对话已结束”。

## MODIFIED Requirements
### Requirement: 自由聊天开关
- 默认关闭自由聊天。
- 当自由聊天关闭时，聊天面板禁止手动输入文本，发送按钮仅在固定选项被选中并填入输入框后有效。
