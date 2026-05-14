# Checklist

- [x] 记忆数据结构正确添加到 `CharacterProfile`，并在保存/读取存档时不会丢失。
- [x] 聊天结束后，系统能够静默调用 API 提取出合理的 JSON 记忆数据并存入本地。
- [x] 大模型的 System Prompt 中正确注入了历史记忆文本。
- [x] 日程安排执行过程中，能够按预期概率触发暂停并弹出 `schedule_event_panel`。
- [x] `schedule_event_panel` 能够正确显示 AI 生成的事件情境和选项。
- [x] 玩家做出选择后，系统能根据 AI 结算结果正确增减属性，并继续未完成的日程安排。