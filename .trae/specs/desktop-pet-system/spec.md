# Desktop Pet System Spec

## Why
当前市场上的AI虚拟陪伴软件（如 VPet, 各类Live2D桌宠等）的核心竞争力之一是“随时随地的陪伴感”。为了提升本项目的陪伴价值，需要实现一个独立于主游戏窗口之外的桌宠（Desktop Pet）。
桌宠应具备：无边框、背景透明、置顶显示、支持鼠标拖拽，且与主游戏的 AI 数据互通（包括好感度、信任度、情感阶段），让玩家在桌面办公或休息时依然能与角色互动聊天。

## What Changes
- 新增独立的 Godot `Window` 节点场景 `desktop_pet.tscn`，配置为透明、无边框、置顶。
- 在 `desktop_pet.gd` 中实现鼠标点击判定与拖拽逻辑。
- 新增 `desktop_pet.txt` 作为桌宠专属的大模型提示词模板（System Prompt）。
- 桌宠内部包含微型聊天气泡、立绘显示区域及简易输入框，并接入已有的 `deepseek_client.gd` 进行对话。
- 主场景 `main_scene.tscn` 侧边栏/底部新增“开启桌宠”的开关按钮。

## Impact
- Affected specs: 无
- Affected code: `main_scene.tscn` (新增按钮与子窗口挂载点)、可能需要在 `GameDataManager` 中添加桌宠单例的引用，以便同步数据。

## ADDED Requirements
### Requirement: 基础透明桌宠框架
系统必须提供一个可以脱离主程序界面存在、漂浮在 Windows 桌面上的宠物窗口。
#### Scenario: 唤出桌宠
- **WHEN** 玩家在主界面点击“开启桌宠”按钮
- **THEN** 在系统桌面上弹出一个只有角色立绘的透明无边框窗口，并处于置顶状态。

#### Scenario: 拖拽移动
- **WHEN** 玩家使用鼠标左键按住桌宠立绘区域并拖动
- **THEN** 桌宠窗口跟随鼠标移动到桌面任意位置。

#### Scenario: 互动与聊天
- **WHEN** 玩家在桌宠窗口的输入框发送消息
- **THEN** 桌宠能正确读取当前的亲密度和阶段数据，生成符合设定的回复，并在气泡UI中显示。

## MODIFIED Requirements
### Requirement: 现有 AI 对话接口支持独立窗口
原有的 `dialogue_manager` 强绑定在 `chat_scene` 中，桌宠需要独立的对话处理逻辑，但底层复用相同的 API 客户端和角色记忆。
