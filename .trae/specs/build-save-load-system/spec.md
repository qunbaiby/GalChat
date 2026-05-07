# Build Save Load System Spec

## Why
目前项目的存档系统采用了碎片化的自动保存机制（直接覆盖 `user://` 目录下的 JSON 文件），这存在两个严重问题：
1. 缺乏安全写入机制，如果在写入瞬间崩溃或断电，存档文件会永久损坏。
2. 缺乏状态原子性，如果某个子模块保存成功而另一个保存失败，会导致数据撕裂。
3. 缺乏多存档槽位支持，玩家无法在关键剧情前手动存档和读档。

我们需要构建一个完善、安全、支持多槽位的存读档系统，并提供相应的 UI 界面。

## What Changes
- 引入安全写入机制（Safe Write），在写入文件时先写入 `.tmp` 临时文件，确认无误后再替换原文件，防止存档损坏。
- 创建统一的 `SaveManager`，将原本散落在 `CharacterProfile`、`ChatHistoryManager`、`MemoryManager` 等各处的保存逻辑统一管理，实现原子化打包保存。
- 支持多存档槽位机制（如 AutoSave, QuickSave, ManualSave 1~N），每个存档独立存放，包含游戏进度快照及缩略图。
- 设计并实现存读档 UI 界面（Save/Load Menu），允许玩家查看存档列表、覆盖存档、读取存档及删除存档。
- 改造 `GameDataManager` 及现有的保存调用节点，将数据读写请求全部路由至新的 `SaveManager`。

## Impact
- Affected specs: 存档系统、玩家交互流程。
- Affected code:
  - `scripts/data/game_data_manager.gd`
  - `scripts/data/character_profile.gd`
  - `scripts/data/chat_history_manager.gd`
  - `scripts/data/memory_manager.gd`
  - 新增 `scripts/data/save_manager.gd`
  - 新增存读档 UI 相关的场景及脚本（如 `scenes/ui/save_load/save_load_panel.tscn`）。

## ADDED Requirements
### Requirement: Safe File Saving
系统在保存任何关键 JSON 文件时，必须先将其写入 `.tmp` 文件。仅在 `.tmp` 成功闭合并落盘后，才将其重命名为正式存档文件。

### Requirement: Unified Save Manager
系统必须提供统一的 API（如 `SaveManager.save_game(slot_id)`）来同时打包并保存当前的角色配置、聊天历史、玩家记忆等上下文数据，确保原子性。

### Requirement: Save/Load UI
系统需提供直观的存读档界面：
- 界面包含多个存档槽位，显示存档时间、当前阶段、游戏时间/截图。
- 支持手动保存和加载。
- 游戏主界面或开始界面需提供进入“读档”和“存档”界面的入口。

## MODIFIED Requirements
### Requirement: Existing Auto-Save
原本的实时覆盖保存将被修改为“标记脏数据”或统一调用 `SaveManager` 的 `auto_save` 接口，以降低磁盘 I/O 风险并防止数据撕裂。
