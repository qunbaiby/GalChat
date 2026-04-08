# 语音识别 (ASR) 功能 Spec

## Why
玩家需要能够通过语音直接输入聊天内容，而不仅仅是打字。利用已经开通的豆包（Volcengine）一句话识别功能，可以极大提升玩家的沉浸感和交互便捷性。

## What Changes
- 添加一个基于豆包一句话识别 API 的 `DoubaoASRService` 类，用于处理语音到文本的转换。
- 在 `chat_scene.tscn` 聊天界面的输入区域添加一个“按住说话”按钮。
- 配置 Godot 的麦克风权限（`audio/driver/enable_input`）。
- 配置 Godot 的音频总线，添加一个 Record Bus，并附加 `AudioEffectRecord` 用于捕获麦克风输入。
- 实现长按语音按钮进行录音，松开后调用 ASR 服务将语音转换为文本，并填入输入框的功能。

## Impact
- Affected specs: 聊天输入系统
- Affected code:
  - `project.godot` (开启麦克风权限)
  - `default_bus_layout.tres` (添加 Record Bus)
  - `assets/scripts/api/doubao_ASR_Service.gd` (新建)
  - `assets/scenes/ui/chat/chat_scene.tscn` (新增语音按钮，挂载 ASR 和麦克风相关节点)
  - `assets/scripts/chat/dialogue_manager.gd` (处理录音逻辑和 ASR 回调)

## ADDED Requirements
### Requirement: 语音录制与识别
系统必须提供一个语音录制功能，允许玩家通过麦克风输入语音，并将其转换为文本。

#### Scenario: 玩家使用语音输入
- **WHEN** 玩家按下并按住语音录制按钮
- **THEN** 系统开始录制麦克风音频
- **WHEN** 玩家松开语音录制按钮
- **THEN** 系统停止录音，将音频发送到豆包 ASR 接口进行识别
- **WHEN** ASR 接口返回识别结果
- **THEN** 识别出的文本会自动填充到输入框中
