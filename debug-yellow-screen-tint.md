[OPEN] yellow-screen-tint

# 调试目标
- 现象：运行项目后，画面像蒙了一层浅浅的黄色。
- 目标：确认是否由天气系统插件导致，或是其他全屏染色/后处理节点导致。

# 当前假设
1. 天气系统插件注入了暖色全屏覆盖层或颜色调制。
2. 主场景自身存在暖色屏幕后处理材质，不属于天气插件。
3. 时间系统在早晨时段动态应用了偏黄环境色。
4. 多个后处理效果叠加，综合色偏黄。
5. 根节点或顶层容器被设置了暖色 `modulate/self_modulate`。

# 计划
1. 静态定位所有可能的全屏颜色来源。
2. 找到主场景运行入口与天气系统插件挂载点。
3. 对可疑节点加最小化运行时埋点。
4. 复现并收集证据。
5. 根据证据判断根因，再做最小修复。

# 证据
- `.dbg/trae-debug-log-yellow-screen-tint.ndjson` 第 4 行：`weather_bridge.gd:_sync_weather` 记录当前天气描述为“未知/阴天”，均映射成 `target_weather_id = normal`，说明并没有启用雨雪雷等天气特效。
- `.dbg/trae-debug-log-yellow-screen-tint.ndjson` 第 3、7 行：`weather_bridge.gd:_sync_time` 与 `romestead_environment_system.gd:_update_environment_mix` 都显示当前时间是 `08:00`，`weather_light_curve = 0.0`，说明黄色感并不是雨雪天气叠加导致。
- `.dbg/trae-debug-log-yellow-screen-tint.ndjson` 第 6、8 行：`romestead_environment_overlay.gd:_draw_time_tint` 在 `08:00` 仍然计算出 `dawn = 1.0`、`dusk = 1.0`、`warm = 1.0`、`warm_alpha = 0.08`，并持续绘制暖色全屏矩形。
- `addons/romestead_weather_free/romestead_environment_overlay.gd` 中暖色计算使用了 `abs(hour - 5.75)` / `abs(hour - 21.8)` 再传给 `_smoothstep(5.0, 6.8, ...)` 与 `_smoothstep(21.0, 22.6, ...)`；该写法会让大量时段都落入 `warm = 1.0`，不是只在黎明/黄昏生效。

# 结论
- 已确认：画面浅黄色蒙层来自天气插件 `romestead_weather_free` 的屏幕 overlay，而不是实际雨雪天气效果。
- 更具体地说，是 `romestead_environment_overlay.gd` 的 `_draw_time_tint()` 中暖色时间窗计算有误，导致 `08:00` 这类正常白天时段仍然绘制 `alpha = 0.08` 的暖色全屏矩形。
- `weather_bridge.gd` 的桥接本身只是把项目时间与天气同步给插件；当前天气被同步为 `normal`，因此根因不在天气描述映射，而在插件 overlay 的时间 tint 算法。

# 修复
- 将 `romestead_environment_overlay.gd` 的黎明/黄昏计算改为基于“离中心时刻的距离”衰减，避免 `08:00` 仍然命中暖色 overlay。
- 新增“目标天气层”机制：`weather_bridge.gd -> romestead_environment_system.gd -> romestead_environment_overlay.gd` 现在只会在显式注册的 `WeatherLayer` 节点矩形内绘制天气，而不会再无条件作用于整个屏幕。
- `main_scene.gd` 在每次切换主背景时，会自动查找当前背景场景里的 `WeatherLayer` 并注册给天气系统。
- 已为 `default_room_bg.tscn`、`piano_room_bg.tscn`、`art_studio_bg.tscn` 补充 `WeatherLayer` 节点，后续其他场景也可以按同样方式接入。

# 修复后验证
- `.dbg/trae-debug-log-yellow-screen-tint.ndjson` 第 13-14 行：已确认天气系统成功绑定到 `/root/MainScene/BackgroundContainer/PianoRoomBg/WeatherLayer`。
- `.dbg/trae-debug-log-yellow-screen-tint.ndjson` 第 15、17 行：`08:00` 时 `dawn = 0.0`、`dusk = 0.0`、`warm = 0.0`、`warm_alpha = 0.0`，说明浅黄色暖色蒙层已被修正。
- `.dbg/trae-debug-log-yellow-screen-tint.ndjson` 第 16、18 行：`has_overlay_target = true`，说明天气效果已切换为节点定向模式，而不是原来的无目标全屏模式。
