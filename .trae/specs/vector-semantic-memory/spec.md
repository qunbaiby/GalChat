# 向量化语义检索分级记忆系统 Spec

## Why
根据《分级长程记忆系统实现方案》的设计理念，虽然我们已经实现了基于 JSON 的结构化记忆管理（解决了冲突与篡改问题），但随着时间推移，记忆库容量会不断增加。如果将所有记忆无脑注入系统提示词（上下文窗口溢出），不仅会拖慢大模型推理速度，更会因为“注意力稀释”导致 AI 忽略核心事实并产生幻觉。
为此，我们需要引入方案中提到的 **“Level 2/3 混合检索架构（向量语义检索）”**。利用 `doubao-embedding-vision-251215` 向量模型，在不依赖外部复杂向量数据库的情况下，通过本地 GDScript 计算余弦相似度，实现基于用户当前对话内容的**动态按需召回**，确保只将最相关的高置信度记忆送入上下文，从根源上杜绝假性失忆与幻觉。

## What Changes
- **配置层**: 在 `config_resource.gd` 中新增火山引擎（Doubao）Embedding 服务的配置项（API Key 和模型名 `doubao-embedding-vision-251215`）。
- **API 接入**: 新增 `doubao_embedding_client.gd`（或扩展现有网络客户端），专门用于请求 `/api/v3/embeddings` 获取文本向量（`Array[float]`）。
- **数据结构**: **BREAKING** `memory_manager.gd` 中的 `MemoryItem` 字典增加 `embedding: Array` 字段。每次执行 `ADD` 或 `UPDATE` 操作时，自动异步请求其向量并存入本地 JSON。
- **检索逻辑**: 在 `memory_manager.gd` 中实现基于余弦相似度（Cosine Similarity）的 Top-K 向量检索功能。
- **业务流改造**: 玩家发送消息时，先请求玩家消息的 Embedding，再与本地记忆库进行相似度比对。仅召回 **全部核心记忆（Core）** + **Top-K 最相关的情绪/习惯/羁绊记忆**，组装成最终的【玩家专属长记忆档案】传入聊天 Prompt。

## Impact
- Affected specs: 聊天会话生命周期 (Chat Session Lifecycle), 记忆管理与存储 (Memory Storage)
- Affected code:
  - `assets/scripts/data/config_resource.gd`
  - `assets/scripts/data/memory_manager.gd`
  - `assets/scripts/api/deepseek_client.gd` (或新增专用的 `doubao_embedding_client.gd`)
  - `assets/scripts/chat/dialogue_manager.gd`
  - `assets/scenes/ui/settings/settings_scene.tscn` (添加 Embedding 配置界面)

## ADDED Requirements
### Requirement: 记忆向量化与按需召回 (语义检索)
系统在写入非核心记忆时，必须将其转化为高维向量存储；在聊天生成前，系统必须根据当前用户输入的语义向量，提取相关度最高的前 N 条记忆。

#### Scenario: 跨周期关联召回
- **WHEN** 玩家输入“我今天要熬夜赶画稿，好累”。
- **THEN** 系统将其转化为向量，与本地记忆库计算相似度，精准召回之前存储的“习惯记忆：平时晚上经常熬夜画画”和“羁绊记忆：约定未来多提醒玩家早点休息”，而忽略与当前语境无关的“喜欢吃辣”等记忆。

## MODIFIED Requirements
### Requirement: 动态 Prompt 组装
`get_memory_prompt` 方法不再返回全量记忆，而是接收一个预先筛选好的 `relevant_memories` 列表进行格式化。

## REMOVED Requirements
### Requirement: 全量记忆注入
**Reason**: 全量注入会导致上下文溢出和注意力分散。
**Migration**: 核心记忆（Core）依旧全量注入（作为 Level 3 的强制前置召回），但情绪、习惯、羁绊记忆改为 Top-K 向量检索注入。