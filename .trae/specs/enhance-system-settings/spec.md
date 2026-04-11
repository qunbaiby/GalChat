# 系统设置及音画优化 Spec

## Why
当前的设置界面中将 AI 相关的配置分散在多个 Tab，且缺乏大多数游戏必备的“画面设置”和“音量设置”。为了提升玩家体验和游戏完善度，需要对设置界面进行重构与扩充。

## What Changes
- **AI设置整合**：将现有的“API设置”、“语音设置”、“向量设置”合并到一个名为“AI 设置”的统一 Tab 下，并在内部使用分类标题（如 `Label` 或 `HSeparator`）进行视觉区分。
- **界面样式优化**：优化整个设置面板的 UI 排版与样式（例如按钮、滑动条、背景等），使其更贴合现有的 UI 风格。
- **新增画面设置**：
  - 分辨率选项：1600x900、1920x1080、全屏幕。
  - 画面帧数选项：30 FPS、60 FPS、120 FPS。
  - 垂直同步选项：关闭、开启。
- **新增音量设置**：
  - BGM（背景音乐）音量调节。
  - 角色语音音量调节。
- **主场景音乐**：进入主场景（`main_scene.tscn`）时自动播放背景音乐（BGM），并受音量设置控制。
- **持久化保存**：在 `config_resource.gd` 中新增音画相关配置字段并加入 JSON 本地读写逻辑。

## Impact
- Affected specs: System Configuration, UI Flow, Audio/Video Management
- Affected code:
  - `scenes/ui/settings/settings_scene.tscn` & `scripts/ui/settings/settings_scene.gd`
  - `scripts/data/config_resource.gd`
  - `scenes/ui/main/main_scene.tscn` & `scripts/ui/main/main_scene.gd`

## ADDED Requirements
### Requirement: 画面控制
系统应能够根据玩家选择实时切换游戏窗口尺寸、全屏模式，修改引擎的 `Engine.max_fps` 和 `DisplayServer.window_set_vsync_mode`。

### Requirement: 音频控制
系统应能够通过 `AudioServer` 或者直接调节对应 `AudioStreamPlayer` 的 `volume_db`，控制全局 BGM 和角色配音的音量大小。
