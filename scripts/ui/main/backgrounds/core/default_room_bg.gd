extends "res://scripts/ui/main/backgrounds/core/bg_scene_base.gd"

@onready var bg_rect: TextureRect = $background
@onready var chat_button: Button = get_node_or_null("ChatButton") as Button

var _base_bubble_pos := Vector2.ZERO
var _bubble_tween: Tween
var _base_interact_pos := Vector2.ZERO
var _interact_bubble_tween: Tween
var _ui_tween: Tween
var _is_ui_hidden := false
var _chat_button_available := true
var _concern_mode_available := false
var _chat_status_badge: PanelContainer = null
var _chat_status_icon_label: Label = null
var _chat_status_text_label: Label = null

# Idle Quote Bubble UI (From Scene)
var idle_bubble_panel: Control
var idle_bubble_label: RichTextLabel
var idle_audio_player: AudioStreamPlayer
var _idle_typewriter_tween: Tween
var _idle_hide_tween: Tween
var _is_idle_speaking: bool = false
var _current_idle_text: String = ""
var _idle_bubble_anchor: Vector2 = Vector2.ZERO
var _idle_hide_delay: float = 1.5

func _ready() -> void:
	super._ready()

	if chat_button:
		_base_interact_pos = chat_button.position
		_base_bubble_pos = chat_button.position
		_ensure_chat_button_decorations()

	_check_story_button_visibility()
	if GameDataManager.story_time_manager and not GameDataManager.story_time_manager.time_advanced.is_connected(_on_time_advanced):
		GameDataManager.story_time_manager.time_advanced.connect(_on_time_advanced)

	_play_bubble_anim()
	
	# Initial UI state check
	var main_scene = get_tree().root.get_node_or_null("MainScene")
	if main_scene and main_scene.get("chat_scene_instance") and main_scene.chat_scene_instance.visible:
		set_ui_hidden(true)
	elif main_scene and main_scene.get("_story_mode_active"):
		set_ui_hidden(true)
		
	_setup_idle_quote_bubble()

func _exit_tree() -> void:
	if TTSManager:
		if TTSManager.tts_success.is_connected(_on_idle_tts_success):
			TTSManager.tts_success.disconnect(_on_idle_tts_success)
		if TTSManager.tts_failed.is_connected(_on_idle_tts_failed):
			TTSManager.tts_failed.disconnect(_on_idle_tts_failed)
	if is_instance_valid(idle_audio_player):
		idle_audio_player.stop()

func _get_main_scene() -> Node:
	return get_tree().root.get_node_or_null("MainScene")

func _has_main_story_available() -> bool:
	var main_scene := _get_main_scene()
	if main_scene and main_scene.has_method("has_scene_chat_mainline_available"):
		return bool(main_scene.has_scene_chat_mainline_available())
	return false

func _compute_concern_mode_available() -> bool:
	if not GameDataManager.story_time_manager:
		return false
	var date_dict = GameDataManager.story_time_manager.get_current_date_dict()
	var weekday = date_dict.weekday
	var current_hour = GameDataManager.story_time_manager.current_hour
	if not (weekday == 0 or weekday == 6 or (weekday == 5 and current_hour >= 20)):
		return false
	var current_day_offset = GameDataManager.story_time_manager.current_day_offset
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(current_day_offset) + "_story_button")
	return rng.randf() < 0.6

func is_concern_mode_available() -> bool:
	return _concern_mode_available and _chat_button_available and not _is_ui_hidden

func set_chat_button_available(is_available: bool) -> void:
	_chat_button_available = is_available
	refresh_chat_button_state()

func refresh_chat_button_state() -> void:
	if not is_instance_valid(chat_button):
		return
	_concern_mode_available = _compute_concern_mode_available()
	if _is_ui_hidden or not _chat_button_available:
		chat_button.visible = false
		_update_chat_button_status_badge("normal")
		return
	chat_button.visible = true
	chat_button.modulate.a = 1.0
	if _has_main_story_available():
		_update_chat_button_status_badge("main_story")
	elif _concern_mode_available:
		_update_chat_button_status_badge("concern")
	else:
		_update_chat_button_status_badge("normal")

