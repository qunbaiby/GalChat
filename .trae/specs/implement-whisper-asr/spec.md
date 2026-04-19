# Implement Whisper ASR Spec

## Why
玩家希望通过语音直接输入聊天内容。基于已安装的 `godot-whisper` 插件，我们可以实现一个完全离线、本地的语音转文字（ASR）功能，这能解决之前依赖网络 API 导致的高延迟和格式拒绝问题，同时提升隐私和稳定性。

## What Changes
- **环境配置**: 开启 Godot 的全局麦克风输入权限（`audio/driver/enable_input`），并配置音频总线（`default_bus_layout.tres`）以包含 `Record` 和 `MuteBus`，挂载 `AudioEffectCapture` 用于录音。
- **ASR 服务类**: 新建 `LocalWhisperASR` 节点脚本，继承自插件的 `SpeechToText`，封装“按下录音、松开识别”的逻辑。
- **UI 恢复**: 在 `chat_scene.tscn` 的输入区重新添加 `VoiceRecordButton`（🎙 按键）和 `MicCapture` 节点。
- **逻辑绑定**: 修改 `dialogue_manager.gd` 以响应语音按键的按下与松开，调用 `LocalWhisperASR` 并通过信号接收最终识别的文本填充到输入框中。

## Impact
- Affected specs: 聊天输入系统
- Affected code:
  - `project.godot` (麦克风权限)
  - `default_bus_layout.tres` (添加 Capture 特效)
  - `scripts/api/local_whisper_asr.gd` (新建服务类)
  - `scenes/ui/chat/chat_scene.tscn` (恢复语音按钮和 ASR 节点)
  - `scripts/chat/dialogue_manager.gd` (处理录音 UI 逻辑和 ASR 回调)

## ADDED Requirements
### Requirement: 离线语音录制与识别
系统必须提供一个语音录制功能，允许玩家按住按钮说话，松开后利用本地 Whisper 模型将其转换为文本。

#### Scenario: 玩家使用本地语音输入
- **WHEN** 玩家按下并按住语音录制按钮
- **THEN** 按钮显示“松开发送”，`LocalWhisperASR` 清空缓冲区并开始捕获麦克风音频
- **WHEN** 玩家松开语音录制按钮
- **THEN** 按钮恢复原状，`LocalWhisperASR` 在后台子线程中提取缓冲区的音频并调用模型转录
- **WHEN** Whisper 模型完成转录并发出 `transcribe_completed` 信号
- **THEN** 识别出的文本会自动填充到输入框中，并提示玩家“语音识别成功”
