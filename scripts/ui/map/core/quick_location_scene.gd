extends Control

const QUICK_OPTION_LIST_HELPER = preload("res://scripts/ui/story/quick_option_list_helper.gd")
const NPC_BUBBLE_LINES_PATH := "res://assets/data/map/npc/npc_bubble_lines.json"
const SUBMENU_FADE_DURATION := 0.25
const SUBMENU_PORTRAIT_RATIO_X := 1.0 / 6.0
const SUBMENU_INFO_HIDDEN_OFFSET_X := 120.0
const MENU_ENTRY_PORTRAIT_OFFSET_Y := 90.0
const BUBBLE_MIN_SHOW_TIME := 2.6
const BUBBLE_SHOW_TIME_PER_CHAR := 0.08
const BUBBLE_TYPEWRITER_CHAR_TIME := 0.045
const BUBBLE_HIDE_DELAY_AFTER_VOICE := 1.0
const BUBBLE_RECENT_HISTORY_LIMIT := 4
const SUBMENU_PANEL_CENTER_RATIO := 2.0 / 3.0
const SUBMENU_PANEL_MIN_RIGHT_MARGIN := 28.0
const SUBMENU_PANEL_MAX_WIDTH_RATIO := 0.60
const QUICK_ACTION_BUTTON_SCENE = preload("res://scenes/ui/map/core/quick_action_button.tscn")

@onready var bg_texture: TextureRect = $Background
@onready var map_info_panel: PanelContainer = $MapInfoPanel
@onready var name_label: Label = $MapInfoPanel/InfoMargin/VBox/NameLabel
@onready var desc_label: Label = $MapInfoPanel/InfoMargin/VBox/DescLabel
@onready var back_button: Button = $BackButton

@onready var interaction_menu = $InteractionMenu
@onready var info_and_options = $InteractionMenu/InfoAndOptions

@onready var menu_name_label = $InteractionMenu/InfoAndOptions/NPCInfoVBox/NameLabel
@onready var menu_stage_label = $InteractionMenu/InfoAndOptions/NPCInfoVBox/StageHBox/StageLabel
@onready var menu_hearts_label = $InteractionMenu/InfoAndOptions/NPCInfoVBox/HeartsLabel

@onready var npc_portrait = $InteractionMenu/NPCPortrait
@onready var npc_anim_sprite = $InteractionMenu/NPCPortrait/AnimatedSprite
@onready var npc_static_sprite = $InteractionMenu/NPCPortrait/StaticSprite
@onready var bubble_anchor_top: Marker2D = $InteractionMenu/NPCPortrait/BubbleAnchorTop
@onready var bubble_anchor_side: Marker2D = $InteractionMenu/NPCPortrait/BubbleAnchorSide

@onready var menu_options_vbox = $InteractionMenu/InfoAndOptions/OptionsVBox

@onready var dialogue_panel = $DialoguePanel
@onready var dialogue_name_label: Label = $DialoguePanel/DialogueLayer/VBox/NameLabel
@onready var dialogue_text_label: RichTextLabel = $DialoguePanel/DialogueLayer/VBox/RichTextLabel
@onready var dialogue_quick_option_layer: Control = $DialoguePanel/QuickOptionLayer
@onready var dialogue_quick_options_container: VBoxContainer = $DialoguePanel/QuickOptionLayer/ScrollContainer/QuickOptions
@onready var dialogue_input_layer: Panel = $DialoguePanel/InputLayer
@onready var dialogue_input_field: TextEdit = $DialoguePanel/InputLayer/HBoxContainer/InputField
@onready var dialogue_send_button: Button = $DialoguePanel/InputLayer/HBoxContainer/SendButton
@onready var dialogue_history_button: Button = $DialoguePanel/HistoryButton
@onready var dialogue_end_button: Button = $DialoguePanel/EndChatButton
@onready var bubble_root: Node2D = $InteractionMenu/NPCPortrait/BubbleRoot
@onready var speech_bubble: PanelContainer = $InteractionMenu/NPCPortrait/BubbleRoot/SpeechBubble
@onready var bubble_text_label: RichTextLabel = $InteractionMenu/NPCPortrait/BubbleRoot/SpeechBubble/BubbleMargin/BubbleText

var location_id: String = ""
var initial_npc_id: String = ""

var current_interacting_npc_id: String = ""
var original_char_x: float = 9.0
var original_char_y: float = 0.0
var original_info_x: float = 0.0
var _submenu_restore_started: bool = false
var _bubble_sequence_id: int = 0
var _bubble_current_tts_text: String = ""
var _bubble_audio_player: AudioStreamPlayer = null
var _bubble_hide_tween: Tween = null
var _bubble_typewriter_tween: Tween = null
var _awaiting_topic_selection: bool = false
var _topic_greeting_playing: bool = false
var _pending_topic_options: Array = []
var _quick_chat_active: bool = false
var _selected_topic: String = ""
var _npc_bubble_lines_cache: Dictionary = {}
var _bubble_ai_request_serial: int = 0
var _bubble_ai_completed_callable: Callable = Callable()
var _bubble_ai_failed_callable: Callable = Callable()
var _recent_bubble_lines: Array[String] = []

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_load_npc_bubble_lines()
	
	if npc_portrait:
		original_char_x = npc_portrait.position.x
		original_char_y = npc_portrait.position.y
	if info_and_options:
		original_info_x = info_and_options.position.x
	if bubble_root:
		bubble_root.hide()
	if speech_bubble:
		speech_bubble.hide()
	
	_bubble_audio_player = AudioStreamPlayer.new()
	_bubble_audio_player.bus = "Voice"
	_bubble_audio_player.finished.connect(_on_bubble_audio_finished)
	add_child(_bubble_audio_player)
	
	if TTSManager:
		if not TTSManager.tts_success.is_connected(_on_bubble_tts_success):
			TTSManager.tts_success.connect(_on_bubble_tts_success)
		if not TTSManager.tts_failed.is_connected(_on_bubble_tts_failed):
			TTSManager.tts_failed.connect(_on_bubble_tts_failed)
		
	# 隐藏选项菜单和角色
	interaction_menu.hide()
	
	if dialogue_panel:
		dialogue_panel.hide()
		if dialogue_quick_option_layer:
			dialogue_quick_option_layer.hide()
		if dialogue_panel.has_signal("message_sent"):
			dialogue_panel.message_sent.connect(_on_dialogue_message_sent)
		if dialogue_end_button and not dialogue_end_button.pressed.is_connected(_on_dialogue_close_pressed):
			dialogue_end_button.pressed.connect(_on_dialogue_close_pressed)
		# 监听对话结束信号，以便恢复互动选项
		if dialogue_panel.has_signal("dialogue_finished"):
			dialogue_panel.dialogue_finished.connect(func():
				if _quick_chat_active or _awaiting_topic_selection:
					return
				if current_interacting_npc_id != "":
					if not _submenu_restore_started:
						_restore_after_sub_menu(true)
					else:
						info_and_options.show()
			)
	
	if location_id != "":
		if MapDataManager.has_method("set_last_location"):
			MapDataManager.set_last_location(location_id)
		_load_location_data()
		
		# Broadcast state change to EventManager to check for global events
		var event_manager = get_node_or_null("/root/EventManager")
		if event_manager and event_manager.has_method("broadcast_state_change"):
			event_manager.broadcast_state_change({"location_id": location_id})
			
	if initial_npc_id != "":
		# 进入场景时先自动展示角色，但不触发“打开菜单”台词
		call_deferred("_on_npc_clicked", initial_npc_id, false)
		call_deferred("_schedule_scene_entry_bubble", initial_npc_id)

