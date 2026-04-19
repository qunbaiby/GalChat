# Tasks
- [x] Task 1: Analyze new scene structures: 读取 `scenes/ui/desktop_pet/pet_body.tscn` 确认 SpineSprite 和 BubbleContainer 的确切节点路径，如果不存在则创建 `scripts/ui/desktop_pet/pet_body.gd` 并挂载。
- [x] Task 2: Create/Update `pet_body.gd`: 将气泡显示逻辑（`_add_bubble`, `display_bubble`, `_process_next_bubble` 等）以及 Spine 的触控逻辑（`_trigger_pet_touch`, `_on_pet_clicked`）从 `desktop_pet.gd` 迁移至 `pet_body.gd`。提供 `get_passthrough_rects() -> Array[Rect2]` 方法，返回角色和气泡的全局矩形区域。
- [x] Task 3: Refactor `desktop_pet.gd` (Chat & Logic): 移除旧的气泡与 Spine 交互代码。通过调用 `PetBody` 提供的方法（如 `pet_body.display_bubble(text)`）来触发展示，并监听来自 `PetBody` 的交互信号（如被点击时触发主动聊天）。
- [x] Task 4: Update mouse passthrough in `desktop_pet.gd`: 重写 `_update_mouse_passthrough`，通过收集 `Background_layer`, `UIContainer`, `InputLayer` 以及 `PetBody.get_passthrough_rects()` 的有效区域，重新构建多边形并应用到 `DisplayServer` 上。

# Task Dependencies
- [Task 2] depends on [Task 1]
- [Task 3] depends on [Task 2]
- [Task 4] depends on [Task 3]
