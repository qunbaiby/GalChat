# Tasks

- [x] Task 1: 创建固定聊天剧本结构与数据
  - [x] SubTask 1.1: 在 `assets/data/mobile/fixed_chats` 下创建 `jing_piano_practice_invite.json` 剧本。
  - [x] SubTask 1.2: 剧本包含消息队列、玩家选项、图片发送、系统消息等。

- [x] Task 2: 实现 MobileFixedChatManager 全局管理器
  - [x] SubTask 2.1: 创建 `scripts/data/mobile_fixed_chat_manager.gd` 并配置为 Autoload。
  - [x] SubTask 2.2: 实现剧本加载、进度存档、未读消息红点计数逻辑。
  - [x] SubTask 2.3: 发送未读消息数量变更的信号。

- [x] Task 3: 改造 DebugPanel 增加调试开关
  - [x] SubTask 3.1: 在 Debug 面板中添加 "启用自由 AI 聊天" 的 CheckButton（默认关闭）。
  - [x] SubTask 3.2: 在 Debug 面板中添加测试按钮以触发静的固定剧本。

- [x] Task 4: 改造 MainScene 和联系人列表的红点提示
  - [x] SubTask 4.1: 在主界面的 WeChatButton 上添加红点节点，并根据未读数显示/隐藏及播放晃动动画。
  - [x] SubTask 4.2: 在联系人列表项 (`mobile_contact_list_item.tscn`) 增加红点节点，并在有固定消息时显示。

- [x] Task 5: 改造 MobileChatPanel 适配固定聊天模式
  - [x] SubTask 5.1: 拦截自由输入，如果自由聊天关闭，将输入框设为只读/不可编辑。
  - [x] SubTask 5.2: 在输入框上方动态生成固定选项列表，点击选项将文本填入输入框。
  - [x] SubTask 5.3: 点击发送时，若处于固定聊天模式，则推进固定剧本，播放后续消息（包括图片和系统提示）。
  - [x] SubTask 5.4: 在固定剧情结束后插入系统消息“本轮对话已结束”。

# Task Dependencies
- Task 2 depends on Task 1
- Task 4 depends on Task 2
- Task 5 depends on Task 2 and Task 3
