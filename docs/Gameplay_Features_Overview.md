# 《GalChat》玩法与功能全景图谱

**文档说明**：本报告基于对 `GalChat` 项目（Godot 4.5.1 Mono 架构）的源码、场景及配置文件的全面分析生成，旨在提供整个项目的核心玩法、系统模块和功能点的全景视图。

---

## 一、 核心养成与成长系统 (Growth & Progression)

| 模块名称 | 功能名称 | 核心玩法 / 功能描述 | 关联代码 / UI场景 |
| :--- | :--- | :--- | :--- |
| **基础养成** | **四基十六维属性** | 核心属性分为体、智、魅、感4大类，下设体能、形体、学识、表达、气质、共情等16项子属性，决定角色的能力成长方向。 | `stats_panel.tscn`<br>`character_profile.json` |
| **基础养成** | **精力与经济管理** | 每日拥有固定的精力值（Energy），执行活动消耗精力并获得经验/金币，同时产生压力，需通过休息恢复。 | `top_status_panel.tscn`<br>`game_data_manager.gd` |
| **情感羁绊** | **情感阶段升阶** | 从“陌生人”到“灵魂伴侣”共9个阶段。升阶需满足“共感值”（亲密+信任）门槛，并消耗互动经验。 | `personality_system.gd`<br>`affection_button` |
| **动态人格** | **大五人格漂移** | 基于大五人格模型，日常互动产生“短期压力”和“长期塑形压力”，结算时引发人格属性漂移，影响角色底层性格。 | `personality_panel.tscn`<br>`personality_system.gd` |
| **动态人格** | **情绪与状态系统** | 情绪系统（开心、疲惫、委屈等）实时联动角色的表情和对话语气，并受双层压力架构（连续模式）影响。 | `emotion_panel.tscn`<br>`dialogue_manager.gd` |

---

## 二、 AI 交互与对话系统 (AI Interaction)

| 模块名称 | 功能名称 | 核心玩法 / 功能描述 | 关联代码 / UI场景 |
| :--- | :--- | :--- | :--- |
| **智能对话** | **多模型流式聊天** | 接入 DeepSeek、豆包、通义千问等 LLM。支持流式文本渲染、打字机效果及实时情感标签解析。 | `deepseek_client.gd`<br>`dialogue_panel.tscn` |
| **智能对话** | **动态话题推荐** | 根据当前世界观、所处阶段、时间和心情，AI 动态生成3个推荐话题（Topic）供玩家选择开启对话。 | `prompt_manager.gd`<br>`TopicPanel` (主场景) |
| **多模态交互** | **语音识别与合成** | 支持 ASR 玩家语音输入，以及 TTS 角色语音播报（过滤括号内的动作描写），增强沉浸感。 | `tts_manager.gd`<br>`voice_input_panel.tscn` |
| **记忆引擎** | **分层记忆路由** | 区分共享记忆、私人记忆、世界事实等（`visibility`控制），聊天和固定剧情会自动记录并成为后续 AI 回复的上下文。 | `memory_manager.gd`<br>`player_memory.json` |

---

## 三、 日常生活与社交 (Life & Social)

| 模块名称 | 功能名称 | 核心玩法 / 功能描述 | 关联代码 / UI场景 |
| :--- | :--- | :--- | :--- |
| **日程管理** | **行程安排** | 玩家规划角色每日行程（学习、打工、休息），消耗金币执行，提升各项子属性。周末休息或特定时间段限制。 | `activity_panel.tscn`<br>`schedule_manager.gd` |
| **地图探索** | **世界地图与事件** | 提供咖啡厅、艺术广场等15+个地点。结合时间、阶段解锁。进入地点可能触发全局事件调度池中的 AVG 剧情。 | `world_map_scene.tscn`<br>`event_registry.json` |
| **手机社交** | **虚拟手机系统** | 包含即时通讯（文字/语音/视频通话）、朋友圈（点赞互动）、相册等现代化虚拟手机功能。 | `mobile_interface.tscn`<br>`mobile_chat_history.json` |
| **生活互动** | **互动菜单** | 主界面右侧核心交互区，包含：与角色聊天、送礼、做饭、共创画板（AI绘画联动）、休息等操作。 | `InteractGroup` (主场景)<br>`main_scene.tscn` |

---

## 四、 记录与生产力工具 (Tools & Archives)

| 模块名称 | 功能名称 | 核心玩法 / 功能描述 | 关联代码 / UI场景 |
| :--- | :--- | :--- | :--- |
| **时间管理** | **番茄钟** | 游戏内置实用的番茄钟与待办事项管理，与角色的养成收益挂钩，陪伴玩家共同专注工作/学习。 | `pomodoro_panel.tscn`<br>`PomodoroButton` |
| **时光记录** | **AI 绘图日记** | 角色会根据当天的互动记录生成日记内容，并调用 AI 接口（Dall-E/豆包）自动生成当天的配图插画。 | `diary_panel.tscn`<br>`diary_manager.gd` |
| **关系图谱** | **人物关系网** | 档案系统中的核心模块。以可视化、可拖拽的树状图展示玩家、Luna 以及其他 NPC（如雅、静、朔）的解锁与关系状态。 | `relation_graph_view.tscn`<br>`luna_relationship_graph.json` |
| **休闲工具** | **音乐播放器** | 游戏内嵌音乐播放器组件，支持 BGM 列表管理与自定义音乐播放。 | `music_player.tscn`<br>`audio_manager.gd` |

---

## 五、 视觉与系统扩展 (Visuals & Extensions)

| 模块名称 | 功能名称 | 核心玩法 / 功能描述 | 关联代码 / UI场景 |
| :--- | :--- | :--- | :--- |
| **视觉呈现** | **Spine 骨骼与换装** | 深度集成 Spine 骨骼动画，提供极高品质的动态立绘。支持在“衣橱”中切换多套服装（如JK制服），实时改变外观。 | `wardrobe_panel.tscn`<br>`character_layer.gd` |
| **跨端体验** | **桌宠模式** | 游戏内点击即可无缝切换为“桌面宠物”模式，角色以 Q版 形态悬浮在系统桌面上陪伴玩家。 | `desktop_pet_main.tscn`<br>`DesktopPetButton` |
| **底层系统** | **全局存档机制** | 支持多档位存档（Slot），可持久化保存属性、记忆、聊天记录、手机数据等，包含自动存档与手动读写。 | `save_manager.gd`<br>`SystemButton` (主场景) |
| **UI 动效** | **自定义 Shader 渲染** | 主场景大量运用了高级 UI Shader（如地图按钮的左斜梯形切割+霓虹描边、天气模糊、过场消融等）。 | `left_trapezoid.gdshader`<br>`galchat_theme.tres` |

---

> 本文档由系统自动生成，旨在协助开发者与策划快速梳理项目脉络，掌握项目架构的宏观与微观关联。
