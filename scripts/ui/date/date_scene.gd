extends Control

@onready var portrait_texture = %PortraitTexture
@onready var bubble_panel = %BubblePanel
@onready var bubble_text = %BubbleText
@onready var heart_level = %HeartLevel
@onready var resonance_bar = %ResonanceBar
@onready var resonance_text = %ResonanceText
@onready var cancel_btn = %CancelButton
@onready var date_btn = %DateButton

@onready var date_type_vbox = %DateTypeVBox
@onready var slot_morning = %SlotMorning
@onready var slot_afternoon = %SlotAfternoon
@onready var slot_evening = %SlotEvening

@onready var custom_image_popup = %CustomImagePopup
@onready var drop_hint = %DropHint
@onready var preview_rect = %PreviewRect
@onready var confirm_image_btn = %ConfirmImageBtn
@onready var cancel_image_btn = %CancelImageBtn

var _bubble_stream_buffer: String = ""
var _is_closing: bool = false
var _deepseek_client: Node = null
var _bubble_audio_player: AudioStreamPlayer = null
var _bubble_typewriter_tween: Tween = null
var _bubble_hide_tween: Tween = null
var _bubble_sequence_id: int = 0
var _bubble_current_tts_text: String = ""

var _date_config: Dictionary = {}
var _slots: Dictionary = {
	"morning": {"button": null, "thumb": null, "label": null, "location_id": "", "enabled": true, "name": "早上", "custom_texture": null},
	"afternoon": {"button": null, "thumb": null, "label": null, "location_id": "", "enabled": true, "name": "下午", "custom_texture": null},
	"evening": {"button": null, "thumb": null, "label": null, "location_id": "", "enabled": true, "name": "晚上", "custom_texture": null}
}

var _pending_custom_texture: Texture2D = null

const BUBBLE_TYPEWRITER_CHAR_TIME := 0.045
const BUBBLE_HIDE_DELAY_AFTER_VOICE := 1.0

func _ready() -> void:
	cancel_btn.pressed.connect(_on_cancel_pressed)
	date_btn.pressed.connect(_on_date_pressed)
	
	confirm_image_btn.pressed.connect(_on_confirm_image_pressed)
	cancel_image_btn.pressed.connect(_on_cancel_image_pressed)
	
	get_window().files_dropped.connect(_on_files_dropped)
	
	_init_slots()
	_load_date_config()
	
	_bubble_audio_player = AudioStreamPlayer.new()
	_bubble_audio_player.bus = "Voice"
	_bubble_audio_player.finished.connect(_on_bubble_audio_finished)
	add_child(_bubble_audio_player)
	
	if TTSManager:
		if not TTSManager.tts_success.is_connected(_on_bubble_tts_success):
			TTSManager.tts_success.connect(_on_bubble_tts_success)
		if not TTSManager.tts_failed.is_connected(_on_bubble_tts_failed):
			TTSManager.tts_failed.connect(_on_bubble_tts_failed)
	
	_load_luna_animated_portrait()
	
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	
	_init_ui()
	_trigger_greeting_bubble()

