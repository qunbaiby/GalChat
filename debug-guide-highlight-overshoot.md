# [OPEN] guide-highlight-overshoot

## 问题

- 症状：课程安排引导中，`CategoryTabs` 与 `CategoryContentCard` 的高亮范围明显左右超出，且上下边界与预期不一致。
- 期望：高亮应严格贴合 `CategoryTabs` 与 `CategoryContentCard` 的实际可见边界，不额外外扩，也不漏包。

## 复现路径

1. 进入新手引导并打开课程安排界面。
2. 观察 `课程类型切换` 步骤中的 `CategoryTabs` 高亮范围。
3. 切换到 `课程列表区域` 步骤，观察 `CategoryContentCard` 与 `CategoryTabs` 的高亮范围。

## 假设

- A：`activity_panel.gd` 取到的 `get_global_rect()` 本身就比视觉面板更大，导致高亮源数据已经偏大。
- B：`guide_manager.gd` 在组装 `focus_rects` 时对 `CategoryTabs` / `CategoryContentCard` 叠加了额外矩形或 padding，导致最终范围被合并放大。
- C：`guide_overlay.gd` 在 `_sanitize_focus_rect()`、`_rebuild_focus_frames()` 或 glow/frame 绘制阶段再次扩张了矩形，导致显示比源矩形更大。
- D：实际超出的并不是高亮矩形，而是相关父节点透明遮罩/描边阴影造成的视觉错觉，需要对比 `frame` 与 `glow` 的最终尺寸。

## 计划

1. 给 `activity_panel.gd`、`guide_manager.gd`、`guide_overlay.gd` 添加最小埋点。
2. 启动调试服务器并让你复现停留。
3. 读取 `pre-fix` 日志，对比源节点矩形、focus 矩形、最终 glow/frame 矩形。
4. 只根据证据做最小修复。
