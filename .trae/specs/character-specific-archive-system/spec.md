# Character-Specific Archive System Spec

## Why
目前游戏在多角色切换时存在以下问题：
1. 旁白生成（`narrator_generation.txt`）硬编码了角色名字，没有动态区分当前角色。
2. 记忆库和性格档案在初次建立新角色时，因为旧有的文件迁移机制导致它们直接复制了前一个角色的存档，从而造成记忆和性格“共享”的错觉。
3. 玩家无法直观地查看不同角色的记忆和动态性格演化过程。原有的记忆管理面板隐藏在 Debug 界面中，不适合作为正式功能。

为了解决这些问题，我们需要修复档案的迁移逻辑，确保每个角色拥有完全独立的记忆和性格演化底色，同时建立一个“档案库”页面供玩家浏览。

## What Changes
- **BREAKING**: 修改 `character_profile.gd` 和 `memory_manager.gd` 中的旧存档迁移逻辑，将旧存档重命名（例如追加 `_migrated` 后缀），以防止所有新创建的角色重复复制同一份初始档案。
- 修改 `narrator_generation.txt`，将硬编码的角色名替换为动态变量（例如 `{{char_name}}`）。
- 在 `main_scene`（主界面）添加“档案库”入口按钮。
- 新建 `archive_panel.tscn` 及对应脚本，支持按角色分类查看。
  - 左侧或上方包含角色切换标签（只切换档案查看的角色，不改变当前游戏正在交互的角色）。
  - 包含“性格演化”页面，通过进度条或图表展示该角色的五大性格（开放性、尽责性、外倾性、宜人性、神经质）当前值与初始底色（Base Personality）的对比。
  - 包含“记忆库”页面，展示该角色的四层记忆（核心、情绪、习惯、羁绊）。
- 从 `debug_panel.tscn` 和 `debug_panel.gd` 中移除原有的“记忆管理”页签。

## Impact
- Affected specs: 多角色系统、动态性格系统、记忆系统
- Affected code:
  - `scripts/templates/prompts/narrator_generation.txt`
  - `scripts/data/character_profile.gd`
  - `scripts/data/memory_manager.gd`
  - `scenes/ui/main/main_scene.tscn` & `scripts/ui/main/main_scene.gd`
  - `scenes/ui/chat/debug_panel.tscn` & `scripts/ui/chat/debug_panel.gd`
  - 新增 `scenes/ui/archive/archive_panel.tscn` & `scripts/ui/archive/archive_panel.gd`

## ADDED Requirements
### Requirement: Archive Panel
The system SHALL provide an Archive panel accessible from the main menu.
#### Scenario: Viewing a character's archive
- **WHEN** user opens the Archive panel and selects a character
- **THEN** the system displays the selected character's memory layers and personality traits compared to their base personality, loading the data directly from the character's save file without affecting the active game state.

## MODIFIED Requirements
### Requirement: Save Migration
- **WHEN** migrating a legacy save file for a character
- **THEN** the system MUST rename or remove the legacy file after migration to prevent subsequent new characters from copying it.

## REMOVED Requirements
### Requirement: Debug Memory Management
**Reason**: Memory management is now a formalized player-facing feature in the Archive panel.
**Migration**: Removed from the Debug panel.
