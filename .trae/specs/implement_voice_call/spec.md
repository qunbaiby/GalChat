# Voice Call Feature Spec

## Why
玩家希望在手机聊天界面中能够与角色进行更具沉浸感的语音通话。通过模拟真实的语音通话界面，逐字显示没有括号动作描述的文本，并同步播放角色的语音，可以大幅提升伴侣养成游戏的代入感和真实感。

## What Changes
- **新增语音通话界面**：在手机聊天右上角新增语音通话按钮，点击后进入语音通话专属界面。
- **角色头像集成**：在 `luna.json` 和 `ya.json` 中配置角色头像路径，并在普通手机聊天和语音通话界面中显示该头像。
- **纯净文本显示与语音播放**：语音通话界面的消息不显示括号动作描述，消息逐字显示，并同时播放语音（TTS）。
- **玩家语音输入与逐字显示**：语音通话界面右下角新增语音输入按钮（角色讲话时禁用）。玩家按住录音，松开后通过 ASR 识别为文字，文字在屏幕上逐字显示完毕后，轮到角色回应。
- **消息拆分逻辑优化**：优化普通手机聊天和语音对话的消息拆分逻辑，确保 Voice Call 也能正确处理多段消息（按段落顺序逐字显示并播放）。

## Impact
- Affected specs: 手机聊天功能、TTS/ASR语音交互功能。
- Affected code: 
  - `mobile_chat_panel.tscn` / `mobile_chat_panel.gd`
  - 新增 `voice_call_panel.tscn` / `voice_call_panel.gd`
  - `luna.json` / `ya.json`

## ADDED Requirements
### Requirement: Voice Call Interface
The system SHALL provide a Voice Call Interface that can be toggled from the Mobile Chat Panel.

#### Scenario: Enter Voice Call
- **WHEN** the user clicks the voice call button in the mobile chat
- **THEN** the UI switches to the voice call layout, displaying the character's avatar, name, and "通话中" status.

#### Scenario: Character Speaking in Voice Call
- **WHEN** the character sends a message
- **THEN** the message text (stripped of bracketed actions) is displayed character by character, accompanied by TTS voice playback. The player's record button is disabled during this time.

#### Scenario: Player Speaking in Voice Call
- **WHEN** it is the player's turn and they hold the record button
- **THEN** the system records their voice. Upon release, the audio is transcribed via ASR. The resulting text is displayed character by character. Once fully displayed, the message is sent to the AI character.