func _load_location_data():
	var loc_data = MapDataManager.get_location(location_id)
	if loc_data.is_empty():
		return
		
	name_label.text = loc_data.get("name", "未知地点")
	desc_label.text = loc_data.get("description", "没有描述")
	
	# 设置背景图
	var bg_id = loc_data.get("bg_id", "")
	var real_path = ""
	if not bg_id.is_empty():
		real_path = ImageManager.get_image_path(bg_id)
		if real_path.is_empty():
			real_path = bg_id # Fallback
			
	if not real_path.is_empty() and ResourceLoader.exists(real_path):
		bg_texture.texture = load(real_path)
	else:
		bg_texture.texture = null

func _load_npc_bubble_lines() -> void:
	_npc_bubble_lines_cache.clear()
	if not FileAccess.file_exists(NPC_BUBBLE_LINES_PATH):
		return
	var file := FileAccess.open(NPC_BUBBLE_LINES_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_npc_bubble_lines_cache = json.data
	file.close()

func _get_deepseek_client():
	var deepseek_client = get_node_or_null("DeepSeekClient")
	if not deepseek_client:
		deepseek_client = get_node_or_null("/root/MainScene/DeepSeekClient")
	return deepseek_client

func _get_current_story_period() -> String:
	if GameDataManager.story_time_manager:
		return str(GameDataManager.story_time_manager.current_period).strip_edges()
	return ""

func _get_current_weather_desc() -> String:
	if GameDataManager.weather_manager and GameDataManager.weather_manager.is_weather_ready:
		return str(GameDataManager.weather_manager.current_weather_desc).strip_edges()
	return ""

func _matches_contextual_variant(variant: Dictionary, phase: String, action_id: String = "") -> bool:
	var variant_phase := str(variant.get("phase", "")).strip_edges()
	if variant_phase != "" and variant_phase != phase:
		return false
	var variant_action := str(variant.get("action_id", "")).strip_edges()
	if variant_action != "" and variant_action != action_id:
		return false
	var location_ids = variant.get("location_ids", [])
	if location_ids is Array and not location_ids.is_empty():
		if location_id == "" or not location_ids.has(location_id):
			return false
	var time_periods = variant.get("time_periods", [])
	if time_periods is Array and not time_periods.is_empty():
		var current_period := _get_current_story_period()
		if current_period == "" or not time_periods.has(current_period):
			return false
	var weather_keywords = variant.get("weather_keywords", [])
	if weather_keywords is Array and not weather_keywords.is_empty():
		var current_weather := _get_current_weather_desc()
		if current_weather == "":
			return false
		var matched := false
		for keyword in weather_keywords:
			var final_keyword := str(keyword).strip_edges()
			if final_keyword != "" and current_weather.find(final_keyword) != -1:
				matched = true
				break
		if not matched:
			return false
	return true

func _pick_line_from_candidates(lines: Array) -> String:
	if lines.is_empty():
		return ""
	var unique_lines: Array[String] = []
	for candidate in lines:
		var final_candidate := str(candidate).strip_edges()
		if final_candidate != "":
			unique_lines.append(final_candidate)
	if unique_lines.is_empty():
		return ""
	var fresh_lines: Array[String] = []
	for line in unique_lines:
		if not _recent_bubble_lines.has(line):
			fresh_lines.append(line)
	if not fresh_lines.is_empty():
		return fresh_lines.pick_random()
	return unique_lines.pick_random()

func _remember_bubble_line(text: String) -> void:
	var final_text := text.strip_edges()
	if final_text == "":
		return
	_recent_bubble_lines.erase(final_text)
	_recent_bubble_lines.append(final_text)
	while _recent_bubble_lines.size() > BUBBLE_RECENT_HISTORY_LIMIT:
		_recent_bubble_lines.remove_at(0)

func _get_bubble_template_lines(npc_id: String, phase: String) -> Array:
	if _npc_bubble_lines_cache.has(npc_id):
		var phase_map: Dictionary = _npc_bubble_lines_cache[npc_id]
		var contextual_variants = phase_map.get("contextual_variants", [])
		if contextual_variants is Array:
			for variant in contextual_variants:
				if variant is Dictionary and _matches_contextual_variant(variant, phase):
					var variant_lines = variant.get("lines", [])
					if variant_lines is Array and not variant_lines.is_empty():
						return variant_lines
		var phase_lines = phase_map.get(phase, [])
		if phase_lines is Array:
			return phase_lines
	return []

func _get_action_bubble_template_lines(npc_id: String, action_id: String) -> Array:
	if _npc_bubble_lines_cache.has(npc_id):
		var phase_map: Dictionary = _npc_bubble_lines_cache[npc_id]
		var contextual_variants = phase_map.get("contextual_variants", [])
		if contextual_variants is Array:
			for variant in contextual_variants:
				if variant is Dictionary and _matches_contextual_variant(variant, "action_open", action_id):
					var variant_lines = variant.get("lines", [])
					if variant_lines is Array and not variant_lines.is_empty():
						return variant_lines
		var action_map = phase_map.get("action_bubbles", {})
		if action_map is Dictionary:
			var action_lines = action_map.get(action_id, [])
			if action_lines is Array:
				return action_lines
	return []

func _get_npc_relation_stage_info(npc_id: String) -> Dictionary:
	if npc_id == "luna" and GameDataManager.profile:
		var conf := GameDataManager.profile.get_current_stage_config()
		return {
			"stage": int(GameDataManager.profile.current_stage),
			"stage_title": str(conf.get("stageTitle", "陌生人"))
		}
	var npc_rel = GameDataManager.npc_relationship_manager
	if npc_rel:
		var current_stage := int(npc_rel.get_stage(npc_id))
		var stage_config: Dictionary = npc_rel.get_stage_config(npc_id)
		return {
			"stage": current_stage,
			"stage_title": str(stage_config.get("stageTitle", "普通朋友"))
		}
	var npc_stage_data := _get_npc_stage_data(npc_id)
	return {
		"stage": 1,
		"stage_title": str(npc_stage_data.get("stageTitle", "普通朋友"))
	}

func _build_bubble_polish_prompt(npc_id: String, npc_name: String, template_line: String, phase: String, action_id: String = "") -> String:
	var heroine_name := "Luna"
	if GameDataManager.profile and str(GameDataManager.profile.char_name).strip_edges() != "":
		heroine_name = str(GameDataManager.profile.char_name).strip_edges()
	var stage_info := _get_npc_relation_stage_info(npc_id)
	var stage_num := int(stage_info.get("stage", 1))
	var stage_title := str(stage_info.get("stage_title", "普通朋友")).strip_edges()
	var location_name := str(name_label.text).strip_edges()
	if location_name == "":
		location_name = location_id
	var current_period := _get_current_story_period()
	var current_weather := _get_current_weather_desc()
	var trigger_desc := "进入地点时的招呼"
	match phase:
		"menu_open":
			trigger_desc = "打开互动菜单时的招呼"
		"action_open":
			trigger_desc = "选择【%s】操作前的即时回应" % action_id
	var recent_hint := ""
	if not _recent_bubble_lines.is_empty():
		recent_hint = "最近已出现过的气泡：%s\n" % " / ".join(_recent_bubble_lines)
	return "当前是地图场景中的即时气泡台词。请你扮演【%s】，对少女【%s】说一句简短自然的话。\n场景地点：%s\n当前时段：%s\n当前天气：%s\n触发时机：%s\n当前你与%s的关系阶段：第%d阶段（%s）\n基础模板：%s\n%s要求：\n1. 只输出一句成品台词，不要解释。\n2. 保留基础模板原意，但结合当前关系阶段与场景上下文做自然润色。\n3. 长度控制在28字以内，只保留说话内容，不要加入括号动作、旁白或语气说明。\n4. 不要扩写成长对白，不要换行。\n5. 尽量避免与最近已出现的话术过于相似。" % [npc_name, heroine_name, location_name, current_period, current_weather, trigger_desc, heroine_name, stage_num, stage_title, template_line, recent_hint]

func _normalize_bubble_line(raw_text: String, fallback: String) -> String:
	var cleaned := raw_text.strip_edges()
	if cleaned == "":
		return fallback
	var segments := cleaned.split("\n", false)
	for segment in segments:
		var line := str(segment).strip_edges()
		if line != "":
			return _strip_bubble_action_descriptions(line, fallback)
	return fallback

func _strip_bubble_action_descriptions(text: String, fallback: String) -> String:
	var cleaned := text.strip_edges()
	var fallback_cleaned := fallback.strip_edges()
	var patterns := [
		"\\([^()]*\\)",
		"（[^（）]*）"
	]
	for pattern in patterns:
		var fallback_regex := RegEx.new()
		if fallback_regex.compile(pattern) == OK:
			fallback_cleaned = fallback_regex.sub(fallback_cleaned, "", true)
	fallback_cleaned = fallback_cleaned.strip_edges()
	if cleaned == "":
		return fallback_cleaned
	for pattern in patterns:
		var regex := RegEx.new()
		if regex.compile(pattern) == OK:
			cleaned = regex.sub(cleaned, "", true)
	cleaned = cleaned.strip_edges()
	if cleaned == "":
		return fallback_cleaned
	return cleaned

func _request_bubble_line(npc_id: String, npc_name: String, npc_data: Dictionary, phase: String, action_id: String = "") -> void:
	var fallback_line := ""
	if action_id == "":
		fallback_line = _pick_bubble_line(npc_id, npc_name, npc_data, phase)
	else:
		fallback_line = _pick_action_bubble_line(npc_id, npc_name, npc_data, action_id)
	if fallback_line == "":
		return
	var deepseek_client = _get_deepseek_client()
	if not deepseek_client:
		_show_npc_bubble(fallback_line)
		return
	if _bubble_ai_completed_callable.is_valid() and deepseek_client.is_connected("npc_event_dialogue_completed", _bubble_ai_completed_callable):
		deepseek_client.npc_event_dialogue_completed.disconnect(_bubble_ai_completed_callable)
	if _bubble_ai_failed_callable.is_valid() and deepseek_client.is_connected("npc_event_dialogue_failed", _bubble_ai_failed_callable):
		deepseek_client.npc_event_dialogue_failed.disconnect(_bubble_ai_failed_callable)
	_bubble_ai_request_serial += 1
	var request_serial := _bubble_ai_request_serial
	_bubble_ai_completed_callable = Callable(self, "_on_bubble_line_generated").bind(request_serial, fallback_line)
	_bubble_ai_failed_callable = Callable(self, "_on_bubble_line_failed").bind(request_serial, fallback_line)
	deepseek_client.npc_event_dialogue_completed.connect(_bubble_ai_completed_callable, CONNECT_ONE_SHOT)
	deepseek_client.npc_event_dialogue_failed.connect(_bubble_ai_failed_callable, CONNECT_ONE_SHOT)
	var effective_phase := phase
	if action_id != "":
		effective_phase = "action_open"
	var prompt := _build_bubble_polish_prompt(npc_id, npc_name, fallback_line, effective_phase, action_id)
	deepseek_client.generate_npc_event_dialogue(npc_id, prompt)

func _on_bubble_line_generated(generated_text: String, request_serial: int, fallback_line: String) -> void:
	if request_serial != _bubble_ai_request_serial:
		return
	var final_line := _normalize_bubble_line(generated_text, fallback_line)
	_remember_bubble_line(final_line)
	_show_npc_bubble(final_line)

func _on_bubble_line_failed(_error_msg: String, request_serial: int, fallback_line: String) -> void:
	if request_serial != _bubble_ai_request_serial:
		return
	_remember_bubble_line(fallback_line)
	_show_npc_bubble(fallback_line)

func _on_npc_clicked(npc_id: String, play_menu_bubble: bool = true):
	# 如果 NPC 身上配置了专属的动态剧情脚本，则直接跳转至 AVG 剧情模式
	var trigger_script = MapDataManager.get_npc_trigger_script(npc_id)
	if trigger_script != "":
		GameDataManager.set_meta("play_specific_story", trigger_script)
		SceneTransitionManager.transition_to_scene("res://scenes/ui/story/story_scene.tscn")
		return
		
	current_interacting_npc_id = npc_id
	
	var npc_data = MapDataManager.get_npc_data(npc_id)
	var npc_name = npc_data.get("name", npc_id)
	
	var char_file_path = "res://assets/data/characters/npc/" + npc_id + ".json"
	if npc_id == "luna":
		char_file_path = "res://assets/data/characters/luna.json"
		
	var sprite_frames_path = ""
	var static_portrait_path = ""
	var npc_title = "未知"
	
	var file = FileAccess.open(char_file_path, FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.get_data()
			if data is Dictionary:
				npc_name = data.get("char_name", npc_name)
				sprite_frames_path = str(data.get("sprite_frames_path", "")).strip_edges()
				static_portrait_path = str(data.get("static_portrait", "")).strip_edges()
				npc_title = data.get("title", npc_title)
				
	menu_name_label.text = npc_name
		
	# 好感度及情感阶段展示逻辑
	if npc_id == "luna":
		var profile = GameDataManager.profile
		var current_stage = profile.current_stage
		var conf = profile.get_current_stage_config()
		menu_stage_label.text = conf.get("stageTitle", "陌生人")
		
		# 构建爱心字符串 (根据当前阶段显示实心心，总共10颗心)
		var max_hearts = 10
		var filled_hearts = min(current_stage, max_hearts)
		var hearts_str = ""
		for i in range(max_hearts):
			if i < filled_hearts:
				hearts_str += "♥"
			else:
				hearts_str += "♡"
		menu_hearts_label.text = hearts_str
	else:
		# 默认非主角NPC的好感度展示
		# 这里使用专门的 NPC 好感度系统
		var npc_stage_data = _get_npc_stage_data(npc_id)
		menu_stage_label.text = npc_stage_data.get("stageTitle", "普通朋友")
		
		var heart_count = npc_stage_data.get("heartCount", 0)
		# 处理 heartCount 可能是范围字符串的情况 (如 "2-3", "4-9")
		var current_hearts = 0
		if typeof(heart_count) == TYPE_STRING:
			var parts = heart_count.split("-")
			if parts.size() > 0:
				current_hearts = parts[0].to_int()
		else:
			current_hearts = heart_count
			
		var max_hearts = 10
		var filled_hearts = min(current_hearts, max_hearts)
		var hearts_str = ""
		for i in range(max_hearts):
			if i < filled_hearts:
				hearts_str += "♥"
			else:
				hearts_str += "♡"
		menu_hearts_label.text = hearts_str
	
	# 重置显示状态
	if npc_anim_sprite:
		npc_anim_sprite.hide()
		npc_anim_sprite.stop()
	if npc_static_sprite:
		npc_static_sprite.hide()
		
	var loaded_sprite = false
	if not sprite_frames_path.is_empty() and ResourceLoader.exists(sprite_frames_path) and npc_anim_sprite:
		var frames_res = load(sprite_frames_path)
		if frames_res is SpriteFrames:
			npc_anim_sprite.sprite_frames = frames_res
			
			# 找一个默认动画
			var anim_name = ""
			for candidate in ["default", "idle", "calm"]:
				if frames_res.has_animation(candidate):
					anim_name = candidate
					break
			if anim_name == "" and frames_res.get_animation_names().size() > 0:
				anim_name = frames_res.get_animation_names()[0]
				
			if anim_name != "":
				npc_anim_sprite.play(StringName(anim_name))
			
			# 设置专属的大立绘尺寸
			var custom_scale = 0.8
			npc_anim_sprite.scale = Vector2(custom_scale, custom_scale)
			
			var h = 800.0
			if anim_name != "":
				var tex = frames_res.get_frame_texture(anim_name, 0)
				if tex:
					h = tex.get_size().y
					
			# 动态计算高度偏移，使立绘底部对齐屏幕底部 (因为 NPCPortrait 的 y=720)
			npc_anim_sprite.position = Vector2(0, -h / 2.0 * custom_scale) 
			npc_anim_sprite.show()
			loaded_sprite = true
			
	if not loaded_sprite and npc_static_sprite:
		if not static_portrait_path.is_empty() and ResourceLoader.exists(static_portrait_path):
			var tex = load(static_portrait_path)
			if tex is Texture2D:
				npc_static_sprite.texture = tex
				
				# 针对静态图的尺寸适配，保证它能占满大半个屏幕高度
				var tex_size = tex.get_size()
				var target_height = 700.0
				if tex_size.y > 0:
					var target_scale = target_height / tex_size.y
					npc_static_sprite.scale = Vector2(target_scale, target_scale)
					
				# 底部对齐
				npc_static_sprite.position = Vector2(0, -target_height / 2.0)
				npc_static_sprite.show()

	# Clear existing buttons
	for child in menu_options_vbox.get_children():
		child.queue_free()

	# Generate dynamic interaction buttons based on NPC data
	var interactions = npc_data.get("interactions", [])
	if interactions.is_empty():
		interactions = [{"id": "chat", "label": "聊天"}, {"id": "leave", "label": "离开"}]

	for action in interactions:
		var btn = QUICK_ACTION_BUTTON_SCENE.instantiate()
		var action_id = action.get("id", "")
		var action_label = action.get("label", "未知操作")
		
		btn.setup(action_id, action_label)
		
		# Store original text
		btn.set_meta("original_text", action_label)
		
		btn.pressed.connect(_on_menu_action_pressed.bind(action_id))
		menu_options_vbox.add_child(btn)

	back_button.hide() # 隐藏返回地图按钮
	interaction_menu.show()
	
	# 动效过渡
	interaction_menu.modulate.a = 1.0
	info_and_options.modulate.a = 0.0
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(info_and_options, "modulate:a", 1.0, 0.3)
	
	var original_x = info_and_options.position.x
	info_and_options.position.x += 150
	tween.tween_property(info_and_options, "position:x", original_x, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	if npc_portrait:
		npc_portrait.position.x = original_char_x
		npc_portrait.position.y = original_char_y + MENU_ENTRY_PORTRAIT_OFFSET_Y
		npc_portrait.modulate.a = 0.0
		tween.tween_property(npc_portrait, "position:y", original_char_y, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(npc_portrait, "modulate:a", 1.0, 0.28)
	if play_menu_bubble:
		tween.finished.connect(func():
			if not is_inside_tree():
				return
			if current_interacting_npc_id != npc_id:
				return
			_play_menu_open_bubble(npc_id, npc_name, npc_data)
		, CONNECT_ONE_SHOT)

func _get_npc_stage_data(npc_id: String) -> Dictionary:
	# 暂时返回第一阶段作为默认值。实际应用中需要从全局 NPC 好感度管理器中读取当前进度。
	var stages_file = "res://assets/data/characters/npc/" + npc_id + "_stages.json"
	if FileAccess.file_exists(stages_file):
		var file = FileAccess.open(stages_file, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.get_data()
			if data is Dictionary and data.has("stages") and data["stages"].size() > 0:
				# TODO: 接入真实的 NPC 好感度管理器来获取实际进度，这里暂时取第一阶段
				return data["stages"][0]
	return {"stageTitle": "普通朋友", "heartCount": 0}

func _open_sub_menu(scene_path: String, action_id: String = "") -> void:
	_submenu_restore_started = false
	_hide_npc_bubble()
	info_and_options.hide() # 仅隐藏右侧选项，保留角色和姓名
	_hide_map_info_panel(true)
	
	if npc_portrait:
		var tween = create_tween()
		tween.tween_property(npc_portrait, "position:x", _get_submenu_portrait_target_x(), SUBMENU_FADE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		if action_id != "":
			tween.finished.connect(func():
				if not is_inside_tree():
					return
				if current_interacting_npc_id == "":
					return
				var npc_data := MapDataManager.get_npc_data(current_interacting_npc_id)
				var npc_name := str(menu_name_label.text).strip_edges()
				if npc_name == "":
					npc_name = str(npc_data.get("name", current_interacting_npc_id))
				_play_submenu_open_bubble(current_interacting_npc_id, npc_name, npc_data, action_id)
			, CONNECT_ONE_SHOT)
		
	var menu_scene = load(scene_path)
	if menu_scene:
		var menu = menu_scene.instantiate()
		if menu.has_signal("closing_started"):
			menu.closing_started.connect(_on_sub_menu_closing_started, CONNECT_ONE_SHOT)
		if menu.has_signal("tree_exited"):
			menu.tree_exited.connect(func():
				if not is_inside_tree():
					return
				await get_tree().process_frame
				if not is_inside_tree():
					return
					
				var making_node = null
				for child in get_tree().root.get_children():
					if child.name.begins_with("CafeMakingPopup"):
						making_node = child
						break
						
				if making_node:
					making_node.tree_exited.connect(func():
						if not is_inside_tree(): return
						if dialogue_panel and not dialogue_panel.visible and current_interacting_npc_id != "":
							if not _submenu_restore_started:
								_restore_after_sub_menu(false)
					)
				elif dialogue_panel and not dialogue_panel.visible and current_interacting_npc_id != "": 
					if not _submenu_restore_started:
						_restore_after_sub_menu(true)
			)
		get_tree().root.add_child(menu)
		_apply_submenu_panel_layout(menu)

func _get_submenu_portrait_target_x() -> float:
	var viewport_width = get_viewport_rect().size.x
	if viewport_width <= 0.0:
		return original_char_x
	return viewport_width * SUBMENU_PORTRAIT_RATIO_X

func _apply_submenu_panel_layout(menu_root: Node) -> void:
	if menu_root == null:
		return
	for panel_name in ["MenuPanel", "MainPanel", "StudyPopup"]:
		var panel := menu_root.get_node_or_null(panel_name) as Control
		if panel:
			_align_submenu_panel_to_right(panel)

func _align_submenu_panel_to_right(panel: Control) -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var left_bound := viewport_size.x / 3.0 + SUBMENU_PANEL_MIN_RIGHT_MARGIN
	var right_bound := viewport_size.x - SUBMENU_PANEL_MIN_RIGHT_MARGIN
	var max_width := minf(maxf(320.0, right_bound - left_bound), viewport_size.x * SUBMENU_PANEL_MAX_WIDTH_RATIO)
	var panel_width := panel.custom_minimum_size.x
	if panel_width <= 0.0:
		panel_width = absf(panel.offset_right - panel.offset_left)
	if panel_width <= 0.0:
		panel_width = panel.size.x
	panel_width = minf(panel_width, max_width)
	var panel_height := panel.custom_minimum_size.y
	if panel_height <= 0.0:
		panel_height = absf(panel.offset_bottom - panel.offset_top)
	if panel_height <= 0.0:
		panel_height = panel.size.y
	var center_x := viewport_size.x * SUBMENU_PANEL_CENTER_RATIO
	var left := center_x - panel_width * 0.5
	var right := center_x + panel_width * 0.5
	if left < left_bound:
		var underflow := left_bound - left
		left += underflow
		right += underflow
	if right > right_bound:
		var overflow := right - right_bound
		left -= overflow
		right -= overflow
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = left
	panel.offset_right = right
	panel.offset_top = -panel_height * 0.5
	panel.offset_bottom = panel_height * 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

func _on_sub_menu_closing_started() -> void:
	if dialogue_panel and dialogue_panel.visible:
		return
	if _submenu_restore_started:
		return
	_restore_after_sub_menu(true)

func _restore_after_sub_menu(animated: bool) -> void:
	if current_interacting_npc_id == "":
		return
	_submenu_restore_started = true
	info_and_options.show()
	_show_map_info_panel(animated)
	if animated:
		info_and_options.modulate.a = 0.0
		info_and_options.position.x += SUBMENU_INFO_HIDDEN_OFFSET_X
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(info_and_options, "modulate:a", 1.0, SUBMENU_FADE_DURATION)
		tween.tween_property(info_and_options, "position:x", original_info_x, SUBMENU_FADE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		if npc_portrait:
			tween.tween_property(npc_portrait, "position:x", original_char_x, SUBMENU_FADE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(npc_portrait, "position:y", original_char_y, SUBMENU_FADE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	else:
		info_and_options.modulate.a = 1.0
		info_and_options.position.x = original_info_x
		if npc_portrait:
			npc_portrait.position.x = original_char_x
			npc_portrait.position.y = original_char_y

func _hide_map_info_panel(animated: bool) -> void:
	if map_info_panel == null:
		return
	if not animated:
		map_info_panel.modulate.a = 0.0
		map_info_panel.hide()
		return
	map_info_panel.show()
	var tween = create_tween()
	tween.tween_property(map_info_panel, "modulate:a", 0.0, SUBMENU_FADE_DURATION)
	tween.tween_callback(func():
		if map_info_panel:
			map_info_panel.hide()
	)

func _show_map_info_panel(animated: bool) -> void:
	if map_info_panel == null:
		return
	map_info_panel.show()
	if not animated:
		map_info_panel.modulate.a = 1.0
		return
	map_info_panel.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(map_info_panel, "modulate:a", 1.0, SUBMENU_FADE_DURATION)

func _on_menu_action_pressed(action_id: String):
	match action_id:
		"chat":
			_hide_npc_bubble()
			print("快捷模式 - 与 NPC: ", current_interacting_npc_id, " 聊天")
			interaction_menu.hide() # 隐藏互动选项
			_show_topic_selection_in_dialogue()
		"order":
			print("快捷模式 - 与 NPC: ", current_interacting_npc_id, " 点单/服务")
			if current_interacting_npc_id == "ya":
				_open_sub_menu("res://scenes/ui/map/cafe/cafe_order_menu.tscn", action_id)
			else:
				# TODO: 其他 NPC 的互动
				pass
		"study":
			print("快捷模式 - 找 NPC: ", current_interacting_npc_id, " 补习/指导")
			if current_interacting_npc_id == "jing":
				_open_sub_menu("res://scenes/ui/map/library/tutoring_menu.tscn", action_id)
			elif current_interacting_npc_id == "shuo":
				_open_sub_menu("res://scenes/ui/map/art_gallery/art_study_menu.tscn", action_id)
			elif current_interacting_npc_id == "ling":
				_open_sub_menu("res://scenes/ui/map/concert_hall/music_study_menu.tscn", action_id)
			elif current_interacting_npc_id == "aili":
				_open_sub_menu("res://scenes/ui/map/grand_theater/performance_study_menu.tscn", action_id)
		"gift":
			_hide_npc_bubble()
			print("快捷模式 - 给 NPC: ", current_interacting_npc_id, " 送礼")
			interaction_menu.hide() # 隐藏互动选项
			# TODO: 打开送礼界面
		"leave":
			_hide_npc_bubble()
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(interaction_menu, "modulate:a", 0.0, 0.3)
			
			var original_x = info_and_options.position.x
			tween.tween_property(info_and_options, "position:x", original_x + 150, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			
			if npc_portrait:
				var orig_char_y = npc_portrait.position.y
				tween.tween_property(npc_portrait, "position:y", orig_char_y + 30, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			
			tween.chain().tween_callback(func():
				current_interacting_npc_id = ""
				interaction_menu.hide()
				# Restore positions for next time
				info_and_options.position.x = original_x
				if npc_portrait:
					npc_portrait.position.x = original_char_x
					npc_portrait.position.y = original_char_y
				
				# 返回地图
				_on_back_pressed()
			)
		_:
			print("快捷模式 - 未知操作: ", action_id)

func _on_dialogue_finished():
	# 当打字机专属台词结束后，恢复互动菜单显示
	if current_interacting_npc_id != "":
		info_and_options.show()

func _show_topic_selection_in_dialogue() -> void:
	_awaiting_topic_selection = true
	_topic_greeting_playing = true
	_pending_topic_options.clear()
	_quick_chat_active = false
	_selected_topic = ""
	if dialogue_panel.get_parent():
		dialogue_panel.get_parent().move_child(dialogue_panel, -1)
	dialogue_panel.visible = true
	dialogue_panel.modulate.a = 0.0
	var t_tween = create_tween()
	t_tween.tween_property(dialogue_panel, "modulate:a", 1.0, 0.3)

	var npc_name := str(menu_name_label.text).strip_edges()
	if npc_name == "":
		npc_name = current_interacting_npc_id
	dialogue_name_label.text = npc_name
	dialogue_text_label.bbcode_enabled = true
	dialogue_text_label.text = "[center]想和 %s 聊什么？[/center]" % npc_name
	dialogue_text_label.visible_ratio = 1.0
	dialogue_text_label.visible_characters = -1

	if dialogue_input_layer:
		dialogue_input_layer.hide()
	if dialogue_history_button:
		dialogue_history_button.hide()
	if dialogue_end_button:
		dialogue_end_button.show()
	if dialogue_quick_option_layer:
		dialogue_quick_option_layer.hide()

	_clear_dialogue_topic_options()
	
	# 请求 AI 动态生成话题
	var profile = GameDataManager.profile
	var npc_stage_data = _get_npc_stage_data(current_interacting_npc_id)
	var stage_title = npc_stage_data.get("stageTitle", "普通朋友")
	var prompt_npc_name := str(menu_name_label.text).strip_edges()
	if prompt_npc_name == "":
		prompt_npc_name = current_interacting_npc_id
	
	var prompt = "【系统指令】\n请基于当前少女【%s】与NPC【%s】的情感阶段（当前阶段：%s），以【%s】的口吻，生成 3 个向【%s】发起聊天的话题选项。\n要求：\n1. 直接输出 3 个选项，每行一个。\n2. 不要带有序号（如 1. 2. 3.）、破折号或其他前缀。\n3. 话题要自然、简短（20字以内），符合日常聊天习惯。" % [profile.char_name, prompt_npc_name, stage_title, profile.char_name, prompt_npc_name]
	
	var deepseek_client = get_node_or_null("DeepSeekClient")
	if not deepseek_client:
		# Fallback to main scene if not found locally
		deepseek_client = get_node_or_null("/root/MainScene/DeepSeekClient")
	
	if not deepseek_client:
		printerr("DeepSeekClient not found!")
		_render_dynamic_topics("最近生意怎么样？\n今天有什么推荐的吗？\n想随便聊聊。")
		return
		
	deepseek_client.generate_dynamic_topics(prompt, func(text: String):
		if not _awaiting_topic_selection:
			return
		if text.is_empty():
			_render_dynamic_topics("最近生意怎么样？\n今天有什么推荐的吗？\n想随便聊聊。")
		else:
			_render_dynamic_topics(text)
	)
	_request_topic_greeting_for_location()

func _render_dynamic_topics(raw_text: String) -> void:
	_pending_topic_options = QUICK_OPTION_LIST_HELPER.parse_topic_lines(
		raw_text,
		["聊点什么呢？", "天气不错", "分享件有趣的事"],
		3
	)
	if _awaiting_topic_selection and not _topic_greeting_playing:
		_show_dialogue_topic_options()

func _clear_dialogue_topic_options() -> void:
	for child in dialogue_quick_options_container.get_children():
		child.queue_free()

func _show_dialogue_topic_options() -> void:
	_clear_dialogue_topic_options()
	if dialogue_quick_option_layer:
		dialogue_quick_option_layer.show()
	if _pending_topic_options.is_empty():
		QUICK_OPTION_LIST_HELPER.show_loading_item(dialogue_quick_options_container)
		return
	QUICK_OPTION_LIST_HELPER.populate_option_items(dialogue_quick_options_container, _pending_topic_options, _on_topic_selected, 50.0)

func _request_topic_greeting_for_location() -> void:
	var deepseek_client = get_node_or_null("DeepSeekClient")
	if not deepseek_client:
		deepseek_client = get_node_or_null("/root/MainScene/DeepSeekClient")
	if not deepseek_client:
		_on_location_topic_greeting_failed("DeepSeekClient not found")
		return

	if deepseek_client.is_connected("npc_event_dialogue_completed", _on_location_topic_greeting_generated):
		deepseek_client.npc_event_dialogue_completed.disconnect(_on_location_topic_greeting_generated)
	if deepseek_client.is_connected("npc_event_dialogue_failed", _on_location_topic_greeting_failed):
		deepseek_client.npc_event_dialogue_failed.disconnect(_on_location_topic_greeting_failed)

	deepseek_client.npc_event_dialogue_completed.connect(_on_location_topic_greeting_generated, CONNECT_ONE_SHOT)
	deepseek_client.npc_event_dialogue_failed.connect(_on_location_topic_greeting_failed, CONNECT_ONE_SHOT)

	var npc_stage_data = _get_npc_stage_data(current_interacting_npc_id)
	var stage_title = npc_stage_data.get("stageTitle", "普通朋友")
	var greeting_prompt = "请生成一句与你面前的人开启聊天的话题问候，核心意思是“要聊点什么呢？”。要求：1. 结合你当前的身份、与对方的好感阶段和语气，当前阶段是%s。2. 必须符合角色口吻。3. 只输出一句简短台词，20字以内。4. 可以带一个简短括号动作描写。5. 不要展开成长对话，不要输出选项。" % [stage_title]
	deepseek_client.generate_npc_event_dialogue(current_interacting_npc_id, greeting_prompt)

func _on_location_topic_greeting_generated(greeting_text: String) -> void:
	if not _awaiting_topic_selection:
		return
	var npc_name := str(menu_name_label.text).strip_edges()
	if npc_name == "":
		npc_name = current_interacting_npc_id
	if dialogue_panel.has_method("cancel_single_line"):
		dialogue_panel.cancel_single_line(false)
	if dialogue_panel.has_signal("single_line_finished"):
		dialogue_panel.single_line_finished.connect(_on_location_topic_greeting_finished, CONNECT_ONE_SHOT)
	dialogue_panel.play_single_line(current_interacting_npc_id, npc_name, greeting_text, true, true, true)

func _on_location_topic_greeting_failed(_error_msg: String) -> void:
	if not _awaiting_topic_selection:
		return
	_on_location_topic_greeting_generated("（看向你）这次想聊点什么？")

func _on_location_topic_greeting_finished() -> void:
	if not _awaiting_topic_selection:
		return
	_topic_greeting_playing = false
	_show_dialogue_topic_options()

func _on_topic_selected(topic: String) -> void:
	# 执行互动开销
	if GameDataManager.interaction_manager:
		if not GameDataManager.interaction_manager.execute_interaction("chat_jing"):
			return
	else:
		if not GameDataManager.profile.consume_energy(5):
			ToastManager.show_system_toast("行动力不足，需要5点行动力", Color.RED)
			return

	_awaiting_topic_selection = false
	_topic_greeting_playing = false
	_quick_chat_active = true
	_selected_topic = topic

	interaction_menu.show() # 恢复背景层
	info_and_options.hide() # 但是隐藏互动选项菜单，让对话框显示

	if dialogue_quick_option_layer:
		dialogue_quick_option_layer.hide()
	if dialogue_input_layer:
		dialogue_input_layer.show()
	if dialogue_history_button:
		dialogue_history_button.hide()
	if dialogue_end_button:
		dialogue_end_button.show()
	dialogue_input_field.text = ""
	dialogue_input_field.editable = false
	dialogue_send_button.disabled = true

	var profile = GameDataManager.profile
	var char_name = profile.char_name if profile.char_name != "" else "Luna"
	var event_desc = char_name + "对你说：" + topic
	_trigger_npc_event_dialogue(current_interacting_npc_id, event_desc)

func _trigger_npc_event_dialogue(npc_id: String, event_desc: String) -> void:
	var deepseek_client = get_node_or_null("/root/MainScene/DeepSeekClient") # 借用全局或寻找本场景的客户端
	if not deepseek_client:
		# 尝试在本场景找找看有没有
		deepseek_client = get_node_or_null("DeepSeekClient")
		if not deepseek_client:
			printerr("DeepSeekClient not found!")
			return
			
	# 如果找到了现有的 client，先断开之前可能的连接
	if deepseek_client.is_connected("npc_event_dialogue_completed", _on_topic_reply_generated):
		deepseek_client.npc_event_dialogue_completed.disconnect(_on_topic_reply_generated)
	if deepseek_client.is_connected("npc_event_dialogue_failed", _on_topic_reply_failed):
		deepseek_client.npc_event_dialogue_failed.disconnect(_on_topic_reply_failed)
		
	# 临时连接信号用于接收这一次对话的结果
	deepseek_client.npc_event_dialogue_completed.connect(_on_topic_reply_generated, CONNECT_ONE_SHOT)
	deepseek_client.npc_event_dialogue_failed.connect(_on_topic_reply_failed, CONNECT_ONE_SHOT)
		
	# 生成并播放 NPC 的专属台词
	deepseek_client.generate_npc_event_dialogue(
		npc_id,
		event_desc
	)

func _on_topic_reply_generated(reply_text: String) -> void:
	if not dialogue_panel or not dialogue_panel.visible:
		return
	var npc_name := str(menu_name_label.text).strip_edges()
	if npc_name == "":
		npc_name = current_interacting_npc_id
	dialogue_name_label.text = npc_name
	dialogue_text_label.bbcode_enabled = true
	dialogue_text_label.text = reply_text
	dialogue_text_label.visible_ratio = 1.0
	dialogue_text_label.visible_characters = -1
	dialogue_input_field.editable = true
	dialogue_send_button.disabled = false

func _on_topic_reply_failed(_error_msg: String) -> void:
	if not dialogue_panel or not dialogue_panel.visible:
		return
	var npc_name := str(menu_name_label.text).strip_edges()
	if npc_name == "":
		npc_name = current_interacting_npc_id
	dialogue_name_label.text = npc_name
	dialogue_text_label.bbcode_enabled = true
	dialogue_text_label.text = "……（默认回应）"
	dialogue_text_label.visible_ratio = 1.0
	dialogue_text_label.visible_characters = -1
	dialogue_input_field.editable = true
	dialogue_send_button.disabled = false

func _on_dialogue_message_sent(text: String) -> void:
	if not _quick_chat_active:
		return
	var trimmed_text := text.strip_edges()
	if trimmed_text == "":
		return

	dialogue_name_label.text = GameDataManager.profile.char_name
	dialogue_text_label.bbcode_enabled = true
	dialogue_text_label.text = trimmed_text
	dialogue_text_label.visible_ratio = 1.0
	dialogue_text_label.visible_characters = -1
	dialogue_input_field.editable = false
	dialogue_send_button.disabled = true

	var event_desc := "当前聊天话题：%s\n%s对你说：%s" % [_selected_topic, GameDataManager.profile.char_name, trimmed_text]
	_trigger_npc_event_dialogue(current_interacting_npc_id, event_desc)

func _on_dialogue_close_pressed() -> void:
	if not _awaiting_topic_selection and not _quick_chat_active:
		return
	_close_dialogue_chat()

func _close_dialogue_chat() -> void:
	_awaiting_topic_selection = false
	_topic_greeting_playing = false
	_pending_topic_options.clear()
	_quick_chat_active = false
	_selected_topic = ""
	if dialogue_panel.has_method("cancel_single_line"):
		dialogue_panel.cancel_single_line(false)
	if dialogue_quick_option_layer:
		dialogue_quick_option_layer.hide()
	_clear_dialogue_topic_options()
	if dialogue_input_layer:
		dialogue_input_layer.hide()
	if dialogue_history_button:
		dialogue_history_button.hide()
	if dialogue_panel:
		dialogue_panel.hide()
	if current_interacting_npc_id != "":
		interaction_menu.show()
		info_and_options.show()

func _on_back_pressed():
	_hide_npc_bubble(true)
	var world_map_scene = "res://scenes/ui/map/core/world_map_scene.tscn"
	SceneTransitionManager.transition_to_scene(world_map_scene)

func _exit_tree() -> void:
	_hide_npc_bubble(true)
	var deepseek_client = _get_deepseek_client()
	if deepseek_client:
		if _bubble_ai_completed_callable.is_valid() and deepseek_client.is_connected("npc_event_dialogue_completed", _bubble_ai_completed_callable):
			deepseek_client.npc_event_dialogue_completed.disconnect(_bubble_ai_completed_callable)
		if _bubble_ai_failed_callable.is_valid() and deepseek_client.is_connected("npc_event_dialogue_failed", _bubble_ai_failed_callable):
			deepseek_client.npc_event_dialogue_failed.disconnect(_bubble_ai_failed_callable)
	if TTSManager:
		if TTSManager.tts_success.is_connected(_on_bubble_tts_success):
			TTSManager.tts_success.disconnect(_on_bubble_tts_success)
		if TTSManager.tts_failed.is_connected(_on_bubble_tts_failed):
			TTSManager.tts_failed.disconnect(_on_bubble_tts_failed)

func _schedule_scene_entry_bubble(npc_id: String) -> void:
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	if initial_npc_id != npc_id:
		return
	if current_interacting_npc_id != npc_id:
		return
	var npc_data := MapDataManager.get_npc_data(npc_id)
	var npc_name := str(menu_name_label.text).strip_edges()
	if npc_name == "":
		npc_name = str(npc_data.get("name", npc_id))
	_play_scene_entry_bubble(npc_id, npc_name, npc_data)

func _play_scene_entry_bubble(npc_id: String, npc_name: String, npc_data: Dictionary) -> void:
	_request_bubble_line(npc_id, npc_name, npc_data, "scene_entry")

func _play_menu_open_bubble(npc_id: String, npc_name: String, npc_data: Dictionary) -> void:
	_request_bubble_line(npc_id, npc_name, npc_data, "menu_open")

func _play_submenu_open_bubble(npc_id: String, npc_name: String, npc_data: Dictionary, action_id: String) -> void:
	_request_bubble_line(npc_id, npc_name, npc_data, "menu_open", action_id)

func _pick_bubble_line(npc_id: String, npc_name: String, npc_data: Dictionary, phase: String) -> String:
	var phase_lines := _get_bubble_template_lines(npc_id, phase)
	if not phase_lines.is_empty():
		return _pick_line_from_candidates(phase_lines)
	
	var identity_text := str(npc_data.get("identity_background", "")).strip_edges()
	var tags: Array = npc_data.get("tags", [])
	match phase:
		"scene_entry":
			if "咖啡" in identity_text or "老板娘" in identity_text:
				return ["欢迎，先歇一会儿吧。", "你来得正巧，店里刚安静下来。"].pick_random()
			if "老师" in identity_text or tags.has("音乐老师"):
				return ["先别急着开口，整理一下状态。", "来了就好，先把呼吸放稳。"].pick_random()
			if "学长" in identity_text or "研究生" in identity_text or tags.has("学长"):
				return ["你来了。", "这里还算安静，坐下再说。"].pick_random()
		"menu_open":
			if "咖啡" in identity_text or "老板娘" in identity_text:
				return ["慢慢说，我在听。", "想喝什么，或者想聊什么，都可以告诉我。"].pick_random()
			if "老师" in identity_text or tags.has("音乐老师"):
				return ["好，把注意力收回来。", "嗯，说吧，今天准备做什么。"].pick_random()
			if "学长" in identity_text or "研究生" in identity_text or tags.has("学长"):
				return ["说重点。", "既然过来了，就别一直沉默。"].pick_random()
	return ["你来了。", "%s，欢迎。".replace("%s", npc_name)].pick_random()

func _pick_action_bubble_line(npc_id: String, npc_name: String, npc_data: Dictionary, action_id: String) -> String:
	var action_lines := _get_action_bubble_template_lines(npc_id, action_id)
	if not action_lines.is_empty():
		return _pick_line_from_candidates(action_lines)
	var identity_text := str(npc_data.get("identity_background", "")).strip_edges()
	if action_id == "order" and ("咖啡" in identity_text or "老板娘" in identity_text):
		return _pick_line_from_candidates(["慢慢挑，我不着急。", "点单之前，先想想你今天想要什么味道。"])
	if action_id == "study" and ("老师" in identity_text or "学长" in identity_text):
		return _pick_line_from_candidates(["开始吧，先从你最没把握的部分讲。", "把注意力收回来，我们现在开始。"])
	return "%s，准备好了就开始吧。".replace("%s", npc_name)

func _show_npc_bubble(text: String) -> void:
	if not bubble_root or not speech_bubble or not bubble_text_label:
		return
	
	_bubble_sequence_id += 1
	var seq := _bubble_sequence_id
	_bubble_current_tts_text = text
	if _bubble_hide_tween:
		_bubble_hide_tween.kill()
	if _bubble_typewriter_tween:
		_bubble_typewriter_tween.kill()
	if _bubble_audio_player:
		_bubble_audio_player.stop()
	
	bubble_text_label.text = text
	bubble_text_label.visible_ratio = 0.0
	bubble_root.show()
	speech_bubble.show()
	speech_bubble.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(speech_bubble, "modulate:a", 1.0, 0.2)
	var typewriter_duration := maxf(0.35, float(text.length()) * BUBBLE_TYPEWRITER_CHAR_TIME)
	_bubble_typewriter_tween = create_tween()
	_bubble_typewriter_tween.tween_property(bubble_text_label, "visible_ratio", 1.0, typewriter_duration)
	_play_bubble_tts(text)
	_schedule_bubble_auto_hide(seq, text, typewriter_duration)

func _schedule_bubble_auto_hide(seq: int, text: String, typewriter_duration: float) -> void:
	var wait_time := typewriter_duration + maxf(BUBBLE_MIN_SHOW_TIME, float(text.length()) * BUBBLE_SHOW_TIME_PER_CHAR)
	await get_tree().create_timer(wait_time).timeout
	if not is_inside_tree():
		return
	if seq != _bubble_sequence_id:
		return
	if _bubble_audio_player and _bubble_audio_player.playing:
		return
	_hide_npc_bubble()

func _hide_npc_bubble(immediate: bool = false) -> void:
	_bubble_sequence_id += 1
	_bubble_current_tts_text = ""
	if _bubble_audio_player:
		_bubble_audio_player.stop()
	if _bubble_typewriter_tween:
		_bubble_typewriter_tween.kill()
	if not bubble_root or not speech_bubble:
		return
	if _bubble_hide_tween:
		_bubble_hide_tween.kill()
	if immediate:
		speech_bubble.hide()
		bubble_root.hide()
		speech_bubble.modulate.a = 0.0
		return
	if not speech_bubble.visible:
		bubble_root.hide()
		return
	_bubble_hide_tween = create_tween()
	_bubble_hide_tween.tween_property(speech_bubble, "modulate:a", 0.0, 0.18)
	_bubble_hide_tween.chain().tween_callback(func():
		if speech_bubble:
			speech_bubble.hide()
		if bubble_root:
			bubble_root.hide()
	)

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
	if backend == "qwen_tts":
		if GameDataManager.config.qwen_tts_voice_types.has(current_interacting_npc_id):
			options["voice_type"] = GameDataManager.config.qwen_tts_voice_types[current_interacting_npc_id]
	else:
		if GameDataManager.config.character_voice_types.has(current_interacting_npc_id):
			options["voice_type"] = GameDataManager.config.character_voice_types[current_interacting_npc_id]
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
	if speech_bubble and speech_bubble.visible:
		var seq := _bubble_sequence_id
		await get_tree().create_timer(BUBBLE_HIDE_DELAY_AFTER_VOICE).timeout
		if not is_inside_tree():
			return
		if seq != _bubble_sequence_id:
			return
		if speech_bubble and speech_bubble.visible:
			_hide_npc_bubble()
