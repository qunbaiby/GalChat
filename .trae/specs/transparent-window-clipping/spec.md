# Transparent Window Clipping Spec

## Why
目前桌宠的背景是透明的，但是整个方形窗口依然会拦截鼠标的点击事件，导致用户无法点击桌宠背后的其他应用窗口。参考 `ddlink_avg` 项目中的透明区域裁剪逻辑，我们需要实现一个精确的鼠标事件穿透功能，使得只有桌宠本身的可见区域（宠物本体、底部的操作栏以及动态显示的气泡）能够拦截点击，其余透明区域允许鼠标穿透。

## What Changes
- 在 `desktop_pet.gd` 中新增 `_update_mouse_passthrough()` 方法。
- 计算 `Control/PetContainer`、`Control/HBoxContainer` 以及 `Control/BubbleContainer`（当其内部的 `SpeechBubble` 可见时）的合并可见区域。
- 为了让 Godot 原生的 `DisplayServer.window_set_mouse_passthrough` 支持多个不相连的矩形区域，使用“零宽桥接”（Zero-width bridge）算法将多个 `Rect2` 连接成一个不规则的多边形（`PackedVector2Array`）。
- 监听 `SpeechBubble` 的 `visibility_changed` 信号，在对话气泡显示或隐藏时，动态更新裁剪区域。
- 在 `_ready()` 中通过 `call_deferred` 首次调用该方法。

## Impact
- Affected specs: 桌宠交互体验、窗口系统。
- Affected code:
  - `scripts/ui/desktop_pet/desktop_pet.gd`

## ADDED Requirements
### Requirement: 动态鼠标穿透裁剪
系统必须根据当前 UI 元素的可见性，动态生成不规则多边形传递给操作系统进行窗口区域裁剪。

#### Scenario: Success case
- **WHEN** 游戏启动，桌宠出现在右下角
- **THEN** 只有宠物和输入框所在的矩形区域接收鼠标点击，两者中间的空白透明区域可以点穿到底层桌面。
- **WHEN** 桌宠开始说话并显示气泡
- **THEN** 穿透区域自动更新，气泡所在位置也变得不可穿透，允许用户点击气泡。
- **WHEN** 气泡消失
- **THEN** 原气泡区域重新变得透明且鼠标可穿透。