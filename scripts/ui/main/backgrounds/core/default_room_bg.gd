extends "res://scripts/ui/main/backgrounds/core/bg_scene_base.gd"

@onready var bg_rect: TextureRect = $background
@onready var story_button: Button = $StoryButton
@onready var interact_trigger_button: Button = $InteractTriggerButton

var _base_bubble_pos := Vector2.ZERO
var _bubble_tween: Tween
var _base_interact_pos := Vector2.ZERO
var _interact_bubble_tween: Tween
var _ui_tween: Tween
var _is_ui_hidden := false

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
	
	if interact_trigger_button:
		_base_interact_pos = interact_trigger_button.position

	if story_button:
		_base_bubble_pos = story_button.position
		_check_story_button_visibility()
		if GameDataManager.story_time_manager:
			GameDataManager.story_time_manager.time_advanced.connect(_on_time_advanced)

	_play_bubble_anim()
	
	# Initial UI state check
	var main_scene = get_tree().root.get_node_or_null("MainScene")
	if main_scene and main_scene.get("chat_scene_instance") and main_scene.chat_scene_instance.visible:
		set_ui_hidden(true)
	elif main_scene and main_scene.get("_story_mode_active"):
		set_ui_hidden(true)
		
	_setup_idle_quote_bubble()

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
	if _is_idle_speaking or _is_ui_hidden:
		return
		
	if not idle_bubble_panel or not idle_bubble_label:
		push_warning("闲聊气泡未配置: 请在场景中添加 IdleQuoteBubble 节点及其子节点 Label")
		return
		
	var deepseek_client = get_tree().root.get_node_or_null("MainScene/DeepSeekClient")
	if not deepseek_client:
		return
		
	_is_idle_speaking = true
	
	if not deepseek_client.is_connected("idle_quote_completed", _on_idle_quote_completed):
		deepseek_client.idle_quote_completed.connect(_on_idle_quote_completed)
	if not deepseek_client.is_connected("idle_quote_failed", _on_idle_quote_failed):
		deepseek_client.idle_quote_failed.connect(_on_idle_quote_failed)
		
	deepseek_client.send_idle_quote_generation(GameDataManager.profile.current_character_id)

func _on_idle_quote_completed(quote: String) -> void:
	var deepseek_client = get_tree().root.get_node_or_null("MainScene/DeepSeekClient")
	if deepseek_client:
		deepseek_client.idle_quote_completed.disconnect(_on_idle_quote_completed)
		deepseek_client.idle_quote_failed.disconnect(_on_idle_quote_failed)
	show_idle_quote_text(quote)

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

	idle_bubble_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	idle_bubble_label.custom_minimum_size.x = 0
	idle_bubble_label.text = quote

	idle_bubble_panel.size = Vector2.ZERO
	var panel_min_size = idle_bubble_panel.get_combined_minimum_size()
	var max_panel_width = 320.0

	if panel_min_size.x > max_panel_width:
		idle_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var stylebox = idle_bubble_panel.get_theme_stylebox("panel")
		var padding_x = 40.0
		if stylebox is StyleBoxFlat:
			padding_x = stylebox.content_margin_left + stylebox.content_margin_right
		idle_bubble_label.custom_minimum_size.x = max_panel_width - padding_x

		idle_bubble_panel.size = Vector2.ZERO
		panel_min_size = idle_bubble_panel.get_combined_minimum_size()

	idle_bubble_panel.size = panel_min_size
	idle_bubble_panel.position = _idle_bubble_anchor - panel_min_size / 2.0

	idle_bubble_label.visible_ratio = 0.0
	idle_bubble_panel.modulate.a = 0.0
	idle_bubble_panel.visible = true

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
	var deepseek_client = get_tree().root.get_node_or_null("MainScene/DeepSeekClient")
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
	if idle_audio_player and audio_stream:
		idle_audio_player.stream = audio_stream
		idle_audio_player.play()

