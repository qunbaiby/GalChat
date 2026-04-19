# Tasks
- [x] Task 1: 增加配置项和 UI 支持。
  - [x] SubTask 1.1: 在 `config_resource.gd` 中增加 `doubao_embedding_api_key` 和 `doubao_embedding_model` 字段（默认 `doubao-embedding-vision-251215`）。
  - [x] SubTask 1.2: 在 `settings_scene.tscn` 和 `settings_scene.gd` 中添加对 Embedding 服务的 UI 输入和保存。

- [x] Task 2: 创建 `doubao_embedding_client.gd` 实现向量请求。
  - [x] SubTask 2.1: 在 `assets/scripts/api/` 下创建新的 Node 脚本，支持调用火山引擎 `/api/v3/embeddings`（或标准 `/v1/embeddings`）并返回 `Array[float]` 类型的向量数据。
  - [x] SubTask 2.2: 暴露异步方法 `get_embedding(text: String) -> Array`，供其他模块使用。
  - [x] SubTask 2.3: 在 `main_scene.gd` 或全局 Autoload 中实例化并挂载该客户端。

- [x] Task 3: 改造 `memory_manager.gd` 实现向量存储与检索。
  - [x] SubTask 3.1: 更新 `MemoryItem` 结构，支持 `embedding` 字段，并在 `load_memory` 中加载。
  - [x] SubTask 3.2: 更新 `add_memory` 和 `update_memory`，在写入成功后，调用 `doubao_embedding_client` 获取内容的向量，再保存到 JSON。对于旧的无向量的记忆，在后台尝试补全（或由后续触发）。
  - [x] SubTask 3.3: 在 `memory_manager.gd` 中实现 `calculate_cosine_similarity(vec1: Array, vec2: Array) -> float`。
  - [x] SubTask 3.4: 新增 `retrieve_relevant_memories(user_embedding: Array, top_k: int = 5) -> Array`，计算非 core 层记忆的相似度，排序并返回最高分的前 K 条；Core 记忆则固定加入结果中。
  - [x] SubTask 3.5: 更新 `get_memory_prompt(relevant_memories: Array)`，不再盲目读取全部字典，而是只将传入的 `relevant_memories` 转化为文本。

- [x] Task 4: 改造聊天请求流 (`dialogue_manager.gd` / `deepseek_client.gd`)。
  - [x] SubTask 4.1: 在 `send_chat_message` 时，如果配置了 Embedding API Key，则先异步请求用户输入的向量。
  - [x] SubTask 4.2: 获取到用户向量后，调用 `retrieve_relevant_memories`。
  - [x] SubTask 4.3: 修改 `build_chat_prompt`，传入这些检索到的记忆并构建 System Prompt，然后再发送给聊天 API。

# Task Dependencies
- [Task 2] depends on [Task 1]
- [Task 3] depends on [Task 2]
- [Task 4] depends on [Task 3]