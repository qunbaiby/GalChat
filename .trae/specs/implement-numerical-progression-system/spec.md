# Numerical Progression System Spec (三维六基养成体系)

## Why
目前游戏侧重于文字对话与性格演化，缺少长线的数值养成目标与策略性玩法。引入基于「体、智、魅」三维核心和六大基础属性（三维六基）的养成体系，能够为玩家提供明确的日程安排、课程选择和数值反馈，进一步丰富美少女大学生的校园生活体验，并为未来的多结局判定打下基础。

## What Changes
- **新增数据模块 (Stats System)**：管理六大基础属性（身体素质、体能活力、学业素养、知识储备、社交情商、创意审美），支持从0到2001+的9级成长，并根据公式换算出三大核心维度（体、智、魅）。
- **新增活动模块 (Activity Manager)**：管理校园课程与活动（如体能特训课、专业精读课等），支持消耗行动力/精力换取基础属性提升。
- **角色存档扩展**：在 `character_profile.gd` 中新增三维六基的持久化数据字段以及每日精力值。
- **新增 UI 场景**：
  - `stats_panel.tscn`：属性展示面板，可视化当前六大基础属性的进度与三大核心维度的评级。
  - `activity_panel.tscn`：行程/活动选择面板，供玩家为角色安排课程与活动，获取属性收益。
- **主界面集成**：在主游戏界面增加入口，允许玩家打开属性面板与活动面板。

## Impact
- Affected specs: 角色存档读写 (`character_profile.gd`)，每日重置逻辑 (`init_daily_mood`)
- Affected code: `game_data_manager.gd`, `main.tscn` (或对应主界面)

## ADDED Requirements
### Requirement: 核心数值换算 (Core Dimensions Calculation)
The system SHALL calculate the three core dimensions using the exact formulas provided:
- **体** = ⌊(身体素质 × 0.6 + 体能活力 × 0.4) ÷ 10⌋
- **智** = ⌊(学业素养 × 0.5 + 知识储备 × 0.5) ÷ 10⌋
- **魅** = ⌊(社交情商 × 0.5 + 创意审美 × 0.5) ÷ 8⌋
- 核心维度满值为 150。

### Requirement: 活动与精力系统 (Activity & Energy System)
The system SHALL provide an activity system where:
- 角色拥有每日精力值（如默认 100 点）。
- 执行不同的课程/活动（如“专业精读课”）将消耗精力值，并获得对应的基础属性奖励（如学业素养 +20~35）。
- 每日首次登录（跨天）自动回满精力值。

#### Scenario: 玩家安排课程
- **WHEN** 玩家在活动面板选择“体能特训课”并点击执行
- **THEN** 系统扣除对应精力值，随机增加 15~25 点“体能活力”，并保存至角色存档，UI 实时刷新显示最新数值。

## MODIFIED Requirements
### Requirement: 角色存档持久化
`character_profile.gd` SHALL persist the 6 basic stats, 3 core dimensions, and current energy points. 
**Migration**: Existing save files should initialize these new stats to their default level 1 values (e.g., 0) and max energy.