# Whisper 语音识别模型下载与配置指南

当前项目已经集成了 `godot-whisper` 离线语音转文字功能。为了让它正常工作，你还需要下载一个 Whisper 语言模型（`.bin` 文件）。

## 1. 下载模型
Godot-Whisper 插件自带了模型下载工具。
1. 在 Godot 编辑器的顶部菜单栏，找到 **Project (项目)** -> **Tools (工具)** -> **Whisper Downloader** （如果有该菜单）。
2. 如果没有，可以在任何场景（比如新建一个测试场景）中添加一个 `CaptureStreamToText` 节点，点击它，在检查器中会出现“Download”按钮。
3. 选择 `tiny` 模型并点击下载。模型会被下载到 `res://addons/godot_whisper/models/` 目录下。

> 注意：如果内置下载器因为网络问题失败，你可以手动前往 [HuggingFace (ggerganov/whisper.cpp)](https://huggingface.co/ggerganov/whisper.cpp/tree/main) 下载 `ggml-tiny.bin`，并将其放入项目的文件夹中。

## 2. 配置模型
1. 打开 `res://scenes/ui/chat/chat_scene.tscn`。
2. 在场景树中选中 `LocalWhisperASR` 节点。
3. 在右侧属性检查器（Inspector）中，找到 `Language Model` 属性。
4. 将刚刚下载的 `.bin` 模型文件拖拽到该属性框中，或者点击“加载”选择该模型。

完成以上步骤后，运行游戏，按住聊天界面的麦克风按钮（🎙）说话，松开后即可在本地进行语音识别！
