# Debug Session: date-segment-flow
- **Status**: [OPEN]
- **Issue**: 约会剧情每个时段内容偏短；时段切换时标题卡未稳定衔接；用户期望三个时段分开生成并各自有完整剧情体量
- **Scope**:
  - `scripts/data/date_story_manager.gd`
  - `scripts/ui/date/date_generation_controller.gd`
  - `scripts/api/services/deepseek/deepseek_scene_event_service.gd`
  - `scripts/dialogue/dialogue_manager.gd`
  - `scripts/ui/story/story_period_card.gd`

## Reproduction Steps
1. 在约会界面选择三个时段的地点。
2. 生成约会剧情并进入故事场景。
3. 观察每个时段的剧情长度是否足够。
4. 观察从一个时段切换到下一个时段时，是否稳定显示标题卡后再进入剧情。

## Hypotheses
| ID | Hypothesis | Likelihood | Effort | Evidence |
|----|------------|------------|--------|----------|
| A | 当前单次 AI 返回的 `segments` 仅提供很短的段落骨架，而本地扩写不足，导致每个时段体感偏短 | High | Med | Pending |
| B | 标题卡事件插入位置正确，但下一条可阻塞事件过早推进，导致切段时没有完整播放标题卡 | High | Med | Pending |
| C | 现在仍是“一次请求生成三段结构”，而不是逐时段请求，导致单段内容被压缩 | High | Low | Pending |
| D | 标题卡播放与背景/对白 UI 恢复时序冲突，导致切段时出现直接进剧情或视觉覆盖错误 | Med | Med | Pending |

## Plan
- 先核对当前生成链路是否仍为单请求多段。
- 再补运行时采证，记录每个 segment 的长度、转成 events 的数量、以及 `period_card` 前后的推进顺序。
- 依据证据决定是改为逐段生成，还是保留单请求但改为逐段扩写/逐段播放。

## Evidence
- 最新日志确认当前旧链路仍为一次请求生成三段：`plan_count = 3`，返回 `segment_count = 3`。
- 最新日志确认 AI 单段骨架过短：`segment_line_counts = [8, 8, 8]`，`segment_char_counts = [163, 182, 173]`。
- 最新日志确认最终脚本里只保留了一个切段卡：`final_period_card_count = 1`，因此第二、第三时段不是“标题卡太快”，而是根本没有正确落进最终脚本。

## Fix Direction
- 已将生成链路改为“逐时段请求 -> 单段 sanitize -> 最终合并完整剧本”。
- 已将 prompt 改为单段 richer 输出，常规模式要求每段 `10-14` 行，重试模式 `7-9` 行。
