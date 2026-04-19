# Tasks

- [x] Task 1: 扩展配置系统 (`config_resource.gd`)
  - [x] SubTask 1.1: 新增画面配置变量（resolution_idx, fps_idx, vsync_enabled）。
  - [x] SubTask 1.2: 新增音量配置变量（bgm_volume, voice_volume）。
  - [x] SubTask 1.3: 更新 `save_config` 和 `load_config` 方法，支持读写新增字段，并在加载时应用（Apply）设置。

- [x] Task 2: 重构设置界面 UI (`settings_scene.tscn`)
  - [x] SubTask 2.1: 合并原有的 API、语音、向量设置到一个 `VBoxContainer`（命名为 "AI 设置"），通过分隔符和分类标签区分。
  - [x] SubTask 2.2: 添加新的 Tab: "画面设置"，按照参考图实现分辨率、帧率、垂直同步的选择器（例如按钮组或下拉菜单）。
  - [x] SubTask 2.3: 添加新的 Tab: "声音设置"，包含 BGM 和角色语音的音量调节滑动条（HSlider）。
  - [x] SubTask 2.4: 整体美化排版，修改默认的暗色背景、调整间距、字体颜色等，使其更贴近游戏整体美术风格。

- [x] Task 3: 实现设置功能逻辑 (`settings_scene.gd`)
  - [x] SubTask 3.1: 修改 UI 数据绑定逻辑，适配整合后的 AI 设置字段读取与保存。
  - [x] SubTask 3.2: 实现“画面设置”的逻辑，监听值改变，动态应用 `DisplayServer` 窗口大小/全屏、`Engine.max_fps`、以及垂直同步开关，并在保存时写入配置。
  - [x] SubTask 3.3: 实现“声音设置”的逻辑，监听滑动条拖动，利用 `AudioServer` 改变对应的 Bus 音量。

- [x] Task 4: 主场景 BGM 支持 (`main_scene.tscn` & `main_scene.gd`)
  - [x] SubTask 4.1: 在主场景确认 `AudioStreamPlayer` 节点（名为 BGM），配置正确的音频总线（Bus = "BGM"）。
  - [x] SubTask 4.2: 配置循环播放的默认 BGM 音频资源（如果缺失的话），并在 `_ready()` 阶段自动播放。
  - [x] SubTask 4.3: 确认音频总线布局（`default_bus_layout.tres` 中包含 BGM 和 Voice 轨道）。