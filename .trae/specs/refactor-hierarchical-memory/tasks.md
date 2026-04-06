# Tasks
- [x] Task 1: 模块化重构 `memory_manager.gd` 实现结构化存储。
  - [x] SubTask 1.1: 在 `memory_manager.gd` 中定义基于字典的 `MemoryItem` 结构（包含 `id`, `content`, `timestamp`, `category`）。
  - [x] SubTask 1.2: 更新 `load_memory` 和 `save_memory` 方法以支持新数据结构，并添加版本或向前兼容处理（清空旧格式）。
  - [x] SubTask 1.3: 实现 `add_memory_item`, `update_memory_item`, `delete_memory_item` 方法。
  - [x] SubTask 1.4: 调整 `get_memory_prompt` 以将结构化数据格式化为带有 `[已确认事实]` 标签的文本串。
- [x] Task 2: 升级记忆提取智能体提示词 (`memory_extraction.txt`)。
  - [x] SubTask 2.1: 强制要求输出 JSON 格式的 `operations` 数组，允许 `ADD`, `UPDATE`, `DELETE` 操作，并带上时间戳和原因。
- [x] Task 3: 更新 `deepseek_client.gd` 与 `dialogue_manager.gd` 处理 JSON 记忆响应。
  - [x] SubTask 3.1: 将 `_send_memory_extraction` 设置为要求 `{"type": "json_object"}` 响应格式。
  - [x] SubTask 3.2: 在 `dialogue_manager.gd` 的 `_on_memory_response` 中解析 JSON，并根据 action 调用 `memory_manager.gd` 对应的方法。
- [x] Task 4: 更新聊天防幻觉提示词 (`default_chat.txt`)。
  - [x] SubTask 4.1: 加入严格的事实分离指令：“只能使用【已确认事实】标记中的内容，绝对不能编造任何未确认的用户信息、经历、偏好”。
- [x] Task 5: 适配 Debug 面板 (`debug_panel.gd`)。
  - [x] SubTask 5.1: 修复 `_update_memory_text`，使其正确遍历和展示新的字典结构的记忆。

# Task Dependencies
- [Task 3] depends on [Task 1] and [Task 2]
- [Task 5] depends on [Task 1]
