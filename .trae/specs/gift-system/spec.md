# 礼物系统 (Gift System) Spec

## Why
目前游戏缺乏玩家与AI角色主动互动的数值成长手段。增加“送礼”玩法可以增强玩家代入感，丰富互动维度，并通过影响亲密度和信任度来推动情感阶段发展。同时，引入基于情感阶段的动态反馈和连续送礼的数值衰减机制，以防止玩家恶意刷数值，增加系统的策略性和真实感。

## What Changes
- 构建礼物数据字典 `gifts.json`，可配置礼物的 icon、名称、描述、基础亲密/信任数值和稀有度/分类。
- 增加 `gift_manager.gd`，管理礼物数据加载、好感度影响计算、连续送礼递减规则和各情感阶段下的偏好系数。
- 新增 `gift_panel.tscn` 和 `gift_panel.gd`，在其中使用网格或列表展示玩家可送的礼物，点击查看详情，确认送出。
- 修改 `chat_scene.tscn` 和 `dialogue_manager.gd`，在输入框附近添加“送礼物”入口按钮，点击唤起面板。
- 送出礼物后，在界面通过 Toast 提示增加的亲密/信任值。
- 在后台将送礼事件（含礼物名称和描述）包装为系统 Prompt 传入大语言模型，角色根据当前情感阶段生成感谢或婉拒的动态台词。

## Impact
- Affected specs: 对话系统、养成属性与好感度阶段。
- Affected code:
  - `scripts/chat/dialogue_manager.gd`
  - `scenes/ui/chat/chat_scene.tscn`
  - 新增 `scripts/data/gift_manager.gd` 并在全局注册。
  - 新增 `scenes/ui/gift/gift_panel.tscn` 及脚本。

## ADDED Requirements
### Requirement: 礼物数据结构
系统 SHALL 支持通过 JSON 文件配置礼物。每项礼物包括：`id`, `name`, `desc`, `icon_path`, `base_intimacy`, `base_trust`。

### Requirement: 数值阶段加成与连续衰减
- **阶段加成**：针对不同的情感阶段（如 Stage 1: 陌生, Stage 2: 熟人, Stage 3: 暧昧 等），礼物的加成系数不同。例如，昂贵礼物在陌生阶段可能增加大量信任但亲密增加有限，在恋人阶段普通手工礼物即可大幅增加亲密。
- **连续递减**：为了防止玩家通过送礼无脑刷数据，系统 SHALL 记录最近赠送的礼物历史或次数。连续送同一件礼物，或短时间内大量送礼，其基础数值将按比例递减（例如 100% -> 80% -> 50% -> 10%）。

### Requirement: 大语言模型动态回应
送礼完成后，系统 SHALL 发送一条静默指令给 LLM（如：“【系统动作：玩家刚刚送给了你 [礼物名]，描述是：[礼物描述]。请根据你们当前的关系阶段，给出自然的反应和台词。】”），使角色主动说话，走完整的打字机与语音流程。
