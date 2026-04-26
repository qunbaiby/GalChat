# 地图导航系统设计与性能优化报告

## 1. 架构概述
本系统主要分为三层架构：
- **Level 1 (World Map)**: 全局地图界面（`world_map_scene.tscn`），用户可以在此点击大区域（如滨河南区、嘉南区等）。
- **Level 2 (Area Detail)**: 区域详情弹窗，在点击大区域后，使用Tween实现平滑放大弹出的二级菜单，展示区域内的可探索地点。
- **Level 3 (Exploration Map)**: 具体场景地图（如 `central_street.tscn`），基于 `TileMap` 和 `CharacterBody2D` 实现的八方向可移动RPG探索场景。

数据层由统一的自动加载单例 `MapDataManager` 驱动，降低了场景间的耦合度。

## 2. 数据结构设计示例
`MapDataManager` 在 `_load_map_data()` 中管理所有静态配置。
```json
// Area 示例
"binhe_south": {
    "id": "binhe_south",
    "name": "滨河南区",
    "description": "繁华的商业区与行政中心。",
    "locations": ["central_street", "themis_law_firm", "he_yin_hall"]
}

// Location 示例
"central_street": {
    "id": "central_street",
    "name": "中央商业街",
    "description": "繁华的购物街。",
    "scene_path": "res://scenes/map/locations/central_street.tscn"
}
```

## 3. 性能优化措施

### 3.1 UI渲染与内存优化
- **UI复用与动态生成**：大地图场景在被调用时实例化，并在 `_on_close_pressed` 中处理隐藏逻辑。二级菜单内的地点列表是在点击具体区域时动态生成的（先执行 `queue_free()` 清理旧节点，再根据数据配置生成新节点），避免了庞大UI树常驻内存。
- **平滑过渡与动画性能**：使用Godot的 `create_tween()` 替代繁重的 `AnimationPlayer` 状态机来执行UI的弹出和隐藏，这大幅降低了CPU开销，同时保持了“沉浸式体验”。
- **遮挡剔除（CanvasLayer）**：将游戏主场景UI放置在不同的 Z-Index/CanvasLayer 下，当全屏地图开启时，底层不必要的UI渲染可以得到有效控制。

### 3.2 物理与移动性能优化
- **角色物理更新分离**：`PlayerCharacter` 使用了 `_physics_process(delta)` 处理输入和位移，这确保了物理帧率独立于渲染帧率，使得八方向移动不会因为画面掉帧而出现瞬移。
- **碰撞形状精简**：在探索场景（`central_street.tscn`等）中，四周边框采用了 `RectangleShape2D` 组合而非复杂的Polygon多边形碰撞，最大化减少了物理引擎 (Box2D) 的求交计算量。
- **输入向量归一化**：在 `input_dir.normalized()` 计算中，使用Godot内置的高效数学库，保证了对角线移动时不会出现加速现象（长度保持为1），且不会造成浮点精度瓶颈。

### 3.3 TileMap 优化
- 使用 `TileMap` (Godot 4.x Format 2) 进行背景渲染。
- 将静态的装饰物尽量集成在TileMap层中而不是作为单独的 Sprite2D 节点存在，这能够享受引擎底层的合批渲染(Batching)红利，大幅减少 Draw Calls，保证了在移动设备或低端机上的流畅度。