func _ensure_chat_button_decorations() -> void:
	if not is_instance_valid(chat_button):
		return
	_chat_status_badge = chat_button.get_node_or_null("StatusBadge") as PanelContainer
	if not is_instance_valid(_chat_status_badge):
		_chat_status_icon_label = null
		_chat_status_text_label = null
		return
	_chat_status_icon_label = _chat_status_badge.get_node_or_null("Margin/HBox/StatusIconLabel") as Label
	_chat_status_text_label = _chat_status_badge.get_node_or_null("Margin/HBox/StatusTextLabel") as Label
	_chat_status_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _update_chat_button_status_badge(mode: String) -> void:
	_ensure_chat_button_decorations()
	if not is_instance_valid(_chat_status_badge) or not is_instance_valid(_chat_status_icon_label) or not is_instance_valid(_chat_status_text_label):
		return
	match mode:
		"main_story":
			_chat_status_badge.visible = true
			_chat_status_icon_label.text = "!"
			_chat_status_text_label.text = "主线"
			_chat_status_icon_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.58, 1.0))
			_chat_status_text_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.76, 1.0))
		"concern":
			_chat_status_badge.visible = true
			_chat_status_icon_label.text = "..."
			_chat_status_text_label.text = "心事"
			_chat_status_icon_label.add_theme_color_override("font_color", Color(0.98, 0.74, 0.86, 1.0))
			_chat_status_text_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.93, 1.0))
		_:
			_chat_status_badge.visible = false

func _setup_idle_quote_bubble() -> void:
	idle_bubble_panel = get_node_or_null("IdleQuoteBubble")
	if idle_bubble_panel:
		idle_bubble_panel.visible = false
		_idle_bubble_anchor = idle_bubble_panel.position + idle_bubble_panel.size / 2.0
		idle_bubble_label = idle_bubble_panel.get_node_or_null("Label")
		if idle_bubble_label:
			idle_bubble_label.visible_characters = 0
			
	idle_audio_player = get_node_or_null("IdleAudioPlayer")
	if not idle_audio_player:
		idle_audio_player = AudioStreamPlayer.new()
		idle_audio_player.name = "IdleAudioPlayer"
		add_child(idle_audio_player)
	
	if not idle_audio_player.finished.is_connected(_on_idle_audio_finished):
		idle_audio_player.finished.connect(_on_idle_audio_finished)

func _unhandled_input(event: InputEvent) -> void:
	if _is_idle_speaking or _is_ui_hidden:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var luna = get_node_or_null("LunaAni")
		if luna and luna.is_visible_in_tree():
			var local_pos = luna.get_local_mouse_position()
			var frames = luna.sprite_frames
			if frames and frames.has_animation(luna.animation):
				var tex = frames.get_frame_texture(luna.animation, luna.frame)
				if tex:
					var size = tex.get_size()
					var offset = -size / 2.0 if luna.centered else Vector2.ZERO
					var rect = Rect2(offset, size)
					if rect.has_point(local_pos):
						var image = tex.get_image()
						if image:
							var pixel_pos = Vector2i(local_pos - offset)
							if pixel_pos.x >= 0 and pixel_pos.y >= 0 and pixel_pos.x < image.get_width() and pixel_pos.y < image.get_height():
								if image.get_pixelv(pixel_pos).a > 0.05:
									_on_character_clicked()
									get_viewport().set_input_as_handled()
						else:
							_on_character_clicked()
							get_viewport().set_input_as_handled()

func _on_character_clicked() -> void:
	request_idle_quote()

func request_idle_quote() -> bool:
	if _is_idle_speaking or _is_ui_hidden:
		return false
		
	if not idle_bubble_panel or not idle_bubble_label:
		push_warning("闲聊气泡未配置: 请在场景中添加 IdleQuoteBubble 节点及其子节点 Label")
		return false
		
	var deepseek_client = DeepSeekClientLocator.find(self)
	if not deepseek_client:
		return false
		
	_is_idle_speaking = true
	
	if not deepseek_client.is_connected("idle_quote_completed", _on_idle_quote_completed):
		deepseek_client.idle_quote_completed.connect(_on_idle_quote_completed)
	if not deepseek_client.is_connected("idle_quote_failed", _on_idle_quote_failed):
		deepseek_client.idle_quote_failed.connect(_on_idle_quote_failed)
		
	deepseek_client.send_idle_quote_generation(GameDataManager.profile.current_character_id)
	return true

func is_idle_quote_playing() -> bool:
	return _is_idle_speaking

func _on_idle_quote_completed(quote: String) -> void:
	var deepseek_client = DeepSeekClientLocator.find(self)
	if deepseek_client:
		deepseek_client.idle_quote_completed.disconnect(_on_idle_quote_completed)
		deepseek_client.idle_quote_failed.disconnect(_on_idle_quote_failed)
	show_idle_quote_text(quote)

