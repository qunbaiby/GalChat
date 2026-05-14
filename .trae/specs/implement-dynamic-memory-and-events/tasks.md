# Tasks

- [x] Task 1: 扩展数据结构与基础模块
  - [x] SubTask 1.1: 在 `character_profile.gd` 中新增 `memories` (Dictionary) 属性及其序列化/反序列化支持。
  - [x] SubTask 1.2: 创建 `scripts/core/memory_manager.gd` 并在 `game_data_manager.gd` 中注册为单例/管理类，提供增删改查记忆的接口。

- [ ] Task 2: 实现记忆提取与 Prompt 注入
  - [ ] SubTask 2.1: 在 `deepseek_client.gd` 中新增 `extract_memory_from_chat(user_text, ai_reply)` 方法，利用大模型分析对话并提取 JSON 格式的记忆标签。
  - [ ] SubTask 2.2: 修改 `prompt_manager.gd`，在构建常规对话、整点报时、主动问候的 Prompt 时，附加上相关的 `memories` 数据。
  - [ ] SubTask 2.3: 在 `desktop_pet.gd` 或 `dialogue_manager.gd` 中，每次完成一轮对话后异步调用记忆提取。

- [x] Task 3: 构建日程事件 UI 与底层结构
  - [x] SubTask 3.1: 创建 `scenes/ui/activity/schedule_event_panel.tscn` 及其脚本，包含事件描述文本框和 2 个选项按钮。
  - [x] SubTask 3.2: 在 `deepseek_client.gd` 中新增 `generate_schedule_event(course_data)` 和 `resolve_schedule_event(course_data, event_context, chosen_option)` 接口。

- [x] Task 4: 集成日程事件到执行面板
  - [x] SubTask 4.1: 修改 `schedule_execution_panel.gd` 的 `_on_click_area_pressed` 和 `tween.finished` 回调，加入概率触发事件的逻辑（暂停移动，弹出事件面板）。
  - [x] SubTask 4.2: 连接事件面板的选项点击信号，请求 AI 结算结果，播放奖励/惩罚动画后恢复日程执行。

- [ ] Task 5: 修复记忆数据结构位置
  - [ ] SubTask 5.1: 撤销 `MemoryManager` 作为独立文件的做法，将 `memories` 数据结构直接添加到 `CharacterProfile` 中。
  - [ ] SubTask 5.2: 确保 `CharacterProfile` 的序列化/反序列化（`save_profile` / `load_profile`）能够正确保存和读取 `memories` 数据。
  - [ ] SubTask 5.3: 更新所有调用过 `GameDataManager.memory_manager` 的地方，改为直接访问 `GameDataManager.profile.memories` 并调用其内部的增删改查方法。

# Task Dependencies
- Task 2 depends on Task 1
- Task 4 depends on Task 3