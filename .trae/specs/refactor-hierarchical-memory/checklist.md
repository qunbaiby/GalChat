\*- \[x] `memory_manager.gd` 成功将记忆存储为带 `id` 和 `timestamp` 的字典对象，且存取正确。

* [x] 记忆提取智能体 (`memory_extraction.txt` 和 `deepseek_client.gd`) 正确输出并请求 JSON 格式的数据。

* [x] `dialogue_manager.gd` 可以正确解析 `ADD`, `UPDATE`, `DELETE` 记忆操作并调用 `memory_manager.gd`，在界面有 Toast 提示反馈。

* [x] 聊天系统的系统提示词 (`default_chat.txt`) 中，已存在明确的【已确认事实】约束并严格防止幻觉。

* [x] Debug 面板可以正确展示更新后的结构化记忆。

