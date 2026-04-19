# Refactor Desktop Pet Scene Spec

## Why
场景 `desktop_pet.tscn` 进行了重大结构调整。Spine 节点和对话气泡被移入独立的 `pet_body.tscn` 场景中，以便后续扩展角色移动等逻辑（让气泡跟随角色移动）。同时新增了 `Background_layer` 用于承载背景素材。需要根据新的节点树结构重构脚本逻辑，特别是透明窗口的鼠标点击穿透（Mouse Passthrough）逻辑，以确保功能正常运行。

## What Changes
- **BREAKING**: 从 `desktop_pet.gd` 中剥离 Spine 动画控制、对话气泡的队列与渲染逻辑、以及宠物的触碰交互逻辑，将其迁移至新建/现有的 `pet_body.gd` 脚本中。
- 重构 `desktop_pet.gd`，移除已迁移的逻辑，改为向 `PetBody` 节点发送指令或监听其信号。
- 重新设计 `desktop_pet.gd` 中的 `_update_mouse_passthrough` 逻辑。确保能正确获取 `Background_layer`、`PetBody`（及其内部的气泡和 Spine 动画）、`UIContainer` 和 `InputLayer` 的有效矩形区域，并合成正确的鼠标点击穿透多边形。

## Impact
- Affected specs: 桌面宠物展示与交互能力、透明窗口穿透检测。
- Affected code: 
  - `scripts/ui/desktop_pet/desktop_pet.gd`
  - `scripts/ui/desktop_pet/pet_body.gd` (新建或修改)
  - `scenes/ui/desktop_pet/pet_body.tscn`
  - `scenes/ui/desktop_pet/desktop_pet.tscn`

## ADDED Requirements
### Requirement: Independent Pet Body
The system SHALL manage pet animations and chat bubbles inside an independent `PetBody` scene.
#### Scenario: Success case
- **WHEN** AI generates a chat response
- **THEN** `desktop_pet.gd` forwards the text to `PetBody`, which manages the bubble queue and displays the bubbles following its own local coordinates.

## MODIFIED Requirements
### Requirement: Transparent Window Passthrough
**Reason**: Node structure changed significantly, existing paths (e.g. `Control/BubbleContainer`) are no longer valid.
**Migration**: Update `_update_mouse_passthrough` to iterate over the new `Background_layer`, `UIContainer`, `InputLayer`, and ask `PetBody` for its active visual rects (Spine bounds + Bubble bounds) to build the zero-width bridge polygon.
