# 模块化分级记忆系统 Spec

## Why
当前项目的记忆系统仅使用简单的字符串数组进行盲目追加，缺乏结构化属性（如时间戳、来源、状态），且记忆提取智能体仅能添加记忆，无法处理冲突或更新已有记忆。这容易导致记忆库无限膨胀、新旧记忆冲突，进而诱发AI角色在对话中产生失忆与幻觉（编造虚假信息）。基于提供的《分级长程记忆系统实现方案》PDF文件，我们需要引入结构化记忆管理、基于操作(ADD/UPDATE/DELETE)的记忆写入机制，并在生成端加入强约束，从根源上防范AI失忆和幻觉。

## What Changes
- **BREAKING**: 重构 `memory_manager.gd` 中的数据结构。将原本的 `Dictionary[String, Array[String]]` 改为基于 `MemoryItem`（字典结构，包含 `id`, `content`, `timestamp`, `category` 等字段）的数组。
- 更新 `memory_extraction.txt` 提示词。强制记忆智能体返回带有明确操作意图（如 `ADD`, `UPDATE`, `DELETE`）的JSON格式，使其能够解决新旧记忆冲突。
- 修改 `deepseek_client.gd` 中关于记忆提取的请求配置，强制返回 `json_object` 格式。
- 修改 `dialogue_manager.gd` 中的 `_on_memory_response` 逻辑，解析JSON操作并调用相应的管理器方法。
- 在 `default_chat.txt` 聊天系统提示词中增加严厉的防编造和防幻觉指令（对应PDF中“生成端：强约束+事后校验”）。
- 更新 `debug_panel.gd` 以适配并展示新的结构化记忆数据。

## Impact
- Affected specs: 记忆提取与管理 (Memory Extraction & Management), 聊天生成提示词约束 (Chat Prompt Generation)
- Affected code: 
  - `assets/scripts/data/memory_manager.gd`
  - `assets/scripts/api/deepseek_client.gd`
  - `assets/scripts/chat/dialogue_manager.gd`
  - `assets/scripts/ui/chat/debug_panel.gd`
  - `assets/templates/prompts/memory_extraction.txt`
  - `assets/templates/prompts/default_chat.txt`

## ADDED Requirements
### Requirement: 结构化记忆与冲突解决 (Level 4: 元记忆层逻辑)
系统必须将记忆存储为包含唯一标识、分类和时间戳的结构化数据，并允许记忆提取智能体通过明确的操作指令来更新或删除陈旧/冲突的记忆。

#### Scenario: 更新过时记忆
- **WHEN** 玩家表示“我现在不熬夜了，每天11点就睡”。
- **THEN** 记忆提取智能体应输出一个 `UPDATE` 操作，将原有的“习惯熬夜”记忆更新为“每天11点睡觉”，系统相应更新该条记忆的时间戳和内容。

## MODIFIED Requirements
### Requirement: 防幻觉提示词约束 (防编造机制)
聊天生成提示词必须明确划定事实与生成的边界，禁止AI自行推断或编造玩家的未确认信息。

## REMOVED Requirements
### Requirement: 纯文本标签记忆提取
**Reason**: 基于 `<mem_core:xxx>` 的正则提取无法实现对过往记忆的精准更新或删除。
**Migration**: 迁移至结构化的JSON输出格式 `{"operations": [{"action": "...", "content": "..."}]}`。
