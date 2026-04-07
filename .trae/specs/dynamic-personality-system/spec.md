# 动态人格演化系统 (Dynamic Personality System) Spec

## 背景 (Why)
当前角色的性格特征和行为逻辑（`personality_traits`）是与情感阶段（`stages`）强绑定的。这导致角色的性格会随着好感度突破发生断崖式、模板化的转变，缺乏真实成长的细腻感。根据《人格系统完整策划案》的指引，我们需要彻底解耦情感阶段与性格特征，引入基于大五人格模型（FFM）的动态演化系统，让每次互动都能微妙地塑造角色的专属人格底色。情感阶段应仅负责处理角色与玩家之间的亲密关系和游戏机制，而不再干涉底层的性格倾向。

## 变更内容 (What Changes)
- **BREAKING**: 将 `luna.json` 中各个 `stages` 节点内的 `personality_traits` 字段移除。
- 在 `luna.json` 根节点新增 `base_personality`，包含大五人格（开放性、尽责性、外倾性、宜人性、神经质）的初始基准分（10-90，默认50）及核心特质。
- 新增 `PersonalitySystem` (脚本 `assets/scripts/data/personality_system.gd`) 用于管理大五人格分值，并负责根据当前分值动态生成文本化的人格描述。
- 修改 `CharacterProfile` 以存储和持久化加载大五人格的动态分值。
- 升级意图与情感分析 Agent（修改 `emotion_analysis.txt`），使其在分析好感/信任度的同时，分析玩家行为对大五人格五大维度的影响，并输出标签如 `<openness:+1.5><neuroticism:-1.0>`。
- 更新 `deepseek_client.gd`，解析大五人格的变动标签，并同步更新到 `CharacterProfile` 中。
- 修改 `prompt_manager.gd`，将动态生成的 `personality_traits` 注入到聊天提示词的对应占位符中。

## 影响范围 (Impact)
- 受影响的功能: AI 角色回复逻辑、情感分析流程、游戏存档系统。
- 受影响的代码:
  - `assets/data/characters/luna.json` (数据结构变动)
  - `assets/scripts/data/character_profile.gd` (存档字段增加)
  - `assets/scripts/data/prompt_manager.gd` (Prompt 构建逻辑)
  - `assets/scripts/api/deepseek_client.gd` (解析逻辑增加)
  - `assets/templates/prompts/emotion_analysis.txt` (Prompt 模板增加大五人格分析指令)
  - `assets/scripts/data/game_data_manager.gd` (注册新的系统管理器)

## 新增需求
### 需求: 动态人格底色与演化
系统需要基于大五人格模型，跟踪并更新角色的开放性(openness)、尽责性(conscientiousness)、外倾性(extraversion)、宜人性(agreeableness)、神经质(neuroticism)得分。
#### 场景: 玩家互动导致性格演化
- **WHEN** 玩家发送了一条鼓励角色尝试新事物的消息。
- **THEN** 情感分析 Agent 识别出“开放性”影响，返回 `<openness:+2.0>`，系统将角色的开放性得分增加，并在下次对话中，角色的动态性格描述会表现出对新事物的更高接受度。

## 修改需求
### 需求: 提示词性格生成逻辑
**旧逻辑**: 从当前的好感度阶段中读取固定的 `personality_traits` 文本。
**新逻辑**: 从 `PersonalitySystem` 中获取由当前大五人格分数动态组合而成的 `personality_traits` 描述文本，结合 `luna.json` 中配置的初始底色，传递给大模型，实现性格的动态变化。