func _on_idle_tts_failed(err_msg: String, text: String) -> void:
	if text != _current_idle_text:
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
	if not is_instance_valid(story_button): return
	if not GameDataManager.story_time_manager: return

	if _is_ui_hidden:
		story_button.visible = false
		if _bubble_tween and _bubble_tween.is_valid():
			_bubble_tween.kill()
		return
	
	var date_dict = GameDataManager.story_time_manager.get_current_date_dict()
	var weekday = date_dict.weekday
	var current_hour = GameDataManager.story_time_manager.current_hour
	
	var should_show = false
	# 周末（0, 6）或者周五晚（20点及以后）才有概率出现心事
	if weekday == 0 or weekday == 6 or (weekday == 5 and current_hour >= 20):
		var current_day_offset = GameDataManager.story_time_manager.current_day_offset
		var rng = RandomNumberGenerator.new()
		rng.seed = hash(str(current_day_offset) + "_story_button")
		# 60%概率出现
		if rng.randf() < 0.6:
			should_show = true
			
	story_button.visible = should_show
	if should_show:
		story_button.modulate.a = 1.0
	
	if should_show:
		if not _bubble_tween or not _bubble_tween.is_valid():
			_play_bubble_anim()
	else:
		if _bubble_tween and _bubble_tween.is_valid():
			_bubble_tween.kill()
	
func set_ui_hidden(is_hidden: bool) -> void:
	_is_ui_hidden = is_hidden
	var story_button = get_node_or_null("StoryButton")
	var interact_button = get_node_or_null("InteractTriggerButton")
	
	if _ui_tween:
		_ui_tween.kill()
	_ui_tween = create_tween()
	
	var target_a = 0.0 if is_hidden else 1.0
	
	if story_button:
		_ui_tween.parallel().tween_property(story_button, "modulate:a", target_a, 0.3)
	if interact_button:
		_ui_tween.parallel().tween_property(interact_button, "modulate:a", target_a, 0.3)
	if idle_bubble_panel and idle_bubble_panel.visible:
		_ui_tween.parallel().tween_property(idle_bubble_panel, "modulate:a", target_a, 0.3)
		
	if is_hidden:
		_ui_tween.tween_callback(func():
			if story_button: story_button.visible = false
			if interact_button: interact_button.visible = false
			if idle_bubble_panel: 
				idle_bubble_panel.visible = false
				_is_idle_speaking = false
		)
	else:
		if story_button:
			story_button.visible = false
			story_button.modulate.a = 1.0
		if interact_button:
			interact_button.visible = true
			interact_button.modulate.a = 1.0
		_check_story_button_visibility()

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

	if is_instance_valid(story_button):
		story_button.pivot_offset = story_button.size / 2.0

	_bubble_tween = create_tween().set_loops()

	if is_instance_valid(story_button):
		# 上浮与放大
		_bubble_tween.tween_property(story_button, "position:y", _base_bubble_pos.y - 12.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_bubble_tween.parallel().tween_property(story_button, "scale", Vector2(1.05, 1.05), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# 下落与缩小还原
		_bubble_tween.tween_property(story_button, "position:y", _base_bubble_pos.y, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_bubble_tween.parallel().tween_property(story_button, "scale", Vector2(1.0, 1.0), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
	if _interact_bubble_tween:
		_interact_bubble_tween.kill()
		
	if is_instance_valid(interact_trigger_button):
		interact_trigger_button.pivot_offset = interact_trigger_button.size / 2.0
		
		_interact_bubble_tween = create_tween().set_loops()
		# 错开动画时间，使用不同的初始延迟或者不同的周期
		_interact_bubble_tween.tween_property(interact_trigger_button, "position:y", _base_interact_pos.y - 10.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_interact_bubble_tween.parallel().tween_property(interact_trigger_button, "scale", Vector2(1.03, 1.03), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
		_interact_bubble_tween.tween_property(interact_trigger_button, "position:y", _base_interact_pos.y, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_interact_bubble_tween.parallel().tween_property(interact_trigger_button, "scale", Vector2(1.0, 1.0), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
