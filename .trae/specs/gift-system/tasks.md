# Tasks

- [x] Task 1: 构建礼物数据基础
  - [x] SubTask 1.1: 创建 `assets/data/gifts.json` 包含基础礼物数据（按不同稀有度/种类设计）。
  - [x] SubTask 1.2: 使用 GDScript 生成一系列默认的礼物图标（`.tres` GradientTexture2D，与之前的课程图标类似）。
  - [x] SubTask 1.3: 创建 `scripts/data/gift_manager.gd` 解析 JSON 并在 `GameDataManager`（或 AutoLoad）中注册，管理送礼规则。

- [x] Task 2: 实现数值计算与衰减逻辑
  - [x] SubTask 2.1: 在 `gift_manager.gd` 中实现基于情感阶段（Stage）的加成系数配置。
  - [x] SubTask 2.2: 实现连续送礼递减机制：记录玩家的送礼历史/次数，每次赠送同一件或同类礼物时，基础加成按比例衰减（如 0.8, 0.5）。

- [x] Task 3: 构建 GiftPanel UI 面板
  - [x] SubTask 3.1: 创建 `scenes/ui/gift/gift_panel.tscn`，包含礼物网格列表（GridContainer）、礼物详情（图标、名称、描述、效果）和“送出”按钮。
  - [x] SubTask 3.2: 编写 `scripts/ui/gift/gift_panel.gd`，实现 UI 的选中高亮、数值展示和送出信号发射。

- [x] Task 4: 聊天界面集成与 LLM 联动
  - [x] SubTask 4.1: 在 `chat_scene.tscn` 输入栏区域增加“送礼”按钮，点击显示 `GiftPanel`。
  - [x] SubTask 4.2: 监听面板的“确认送礼”事件，调用 `gift_manager` 计算并扣除资源/增加亲密与信任，更新 UI 的属性条，触发 Toast 提示。
  - [x] SubTask 4.3: 在 `dialogue_manager.gd` 中构造特殊的送礼 Prompt，静默发给 LLM，让角色根据礼物和情感阶段进行反馈（走打字机+TTS）。

# Task Dependencies
- Task 2 depends on Task 1
- Task 3 depends on Task 1
- Task 4 depends on Task 2 and Task 3
