# Tasks

- [x] Task 1: 体育馆专属菜单 UI 构建
  - [x] SubTask 1.1: 创建 `scenes/ui/map/gym/gym_training_menu.tscn`，使用 PanelContainer，设置居中布局。
  - [x] SubTask 1.2: 在菜单中添加标题“体育馆训练”，并在其下添加一个 GridContainer（或 VBoxContainer）存放四个训练项目按钮（游泳馆、健身房、瑜伽馆、舞室）。
  - [x] SubTask 1.3: 为菜单应用现有的 UI 风格（薄荷绿/奶白，圆角 12px）。
  - [x] SubTask 1.4: 在菜单底部或合适位置添加“< 返回”按钮，用于关闭菜单/返回地图。

- [x] Task 2: 体育馆训练菜单脚本逻辑
  - [x] SubTask 2.1: 创建 `scripts/ui/map/gym/gym_training_menu.gd` 并绑定到场景。
  - [x] SubTask 2.2: 配置四个训练项目的消耗（时间、体力）和收益（提升的属性类型及数值，例如游泳加体质，舞室加魅力/气质等）。
  - [x] SubTask 2.3: 实现点击训练项目的逻辑：检查体力是否足够，若不足则提示；若足够，则扣除体力、推进时间，并调用属性增加接口。
  - [x] SubTask 2.4: 训练完成后弹出 Toast 提示（例如“游泳训练完成！体质 +3”），无需调用 NPC 评价逻辑。
  - [x] SubTask 2.5: 实现返回按钮逻辑，触发 `closed` 信号。

- [x] Task 3: 地图进入逻辑适配
  - [x] SubTask 3.1: 修改 `assets/data/map/core/map_data.json` 中 `gym` 的配置，确保其不包含 resident_npcs，并且指定 `scene_path` 为我们处理该逻辑的场景（如果是复用 `quick_location_scene.tscn`，则保持原样）。
  - [x] SubTask 3.2: 修改 `quick_location_scene.gd`（或创建专属 `gym_scene.gd`）：当检测到当前地点为 `gym` 且没有 NPC 时，隐藏 `InteractionMenu`（包括立绘、信息、通用选项）。
  - [x] SubTask 3.3: 在进入 `gym` 时，直接实例化并居中显示 `gym_training_menu.tscn`。
  - [x] SubTask 3.4: 监听 `gym_training_menu` 的 `closed` 信号，当其关闭时，执行返回大地图的逻辑（调用 `_on_back_pressed()` 或相关返回函数）。