# Tasks

- [x] Task 1: UI 布局重构
  - [x] SubTask 1.1: 在 `date_scene.tscn` 中，将现有的“放弃”按钮移动到屏幕左上角，文本修改为“< 返回”，调整样式使其符合返回按钮的外观。
  - [x] SubTask 1.2: 在底部“去约会”按钮左侧，添加一个 HBoxContainer，内部包含三个表示槽位的控件（早上、下午、晚上）。
  
- [x] Task 2: 构建约会配置数据
  - [x] SubTask 2.1: 在 `assets/data/interaction/` 目录下创建 `date_config.json`，配置“漫步散心”、“逛街购物”、“观影看展”、“餐饮小聚”四种类型及对应的地点 ID。
  - [x] SubTask 2.2: 在 `date_scene.gd` 中编写加载 `date_config.json` 的逻辑。

- [x] Task 3: 约会类型与地点下拉列表 UI
  - [x] SubTask 3.1: 在右侧面板中，动态生成约会类型的列表项。
  - [x] SubTask 3.2: 实现点击约会类型展开/折叠下方地点列表的逻辑。
  - [x] SubTask 3.3: 每个地点列表项需要包含地点名称、描述（可选）以及一个“+”添加按钮。
  - [x] SubTask 3.4: 从 `map_data.json` 获取地点的具体名称用于显示。

- [x] Task 4: 槽位添加、撤销与时间逻辑
  - [x] SubTask 4.1: 实现获取当前游戏时间逻辑（依赖 `GameDataManager.story_time_manager.current_period` 或类似机制）。
  - [x] SubTask 4.2: 初始化时，根据当前时间禁用过去的槽位（如早上、下午）。
  - [x] SubTask 4.3: 实现点击“+”按钮，将地点数据分配给第一个空闲且可用的槽位，更新槽位 UI。
  - [x] SubTask 4.4: 实现点击已填充的槽位，清空该槽位的数据并恢复空闲 UI。

- [x] Task 5: 启动约会接口预留
  - [x] SubTask 5.1: 点击“去约会”按钮时，校验是否至少选择了一个约会地点。
  - [x] SubTask 5.2: 提取槽位中已安排的地点列表，调用 `_start_date_plan(plan_list)` 预留接口，并打印出计划数据。