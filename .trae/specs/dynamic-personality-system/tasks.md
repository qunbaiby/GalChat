# Tasks
- [x] Task 1: 数据结构调整：修改 `luna.json` 和 `CharacterProfile`
  - [x] SubTask 1.1: 移除 `luna.json` 中各个 `stages` 节点内的 `personality_traits` 字段。
  - [x] SubTask 1.2: 在 `luna.json` 的根节点新增 `base_personality` 对象，设置初始的五大维度分数（开放性、尽责性、外倾性、宜人性、神经质，默认均为50）。
  - [x] SubTask 1.3: 修改 `character_profile.gd`，增加大五人格分数的变量（10.0 - 90.0的浮点数），并在 `load_profile` 和 `save_profile` 中处理它们的读取与持久化存储。若存档中没有，则从 `luna.json` 的 `base_personality` 中读取初始值。

- [x] Task 2: 建立动态人格系统核心逻辑：创建 `PersonalitySystem`
  - [x] SubTask 2.1: 创建 `assets/scripts/data/personality_system.gd` 脚本。
  - [x] SubTask 2.2: 在 `game_data_manager.gd` 中注册实例化 `personality_system`。
  - [x] SubTask 2.3: 在 `PersonalitySystem` 中实现 `update_trait` 方法，根据传入的分数增减量更新 `CharacterProfile` 中的对应维度，并严格限制在 10.0 - 90.0 的范围内。
  - [x] SubTask 2.4: 在 `PersonalitySystem` 中实现 `get_dynamic_traits` 方法，根据当前各大五人格的分数，映射生成一段文本化的人格描述（例如：如果外倾性大于70，则输出“活泼健谈，热爱社交...”）。

- [x] Task 3: 大模型情感分析流程升级：修改 Prompt 和解析逻辑
  - [x] SubTask 3.1: 修改 `emotion_analysis.txt` 的 Prompt，让大模型在分析玩家意图的同时，评估并输出大五人格的变化标签（格式如 `<openness:+1.5>`、`<neuroticism:-1.0>`）。
  - [x] SubTask 3.2: 修改 `deepseek_client.gd` 中的 `_on_emotion_response` 方法，增加对大五人格五种标签的正则匹配和解析逻辑。
  - [x] SubTask 3.3: 将解析出的大五人格变化数值调用 `PersonalitySystem.update_trait` 进行同步，并在 `toast` 通知或控制台中显示动态性格变化。

- [x] Task 4: 聊天上下文更新：修改 `PromptManager`
  - [x] SubTask 4.1: 修改 `prompt_manager.gd`，在构建 `build_chat_prompt` 等提示词时，调用 `PersonalitySystem.get_dynamic_traits()` 替代之前直接从 `stage_conf` 中获取的 `personality_traits`。
  - [x] SubTask 4.2: 确保动态生成的人格描述能够正确替换提示词中的 `{personality_traits}` 占位符，从而在接下来的每一轮对话中生效。

# Task Dependencies
- [Task 2] depends on [Task 1]
- [Task 3] depends on [Task 2]
- [Task 4] depends on [Task 2]