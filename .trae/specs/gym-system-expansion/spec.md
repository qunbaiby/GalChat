# 体育馆玩法系统拓展 Spec

## Why
目前在艺术大学地图中，音乐馆和美术馆等场景已经实现了完整的互动学习菜单，但体育馆作为基础地点仍然缺乏具体玩法。为了丰富校园场景功能，并提供一个不依赖特定 NPC 的基础属性训练途径，我们需要对体育馆场景进行定制化拓展。

## What Changes
- **地图数据配置**：更新 `map_data.json` 中体育馆（gym）的 `scene_path`，使其指向新创建的专属场景。
- **创建独立场景**：在 `scenes/map/locations/` 目录下新建 `gym.tscn`（或复用/修改现有逻辑使体育馆支持无 NPC 直接打开菜单）。
- **无 NPC 逻辑适配**：修改/扩展地点进入逻辑，当进入体育馆时，不显示 NPC 立绘、好感度和标准互动菜单，而是直接弹出居中显示的体育馆专属训练菜单。
- **训练菜单设计**：新建 `gym_training_menu.tscn`，包含四个训练项目：游泳馆、健身房、瑜伽馆、舞室。布局需居中对齐，符合现有的 UI 主题风格。
- **属性提升逻辑**：实现各个训练项目点击后扣除体力和时间，并增加相应的角色属性（如体质、魅力等）。
- **无反馈逻辑适配**：训练结束后，不触发 NPC 评价环节，直接完成结算并更新 UI，玩家可以继续训练或直接返回地图。

## Impact
- Affected specs: 地点进入逻辑（`quick_location_scene.gd` 或新场景）、活动/训练系统。
- Affected code:
  - `assets/data/map/core/map_data.json`
  - 新增 `scenes/map/locations/gym.tscn`（如果需要独立场景）或 `scenes/ui/map/gym/gym_training_menu.tscn`
  - 新增 `scripts/ui/map/gym/gym_training_menu.gd`
  - 可能涉及 `quick_location_scene.gd` 中对无 NPC 状态的判断。

## ADDED Requirements
### Requirement: 体育馆专属菜单
系统 SHALL 提供一个居中显示的体育馆训练菜单，包含四个项目，且无需与 NPC 交互即可直接访问。

#### Scenario: 进入体育馆
- **WHEN** 玩家在地图上点击进入体育馆
- **THEN** 界面不显示任何 NPC，直接弹出体育馆训练菜单，且包含“返回地图”的退出途径。

### Requirement: 体育馆训练结算
系统 SHALL 允许玩家消耗时间和体力进行四种不同的训练，并提升相应的属性，无 NPC 评价反馈。

#### Scenario: 进行游泳训练
- **WHEN** 玩家在体育馆菜单点击“游泳馆”
- **THEN** 游戏时间推进，消耗一定体力，角色的对应属性（如体质）提升，并弹出系统提示“训练完成，体质增加”，随后菜单刷新状态，不显示任何 NPC 对话。
