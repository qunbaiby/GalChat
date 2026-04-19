# Tasks
- [x] Task 1: 配置音频环境与权限
  - [x] SubTask 1.1: 在 `project.godot` 中开启 `audio/driver/enable_input=true`。
  - [x] SubTask 1.2: 创建/修改 `default_bus_layout.tres`，添加一个名为 "Record" 的 Bus，并挂载 `AudioEffectRecord` 效果。同时将其 Mute 掉以防回音。

- [x] Task 2: 实现 Doubao ASR Service
  - [x] SubTask 2.1: 创建 `assets/scripts/api/doubao_ASR_Service.gd` 脚本。
  - [x] SubTask 2.2: 实现对 `https://openspeech.bytedance.com/api/v1/asr` 的 HTTP 请求，组装 JSON body 并将录音数据 Base64 编码。
  - [x] SubTask 2.3: 定义信号 `asr_success(text: String)` 和 `asr_failed(error_msg: String)`。

- [x] Task 3: 修改聊天界面与逻辑
  - [x] SubTask 3.1: 在 `assets/scenes/ui/chat/chat_scene.tscn` 的 `InputLayer/HBoxContainer` 中添加一个 `VoiceRecordButton`（文本例如“按住说话”）。
  - [x] SubTask 3.2: 在场景中添加一个 `AudioStreamPlayer` 节点作为麦克风捕获载体，其 Stream 设置为 `AudioStreamMicrophone`，Bus 设置为 `Record`，并开启 autoplay。
  - [x] SubTask 3.3: 在 `chat_scene.tscn` 中添加 `DoubaoASRService` 节点。
  - [x] SubTask 3.4: 修改 `assets/scripts/chat/dialogue_manager.gd`，处理按钮的 button_down 和 button_up 事件，控制 `AudioEffectRecord` 的录制。
  - [x] SubTask 3.5: 将录制到的音频保存为 WAV 临时文件并传给 `DoubaoASRService`。
  - [x] SubTask 3.6: 监听 ASR 的回调，将识别到的文本插入到 `InputField`，并清空临时录音状态。

# Task Dependencies
- [Task 2] depends on [Task 1]
- [Task 3] depends on [Task 2]
