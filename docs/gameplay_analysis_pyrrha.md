# Pyrrha.gd 游戏玩法特性分析报告

本报告基于对 `e:\GalChat_APP\参考\Pyrrha.gd` 源码的深入分析，拆解了 Pyrrha 作为桌面伴侣的核心玩法特性及其底层实现逻辑。

## 1. 主动聊天 (Proactive Chat)
Pyrrha 具备在用户闲置或专注工作时主动发起话题的能力，避免了单纯的“你问我答”模式，提升了陪伴感。
- **触发机制**：通过 `_update_process_monitor(delta)` 持续累加 `_time_since_last_switch`。当该计时器超过设定的 `idle_greeting_interval`（默认 180 秒）且角色处于空闲状态时，触发主动对话。
- **AI 驱动的上下文生成**：调用 `_handle_ai_proactive_topic_request()`，该方法会从全局状态机中获取当前的关系阶段（如 `STRANGER`, `LOVER`）、信任度和亲密度，并结合用户当前停留的应用程序名称，向大语言模型请求生成贴合情境的开场白。
- **视觉联动补强**：在发起主动话题前，若视觉模型（Vision）已启用，代码会优先调用 `chat_content_manager.analyze_now()` 截取屏幕画面。如果视觉模型能返回有效的屏幕内容总结（`summary_reply`），则直接使用该总结作为主动聊天内容，实现“看图说话”。

## 2. 窗口监控 (Window Monitoring)
作为桌面宠物，Pyrrha 能够感知用户的桌面操作，这是其交互逻辑的基石。
- **定时轮询**：在物理帧更新 `_physics_process` 中调用 `_update_process_monitor`，每隔 `_check_interval`（1.0 秒）读取一次操作系统的当前前台进程名称和窗口标题。
- **应用分类与过滤**：
  - 依靠本地配置文件 `AppData.json` 将进程映射为具体的应用类型（如 `chat`, `game_moba`, `dev`, `browser` 等）。
  - 根据应用类型的不同，派发到特定的处理函数，如 `_handle_chat_activity()` 或 `_handle_game_activity()`。
- **防频繁打扰机制**：为了防止应用频繁切换导致 Pyrrha 话痨，系统实现了严格的冷却时间（如全局反应冷却 `_last_reaction_tick` 设置为 2.5 ~ 7.5 秒不等），并在同类型行为发生时检查 `_last_reaction_type` 避免复读。

## 3. 视觉分析 (Vision Analysis)
视觉分析使得 Pyrrha 突破了仅仅读取“窗口标题”的限制，真正“看懂”用户在做什么。
- **模糊匹配时的强制唤醒**：在 `_handle_chat_activity` 中，如果识别到的聊天软件标题是笼统的“微信”或“QQ”（而不是具体的聊天对象名字），Pyrrha 会强制调用 `chat_content_manager.analyze_now()` 启动视觉分析，以获取实际的聊天对象。
- **内容总结与情绪感知**：视觉分析完成后，会触发 `_on_chat_content_analyzed(data)` 信号回调。数据字典中包含了 `chat_with`（聊天对象）、`current_topic`（当前话题）和 `user_emotion`（用户情绪）。
- **动态反应**：如果视觉分析直接给出了 `summary_reply`（总结性吐槽），Pyrrha 会将其拆分并以气泡形式逐句显示。此外，若系统检测到用户情绪为“难过”或“生气”，Pyrrha 还会调用底层关系接口进行情感抚慰。

## 4. 整点报时 (Hourly Chime)
- **系统时间监听**：`_check_hourly_chime()` 同样挂载在窗口监控定时器中。通过 `Time.get_time_dict_from_system()` 获取当前小时与分钟。
- **容错触发**：为了避免刚好在整点时因为对话阻塞而错过报时，代码允许在 0-2 分钟的窗口期内触发报时，并记录 `_last_hourly_chime_hour` 确保每小时只报一次。
- **情境融合**：整点报时并非硬编码的“现在是X点”。系统会将当前时间（并转化为清晨、中午、深夜等自然语言描述）作为上下文传入 AI 模型（`_request_activity_reaction_from_ai`），让 AI 结合当前时间段的话题设定（`chime_topics`）自然地提醒用户。

## 5. 动态关系调整 (Dynamic Relationship Adjustment)
Pyrrha 的行为会随着与用户关系的深入而发生动态变化，这也是 Galgame 元素的核心。
- **多状态机并行**：依赖全局的 `parallel_state_machine`，包含关系状态机和情绪状态机，管理着 `trust`（信任度）和 `intimacy`（亲密度）。
- **关系阶段差异化反馈**：
  - 代码中定义了 `STRANGER`, `FRIEND`, `LOVER`, `SP_TOXIC_ATTACHMENT` 等阶段。
  - **吃醋机制（Jealousy）**：在 `LOVER` 等高亲密度阶段，当 `_handle_chat_activity` 检测到用户与敏感词汇（如“老婆”、“宝贝”或配置的女性名字）聊天时，会触发 `_trigger_jealousy_reaction`，不仅会让 AI 生成吃醋文本，还会调用 `_modify_relationship(-2, -1)` 扣除好感度。
  - **随机吃醋测试**：在恋人阶段，即使对方不在敏感词库内，也有 20% 的概率触发吃醋，增加互动的不可预测性。
  - **游戏互动**：在游戏进程中，如果标题栏包含胜利关键词（`game_win`），Pyrrha 会通过 `_modify_relationship(1, 1)` 增加好感度并送上祝贺。

## 6. 鼠标穿透 (Mouse Passthrough)
为了不影响用户正常的电脑使用，必须实现精确的窗口交互控制。
- **合并交互区域**：`get_passthrough_rect()` 函数负责计算当前哪些屏幕区域需要拦截鼠标点击。它不仅包含 Pyrrha 自身的碰撞体积（`interaction_area`），还会遍历所有活跃的对话气泡（`_active_bubbles`），使用 `rect.merge(bubble_rect)` 将所有气泡区域合并为一个大的矩形。
- **实时系统同步**：在 `_physics_process` 中，只要 Pyrrha 发生了移动（`velocity.length() > 0`）或存在活跃气泡，就会高频调用 `get_tree().call_group("main", "_update_mouse_passthrough")`。
- **无缝体验**：这会通知主场景将合并后的区域发送给操作系统，使未覆盖的区域完全透明且不响应鼠标，从而实现了“虚拟角色在桌面上走动，但完全不影响用户点击后方应用”的神奇效果。