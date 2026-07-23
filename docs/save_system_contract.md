# 存档系统契约

## 状态分层

- 全局设置保存在 `user://config.json`，不属于档案快照。
- 档案长期状态保存在 `user://accounts/<account>/archives/<archive>/`。
- 进行中的剧情只通过 `active_story_state.json` 恢复，不代表一次完整自动存档。
- 弹窗、动画、网络请求、未完成的流式回复和场景节点引用不保存。

## 自动存档提交点

以下业务完成后调用 `SaveManager.auto_save(reason, expected_archive_id)`：

- 新档案初始化完成。
- 剧情、约会和引导剧情完成全部结算。
- 行程、课程、睡眠跨天等玩法结算完成。
- 服装、背景或其他持久化外观状态确认变更。
- 切换档案前保存旧档案。
- 应用真正退出前进行一次兜底保存。

聊天系统后续应在玩家消息与 AI 完整回复构成一个完整回合后提交，不应在流式分句阶段进行全量自动存档。

## 剧情检查点

剧情在对话、选择、称呼输入、自由聊天等阻塞事件处保存检查点。检查点必须包含：

- `schema_version`
- `archive_id`
- `character_id`
- `script_id`
- `script_path`
- `chapter_id`
- `event_index`
- 无资源路径的运行时剧本还需包含 `script_data`

保存检查点不得推进剧情。剧情结束时，顺序必须是：

1. 执行剧情、关系、事件、目标、地图、记忆和引导结算。
2. 提交完整档案。
3. 提交成功后清除剧情检查点。
4. 最后切换场景。

提交失败时保留检查点并停止场景切换。

## 当前 Schema

当前 `ARCHIVE_SCHEMA_VERSION` 为 `1`。不兼容旧的平铺档案文件：

- `settings.json` 使用 `{ schema_version, archive_id, settings }`。
- `custom_state.json` 使用 `{ schema_version, archive_id, state }`。
- `active_story_state.json` 使用带 schema、档案和角色身份的检查点。
- `meta.json` 包含 `schema_version`、`save_generation` 和 `save_reason`。

所有异步或延迟保存请求必须在请求创建时捕获 `expected_archive_id`。活动档案不同则拒绝写入。

统一提交在主线程同步串行执行。保存过程中发生重入请求时直接拒绝，调用方收到 `false`；失败请求不会更新 `meta.json` 或递增 `save_generation`。

## 当前提交范围

统一自动存档刷新以下状态：

- 角色档案、主聊天历史、NPC 关系。
- 玩家记忆、桌宠记忆、故事记忆。
- 剧情时间、礼物、番茄钟、朋友圈和事件。
- 目标、主聊天话题、剧情后续事件、Guide。
- 固定手机聊天状态、相册状态和地图触发历史。
- 档案设置和 `meta.json`。

## 后续阶段

当前提交会聚合关键 Manager 的写入结果，只有全部成功才更新 `meta.json`。它仍由多个文件顺序写入，不具备跨文件回滚能力。下一阶段应引入 dirty domain；最终使用 generation 目录与 manifest，只让 manifest 指向完整写入成功的快照。

## Generation 快照

每次统一提交前写入 `commit_in_progress.json`。业务状态与 `meta.json` 全部写入成功后，将档案内受管 JSON 复制到 `.generations/.staging-gen-N/data/`，记录文件大小和 SHA-256，校验通过后发布为 `gen-N`，最后替换根 `manifest.json` 指针并删除提交标记。

只保留最近三个完整 generation。快照排除：

- `active_story_state.json`，剧情检查点独立恢复。
- `.generations`、manifest、提交标记和临时文件。
- `date_drafts`。
- 照片目录中的图片等二进制文件，仅包含 `photo_metadata.json`。

应用启动或切换档案前，如果发现提交标记，则从 manifest 指向的完整 generation 恢复 live 文件。manifest 损坏时扫描 generation 并选择最新通过大小和 SHA-256 校验的完整代，同时重建指针。恢复长期快照不会覆盖剧情检查点、照片或草稿。

Godot 和底层文件系统不提供数据库级跨文件原子事务。manifest 是最后发布的单文件提交指针；它将可见提交限定为完整快照，但无法保证存储设备在断电时已将所有缓存物理落盘。