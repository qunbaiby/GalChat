extends Node

const PromptBuilderScript = preload("res://scripts/api/chat_realize_turn_prompt_builder.gd")
const SERVICE_PATH := "res://scripts/api/chat_realize_turn_service.gd"
const DEEPSEEK_CLIENT_PATH := "res://scripts/api/deepseek_client.gd"
const DESKTOP_PET_PATH := "res://scripts/ui/desktop_pet/desktop_pet.gd"
const MOBILE_CHAT_PATH := "res://scripts/ui/mobile/chat/mobile_chat_panel.gd"
const CHARACTER_BUBBLE_PATH := "res://scripts/ui/mobile/chat/bubbles/character_bubble.gd"
const DIALOGUE_MANAGER_PATH := "res://scripts/dialogue/dialogue_manager.gd"
const MAIN_SCENE_PATH := "res://scripts/ui/main/main_scene.gd"
const GUIDE_MANAGER_PATH := "res://scripts/data/guide_manager.gd"
const DEBUG_PANEL_PATH := "res://scripts/ui/story/debug_panel.gd"
const DESKTOP_CHAT_WINDOW_PATH := "res://scripts/ui/main/desktop_chat_window.gd"
const DATE_BUBBLE_CONTROLLER_PATH := "res://scripts/ui/date/date_bubble_controller.gd"

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var builder = PromptBuilderScript.new()
	var messages := builder.build_messages(
		"角色核心与可靠记忆。",
		[
			{"role": "assistant", "content": "上一轮回复。"},
			{"role": "user", "content": "现在陪我聊聊。 <--- 【系统提示：这是你们上次聊天的最后一句话，请顺着这个话题继续延展，不要生硬地开启新话题】"}
		],
		"现在陪我聊聊。"
	)
	_expect(str(messages[0].get("role", "")) == "system", "规范上下文第一条不是 system。")
	_expect(str(messages.back().get("content", "")).ends_with("现在陪我聊聊。"), "当前玩家原文不是最后一条。")
	_expect(messages.filter(func(message): return str(message.get("role", "")) == "user").size() == 1, "当前玩家输入被重复注入。")
	_expect(str(messages[0].get("content", "")).contains("[SPLIT]、圆括号动作、<voice:...> 标签或纯文本回复的要求均已废止"), "v6 提示没有废止旧桌宠输出合同。")
	var event_messages := builder.build_messages("角色正在通话。", [], "玩家发起的语音通话刚刚被角色接通。", [], "program_event")
	_expect(str(event_messages[0].get("content", "")).contains("不是玩家说出的话"), "程序事件合同没有禁止把事件当作玩家话语。")
	_expect(str(event_messages.back().get("content", "")).begins_with("【current_program_event"), "程序事件没有使用独立因果起点标签。")

	var service_source := _read_text(SERVICE_PATH)
	_expect(service_source.contains('history_type == "desktop_pet"'), "编排器没有桌宠渠道分支。")
	_expect(service_source.contains("GameDataManager.desktop_pet_memory_manager") and service_source.contains('"desktop_pet"'), "桌宠没有使用现实记忆域。")
	_expect(service_source.contains('history_type == "main_chat" and GameDataManager.chat_scene_state_runtime'), "主场景现场状态没有与桌宠隔离。")
	_expect(service_source.contains("additional_authoritative_context"), "编排器不支持注入程序已提交事实。")
	_expect(service_source.contains("_cancellation_generation") and service_source.contains("request_generation != _cancellation_generation"), "编排器无法丢弃取消期间仍在构建 prompt 的请求。")
	_expect(service_source.contains("if not _active_requests.has(network_id)"), "编排器无法丢弃取消后的迟到网络响应。")
	var deepseek_client_source := _read_text(DEEPSEEK_CLIENT_PATH)
	_expect(not deepseek_client_source.contains("DeepSeekChatStreamService"), "DeepSeekClient 仍加载废弃流式服务。")
	_expect(not deepseek_client_source.contains("send_chat_message_stream"), "DeepSeekClient 仍暴露废弃普通流式对话入口。")
	_expect(not deepseek_client_source.contains("start_chat_stream_with_messages"), "DeepSeekClient 仍暴露废弃自定义流式入口。")
	_expect(not deepseek_client_source.contains("chat_stream_started"), "DeepSeekClient 仍暴露废弃流式开始信号。")
	_expect(not deepseek_client_source.contains("chat_stream_delta"), "DeepSeekClient 仍暴露废弃流式增量信号。")
	_expect(deepseek_client_source.contains("if _uses_official_ai() and not await OfficialAuthManager.ensure_valid_access_token():"), "结构化聊天请求前没有续期官方 access token。")
	_expect(deepseek_client_source.contains("response_code == 401") and deepseek_client_source.contains("OfficialAuthManager.force_refresh_access_token()"), "结构化聊天收到 401 后没有刷新 token。")
	_expect(deepseek_client_source.contains("_start_structured_chat_request(api_messages, request_context)"), "结构化聊天刷新 token 后没有重放原请求。")

	var desktop_pet_source := _read_text(DESKTOP_PET_PATH)
	_expect(desktop_pet_source.contains('send_realize_turn_message(raw_user_text, "desktop_pet"'), "桌宠玩家输入未接入 RealizeTurn。")
	_expect(desktop_pet_source.contains("realize_turn_completed.connect(_on_realize_turn_completed)"), "桌宠没有连接验收完成信号。")
	_expect(desktop_pet_source.contains('bubble_queue.append({"text": rendered_text, "voice_instruction": delivery_instruction})'), "桌宠分段没有绑定动态语音指令。")
	_expect(not desktop_pet_source.contains("系统强制判定：若玩家要求放歌/播放音乐"), "桌宠普通回复仍把工具命令藏在台词合同里。")
	_expect(desktop_pet_source.contains("音乐系统已经完成停止"), "桌宠停止音乐事实没有进入权威上下文。")
	_expect(desktop_pet_source.contains('realize_context["channel"] = "desktop_pet_proactive"'), "桌宠主动事件没有独立的 RealizeTurn 回调渠道。")
	_expect(desktop_pet_source.contains('realize_context["turn_origin"] = "program_event"'), "桌宠主动事件没有使用程序事件因果起点。")
	_expect(desktop_pet_source.contains('send_realize_turn_message(prompt_text, "desktop_pet", realize_context, prompt_access_context)'), "桌宠主动事件未接入 RealizeTurn。")
	_expect(not desktop_pet_source.contains("start_chat_stream_with_messages(pet_messages"), "桌宠主动事件仍使用旧流式生成链。")

	var mobile_chat_source := _read_text(MOBILE_CHAT_PATH)
	_expect(mobile_chat_source.contains('send_realize_turn_message(player_text, "mobile_chat", request_context)'), "手机自由聊天未接入 RealizeTurn。")
	_expect(mobile_chat_source.contains('"recent_messages": recent_messages'), "手机自由聊天没有显式提交自身历史。")
	_expect(mobile_chat_source.contains('"delivery_instruction": str(segment.get("delivery_instruction", "")).strip_edges()'), "手机角色分段没有保存动态语音指令。")
	_expect(mobile_chat_source.contains('build_tts_2_instruction_options(str(msg.get("delivery_instruction", "")))'), "手机语音播放没有使用分段动态语音指令。")
	_expect(mobile_chat_source.contains('"channel": "mobile_call"'), "手机通话自由发言没有独立的 RealizeTurn 回调渠道。")
	_expect(mobile_chat_source.contains('"recent_messages": recent_messages') and mobile_chat_source.contains("current_call_history.slice(-10)"), "手机通话没有显式提交独立历史。")
	_expect(mobile_chat_source.contains('"voice_instruction": str(segment.get("delivery_instruction", "")).strip_edges()'), "手机通话分段没有绑定动态语音指令。")
	_expect(mobile_chat_source.contains("call_panel.add_character_message(call_message)"), "手机通话没有将结构化分段提交给通话面板。")
	_expect(mobile_chat_source.contains('"channel": "mobile_red_packet"'), "手机红包反应没有独立的 RealizeTurn 回调渠道。")
	_expect(mobile_chat_source.contains("角色已经领取该红包"), "手机红包领取事实没有进入权威上下文。")
	_expect(not mobile_chat_source.contains("var fake_msg ="), "手机红包仍通过伪造历史消息驱动角色回复。")
	_expect(not mobile_chat_source.contains("call_chat_api_non_stream("), "手机普通对话仍存在旧非流式生成入口。")
	_expect(not mobile_chat_source.contains("_schedule_follow_up_message"), "手机普通对话仍保留本地角色 follow-up 模板。")
	var character_bubble_source := _read_text(CHARACTER_BUBBLE_PATH)
	_expect(character_bubble_source.contains("panel._play_voice_message(text, msg)"), "手机语音气泡没有把消息元数据传给 TTS。")

	var dialogue_manager_source := _read_text(DIALOGUE_MANAGER_PATH)
	_expect(dialogue_manager_source.contains('send_realize_turn_message(text, "story_chat"'), "Story 普通玩家对话未接入 RealizeTurn。")
	_expect(dialogue_manager_source.contains('"channel": "story_dialogue_player"'), "Story 普通玩家对话没有独立回调渠道。")
	_expect(dialogue_manager_source.contains("_process_realized_story_segment"), "Story RealizeTurn 分段没有进入专用播放管线。")
	_expect(dialogue_manager_source.contains('str(segment.get("delivery_instruction", "")).strip_edges()'), "Story RealizeTurn 分段没有绑定动态语音指令。")
	_expect(dialogue_manager_source.contains('"response_segment_index": int(segment.get("response_segment_index", 0))'), "Story RealizeTurn 分段没有保存 trace 元数据。")
	_expect(dialogue_manager_source.contains("send_chat_message_structured"), "Story Guided AI 的 beat JSON 请求被普通 RealizeTurn 迁移覆盖。")
	_expect(dialogue_manager_source.contains("func _request_guided_ai_opening() -> void:"), "Story Guided AI 进入后没有请求角色主动开场。")
	_expect(dialogue_manager_source.contains("send_options_generation(reply"), "Story Guided AI 角色回复后没有请求生成玩家选项。")
	_expect(dialogue_manager_source.contains("func _populate_quick_options(options: Array) -> void:\n\tif quick_option_layer:\n\t\tquick_option_layer.show()"), "Story AI 主线动态选项没有重新显示外层 QuickOptionLayer。")
	_expect(dialogue_manager_source.contains('"event_kind": "offline_continue"'), "Story 离线重逢续写未迁移为程序事件。")
	_expect(dialogue_manager_source.contains('"event_kind": "gift_reaction"'), "Story 送礼反应未迁移为程序事件。")
	_expect(dialogue_manager_source.contains('"event_kind": "chat_exit"'), "Story 结束告别未迁移为程序事件。")
	_expect(dialogue_manager_source.contains('"channel": "story_dialogue_event"') and dialogue_manager_source.contains('"turn_origin": "program_event"'), "Story 程序事件没有使用独立回调渠道和因果起点。")
	_expect(not dialogue_manager_source.contains("call_chat_api_non_stream("), "Story 普通角色对话仍存在旧非流式生成入口。")
	_expect(not dialogue_manager_source.contains("deepseek_client.send_chat_message("), "Story 普通角色对话仍存在旧聊天生成入口。")

	var main_scene_source := _read_text(MAIN_SCENE_PATH)
	_expect(main_scene_source.contains('"channel": "main_chat_farewell"'), "主场景告别没有独立的 RealizeTurn 回调渠道。")
	_expect(main_scene_source.contains('"turn_origin": "program_event"'), "主场景告别没有使用程序事件因果起点。")
	_expect(not main_scene_source.contains("send_chat_message_stream("), "主场景普通角色对话仍存在旧流式生成入口。")
	_expect(not main_scene_source.contains("chat_stream_started.connect"), "主场景仍连接旧流式开始信号。")
	_expect(not main_scene_source.contains("chat_stream_delta.connect"), "主场景仍连接旧流式增量信号。")
	_expect(main_scene_source.contains('elif _main_action_mode == "schedule":\n\t\t_pause_main_scene_bgm("activity_panel")'), "首次打开行程安排时没有立即暂停主场景 BGM。")
	_expect(main_scene_source.contains("date_button.visible = date_unlocked"), "约会按钮没有随解锁状态切换可见性。")
	var guide_manager_source := _read_text(GUIDE_MANAGER_PATH)
	for feature_id in ["main.diary", "main.creation", "main.wardrobe", "main.date"]:
		_expect(guide_manager_source.contains('"%s": true' % feature_id), "%s 没有配置为默认锁定。" % feature_id)
	var debug_panel_source := _read_text(DEBUG_PANEL_PATH)
	_expect(debug_panel_source.contains('{"id": "main.diary", "label": "日记"}'), "Debug 面板无法解锁主场景日记功能。")

	var desktop_chat_source := _read_text(DESKTOP_CHAT_WINDOW_PATH)
	_expect(desktop_chat_source.contains('send_realize_turn_message(text, "desktop_pet"'), "桌面壁纸自由聊天未接入 RealizeTurn。")
	_expect(desktop_chat_source.contains('"channel": "desktop_wallpaper_chat"'), "桌面壁纸聊天没有独立回调渠道。")
	_expect(not desktop_chat_source.contains("start_chat_stream_with_messages"), "桌面壁纸聊天仍使用旧流式生成链。")
	_expect(not desktop_chat_source.contains("我在听。"), "桌面壁纸聊天仍保留本地角色假回复。")
	_expect(desktop_chat_source.contains("cancel_realize_turn_requests()"), "桌面壁纸窗口关闭时没有取消 RealizeTurn。")

	var date_bubble_source := _read_text(DATE_BUBBLE_CONTROLLER_PATH)
	_expect(date_bubble_source.contains('"channel": "date_bubble"'), "约会气泡没有独立的 RealizeTurn 回调渠道。")
	_expect(date_bubble_source.contains('"turn_origin": "program_event"'), "约会气泡没有使用程序事件因果起点。")
	_expect(date_bubble_source.contains("build_tts_2_instruction_options(delivery_instruction)"), "约会气泡没有使用分段动态语音指令。")
	_expect(not date_bubble_source.contains("start_chat_stream_with_messages"), "约会气泡仍使用旧流式生成链。")
	_expect(date_bubble_source.contains("cancel_realize_turn_requests()"), "约会气泡销毁时没有取消 RealizeTurn。")
	_finish()


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		failures.append("无法读取：%s" % path)
		return ""
	return file.get_as_text()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CHAT_REALIZE_TURN_CONTEXT_SMOKE_OK")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error("CHAT_REALIZE_TURN_CONTEXT_SMOKE: %s" % failure)
	get_tree().quit(1)