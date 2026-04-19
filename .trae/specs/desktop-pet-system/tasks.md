# Tasks
- [x] Task 1: 搭建桌宠基础窗口框架：新建 `desktop_pet.tscn`（类型为 `Window` 节点），配置无边框 (borderless = true)、背景透明 (transparent = true, transparent_bg = true) 以及置顶 (always_on_top = true)。
- [x] Task 2: 实现鼠标拖拽窗口功能：在 `desktop_pet.gd` 中处理 `_gui_input` 和全局鼠标事件，允许玩家通过点击并拖动角色图片移动整个操作系统窗口。
- [x] Task 3: 完善桌宠视觉与聊天UI：在 `desktop_pet.tscn` 中添加角色的初始立绘 (`TextureRect`)，并在旁边设计一个简易的对话气泡展示区 (`RichTextLabel`) 和迷你输入框 (`LineEdit`)。
- [x] Task 4: 构建桌宠专属提示词：在 `scripts/templates/prompts/` 目录下新建 `desktop_pet.txt`，设定桌宠视角下的专属系统提示词。
- [x] Task 5: 接入AI互动功能：在 `desktop_pet.gd` 中实例化并连接 `DeepSeekClient` API。在调用时传入当前的 `GameDataManager.profile` (亲密度、情感阶段等数据)，实现与主游戏一样的语境互动。
- [x] Task 6: 主场景集成控制：在主场景 `main_scene.tscn` (比如左侧边栏或下方菜单) 中添加一个“唤出桌宠”的开关/按钮，用于控制桌宠窗口的开启与关闭，并将该窗口作为主场景的子节点或者全局实例进行管理。

# Task Dependencies
- Task 2 depends on Task 1
- Task 4 depends on Task 3
- Task 5 depends on Task 4 and Task 2
- Task 6 depends on Task 1
