# Implement Co-Creation Drawing Board Spec

## Why
玩家作为“指导人”，Luna作为“美术生”，我们希望引入一种能够打破单向文字对话的互动模式。通过在游戏中提供一个极简画板，玩家可以绘制草图并指导Luna，Luna会利用AI绘画API（如豆包或Gradio后端的Image-to-Image/ControlNet功能）将草图加工成精美画作，并给予符合人设的情感反馈。这不仅增强了陪伴感，还提供了一个充满惊喜的双人共创玩法。

## What Changes
- 添加画板 UI 界面 `drawing_board_panel.tscn`，支持鼠标拖拽绘制线条。
- 利用 `SubViewport` 捕获画板上的草图，并转换为 Base64 格式。
- 在大模型客户端 `deepseek_client.gd`（或图像生成脚本中）增加支持 Image-to-Image（图生图）的 API 调用接口。
- 将共创入口添加到主界面或桌宠界面。
- 当画作生成完成后，弹出带有生成结果的面板，并展示 Luna 的反馈台词：“哥哥，我根据你画的草图，丰富了一下细节，你看好看吗？”。

## Impact
- Affected specs: AI 绘画集成、桌面互动体验
- Affected code: `main_scene.tscn`/`desktop_pet.tscn` (新增入口), `deepseek_client.gd` (新增 API 接口), `drawing_board_panel.tscn` (全新 UI)

## ADDED Requirements
### Requirement: Co-Creation Drawing Board
The system SHALL provide a drawing board where users can sketch and send it to the AI for image-to-image generation.

#### Scenario: Success case
- **WHEN** user draws on the board and clicks "指导 Luna"
- **THEN** the system captures the sketch, calls the image generation API with a predefined prompt (e.g., "精美的二次元插画..."), and returns a stylized image along with Luna's dialogue.
