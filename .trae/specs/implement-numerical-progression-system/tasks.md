# Tasks

- [x] Task 1: 数据层 - 新增基础属性与核心维度的数据结构
  - [x] SubTask 1.1: 在 `character_profile.gd` 中新增 6 项基础属性（`physical_fitness`, `vitality`, `academic_quality`, `knowledge_reserve`, `social_eq`, `creative_aesthetics`）的数值，初始值均为 0。
  - [x] SubTask 1.2: 新增角色当前的“精力值（`current_energy`）”和“行动力上限（`max_energy`，默认100）”，并修改 `init_daily_mood`，实现跨天时恢复满精力值。
  - [x] SubTask 1.3: 修改 `character_profile.gd` 的 `save_profile` 和 `load_profile` 以支持持久化存储这些新数据。

- [x] Task 2: 逻辑层 - 实现数值核心系统 `stats_system.gd`
  - [x] SubTask 2.1: 在 `assets/scripts/data/` 创建 `stats_system.gd`（并在 `game_data_manager.gd` 中注册为单例/节点）。
  - [x] SubTask 2.2: 实现三大核心维度的换算方法（`get_core_physical`, `get_core_intelligence`, `get_core_charm`），使用 PDF 提供的权重与除法（向下取整）公式。
  - [x] SubTask 2.3: 实现基础属性增加的方法（`add_basic_stat`），限制单项属性最大值为 2000。

- [x] Task 3: 逻辑层 - 实现课程/活动系统 `activity_manager.gd`
  - [x] SubTask 3.1: 在 `assets/scripts/data/` 创建 `activity_manager.gd`（并在 `game_data_manager.gd` 中注册为单例/节点）。
  - [x] SubTask 3.2: 定义 PDF 中的 6 门必修课程及其收益范围（如：体能特训课、户外实践课、专业精读课、通识博学课、社交表达课、形象设计课）。
  - [x] SubTask 3.3: 实现执行活动的逻辑（`execute_activity`），验证精力是否足够，扣除精力，计算随机收益并调用 `stats_system` 增加属性，返回收益结果。

- [x] Task 4: 视图层 - 制作属性展示面板 `stats_panel`
  - [x] SubTask 4.1: 创建 UI 场景 `assets/scenes/ui/stats_panel.tscn` 及其脚本 `stats_panel.gd`。
  - [x] SubTask 4.2: 使用 ProgressBar 或 Label 直观展示六大基础属性的进度与等级（0-2000）。
  - [x] SubTask 4.3: 使用 Label 重点展示换算后的三大核心维度（体、智、魅）数值。

- [x] Task 5: 视图层 - 制作行程安排面板 `activity_panel`
  - [x] SubTask 5.1: 创建 UI 场景 `assets/scenes/ui/activity_panel.tscn` 及其脚本 `activity_panel.gd`。
  - [x] SubTask 5.2: 动态生成课程按钮列表，并在按钮上显示名称与消耗的精力。
  - [x] SubTask 5.3: 点击按钮时执行活动，展示属性增加的提示（如飘字或弹窗），并刷新顶部的精力条和属性面板。

- [x] Task 6: 集成 - 主界面入口与测试
  - [x] SubTask 6.1: 在游戏的主界面（如 `main.tscn` 或 `chat_ui.tscn`，根据项目结构）添加“属性”与“行程”的入口按钮。
  - [x] SubTask 6.2: 点击按钮可弹出对应的 Panel，关闭后可返回主界面。
  - [x] SubTask 6.3: 运行并测试一套完整的流程：查看初始属性 -> 打开行程 -> 消耗精力上课 -> 查看属性成长 -> 验证核心维度是否按公式换算增加。

# Task Dependencies
- [Task 2] depends on [Task 1]
- [Task 3] depends on [Task 2]
- [Task 4] depends on [Task 2]
- [Task 5] depends on [Task 3]
- [Task 6] depends on [Task 4] and [Task 5]