func _load_luna_animated_portrait() -> void:
	if not portrait_texture or not (portrait_texture is AnimatedSprite2D):
		return
		
	var char_file_path = "res://assets/data/characters/luna.json"
	var sprite_frames_path = ""
	
	if FileAccess.file_exists(char_file_path):
		var file = FileAccess.open(char_file_path, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				var data = json.get_data()
				if data is Dictionary:
					sprite_frames_path = str(data.get("sprite_frames_path", "")).strip_edges()
	
	if not sprite_frames_path.is_empty() and ResourceLoader.exists(sprite_frames_path):
		var frames_res = load(sprite_frames_path)
		if frames_res is SpriteFrames:
			portrait_texture.sprite_frames = frames_res
			var anim_name = ""
			for candidate in ["default", "idle", "calm"]:
				if frames_res.has_animation(candidate):
					anim_name = candidate
					break
			if anim_name == "" and frames_res.get_animation_names().size() > 0:
				anim_name = frames_res.get_animation_names()[0]
				
			if anim_name != "":
				portrait_texture.play(StringName(anim_name))
				
			portrait_texture.show()

func _init_ui() -> void:
	if not GameDataManager.profile:
		return
		
	var profile = GameDataManager.profile
	var current_stage = profile.current_stage
	var current_resonance = profile.intimacy + profile.trust
	var stage_conf = profile.get_current_stage_config()
	var max_resonance = stage_conf.get("resonance_threshold", 100)
	
	heart_level.text = "LV\n%d" % current_stage
	resonance_bar.max_value = max_resonance
	resonance_bar.value = current_resonance
	resonance_text.text = "%d / %d" % [int(current_resonance), int(max_resonance)]

func _init_slots() -> void:
	_slots["morning"]["button"] = slot_morning
	_slots["afternoon"]["button"] = slot_afternoon
	_slots["evening"]["button"] = slot_evening
	
	_slots["morning"]["thumb"] = slot_morning.get_node("ThumbRect")
	_slots["afternoon"]["thumb"] = slot_afternoon.get_node("ThumbRect")
	_slots["evening"]["thumb"] = slot_evening.get_node("ThumbRect")
	
	_slots["morning"]["label"] = slot_morning.get_node("SlotLabel")
	_slots["afternoon"]["label"] = slot_afternoon.get_node("SlotLabel")
	_slots["evening"]["label"] = slot_evening.get_node("SlotLabel")
	
	var current_period_str = "上午"
	if GameDataManager.story_time_manager:
		current_period_str = GameDataManager.story_time_manager.current_period
	
	var current_period_idx = 1
	if current_period_str == "下午":
		current_period_idx = 2
	elif current_period_str == "傍晚" or current_period_str == "夜晚":
		current_period_idx = 3
	
	# 1: 早上, 2: 下午, 3: 傍晚, 4: 晚上
	if current_period_idx >= 2:
		_slots["morning"]["enabled"] = false
	if current_period_idx >= 3:
		_slots["afternoon"]["enabled"] = false
		
	for period_id in _slots.keys():
		var slot = _slots[period_id]
		var btn = slot["button"]
		var lbl = slot["label"]
		if not slot["enabled"]:
			btn.disabled = true
			lbl.text = slot["name"] + "\n(不可用)"
		else:
			btn.disabled = false
			lbl.text = slot["name"] + "\n(空)"
			
		slot["thumb"].texture = null
		lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
		lbl.remove_theme_color_override("font_shadow_color")
		lbl.remove_theme_constant_override("shadow_outline_size")
		
		if not btn.pressed.is_connected(_on_slot_pressed.bind(period_id)):
			btn.pressed.connect(_on_slot_pressed.bind(period_id))

func _load_date_config() -> void:
	var path = "res://assets/data/interaction/date_config.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var text = file.get_as_text()
			var json = JSON.new()
			var error = json.parse(text)
			if error == OK:
				var data = json.get_data()
				if data is Dictionary:
					_date_config = data
					print("Date config loaded successfully.")
					_populate_date_types()
				else:
					printerr("Date config is not a Dictionary.")
			else:
				printerr("Failed to parse date_config.json at line ", json.get_error_line(), ": ", json.get_error_message())
	else:
		printerr("date_config.json not found at ", path)

var _date_type_item_scene = preload("res://scenes/ui/date/date_type_item.tscn")
var _date_location_item_scene = preload("res://scenes/ui/date/date_location_item.tscn")

func _populate_date_types() -> void:
	if not _date_config.has("date_types"):
		return
		
	for child in date_type_vbox.get_children():
		child.queue_free()
		
	for type_data in _date_config["date_types"]:
		var type_item = _date_type_item_scene.instantiate()
		date_type_vbox.add_child(type_item)
		type_item.set_type_info(type_data["id"], type_data["name"])
		
		if type_data.has("locations"):
			for loc_id in type_data["locations"]:
				var loc_data_dict = MapDataManager.get_location(loc_id)
				var loc_name = loc_data_dict.get("name", loc_id)
				
				var loc_item = _date_location_item_scene.instantiate()
				type_item.add_location_node(loc_item)
				loc_item.setup(loc_id, loc_name, type_data["id"])
				loc_item.add_requested.connect(_on_add_location_pressed)
				
		var custom_item = _date_location_item_scene.instantiate()
		type_item.add_location_node(custom_item)
		custom_item.setup("custom_" + type_data["id"], "添加现实世界场景", type_data["id"])
		custom_item.add_requested.connect(_on_add_custom_location_pressed)

func _on_add_location_pressed(loc_id: String, loc_name: String) -> void:
	var slot_order = ["morning", "afternoon", "evening"]
	var found_slot = ""
	for period in slot_order:
		if _slots[period]["enabled"] and _slots[period]["location_id"] == "":
			found_slot = period
			break
			
	if found_slot != "":
		_slots[found_slot]["location_id"] = loc_id
		_slots[found_slot]["custom_texture"] = null
		_slots[found_slot]["label"].text = _slots[found_slot]["name"] + "\n(" + loc_name + ")"
		
		# 获取地点背景图并设置给 thumb
		var loc_data = MapDataManager.get_location(loc_id)
		var bg_id = loc_data.get("bg_id", "")
		var real_path = ""
		if not bg_id.is_empty():
			real_path = ImageManager.get_image_path(bg_id)
			if real_path.is_empty():
				real_path = bg_id
		if not real_path.is_empty() and ResourceLoader.exists(real_path):
			_slots[found_slot]["thumb"].texture = load(real_path)
			_slots[found_slot]["label"].add_theme_color_override("font_color", Color.WHITE)
			_slots[found_slot]["label"].add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
			_slots[found_slot]["label"].add_theme_constant_override("shadow_outline_size", 4)
		else:
			_slots[found_slot]["thumb"].texture = null
			_slots[found_slot]["label"].add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
			_slots[found_slot]["label"].remove_theme_color_override("font_shadow_color")
			_slots[found_slot]["label"].remove_theme_constant_override("shadow_outline_size")
	else:
		if ToastManager:
			ToastManager.show_toast("没有可用的空闲时间段了")

func _on_add_custom_location_pressed(loc_id: String, loc_name: String) -> void:
	var slot_order = ["morning", "afternoon", "evening"]
	var found_slot = ""
	for period in slot_order:
		if _slots[period]["enabled"] and _slots[period]["location_id"] == "":
			found_slot = period
			break
			
	if found_slot == "":
		if ToastManager:
			ToastManager.show_toast("没有可用的空闲时间段了")
		return
		
	# 记录准备加入的槽位（这里简单化，先弹窗，点确定后再找也可以，或者弹窗直接打开）
	_pending_custom_texture = null
	preview_rect.texture = null
	drop_hint.show()
	custom_image_popup.show()

func _on_files_dropped(files: PackedStringArray) -> void:
	if not custom_image_popup.visible:
		return
	if files.size() > 0:
		var file_path = files[0]
		if file_path.to_lower().ends_with(".png") or file_path.to_lower().ends_with(".jpg") or file_path.to_lower().ends_with(".jpeg"):
			var image = Image.new()
			var err = image.load(file_path)
			if err == OK:
				var tex = ImageTexture.create_from_image(image)
				_pending_custom_texture = tex
				preview_rect.texture = tex
				drop_hint.hide()
			else:
				if ToastManager:
					ToastManager.show_toast("图片加载失败")
		else:
			if ToastManager:
				ToastManager.show_toast("请拖入有效的图片文件 (png/jpg/jpeg)")

func _on_confirm_image_pressed() -> void:
	if _pending_custom_texture == null:
		if ToastManager:
			ToastManager.show_toast("请先拖入图片")
		return
		
	var slot_order = ["morning", "afternoon", "evening"]
	var found_slot = ""
	for period in slot_order:
		if _slots[period]["enabled"] and _slots[period]["location_id"] == "":
			found_slot = period
			break
			
	if found_slot != "":
		_slots[found_slot]["location_id"] = "custom_location"
		_slots[found_slot]["custom_texture"] = _pending_custom_texture
		_slots[found_slot]["label"].text = _slots[found_slot]["name"] + "\n(现实世界)"
		_slots[found_slot]["thumb"].texture = _pending_custom_texture
		_slots[found_slot]["label"].add_theme_color_override("font_color", Color.WHITE)
		_slots[found_slot]["label"].add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		_slots[found_slot]["label"].add_theme_constant_override("shadow_outline_size", 4)
	else:
		if ToastManager:
			ToastManager.show_toast("没有可用的空闲时间段了")
			
	custom_image_popup.hide()

func _on_cancel_image_pressed() -> void:
	custom_image_popup.hide()

func _on_slot_pressed(period_id: String) -> void:
	if not _slots[period_id]["enabled"]:
		return
	if _slots[period_id]["location_id"] != "":
		_slots[period_id]["location_id"] = ""
		_slots[period_id]["custom_texture"] = null
		_slots[period_id]["label"].text = _slots[period_id]["name"] + "\n(空)"
		_slots[period_id]["thumb"].texture = null
		_slots[period_id]["label"].add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
		_slots[period_id]["label"].remove_theme_color_override("font_shadow_color")
		_slots[period_id]["label"].remove_theme_constant_override("shadow_outline_size")

func _trigger_greeting_bubble() -> void:
	bubble_panel.hide()
	
	var main_scene = get_tree().get_root().get_node_or_null("MainScene")
	if main_scene and main_scene.has_node("DeepSeekClient"):
		_deepseek_client = main_scene.get_node("DeepSeekClient")
		
		# Connect to streaming signals
		if not _deepseek_client.is_connected("chat_stream_delta", _on_bubble_chunk_received):
			_deepseek_client.chat_stream_delta.connect(_on_bubble_chunk_received)
		if not _deepseek_client.is_connected("chat_request_completed", _on_bubble_completed):
			_deepseek_client.chat_request_completed.connect(_on_bubble_completed)
		if not _deepseek_client.is_connected("chat_request_failed", _on_bubble_failed):
			_deepseek_client.chat_request_failed.connect(_on_bubble_failed)
			
		var prompt = "【系统指令】玩家打开了约会面板，准备邀请你去约会。请以Luna的口吻，说一句简短的约会开场白，带点期待或者小傲娇。要求：一句话即可，不要带括号动作描述。"
		_bubble_stream_buffer = ""
		# date scene 特有的聊天前缀，不走主场景流式分句
		_deepseek_client.send_chat_message_stream(prompt, "date_scene_greeting")
	else:
		# Fallback
		_show_bubble_text("今天天气不错，你想带我去哪里？")

func _on_bubble_chunk_received(chunk: String) -> void:
	# 不在流式中显示，等拼接完后打字机显示
	_bubble_stream_buffer += chunk

func _on_bubble_completed(response: Dictionary) -> void:
	_disconnect_ai_signals()
	# 提取完整的返回文本
	var full_text = ""
	if response.has("choices") and response["choices"].size() > 0:
		full_text = response["choices"][0]["message"]["content"]
	
	# Clean up any potential action descriptions
	var clean_text = _strip_bubble_action_descriptions(full_text)
	if clean_text.is_empty():
		clean_text = "今天天气不错，你想带我去哪里？"
	_show_bubble_text(clean_text)

func _on_bubble_failed(_error_msg: String) -> void:
	_disconnect_ai_signals()
	_show_bubble_text("今天天气不错，你想带我去哪里？")

func _show_bubble_text(text: String) -> void:
	_bubble_sequence_id += 1
	var seq := _bubble_sequence_id
	_bubble_current_tts_text = text
	
	if _bubble_hide_tween:
		_bubble_hide_tween.kill()
	if _bubble_typewriter_tween:
		_bubble_typewriter_tween.kill()
	if _bubble_audio_player:
		_bubble_audio_player.stop()
		
	bubble_text.text = text
	bubble_text.visible_ratio = 0.0
	bubble_panel.show()
	bubble_panel.modulate.a = 0.0
	
	var tween := create_tween()
	tween.tween_property(bubble_panel, "modulate:a", 1.0, 0.2)
	
	var typewriter_duration := maxf(0.35, float(text.length()) * BUBBLE_TYPEWRITER_CHAR_TIME)
	_bubble_typewriter_tween = create_tween()
	_bubble_typewriter_tween.tween_property(bubble_text, "visible_ratio", 1.0, typewriter_duration)
	
	_play_bubble_tts(text)
	
func _play_bubble_tts(text: String) -> void:
	if not GameDataManager or not GameDataManager.config:
		return
	if not GameDataManager.config.voice_enabled:
		return
	var spoken_text := text.strip_edges()
	if spoken_text == "":
		return
	var options := {}
	var backend := str(GameDataManager.config.tts_backend)
	var char_id := "luna"
	if GameDataManager.profile and GameDataManager.profile.current_character_id != "":
		char_id = GameDataManager.profile.current_character_id
		
	if backend == "qwen_tts":
		if GameDataManager.config.qwen_tts_voice_types.has(char_id):
			options["voice_type"] = GameDataManager.config.qwen_tts_voice_types[char_id]
	else:
		if GameDataManager.config.character_voice_types.has(char_id):
			options["voice_type"] = GameDataManager.config.character_voice_types[char_id]
	TTSManager.synthesize(spoken_text, options)

func _on_bubble_tts_success(audio_stream: AudioStream, text: String) -> void:
	if text != _bubble_current_tts_text:
		return
	if _bubble_audio_player and audio_stream:
		_bubble_audio_player.stream = audio_stream
		_bubble_audio_player.play()

func _on_bubble_tts_failed(_error_msg: String, text: String) -> void:
	if text != _bubble_current_tts_text:
		return

func _on_bubble_audio_finished() -> void:
	if bubble_panel and bubble_panel.visible:
		var seq := _bubble_sequence_id
		await get_tree().create_timer(BUBBLE_HIDE_DELAY_AFTER_VOICE).timeout
		if not is_inside_tree():
			return
		if seq != _bubble_sequence_id:
			return
		if bubble_panel and bubble_panel.visible:
			_hide_bubble()

func _hide_bubble() -> void:
	if not bubble_panel or not bubble_panel.visible:
		return
	if _bubble_hide_tween:
		_bubble_hide_tween.kill()
	_bubble_hide_tween = create_tween()
	_bubble_hide_tween.tween_property(bubble_panel, "modulate:a", 0.0, 0.18)
	_bubble_hide_tween.tween_callback(bubble_panel.hide)

func _disconnect_ai_signals() -> void:
	if _deepseek_client:
		if _deepseek_client.is_connected("chat_stream_delta", _on_bubble_chunk_received):
			_deepseek_client.chat_stream_delta.disconnect(_on_bubble_chunk_received)
		if _deepseek_client.is_connected("chat_request_completed", _on_bubble_completed):
			_deepseek_client.chat_request_completed.disconnect(_on_bubble_completed)
		if _deepseek_client.is_connected("chat_request_failed", _on_bubble_failed):
			_deepseek_client.chat_request_failed.disconnect(_on_bubble_failed)

func _strip_bubble_action_descriptions(text: String) -> String:
	var cleaned := text.strip_edges()
	var patterns := [
		"\\([^()]*\\)",
		"（[^（）]*）"
	]
	for pattern in patterns:
		var regex := RegEx.new()
		if regex.compile(pattern) == OK:
			cleaned = regex.sub(cleaned, "", true)
	return cleaned.strip_edges()

func _exit_tree() -> void:
	if get_window() and get_window().files_dropped.is_connected(_on_files_dropped):
		get_window().files_dropped.disconnect(_on_files_dropped)

func _on_cancel_pressed() -> void:
	if _is_closing:
		return
	_is_closing = true
	
	_disconnect_ai_signals()
	if _bubble_audio_player:
		_bubble_audio_player.stop()
	if _bubble_hide_tween:
		_bubble_hide_tween.kill()
	if _bubble_typewriter_tween:
		_bubble_typewriter_tween.kill()
		
	if TTSManager:
		if TTSManager.tts_success.is_connected(_on_bubble_tts_success):
			TTSManager.tts_success.disconnect(_on_bubble_tts_success)
		if TTSManager.tts_failed.is_connected(_on_bubble_tts_failed):
			TTSManager.tts_failed.disconnect(_on_bubble_tts_failed)
			
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)

func _on_date_pressed() -> void:
	var plan_list = []
	var slot_order = ["morning", "afternoon", "evening"]
	for period in slot_order:
		if _slots[period]["enabled"] and _slots[period]["location_id"] != "":
			plan_list.append({
				"period": period,
				"location_id": _slots[period]["location_id"],
				"custom_texture": _slots[period]["custom_texture"]
			})
			
	if plan_list.is_empty():
		if ToastManager:
			ToastManager.show_toast("请至少选择一个约会地点！")
		return
		
	_start_date_plan(plan_list)

func _start_date_plan(plan_list: Array) -> void:
	print("Date Plan: ", plan_list)
	if ToastManager:
		ToastManager.show_toast("约会计划已生成，即将开始约会...")
