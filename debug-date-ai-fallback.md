# Debug Session: date-ai-fallback
- **Status**: [OPEN]
- **Issue**: 约会剧情生成与槽位短评都直接走保底预设，怀疑 DeepSeek API 调用、响应解析或回退链路存在问题
- **Debug Server**: http://127.0.0.1:7777/event
- **Log File**: .dbg/trae-debug-log-date-ai-fallback.ndjson

## Reproduction Steps
1. 进入约会界面。
2. 将约会地点添加到时间槽位，观察是否立即显示 AI 短评还是直接显示预设文案。
3. 点击开始生成约会剧本，观察是否出现“AI 生成失败，已切换为保底剧情”。
4. 查看调试服务器采集到的运行时日志，定位请求发送、响应返回、解析、回退的具体断点。

## Hypotheses & Verification
| ID | Hypothesis | Likelihood | Effort | Evidence |
|----|------------|------------|--------|----------|
| A | DeepSeek 请求在发送前就失败，导致短评和剧本都直接 fallback | High | Low | Rejected |
| B | DeepSeek API 返回非 200、超时或限流，触发统一回退 | High | Low | Rejected |
| C | API 返回 200，但约会剧本 JSON 内容被截断，解析失败 | High | Med | Confirmed |
| D | 约会剧本已返回并解析成功，但被 sanitize 校验打回保底剧情 | High | Med | Confirmed |
| E | 共享 DeepSeekClient / HTTP 节点 / 信号链时出现串线或取消请求 | Med | Med | Rejected (slot comment queue fixed) |

## Log Evidence
- Debug server started and `.dbg/date-ai-fallback.env` generated.
- Instrumentation added to:
  - `DeepSeekClient` unified debug reporter
  - `deepseek_scene_event_service.gd`
  - `deepseek_chat_stream_service.gd`
  - `date_bubble_controller.gd`
  - `date_generation_controller.gd`
- Reproduction evidence:
  - 槽位短评 4 次请求都成功发出，均返回 HTTP 200，并拿到了 AI 生成文本。
  - 约会剧本请求成功发出，返回 HTTP 200。
  - 约会剧本在 `handle_date_story_completed()` 阶段失败，原因是 `_extract_json_object_from_response()` 未能把 `message.content` 解析成 JSON。
  - 在“只返回 summary + events”方案后，短评请求已按队列串行处理，未再出现前一条请求被后续请求覆盖的现象。
  - 约会剧本仍存在两种失败模式：
    - 模式1：返回 `summary + events` 但 `events` JSON 仍被截断，错误为 `Unterminated string`。
    - 模式2：返回 `summary + events` 并成功解析，但 `sanitize_generated_story()` 后 `used_fallback = true`，说明 AI 事件没有通过本地有效性/覆盖校验。
  - 最新修复已切换为单一稳定模式：AI 只返回 `summary + segments`，本地按 `date_plan` 顺序统一补全 `background`、时段标题、立绘显示逻辑和完整脚本外壳。
  - 最新修复已移除 `date_story_compact_mode` 这类旧分支，仅保留一个生成结构。
  - 最新修复已加入一次“同模式自动重试”：若首次解析失败或清洗后仍回退，会再用更短、更稳的参数请求一次。

## Verification Conclusion
[Pending]
