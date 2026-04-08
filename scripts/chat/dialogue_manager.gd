extends Control

@onready var back_btn: Button = $UIOverlay/BackButton
@onready var debug_btn: Button = $UIOverlay/DebugButton
@onready var history_btn: Button = $UIOverlay/HistoryButton
@onready var intimacy_bar: ProgressBar = $UIOverlay/IntimacyBar

@onready var name_label: Label = $DialogueLayer/NameLabel
@onready var dialogue_text: RichTextLabel = $DialogueLayer/RichTextLabel
@onready var input_field: TextEdit = $InputLayer/HBoxContainer/InputField
@onready var send_btn: Button = $InputLayer/HBoxContainer/SendButton
@onready var affection_btn: Button = $InputLayer/HBoxContainer/AffectionButton
@onready var gift_btn: Button = $InputLayer/HBoxContainer/GiftButton
@onready var voice_record_btn: Button = $InputLayer/HBoxContainer/VoiceRecordButton

@onready var character_layer: TextureRect = $CharacterLayer

@onready var deepseek_client: DeepSeekClient = $DeepSeekClient
@onready var doubao_tts = $DoubaoTTSService
@onready var doubao_asr = $DoubaoASRService
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var mic_capture: AudioStreamPlayer = $MicCapture

@onready var history_panel: Panel = $HistoryPanel
@onready var history_close_btn: Button = $HistoryPanel/HistoryTopBar/HistoryCloseButton
@onready var history_vbox: VBoxContainer = $HistoryPanel/ScrollContainer/VBoxContainer

@onready var affection_panel: Control = $AffectionPanel
@onready var gift_panel: Control = $GiftPanel
@onready var debug_panel: Control = $DebugPanel
@onready var toast: ToastNotification = $ToastNotification
@onready var quick_options_container: VBoxContainer = $QuickOptionLayer/QuickOptions

const HISTORY_ITEM_SCENE = preload("res://scenes/ui/history/history_item.tscn")
const QUICK_OPTION_ITEM_SCENE = preload("res://scenes/ui/chat/quick_option_item.tscn")

func _ready() -> void:
	back_btn.pressed.connect(_on_back_pressed)
	history_btn.pressed.connect(_on_history_pressed)
	debug_btn.pressed.connect(_on_debug_pressed)
	affection_btn.pressed.connect(_on_affection_pressed)
	gift_btn.pressed.connect(_on_gift_pressed)
	gift_panel.gift_sent.connect(_on_gift_sent)
	send_btn.pressed.connect(_on_send_pressed)
	input_field.text_changed.connect(_on_input_text_changed)
	
	voice_record_btn.button_down.connect(_on_voice_record_down)
	voice_record_btn.button_up.connect(_on_voice_record_up)
	doubao_asr.asr_success.connect(_on_asr_success)
	doubao_asr.asr_failed.connect(_on_asr_failed)
	
	history_close_btn.pressed.connect(_on_history_close_pressed)
	
	debug_panel.stage_changed.connect(_on_debug_stage_changed)
	debug_panel.mood_changed.connect(_on_debug_mood_changed)
	
	GameDataManager.profile.stage_upgraded.connect(_on_stage_upgraded)
	
	deepseek_client.chat_request_completed.connect(_on_chat_response)
	deepseek_client.chat_request_failed.connect(_on_chat_error)
	deepseek_client.chat_stream_started.connect(_on_chat_stream_started)
	deepseek_client.chat_stream_delta.connect(_on_chat_stream_delta)
	
	deepseek_client.emotion_request_completed.connect(_on_emotion_response)
	deepseek_client.emotion_request_failed.connect(_on_emotion_error)
	
	deepseek_client.memory_request_completed.connect(_on_memory_response)
	deepseek_client.memory_request_failed.connect(_on_memory_error)
	
	deepseek_client.options_request_completed.connect(_on_options_response)
	deepseek_client.options_request_failed.connect(_on_options_error)
	
	deepseek_client.narrator_request_completed.connect(_on_narrator_response)
	deepseek_client.narrator_request_failed.connect(_on_narrator_error)
	
	doubao_tts.tts_success.connect(_on_tts_success)
	doubao_tts.tts_failed.connect(_on_tts_failed)
	
	# 配置TTS服务
	var config = GameDataManager.config
	doubao_tts.setup_auth(config.doubao_app_id, config.doubao_token, config.doubao_cluster)
	
	_update_ui()
	
	# 初始问候
	var messages = GameDataManager.history.messages
	if messages.size() == 0:
		var char_name = GameDataManager.profile.char_name
		_show_message("你好...今天想聊点什么？", char_name, false)
	else:
		# 有历史记录时，生成旁白并续写话题
		_generate_narrator_and_continue()

func _generate_narrator_and_continue() -> void:
	send_btn.disabled = true
	input_field.editable = false
	print("正在生成场景旁白...")
	# 清空对话框内容，保持干净
	dialogue_text.text = ""
	name_label.text = ""
	deepseek_client.send_narrator_generation()

