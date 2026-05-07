# Tasks
- [x] Task 1: 实现安全文件写入机制
  - [x] SubTask 1.1: 创建 `SafeFileAccess` 工具类或在现有单例中添加基于 `.tmp` 的安全写入方法。
- [x] Task 2: 搭建统筹全局的 `SaveManager`
  - [x] SubTask 2.1: 创建 `SaveManager` 脚本并注册为单例或在 `GameDataManager` 中初始化。
  - [x] SubTask 2.2: 实现 `SaveManager` 对 `CharacterProfile`, `ChatHistoryManager`, `MemoryManager` 数据的统一提取与打包。
  - [x] SubTask 2.3: 实现多槽位（Slot）的存档目录结构与元数据（Meta）管理。
- [ ] Task 3: 改造现有的存档调用
  - [ ] SubTask 3.1: 修改 `CharacterProfile`、`ChatHistoryManager` 等模块的 `save_*` 逻辑，让其向 `SaveManager` 报告变动或由 `SaveManager` 接管。
- [x] Task 4: 开发存读档 UI 界面
  - [x] SubTask 4.1: 创建存档槽位预制体 (`save_slot_item.tscn`)，展示存档信息。
  - [x] SubTask 4.2: 创建存读档主界面 (`save_load_panel.tscn`)，支持分页/列表浏览、保存、读取、删除操作。
  - [x] SubTask 4.3: 在主场景（如 `MainScene`）及开始场景（`StartScene`）添加存读档界面的入口。
- [x] Task 5: 联调与测试
  - [x] SubTask 5.1: 测试自动存档和手动存档是否独立。
  - [x] SubTask 5.2: 测试读取存档后游戏状态（亲密度、阶段、历史记录）是否正确恢复。

# Task Dependencies
- [Task 2] depends on [Task 1]
- [Task 3] depends on [Task 2]
- [Task 4] depends on [Task 2]
- [Task 5] depends on [Task 3] and [Task 4]
