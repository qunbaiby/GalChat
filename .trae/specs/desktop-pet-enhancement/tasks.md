# Tasks
- [x] Task 1: 优化提示词 `desktop_pet.txt`：同步 `default_chat.txt` 的设定占位符（如 `{stage_title}`, `{personality_traits}`, `{memory_desc}` 等），并保留 `[SPLIT]` 拆分规则的强调，使其能够感知玩家的最新情感阶段和性格。
- [x] Task 2: 调整 `desktop_pet.gd` 的提示词加载与请求逻辑：调用 `PromptManager.build_system_prompt()`（或手动提取 `GameDataManager` 状态数据）注入提示词变量，同时确保发送给大模型的 `messages` 历史对话记录是独立于主游戏的。
- [x] Task 3: 重构桌宠 UI (`desktop_pet.tscn`)：创建一个隐藏的 `SpeechBubble` 模板节点（包含 `PanelContainer`, `MarginContainer`, `RichTextLabel` 等层级用于文本渲染），并隐藏或删除原有的静态 `ChatLabel`。
- [x] Task 4: 实现气泡生成与展示逻辑 (`desktop_pet.gd`)：提取并解析 `[SPLIT]` 多段回复，支持打字机效果（通过 Tween 改变 `visible_ratio`），用正则将动作描写 `(...)` 或 `（...）` 变为绿色。
- [x] Task 5: 实现气泡动态堆叠逻辑 (`desktop_pet.gd`)：维护一个活动气泡列表（最多3个），新气泡出现时自动将旧气泡平滑上移（Tween），超出的气泡渐隐销毁，并设定超时自动消失机制。
- [x] Task 6: 接入豆包语音（TTS）：在生成气泡文字的同时，检查并调用现有的 TTS 管理器/客户端（如 `DoubaoTTSClient`），播放对应的语音，并在语音播放完成后（或打字机效果完成后）再展示下一条气泡。
- [x] Task 7: 编写玩法分析报告：分析 `Pyrrha.gd` 源码，撰写 `docs/gameplay_analysis_pyrrha.md` 文档，总结其中的窗口监控、主动搭话、视觉感知、整点报时、好感度动态调整等进阶设计，为后续优化提供参考。

# Task Dependencies
- [Task 2] depends on [Task 1]
- [Task 4] depends on [Task 3]
- [Task 5] depends on [Task 4]
- [Task 6] depends on [Task 5]