func _on_narrator_response(response: Dictionary) -> void:
	if response.has("choices") and response["choices"].size() > 0:
		var narrator_text = response["choices"][0]["message"]["content"].strip_edges()
		
		# 显示旁白，无角色名，不发声，不记录到历史
		await _show_message_async(narrator_text, " ", true)
		
		# 旁白显示完后等待一小段时间
		if is_inside_tree():
			await get_tree().create_timer(1.5).timeout
			
		# 触发角色续写话题
		_trigger_character_continue()
	else:
		_on_narrator_error("旁白生成为空")

func _on_narrator_error(error_msg: String) -> void:
	print("旁白生成失败: ", error_msg)
	# 兜底：如果旁白失败，直接恢复最后一条消息或让角色直接说话
	_restore_last_message()
	send_btn.disabled = false
	input_field.editable = true

func _trigger_character_continue() -> void:
	print("旁白生成完毕，正在思考后续对话...")
	var char_name = GameDataManager.profile.char_name
	
	is_text_playback_finished = false
	pending_options_data.clear()
	
	# 计算玩家离线时间
	var offline_seconds = 0
	var last_time = GameDataManager.profile.last_online_time
	if last_time > 0:
		offline_seconds = Time.get_unix_time_from_system() - last_time
	
	# 获取性格系统动态生成的重逢问候策略
	var greeting_strategy = GameDataManager.personality_system.get_offline_greeting_strategy(GameDataManager.profile, offline_seconds)
	
	# 构造一条系统级的隐式 prompt，让 LLM 知道它需要主动续写话题
	var continue_prompt = "【系统提示：%s。注意：绝对不要输出这段系统提示，直接以%s的口吻说话。】" % [greeting_strategy, char_name]
	
	if GameDataManager.config.ai_mode_enabled:
		# 获取最近一条历史对话的 embedding 来进行记忆检索
		var query_embedding = []
		var messages = GameDataManager.history.messages
		if messages.size() > 0:
			var last_msg = messages[messages.size() - 1]["text"]
			query_embedding = await DoubaoEmbeddingClient.get_embedding(last_msg)
			
		var system_prompt = GameDataManager.prompt_manager.build_chat_prompt(GameDataManager.profile, query_embedding)
		var api_messages = [{"role": "system", "content": system_prompt}]
		api_messages.append_array(deepseek_client._get_history_messages(10))
		api_messages.append({"role": "user", "content": continue_prompt})
		
		var body = {
			"model": GameDataManager.config.model,
			"messages": api_messages,
			"temperature": GameDataManager.config.temperature,
			"max_tokens": GameDataManager.config.max_tokens
		}
		deepseek_client.chat_http.request(deepseek_client._get_url(), deepseek_client._get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	else:
		_show_message("（离线模式）你回来了，我们刚才聊到哪了？", char_name)
		send_btn.disabled = false
		input_field.editable = true

func _restore_last_message() -> void:
	var messages = GameDataManager.history.messages
	if messages.size() > 0:
		var last_msg = messages[messages.size() - 1]
		# 直接静默显示最后一条，不触发打字机和语音
		dialogue_text.text = last_msg["text"]
		dialogue_text.visible_characters = -1
		name_label.text = last_msg["speaker"]
		
		# 恢复对应立绘
		if last_msg["speaker"] == GameDataManager.profile.char_name:
			var current_mood = GameDataManager.profile.current_mood
			_update_character_sprite(current_mood)
	else:
		var char_name = GameDataManager.profile.char_name
		# 如果没有历史记录，静默显示初始问候
		dialogue_text.text = "你好...今天想聊点什么？"
		dialogue_text.visible_characters = -1
		name_label.text = char_name

func _on_input_text_changed() -> void:
	if input_field.text.length() > 120:
		input_field.text = input_field.text.substr(0, 120)
		input_field.set_caret_column(120)

func _update_ui() -> void:
	var profile = GameDataManager.profile
	var conf = profile.get_current_stage_config()
	var threshold = float(conf.get("threshold", 100))
	
	var display_max = threshold
	if threshold >= 9999:
		var prev_stage = max(1, profile.current_stage - 1)
		var prev_conf = profile.get_stage_config(prev_stage)
		var min_val = float(prev_conf.get("threshold", 0)) if not prev_conf.is_empty() else 0.0
		display_max = min_val + 500
		
	intimacy_bar.min_value = 0
	intimacy_bar.max_value = display_max
	intimacy_bar.value = min(profile.intimacy, display_max)
	
	# Update bar color to match stage
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = affection_panel.get_stage_color(profile.current_stage)
	intimacy_bar.add_theme_stylebox_override("fill", stylebox)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main/main_scene.tscn")

var _record_effect: AudioEffectRecord

func _on_voice_record_down() -> void:
	voice_record_btn.text = "松开发送"
	voice_record_btn.modulate = Color(0.8, 0.2, 0.2)
	var bus_idx = AudioServer.get_bus_index("Record")
	_record_effect = AudioServer.get_bus_effect(bus_idx, 0)
	if _record_effect:
		_record_effect.set_recording_active(true)

func _on_voice_record_up() -> void:
	voice_record_btn.text = "按住说话"
	voice_record_btn.modulate = Color(1, 1, 1)
	if _record_effect:
		_record_effect.set_recording_active(false)
		var recording = _record_effect.get_recording()
		if recording:
			recording.save_to_wav("user://temp_record.wav")
			var file = FileAccess.open("user://temp_record.wav", FileAccess.READ)
			if file:
				var data = file.get_buffer(file.get_length())
				file.close()
				toast.show_toast("正在识别语音...", Color.YELLOW)
				doubao_asr.recognize(data)

func _on_asr_success(text: String) -> void:
	if not text.is_empty():
		input_field.text = text
		toast.show_toast("语音识别成功", Color.GREEN)
	else:
		toast.show_toast("未听清你说什么", Color.ORANGE)

func _on_asr_failed(err: String) -> void:
	toast.show_toast("语音识别失败: " + err, Color.RED)
	print("ASR Error: ", err)

func _on_debug_pressed() -> void:
	debug_panel.show_panel()

func _on_affection_pressed() -> void:
	affection_panel.show_panel()

func _on_gift_pressed() -> void:
	gift_panel.show_panel()

func _on_gift_sent(gift_id: String) -> void:
	var profile = GameDataManager.profile
	var gift = GameDataManager.gift_manager.get_gift_by_id(gift_id)
	if gift.is_empty():
		return
		
	var res = GameDataManager.gift_manager.send_gift(profile, gift_id)
	if res.success:
		# 显示Toast
		var msg = "送出了 [%s]\n" % gift.name
		if res.gained_intimacy > 0:
			msg += "亲密 +%.1f " % res.gained_intimacy
		if res.gained_trust > 0:
			msg += "信任 +%.1f" % res.gained_trust
		toast.show_toast(msg, Color.VIOLET)
		
		_update_ui()
		
		# 触发LLM生成对应的感谢/反应
		_trigger_gift_reaction(gift)
	else:
		toast.show_toast(res.msg, Color.RED)

func _trigger_gift_reaction(gift: Dictionary) -> void:
	send_btn.disabled = true
	input_field.editable = false
	
	is_text_playback_finished = false
	pending_options_data.clear()
	
	var char_name = GameDataManager.profile.char_name
	var prompt = "【系统动作：玩家刚刚送给了你一份礼物，名称是：“%s”，描述是：“%s”。请根据你们当前的关系阶段（Stage %d）以及礼物的内容，给出自然的反应和台词。注意：不要输出这段系统提示，直接以%s的口吻说话。】" % [gift.name, gift.desc, GameDataManager.profile.current_stage, char_name]
	
	if GameDataManager.config.ai_mode_enabled:
		deepseek_client.send_chat_message(prompt)
	else:
		if is_inside_tree():
			await get_tree().create_timer(1.0).timeout
		_show_message("（离线模式）谢谢你的礼物！我很喜欢。", char_name)
		send_btn.disabled = false
		input_field.editable = true

func _on_debug_stage_changed(stage: int) -> void:
	toast.show_toast("【Debug】强制切换情感阶段至：" + str(stage), Color.CYAN)
	GameDataManager.profile.force_set_stage(stage)
	# Clear short term history so the AI doesn't get confused by previous stage's context
	GameDataManager.history.messages.clear()
	GameDataManager.history.save_history()
	_update_ui()
	toast.show_toast("已清空上下文历史，以重新适配新阶段", Color.GRAY)

func _on_stage_upgraded(new_stage: int, unlock_dialog: String) -> void:
	toast.show_toast("情感阶段提升至: Stage " + str(new_stage), Color.YELLOW)
	
	var stage_conf = GameDataManager.profile.get_current_stage_config()
	if stage_conf.has("mood_switch"):
		var new_mood = stage_conf["mood_switch"]
		if GameDataManager.mood_system.is_valid_mood(new_mood):
			GameDataManager.profile.update_mood(new_mood)
			toast.show_toast("心情切换为：" + new_mood, Color.ORANGE)

func _on_debug_mood_changed(mood: String) -> void:
	toast.show_toast("【Debug】强制切换心情至：" + mood, Color.CYAN)
	GameDataManager.profile.update_mood(mood)
	_update_ui()

func _update_character_sprite(mood: String) -> void:
	var sprite_path = GameDataManager.mood_system.get_mood_sprite_path(mood)
	if sprite_path != "":
		var tex = load(sprite_path)
		if tex:
			if character_layer.has_method("update_sprite"):
				character_layer.update_sprite(tex)
			else:
				character_layer.texture = tex

func _on_history_pressed() -> void:
	history_panel.show()
	_populate_history_ui()
	
	# 延迟一帧等待容器布局完成，然后滚动到底部
	if is_inside_tree():
		await get_tree().process_frame
	var scroll = history_panel.get_node("ScrollContainer")
	if scroll:
		var v_scroll = scroll.get_v_scroll_bar()
		v_scroll.value = v_scroll.max_value

func _on_history_close_pressed() -> void:
	history_panel.hide()

func _populate_history_ui() -> void:
	# 清空现有子节点
	for child in history_vbox.get_children():
		child.queue_free()
		
	var messages = GameDataManager.history.messages
	for msg in messages:
		var item = HISTORY_ITEM_SCENE.instantiate()
		history_vbox.add_child(item)
		item.setup(msg)
		item.play_voice_requested.connect(_play_cached_voice)

func _play_cached_voice(cache_key: String) -> void:
	var cache_path = doubao_tts.CACHE_DIR + cache_key + "." + doubao_tts.default_encoding
	if FileAccess.file_exists(cache_path):
		var stream = doubao_tts._load_audio_from_file(cache_path)
		if stream:
			audio_player.stream = stream
			audio_player.play()
	else:
		print("未找到语音缓存: ", cache_key)

var pending_status_changes = []

func _on_send_pressed() -> void:
	var text = input_field.text.strip_edges()
	if text.is_empty():
		return
		
	input_field.text = ""
	send_btn.disabled = true
	input_field.editable = false
	
	pending_status_changes.clear()
	
	is_text_playback_finished = false
	pending_options_data.clear()
	
	_show_message(text, "玩家")
	
	# 清空现有的快捷选项
	for child in quick_options_container.get_children():
		child.queue_free()
		
	if GameDataManager.config.ai_mode_enabled:
		deepseek_client.send_chat_message(text)
	else:
		# 本地兜底对话
		if is_inside_tree():
			await get_tree().create_timer(1.0).timeout
		var char_name = GameDataManager.profile.char_name
		_show_message("（离线模式）我...我不知道该说什么...", char_name)
		send_btn.disabled = false
		input_field.editable = true

var pending_reply_lines = []
var stream_live_active: bool = false
var stream_live_done: bool = false
var stream_live_buffer: String = ""
var stream_live_queue: Array = []
var stream_live_worker_running: bool = false

func _on_chat_stream_started() -> void:
	stream_live_active = true
	stream_live_done = false
	stream_live_buffer = ""
	stream_live_queue.clear()
	_try_start_stream_worker()

func _on_chat_stream_delta(delta_text: String) -> void:
	if not stream_live_active:
		return
	stream_live_buffer += delta_text
	_extract_stream_segments(false)
	_try_start_stream_worker()

func _on_chat_response(response: Dictionary) -> void:
	var char_name = GameDataManager.profile.char_name
	
	if stream_live_active:
		stream_live_done = true
		_extract_stream_segments(true)
		_try_start_stream_worker()
		
		# 当流式接收彻底完毕时，由于选项生成需要大约2~3秒，而打字机播放也需要时间
		# 我们在这里提前触发选项生成，让其在后台默默生成
		# 因为此时历史记录中还没有保存AI刚刚说的这句话，我们需要手动将它传给选项生成器
		if GameDataManager.config.ai_mode_enabled:
			deepseek_client.send_options_generation(deepseek_client._chat_stream_full_text)
		return
		
	if response.has("choices") and response["choices"].size() > 0:
		var reply = response["choices"][0]["message"]["content"]
		
		# 非流式模式下，收到完整回复后也立刻提前触发选项生成，并手动传入最新回复
		if GameDataManager.config.ai_mode_enabled:
			deepseek_client.send_options_generation(reply)
			
		# 拦截 reply 进行预处理，提取纯净的消息序列
		var lines = _parse_reply_to_lines(reply)
		if lines.size() == 0:
			_show_message(char_name + " 似乎走神了...", char_name)
			send_btn.disabled = false
			input_field.editable = true
			return
			
		_play_message_sequence(lines, char_name)
	else:
		_show_message(char_name + " 似乎走神了...", char_name)
		send_btn.disabled = false
		input_field.editable = true

# 移除旧的 _on_character_mood_response 和 _on_character_mood_error 回调，
# 因为我们现在改为在 _play_message_sequence 中逐条进行同步等待分析了。

func _parse_reply_to_lines(reply: String) -> Array:
	# Print the raw reply to the console for debugging
	print("\n========== [Chat Agent Output] ==========")
	print(reply)
	print("=========================================\n")
	
	# Try to parse the reply as multiple bubbles using the [SPLIT] token
	var clean_reply = reply.strip_edges()
	
	# Remove any markdown formatting if the LLM still tries to output it
	if clean_reply.begins_with("```"):
		var lines = clean_reply.split("\n")
		if lines.size() > 2:
			lines.remove_at(0)
			if lines[lines.size()-1].begins_with("```"):
				lines.remove_at(lines.size()-1)
			clean_reply = "\n".join(lines).strip_edges()
			
	var message_list = _auto_split_message(clean_reply)
		
	var valid_lines = []
	for line in message_list:
		if typeof(line) == TYPE_STRING:
			var t = line.strip_edges()
			if t != "":
				valid_lines.append(t)
				
	return valid_lines

func _append_status_change(change_text: String, plain_text: String) -> void:
	# 不再向对话框追加状态，而是直接通过 toast 弹出，并输出到控制台
	# print("【情感分析/记忆提取】", plain_text)
	toast.show_toast(plain_text, Color.AQUAMARINE)

func _on_emotion_response(response: Dictionary) -> void:
	if response.has("choices") and response["choices"].size() > 0:
		var reply = response["choices"][0]["message"]["content"]
		
		print("\n========== [Emotion Agent Output] ==========")
		print(reply)
		print("============================================\n")
		
		var regex = RegEx.new()
		regex.compile("(?i)(?:<|\\<|《|\\[|【)\\s*(intimacy|trust|亲密度|亲密变化|信任度|信任值|信任变化|openness|conscientiousness|extraversion|agreeableness|neuroticism)\\s*[:：]\\s*([^>\\>》\\]】]+)\\s*(?:>|\\>|》|\\]|】)")
		var matches = regex.search_all(reply)
		var has_changes = false
		var plain_text_changes = ""
		var personality_changes = ""
		
		for m in matches:
			var tag = m.get_string(1).to_lower()
			var val = m.get_string(2).strip_edges()
			var f_val = val.to_float()
			
			if tag == "intimacy" or tag.begins_with("亲密"):
				GameDataManager.profile.update_intimacy(f_val)
				has_changes = true
				plain_text_changes += "亲密:" + ("+" if f_val > 0 else "") + str(f_val) + " "
			elif tag == "trust" or tag.begins_with("信任"):
				GameDataManager.profile.update_trust(f_val)
				has_changes = true
				plain_text_changes += "信任:" + ("+" if f_val > 0 else "") + str(f_val) + " "
			elif tag in ["openness", "conscientiousness", "extraversion", "agreeableness", "neuroticism"]:
				if f_val != 0.0:
					GameDataManager.personality_system.update_trait(GameDataManager.profile, tag, f_val)
					has_changes = true
					personality_changes += tag.substr(0, 3) + ":" + ("+" if f_val > 0 else "") + str(f_val) + " "
					
		if has_changes:
			GameDataManager.profile.save_profile()
			_update_ui()
			var final_toast = plain_text_changes.strip_edges()
			if personality_changes != "":
				final_toast += " | 人格:" + personality_changes.strip_edges()
			_append_status_change("", final_toast)

func _on_emotion_error(error_msg: String) -> void:
	print("Emotion Agent Failed: ", error_msg)

func _on_memory_response(response: Dictionary) -> void:
	if response.has("choices") and response["choices"].size() > 0:
		var reply = response["choices"][0]["message"]["content"].strip_edges()
		
		print("\n========== [Memory Agent Output] ==========")
		print(reply)
		print("===========================================\n")
		
		# 提取可能的 JSON 代码块
		var json_str = reply
		var regex = RegEx.new()
		regex.compile("```(?:json)?\\s*(\\{[\\s\\S]*?\\})\\s*```")
		var match = regex.search(reply)
		if match:
			json_str = match.get_string(1).strip_edges()
		else:
			# 尝试直接找到第一个 { 和最后一个 }
			var start_idx = reply.find("{")
			var end_idx = reply.rfind("}")
			if start_idx != -1 and end_idx != -1 and end_idx > start_idx:
				json_str = reply.substr(start_idx, end_idx - start_idx + 1)
			
		if json_str == "" or json_str == "无新增记忆":
			return
			
		var json = JSON.new()
		if json.parse(json_str) == OK:
			var data = json.get_data()
			if data is Dictionary and data.has("operations") and data["operations"] is Array:
				if data["operations"].size() == 0:
					return
				
				var plain_text_changes = ""
				for op in data["operations"]:
					if not op is Dictionary or not op.has("action") or not op.has("layer"):
						continue
						
					var action = op["action"]
					var layer = op["layer"]
					var content = op.get("content", "")
					var id = op.get("id", "")
					
					if action == "ADD":
						await GameDataManager.memory_manager.add_memory(layer, content)
						plain_text_changes += "新增记忆: %s\n" % content
					elif action == "UPDATE":
						var success = await GameDataManager.memory_manager.update_memory(layer, id, content)
						if success:
							plain_text_changes += "更新记忆: %s\n" % content
					elif action == "DELETE":
						if GameDataManager.memory_manager.delete_memory(layer, id):
							plain_text_changes += "删除记忆 [%s]\n" % id
							
				if plain_text_changes != "":
					_append_status_change("", plain_text_changes.strip_edges())
		else:
			print("Memory Agent 无法解析JSON: ", json.get_error_message())

func _on_memory_error(error_msg: String) -> void:
	print("Memory Agent Failed: ", error_msg)

var pending_options_data = []
var is_text_playback_finished = true

func _on_options_response(response: Dictionary) -> void:
	if response.has("choices") and response["choices"].size() > 0:
		var reply = response["choices"][0]["message"]["content"]
		
		print("\n========== [Options Agent Output] ==========")
		print(reply)
		print("============================================\n")
		
		var json = JSON.new()
		if json.parse(reply.strip_edges()) == OK:
			var data = json.get_data()
			if data is Dictionary and data.has("options") and data["options"] is Array:
				pending_options_data = data["options"]
				_try_show_options()
				return
				
		print("Warning: Options Agent did not return valid JSON.")

func _try_show_options() -> void:
	# 只有当文本演出完全结束，且已经获取到了选项数据时，才将选项渲染到UI
	if is_text_playback_finished and pending_options_data.size() > 0:
		_populate_quick_options(pending_options_data)
		pending_options_data.clear()

func _on_options_error(error_msg: String) -> void:
	print("Options Agent Failed: ", error_msg)

func _populate_quick_options(options: Array) -> void:
	for child in quick_options_container.get_children():
		child.queue_free()
		
	for opt_text in options:
		if typeof(opt_text) == TYPE_STRING:
			var item = QUICK_OPTION_ITEM_SCENE.instantiate()
			quick_options_container.add_child(item)
			item.setup(opt_text)
			item.option_selected.connect(_on_quick_option_selected)

func _on_quick_option_selected(text: String) -> void:
	input_field.text = text
	_on_send_pressed()

func _on_chat_error(error_msg: String) -> void:
	var char_name = GameDataManager.profile.char_name
	send_btn.disabled = false
	input_field.editable = true
	stream_live_active = false
	stream_live_done = true
	stream_live_buffer = ""
	stream_live_queue.clear()
	toast.show_toast(error_msg, Color.RED)
	# 本地兜底
	if is_inside_tree():
		await get_tree().create_timer(1.0).timeout
	_show_message("你在哪儿？我听不到你的声音了...", char_name)

func _extract_stream_segments(force_flush: bool) -> void:
	var delim = "[SPLIT]"
	while true:
		var idx = stream_live_buffer.find(delim)
		if idx == -1:
			break
		var part = stream_live_buffer.substr(0, idx).strip_edges()
		stream_live_buffer = stream_live_buffer.substr(idx + delim.length())
		if part != "":
			stream_live_queue.append(part)
			
	if force_flush:
		var last_part = stream_live_buffer.strip_edges()
		stream_live_buffer = ""
		if last_part != "":
			var parts = _auto_split_message(last_part)
			for p in parts:
				if typeof(p) == TYPE_STRING:
					var tp = p.strip_edges()
					if tp != "":
						stream_live_queue.append(tp)

func _try_start_stream_worker() -> void:
	if not stream_live_worker_running:
		stream_live_worker_running = true
		call_deferred("_run_stream_worker")

func _run_stream_worker() -> void:
	var char_name = GameDataManager.profile.char_name
	while true:
		while not is_inside_tree():
			await Engine.get_main_loop().process_frame
			
		if stream_live_queue.size() == 0:
			if stream_live_done:
				break
			if is_inside_tree():
				await get_tree().create_timer(0.05).timeout
			continue
			
		var line = stream_live_queue.pop_front()
		if typeof(line) != TYPE_STRING:
			continue
		var t = str(line).strip_edges()
		if t == "":
			continue
			
		if GameDataManager.config.ai_mode_enabled:
			# 异步发起分析，不阻塞当前流程的推进和打字机的显示
			_async_analyze_and_update_mood(t)
				
		await _process_single_message_line_async(t, char_name)
		if is_inside_tree():
			await get_tree().create_timer(0.3).timeout # 缩短强制等待时间，加快演出节奏
			
	stream_live_active = false
	stream_live_worker_running = false
	
	GameDataManager.profile.add_interaction_exp()
	GameDataManager.profile.save_profile()
	_update_ui()
	
	# 因为选项生成请求已经提前到流式接收完毕时发送，这里只需要恢复UI交互即可
	# 等待一小会儿，确保如果选项还没生成完，玩家不会立即打字破坏语境
	if is_inside_tree():
		await get_tree().create_timer(1.0).timeout
		
	is_text_playback_finished = true
	_try_show_options()
		
	send_btn.disabled = false
	input_field.editable = true

func _auto_split_message(text: String) -> Array:
	# 如果AI主动遵守了提示词，直接使用
	if "[SPLIT]" in text:
		return text.split("[SPLIT]", false)
		
	# 系统级强制干预：根据语境智能切分
	# 提取情绪标签，防止它在切分时被破坏或抛弃
	var mood_tag = ""
	var pure_text = text
	var mood_regex = RegEx.new()
	mood_regex.compile("(?i)(?:<|\\<|《|\\[|【)\\s*(mood|心情)\\s*[:：]\\s*([^>\\>》\\]】]+)\\s*(?:>|\\>|》|\\]|】)")
	var mood_match = mood_regex.search(text)
	if mood_match:
		mood_tag = mood_match.get_string()
		pure_text = text.replace(mood_tag, "")
		
	var modified_text = pure_text
	
	# 新增策略0：优先将大模型输出的换行符视为消息分隔符
	# 很多时候AI会用换行来排版不同的动作和对话
	modified_text = modified_text.replace("\r\n", "\n")
	var nl_regex = RegEx.new()
	nl_regex.compile("\\n+")
	modified_text = nl_regex.sub(modified_text, "[SPLIT]", true)
	
	# 修复：确保连续的 [SPLIT] 被合并为一个
	modified_text = modified_text.replace("[SPLIT][SPLIT]", "[SPLIT]")
	modified_text = modified_text.replace("[SPLIT] [SPLIT]", "[SPLIT]")
	
	if not "[SPLIT]" in modified_text:
		var endings = ["。", "！", "？", "……", "”", "」", "~", "～"]
		var brackets = ["（", "("]
		
		# 策略1：根据“标点+动作括号”完美切分，这样刚好能保证切分后下一句以动作开头，带着后续的对话
		for end_char in endings:
			for bracket in brackets:
				modified_text = modified_text.replace(end_char + bracket, end_char + "[SPLIT]" + bracket)
				modified_text = modified_text.replace(end_char + " " + bracket, end_char + "[SPLIT]" + bracket)
				
		# 策略2：如果文本仍未切分且过长（>80字），强行按标点切分
		if not "[SPLIT]" in modified_text and modified_text.length() > 80:
			modified_text = modified_text.replace("。", "。[SPLIT]")
			modified_text = modified_text.replace("！", "！[SPLIT]")
			modified_text = modified_text.replace("？", "？[SPLIT]")
			# 避免把连续的标点切碎
			modified_text = modified_text.replace("[SPLIT][SPLIT]", "[SPLIT]")
		
	var parts = modified_text.split("[SPLIT]", false)
	var merged_parts = []
	var temp_str = ""
	
	for p in parts:
		var tp = p.strip_edges()
		if tp == "": continue
		
		if temp_str == "":
			temp_str = tp
		else:
			# 优化：判断当前片段(tp)或者暂存片段(temp_str)是否*仅仅*包含动作描写（没有实质对话内容）
			var tp_clean = tp
			var temp_clean = temp_str
			var action_regex = RegEx.new()
			action_regex.compile("（.*?）|\\(.*?\\)")
			tp_clean = action_regex.sub(tp_clean, "", true).strip_edges()
			temp_clean = action_regex.sub(temp_clean, "", true).strip_edges()
			
			# 如果某一句太短（<25字符），或者其中一个片段仅仅只有动作描写（去掉括号后无内容），则必须合并
			if temp_str.length() < 25 or tp.length() < 15 or tp_clean == "" or temp_clean == "":
				temp_str += " " + tp
			else:
				merged_parts.append(temp_str)
				temp_str = tp
				
	if temp_str != "":
		merged_parts.append(temp_str)
		
	# 新增限制：如果某一条消息长度超过 60，强制进行二次切分
	var final_split_parts = []
	for part in merged_parts:
		if part.length() > 60:
			var split_part = part
			var endings = ["。", "！", "？", "……", "”", "」", "~", "～"]
			var brackets = ["（", "("]
			# 尝试在动作前切分
			for end_char in endings:
				for bracket in brackets:
					split_part = split_part.replace(end_char + bracket, end_char + "[FORCE_SPLIT]" + bracket)
					split_part = split_part.replace(end_char + " " + bracket, end_char + "[FORCE_SPLIT]" + bracket)
			
			# 如果依然没有切分开，强行按标点切分
			if not "[FORCE_SPLIT]" in split_part:
				split_part = split_part.replace("。", "。[FORCE_SPLIT]")
				split_part = split_part.replace("！", "！[FORCE_SPLIT]")
				split_part = split_part.replace("？", "？[FORCE_SPLIT]")
				split_part = split_part.replace("[FORCE_SPLIT][FORCE_SPLIT]", "[FORCE_SPLIT]")
				
			var sub_parts = split_part.split("[FORCE_SPLIT]", false)
			for sp in sub_parts:
				if sp.strip_edges() != "":
					final_split_parts.append(sp.strip_edges())
		else:
			final_split_parts.append(part)
			
	merged_parts = final_split_parts
		
	# 限制最多3条
	if merged_parts.size() > 3:
		# 只保留前3条，或者把后面的内容全部合并到第3条里
		# 这里选择把多余的部分直接丢弃，强制不超过3条
		var truncated_parts = []
		truncated_parts.append(merged_parts[0])
		truncated_parts.append(merged_parts[1])
		truncated_parts.append(merged_parts[2])
		merged_parts = truncated_parts
		
	# 将心情标签加回最后一条消息末尾
	if merged_parts.size() > 0 and mood_tag != "":
		merged_parts[merged_parts.size() - 1] += mood_tag
		
	if merged_parts.size() == 0:
		return [text]
		
	return merged_parts

func _play_message_sequence(lines: Array, char_name: String) -> void:
	for line in lines:
		if GameDataManager.config.ai_mode_enabled:
			_async_analyze_and_update_mood(line)
				
		await _process_single_message_line_async(line, char_name)
		# 等待上一句（包括打字机和语音）彻底完成后，再强制额外等待 0.3 秒
		if is_inside_tree():
			await get_tree().create_timer(0.3).timeout
		
	GameDataManager.profile.add_interaction_exp()
	GameDataManager.profile.save_profile()
	_update_ui()
	
	if is_inside_tree():
		await get_tree().create_timer(1.0).timeout
		
	is_text_playback_finished = true
	_try_show_options()
		
	send_btn.disabled = false
	input_field.editable = true

func _async_analyze_and_update_mood(line: String) -> void:
	print("正在异步分析单条消息的心情: ", line)
	var mood_id = await deepseek_client.analyze_mood_sync(line)
	print("【Debug】异步 analyze_mood_sync 返回值: '", mood_id, "'")
	if mood_id != "":
		if GameDataManager.mood_system.is_valid_mood(mood_id):
			print("异步分析结果 -> ", mood_id)
			GameDataManager.profile.update_mood(mood_id)
			toast.show_toast("心情变为：" + GameDataManager.mood_system.mood_configs[mood_id]["name"], Color.ORANGE)
			_update_ui()
			_update_character_sprite(mood_id)
		else:
			print("【Debug】异步心情分析返回了未知的 mood_id: '", mood_id, "'")
	else:
		print("异步心情分析未匹配或请求失败")

func _process_single_message_line_async(raw_line: String, char_name: String) -> void:
	var regex = RegEx.new()
	regex.compile("(?i)(?:<|\\<|《|\\[|【)\\s*(mood|心情)\\s*[:：]\\s*([^>\\>》\\]】]+)\\s*(?:>|\\>|》|\\]|】)")
	
	var clean_text = raw_line
	var matches = regex.search_all(raw_line)
	for m in matches:
		clean_text = clean_text.replace(m.get_string(0), "")
			
	var any_tag_regex = RegEx.new()
	any_tag_regex.compile("(?i)(?:<|\\<|《|\\[|【)[^>\\>》\\]】]*?[:：][^>\\>》\\]】]*?(?:>|\\>|》|\\]|】)")
	if any_tag_regex.is_valid():
		clean_text = any_tag_regex.sub(clean_text, "", true)
		
	clean_text = clean_text.strip_edges()
	
	var tts_text = clean_text
	
	var action_regex1 = RegEx.new()
	action_regex1.compile("\\(.*?\\)")
	tts_text = action_regex1.sub(tts_text, "", true)
	
	var action_regex2 = RegEx.new()
	action_regex2.compile("（.*?）")
	tts_text = action_regex2.sub(tts_text, "", true)
	
	var bracket_regex = RegEx.new()
	bracket_regex.compile("\\[.*?\\]|【.*?】|<.*?>|《.*?》")
	tts_text = bracket_regex.sub(tts_text, "", true)
	tts_text = tts_text.strip_edges()
	
	var display_text = clean_text
	var color_regex_zh = RegEx.new()
	color_regex_zh.compile("（(.*?)）")
	display_text = color_regex_zh.sub(display_text, "[color=#aaaaaa]（$1）[/color]", true)
	var color_regex_en = RegEx.new()
	color_regex_en.compile("\\((.*?)\\)")
	display_text = color_regex_en.sub(display_text, "[color=#aaaaaa]($1)[/color]", true)
	
	await _show_message_async(display_text, char_name, false, tts_text)

func _show_message(text: String, speaker_name: String = "", is_restore: bool = false, tts_text: String = "") -> void:
	_show_message_async(text, speaker_name, is_restore, tts_text)

func _show_message_async(text: String, speaker_name: String = "", is_restore: bool = false, tts_text: String = "") -> void:
	if speaker_name == "":
		speaker_name = GameDataManager.profile.char_name
		
	if speaker_name != "":
		name_label.text = speaker_name
		
	# 根据当前心情更新立绘
	if speaker_name == GameDataManager.profile.char_name:
		var current_mood = GameDataManager.profile.current_mood
		_update_character_sprite(current_mood)
		
	# 开启 BBCode 渲染
	dialogue_text.bbcode_enabled = true
	dialogue_text.text = text
	dialogue_text.visible_characters = 0
	
	# 简单的打字机效果
	var tween = create_tween()
	var duration = text.length() * 0.05 # 每个字符 0.05 秒
	tween.tween_property(dialogue_text, "visible_ratio", 1.0, duration)
	tween.finished.connect(func(): dialogue_text.visible_characters = -1)
	
	var cache_key = ""
	var is_tts_started = false
	
	# 触发TTS语音合成 (仅对 角色 发声)，如果是恢复记录则不发声
	if speaker_name == GameDataManager.profile.char_name and GameDataManager.config.voice_enabled and not is_restore:
		# 如果提供了专属的 tts_text (过滤了动作描写的纯净文本)，就用它来发声
		var text_to_speak = tts_text if tts_text != "" else text
		if text_to_speak != "":
			is_tts_started = true
			var options = {"voice_type": GameDataManager.config.doubao_voice_type}
			cache_key = doubao_tts._generate_cache_key(text_to_speak, options)
			doubao_tts.synthesize(text_to_speak, options)
		
	# 保存记录到历史管理器 (只有在非恢复模式时保存)
	if not is_restore:
		GameDataManager.history.add_message(speaker_name, text, cache_key)

	# 等待打字机效果完成
	if is_inside_tree():
		await get_tree().create_timer(duration).timeout
	
	# 如果启动了语音，并且语音还在播放中，则等待语音播放完毕
	if is_tts_started and is_inside_tree():
		# 等待一小会儿确保 TTS 请求有时间返回并开始播放
		await get_tree().create_timer(0.5).timeout 
		while audio_player.playing and is_inside_tree():
			await get_tree().process_frame

func _on_tts_success(audio_stream: AudioStream, text: String) -> void:
	if audio_player:
		audio_player.stream = audio_stream
		audio_player.play()

func _on_tts_failed(error_msg: String, text: String) -> void:
	print("TTS 失败: ", error_msg)