func _refresh_idle_bubble_layout() -> void:
	idle_bubble_label.reset_size()
	idle_bubble_label.update_minimum_size()
	idle_bubble_label.queue_redraw()
	idle_bubble_panel.reset_size()
	idle_bubble_panel.update_minimum_size()
	idle_bubble_panel.queue_redraw()

func show_idle_quote_text(raw_quote: String, strip_actions: bool = false, auto_hide_delay: float = 1.5, play_voice: bool = true) -> void:
	if not idle_bubble_panel or not idle_bubble_label:
		push_warning("闲聊气泡未配置: 请在场景中添加 IdleQuoteBubble 节点及其子节点 Label")
		return

	var quote := _sanitize_bubble_text(raw_quote, strip_actions)
	if quote == "":
		quote = "..."

	_is_idle_speaking = true
	_current_idle_text = quote
	_idle_hide_delay = maxf(0.0, auto_hide_delay)

	if _idle_hide_tween:
		_idle_hide_tween.kill()
	if _idle_typewriter_tween:
		_idle_typewriter_tween.kill()
	if idle_audio_player and idle_audio_player.playing:
		idle_audio_player.stop()

	idle_bubble_panel.visible = true
	idle_bubble_panel.modulate.a = 0.0
	idle_bubble_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	idle_bubble_label.custom_minimum_size = Vector2.ZERO
	idle_bubble_label.size = Vector2.ZERO
	idle_bubble_label.fit_content = false
	idle_bubble_label.fit_content = true
	idle_bubble_label.text = quote
	_refresh_idle_bubble_layout()

	await get_tree().process_frame

	idle_bubble_panel.size = Vector2.ZERO
	var panel_min_size = idle_bubble_panel.get_combined_minimum_size()
	var max_panel_width = 320.0

	if panel_min_size.x > max_panel_width:
		idle_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var stylebox = idle_bubble_panel.get_theme_stylebox("panel")
		var padding_x = 40.0
		if stylebox is StyleBoxFlat:
			padding_x = stylebox.content_margin_left + stylebox.content_margin_right
		idle_bubble_label.custom_minimum_size = Vector2(max_panel_width - padding_x, 0.0)
		idle_bubble_label.size.x = max_panel_width - padding_x
		idle_bubble_label.fit_content = false
		idle_bubble_label.fit_content = true
		_refresh_idle_bubble_layout()

		await get_tree().process_frame

		idle_bubble_panel.size = Vector2.ZERO
		panel_min_size = idle_bubble_panel.get_combined_minimum_size()

	idle_bubble_panel.size = panel_min_size
	idle_bubble_panel.position = _idle_bubble_anchor - panel_min_size / 2.0

	idle_bubble_label.visible_ratio = 0.0
	_idle_hide_tween = create_tween()
	_idle_hide_tween.tween_property(idle_bubble_panel, "modulate:a", 1.0, 0.2)

	_idle_typewriter_tween = create_tween()
	var dur = max(0.5, quote.length() * 0.08)
	_idle_typewriter_tween.tween_property(idle_bubble_label, "visible_ratio", 1.0, dur)

	if play_voice and GameDataManager.config.voice_enabled:
		var options = {}
		var char_id = GameDataManager.profile.current_character_id
		if GameDataManager.config.character_voice_types.has(char_id):
			options["voice_type"] = GameDataManager.config.character_voice_types[char_id]

		if not TTSManager.tts_success.is_connected(_on_idle_tts_success):
			TTSManager.tts_success.connect(_on_idle_tts_success)
		if not TTSManager.tts_failed.is_connected(_on_idle_tts_failed):
			TTSManager.tts_failed.connect(_on_idle_tts_failed)

		TTSManager.synthesize(quote, options)
	else:
		_idle_typewriter_tween.finished.connect(func() -> void:
			_start_idle_hide_timer()
		, CONNECT_ONE_SHOT)

func _sanitize_bubble_text(raw_text: String, strip_actions: bool) -> String:
	var final_text := raw_text.strip_edges()
	final_text = final_text.replace("\r\n", "\n").replace("\n", " ")
	if strip_actions:
		var action_regex := RegEx.new()
		action_regex.compile("（.*?）|\\(.*?\\)")
		final_text = action_regex.sub(final_text, "", true)
	var whitespace_regex := RegEx.new()
	whitespace_regex.compile("\\s+")
	final_text = whitespace_regex.sub(final_text, " ", true)
	return final_text.strip_edges()

