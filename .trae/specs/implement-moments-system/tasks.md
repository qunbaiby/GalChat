# Tasks

- [x] Task 1: 建立朋友圈数据结构与管理器
  - [x] SubTask 1.1: 创建 `scripts/data/moments_manager.gd` 并注册为 Autoload（或依附于 DataManager），管理帖子、点赞和评论数据的增删改查。
  - [x] SubTask 1.2: 确保朋友圈数据支持本地存档与读取。
- [x] Task 2: 更新手机界面入口
  - [x] SubTask 2.1: 在 `mobile_interface.tscn` 的 `List1` 中添加朋友圈 Button 和 Icon。
  - [x] SubTask 2.2: 在 `mobile_interface.gd` 中绑定点击事件，用于打开朋友圈面板。
- [x] Task 3: 制作朋友圈 UI 场景
  - [x] SubTask 3.1: 创建 `moments_panel.tscn` 场景作为主容器。
  - [x] SubTask 3.2: 创建 `moment_item.tscn` 场景，包含头像、名字、正文、图片展示区、点赞/评论按钮及评论列表。
  - [x] SubTask 3.3: 实现 UI 脚本以读取 `MomentsManager` 数据并动态生成/刷新列表。
- [x] Task 4: AI接口及 Prompt 扩展
  - [x] SubTask 4.1: 在 `prompt_manager.gd` 中添加生成朋友圈内容、回复评论的系统提示词模板。
  - [x] SubTask 4.2: 在 `deepseek_client.gd` 中新增 `send_moment_generation()` 和 `send_moment_reply()` 方法，支持处理图文生成链路。
- [x] Task 5: 互动逻辑绑定
  - [x] SubTask 5.1: 绑定点赞按钮事件并更新 UI/数据。
  - [x] SubTask 5.2: 绑定评论输入框，发送评论后立刻显示，并调用 AI 回复接口。
- [x] Task 6: 事件库集成
  - [x] SubTask 6.1: 在 `event_manager.gd` 中实现 `_handle_post_moment()`，连接 AI 触发逻辑，实现通过事件 ID `"post_moment"` 自动发朋友圈的功能。

# Task Dependencies
- [Task 2] 与 [Task 1] 相互独立，但 [Task 3] 必须依赖 [Task 1] 的数据结构。
- [Task 5] 依赖 [Task 3] 和 [Task 4]。
- [Task 6] 依赖 [Task 1] 和 [Task 4]。