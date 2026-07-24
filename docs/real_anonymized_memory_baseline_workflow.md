# 真实匿名记忆质量基线工作流

## 目标

真实基线用于验证生产 embedding 模型下的记忆召回、近邻误召回、否定理解和冲突区分。它与仓库中的人工 smoke fixture 分开：人工 fixture 验证代码路径，真实基线验证产品质量。

## 隐私边界

- 只使用玩家明确同意参与评估的本地会话。
- 不自动导出聊天历史、检索 trace 或存档内容。
- 每条记忆和样本都必须由用户人工脱敏并复核。
- 不保留原始查询文本、玩家名、角色名、档案 ID、时间戳、来源消息引用或自由文本情绪状态。
- 真实数据默认放在 `user://quality_baselines/real_anonymized_memory_baseline.json`，不得提交到 Git。
- 如需在工作区临时处理，只能使用已忽略的 `private_quality_baselines/`。

## 数据准备

1. 复制 `addons/story_editor/tests/fixtures/real_anonymized_memory_baseline.template.json` 到私有位置。
2. 从获得同意的会话中人工选择候选，不运行自动原文导出。
3. 将人物、地点、组织、账号和独特事件改写为无法反推身份的泛化表达。
4. 删除所有禁止字段，并逐条设置 `anonymization_reviewed: true`。
5. 使用同一个生产 embedding 模型生成所有记忆向量和查询向量。
6. 填写真实 `embedding_model` 和 `embedding_dimension`。
7. 人工标注 `expected_memory_ids` 与 `forbidden_memory_ids`。

## 最低门禁

- 至少 12 个真实样本。
- `positive / near_negative / negation / conflict` 每类至少 2 个。
- 每条样本必须声明 `sample_origin: real_session`。
- 数据集来源必须为 `consented_local_sessions`，并设置用户复核和脱敏状态为已完成。
- `Recall@K = 1.0`、`Precision@K >= 0.5`、禁止记忆召回数为 0。

## 验证

默认读取用户目录：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\story_editor\validate_real_memory_baseline.ps1
```

也可以指定私有文件：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\story_editor\validate_real_memory_baseline.ps1 -Dataset res://private_quality_baselines/real_anonymized_memory_baseline.json
```

退出码：

- `0`：数据就绪且质量门禁通过。
- `1`：数据就绪，但召回质量门禁失败。
- `2`：数据缺失、未复核、未脱敏或覆盖不足，不能宣称真实基线完成。