func _on_idle_quote_failed(err: String) -> void:
	var deepseek_client = DeepSeekClientLocator.find(self)
	if deepseek_client:
		deepseek_client.idle_quote_completed.disconnect(_on_idle_quote_completed)
		deepseek_client.idle_quote_failed.disconnect(_on_idle_quote_failed)
	
	_is_idle_speaking = false
	idle_bubble_panel.visible = false
	if idle_bubble_label:
		idle_bubble_label.text = ""

func _on_idle_tts_success(audio_stream: AudioStream, text: String) -> void:
	if text != _current_idle_text:
		return
	if not is_inside_tree() or not is_instance_valid(idle_audio_player) or not idle_audio_player.is_inside_tree():
		return
	if audio_stream:
		idle_audio_player.stream = audio_stream
		idle_audio_player.play()

func _on_idle_tts_failed(err_msg: String, text: String) -> void:
	if text != _current_idle_text:
		return
	if not is_inside_tree():
		return
	_start_idle_hide_timer()

func _on_idle_audio_finished() -> void:
	_start_idle_hide_timer()

func _start_idle_hide_timer() -> void:
	if TTSManager.tts_success.is_connected(_on_idle_tts_success):
		TTSManager.tts_success.disconnect(_on_idle_tts_success)
	if TTSManager.tts_failed.is_connected(_on_idle_tts_failed):
		TTSManager.tts_failed.disconnect(_on_idle_tts_failed)

	await get_tree().create_timer(_idle_hide_delay).timeout
	if not is_inside_tree() or not idle_bubble_panel.visible:
		return
		
	if _idle_hide_tween:
		_idle_hide_tween.kill()
	_idle_hide_tween = create_tween()
	_idle_hide_tween.tween_property(idle_bubble_panel, "modulate:a", 0.0, 0.3)
	_idle_hide_tween.tween_callback(func():
		idle_bubble_panel.visible = false
		idle_bubble_label.text = ""
		_is_idle_speaking = false
	)

func _on_time_advanced(_days: int, _current_period: String) -> void:
	_check_story_button_visibility()
	
	# After time advance, check if we need to hide buttons (e.g. story triggered immediately)
	var main_scene = get_tree().root.get_node_or_null("MainScene")
	if main_scene and main_scene.get("_story_mode_active"):
		set_ui_hidden(true)

func _check_story_button_visibility() -> void:
	_concern_mode_available = _compute_concern_mode_available()
	refresh_chat_button_state()
	if _bubble_tween and _bubble_tween.is_valid() and (not _chat_button_available or _is_ui_hidden):
		_bubble_tween.kill()
	
func set_ui_hidden(is_hidden: bool) -> void:
	_is_ui_hidden = is_hidden
	var active_chat_button := chat_button
	
	if _ui_tween:
		_ui_tween.kill()
	_ui_tween = create_tween()
	
	var target_a = 0.0 if is_hidden else 1.0
	
	if active_chat_button:
		_ui_tween.parallel().tween_property(active_chat_button, "modulate:a", target_a, 0.3)
	if idle_bubble_panel and idle_bubble_panel.visible:
		_ui_tween.parallel().tween_property(idle_bubble_panel, "modulate:a", target_a, 0.3)
		
	if is_hidden:
		_ui_tween.tween_callback(func():
			if active_chat_button: active_chat_button.visible = false
			if idle_bubble_panel: 
				idle_bubble_panel.visible = false
				_is_idle_speaking = false
		)
	else:
		if active_chat_button:
			active_chat_button.visible = _chat_button_available
			active_chat_button.modulate.a = 1.0
		refresh_chat_button_state()

# 如果有特殊的环境切换需求可以在这里实现
func play_environment_anim(anim_name: String) -> void:
	# 例如根据白天黑夜改变颜色
	if anim_name == "night":
		bg_rect.modulate = Color(0.5, 0.5, 0.7)
	elif anim_name == "day":
		bg_rect.modulate = Color(1, 1, 1)

func _play_bubble_anim() -> void:
	if _bubble_tween:
		_bubble_tween.kill()

	if is_instance_valid(chat_button):
		chat_button.pivot_offset = chat_button.size / 2.0

	_bubble_tween = create_tween().set_loops()

	if is_instance_valid(chat_button):
		_bubble_tween.tween_property(chat_button, "position:y", _base_bubble_pos.y - 10.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_bubble_tween.parallel().tween_property(chat_button, "scale", Vector2(1.03, 1.03), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_bubble_tween.tween_property(chat_button, "position:y", _base_bubble_pos.y, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_bubble_tween.parallel().tween_property(chat_button, "scale", Vector2(1.0, 1.0), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
	if _interact_bubble_tween:
		_interact_bubble_tween.kill()
