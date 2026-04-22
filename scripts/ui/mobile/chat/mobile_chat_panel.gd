extends Control

signal back_requested

@onready var back_btn: Button = $Panel/VBox/TopBar/BackBtn
@onready var title_label: Label = $Panel/VBox/TopBar/Title
@onready var voice_call_btn: TextureButton = $Panel/VBox/BottomArea/ActionRow/VoiceCallBtn/Btn
@onready var video_call_btn: TextureRect = $Panel/VBox/BottomArea/ActionRow/VideoBtn/Icon
@onready var message_list: VBoxContainer = $Panel/VBox/ScrollContainer/Margin/MessageList
@onready var input_edit: LineEdit = $Panel/VBox/BottomArea/InputRow/InputEdit
@onready var send_btn: Button = $Panel/VBox/BottomArea/InputRow/SendBtn
@onready var scroll_container: ScrollContainer = $Panel/VBox/ScrollContainer
@onready var deepseek_client = $DeepSeekClient

var doubao_tts = null
var audio_player: AudioStreamPlayer = null

var current_char_id: String = ""
var char_profile: CharacterProfile = null
var chat_history: Array = []
var voice_call_panel_instance = null
var is_voice_call_mode: bool = false
var video_call_panel_instance = null

func _ready() -> void:
	back_btn.pressed.connect(_on_back_pressed)
	send_btn.pressed.connect(_on_send_pressed)
	input_edit.text_submitted.connect(_on_input_submitted)
	voice_call_btn.pressed.connect(_on_voice_call_pressed)
	
	video_call_btn.mouse_filter = Control.MOUSE_FILTER_PASS
	video_call_btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_video_call_pressed()
	)
	
	if deepseek_client:
		deepseek_client.chat_request_completed.connect(_on_ai_response)
		deepseek_client.chat_request_failed.connect(_on_ai_error)
		
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	var tts_script = load("res://scripts/api/doubao_TTS_Service.gd")
	if tts_script:
		doubao_tts = tts_script.new()
		add_child(doubao_tts)
		
		# Load API keys from config
		if GameDataManager.config:
			doubao_tts.setup_auth(
				GameDataManager.config.doubao_app_id,
				GameDataManager.config.doubao_token
			)
			
		doubao_tts.tts_success.connect(_on_tts_success)
		doubao_tts.tts_failed.connect(_on_tts_failed)
		
func _on_tts_success(stream: AudioStream, _text: String) -> void:
	if audio_player:
		audio_player.stream = stream
		audio_player.play()

func _on_tts_failed(err_msg: String, _text: String) -> void:
	print("Mobile Chat TTS Failed: ", err_msg)

func setup(char_id: String) -> void:
	current_char_id = char_id
	
	# Load profile
	char_profile = CharacterProfile.new()
	char_profile.load_profile(char_id)
	
	title_label.text = char_profile.char_name
	
	# Load history
	_load_mobile_history()
	_render_history()

func _on_back_pressed() -> void:
	back_requested.emit()

func _on_voice_call_pressed() -> void:
	if voice_call_panel_instance == null:
		var VoiceCallObj = load("res://scenes/ui/mobile/chat/voice_call_panel.tscn")
		voice_call_panel_instance = VoiceCallObj.instantiate()
		add_child(voice_call_panel_instance)
		voice_call_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		voice_call_panel_instance.call_ended.connect(_on_voice_call_ended)
		voice_call_panel_instance.message_sent.connect(_on_voice_call_message_sent)
		
	voice_call_panel_instance.setup(current_char_id, char_profile)
	voice_call_panel_instance.show()
	is_voice_call_mode = true

func _on_voice_call_ended() -> void:
	if voice_call_panel_instance:
		voice_call_panel_instance.hide()
	is_voice_call_mode = false
	# Refresh history in case voice call added new messages
	_load_mobile_history()
	_render_history()

func _on_video_call_pressed() -> void:
	if video_call_panel_instance == null:
		var VideoCallObj = load("res://scenes/ui/mobile/chat/video_call_panel.tscn")
		video_call_panel_instance = VideoCallObj.instantiate()
		add_child(video_call_panel_instance)
		video_call_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		video_call_panel_instance.call_ended.connect(_on_video_call_ended)
		video_call_panel_instance.message_sent.connect(_on_voice_call_message_sent)
		
	video_call_panel_instance.setup(current_char_id, char_profile)
	
	# 可以根据场景设置不同的背景
	# video_call_panel_instance.set_background("res://assets/images/backgrounds/room_night.png")
	
	video_call_panel_instance.show()
	is_voice_call_mode = true

func _on_video_call_ended() -> void:
	if video_call_panel_instance:
		video_call_panel_instance.hide()
	is_voice_call_mode = false
	_load_mobile_history()
	_render_history()

func _on_voice_call_message_sent(text: String) -> void:
	_send_player_message(text)

func _on_send_pressed() -> void:
	var text = input_edit.text.strip_edges()
	if text == "": return
	
	input_edit.text = ""
	_send_player_message(text)

func _on_input_submitted(text: String) -> void:
	_on_send_pressed()

func _send_player_message(text: String) -> void:
	_add_message_bubble("player", text)
	_save_message_to_history("player", text)
	
	# Disable input while waiting
	input_edit.editable = false
	send_btn.disabled = true
	
	_request_ai_response(text)

func _request_ai_response(player_text: String) -> void:
	if not deepseek_client: return
	
	var system_prompt = GameDataManager.prompt_manager.build_system_prompt(char_profile, "mobile_chat", player_text, [])
	
	var messages = [{"role": "system", "content": system_prompt}]
	
	# Add recent history (last 10 messages)
	var recent = chat_history.slice(-10)
	for msg in recent:
		var role = "user" if msg.speaker == "player" else "assistant"
		messages.append({"role": role, "content": msg.text})
		
	# messages.append({"role": "user", "content": player_text}) # Already in recent
	
	deepseek_client.call_chat_api_non_stream(messages)

func _on_ai_response(response: Dictionary) -> void:
	input_edit.editable = true
	send_btn.disabled = false
	
	if response.has("choices") and response["choices"].size() > 0:
		var content = response["choices"][0].get("message", {}).get("content", "")
		
		# Split by [SPLIT] if any
		var parts = content.split("[SPLIT]")
		
		if is_voice_call_mode:
			if voice_call_panel_instance and voice_call_panel_instance.visible:
				voice_call_panel_instance.add_character_message(content)
			elif video_call_panel_instance and video_call_panel_instance.visible:
				video_call_panel_instance.add_character_message(content)
			# 同时也保存在后台的历史记录中
			for part in parts:
				part = part.strip_edges()
				if part != "":
					_save_message_to_history("char", part)
		else:
			for part in parts:
				part = part.strip_edges()
				if part != "":
					# 20% chance to be a voice message
					var is_voice = randf() < 0.2
					var duration = max(1, int(part.length() / 4.0)) if is_voice else 0
					
					_add_message_bubble("char", part, is_voice, duration)
					_save_message_to_history("char", part, is_voice, duration)
					
			# Scroll to bottom
			await get_tree().create_timer(0.1).timeout
			scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value
	else:
		_add_message_bubble("system", "消息发送失败...")

func _on_ai_error(err_msg: String) -> void:
	input_edit.editable = true
	send_btn.disabled = false
	_add_message_bubble("system", "网络错误: " + err_msg)

func _add_message_bubble(speaker: String, text: String, is_voice: bool = false, duration: int = 0, msg: Dictionary = {}) -> void:
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var bubble_panel = PanelContainer.new()
	bubble_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if speaker == "char" else Control.SIZE_SHRINK_END
	
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15 if speaker == "player" else 0
	style.corner_radius_bottom_right = 15 if speaker == "char" else 0
	
	if speaker == "player":
		style.bg_color = Color(0.54, 0.35, 0.96, 1) # Purple from reference
		hbox.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	elif speaker == "char":
		style.bg_color = Color(0.2, 0.2, 0.2, 1) if is_voice else Color(1, 1, 1, 1)
		hbox.alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		style.bg_color = Color(0.9, 0.9, 0.9, 1)
		hbox.alignment = HORIZONTAL_ALIGNMENT_CENTER
		
	bubble_panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	
	if is_voice:
		var voice_hbox = HBoxContainer.new()
		voice_hbox.alignment = HORIZONTAL_ALIGNMENT_CENTER
		voice_hbox.add_theme_constant_override("separation", 5)
		
		var voice_icon = Label.new()
		voice_icon.text = "•))"
		voice_icon.add_theme_font_size_override("font_size", 16)
		voice_icon.add_theme_color_override("font_color", Color.WHITE)
			
		var dur_label = Label.new()
		dur_label.text = str(duration) + "\""
		dur_label.add_theme_font_size_override("font_size", 16)
		dur_label.add_theme_color_override("font_color", Color.WHITE)
			
		voice_hbox.add_child(voice_icon)
		voice_hbox.add_child(dur_label)
		margin.add_child(voice_hbox)
		
		var min_w = 80
		var max_w = 180 # 限制语音气泡的最大宽度，为右侧转文字按钮留出空间
		var calc_w = clamp(min_w + duration * 8, min_w, max_w)
		margin.custom_minimum_size = Vector2(calc_w, 40)
	else:
		var label = RichTextLabel.new()
		label.bbcode_enabled = true
		if speaker == "player":
			label.text = "[color=white]%s[/color]" % text
		else:
			label.text = "[color=#333333]%s[/color]" % text
		label.fit_content = true
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(50, 0) # Give it a min size to wrap properly
		
		# Calculate max width (approximate)
		var max_w = 260
		label.custom_minimum_size.x = min(max_w, label.get_theme_font("normal_font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 20)
		if label.custom_minimum_size.x > max_w:
			label.custom_minimum_size.x = max_w
			
		label.add_theme_font_size_override("normal_font_size", 14)
		margin.add_child(label)
	
	bubble_panel.add_child(margin)
	
	var content_vbox = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL if speaker == "system" else Control.SIZE_SHRINK_BEGIN
	
	var bubble_row = HBoxContainer.new()
	bubble_row.add_theme_constant_override("separation", 10)
	
	if speaker == "char":
		var avatar = TextureRect.new()
		avatar.custom_minimum_size = Vector2(40, 40)
		avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		
		var avatar_path = ""
		if char_profile:
			avatar_path = char_profile.avatar
			
		if avatar_path != "" and ResourceLoader.exists(avatar_path):
			avatar.texture = load(avatar_path)
			
			# Make avatar round
			var av_panel = PanelContainer.new()
			av_panel.custom_minimum_size = Vector2(40, 40)
			av_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			var av_style = StyleBoxFlat.new()
			av_style.bg_color = Color(1, 1, 1, 1) # Must be opaque for clip mask to work
			av_style.corner_radius_top_left = 20
			av_style.corner_radius_top_right = 20
			av_style.corner_radius_bottom_left = 20
			av_style.corner_radius_bottom_right = 20
			av_panel.add_theme_stylebox_override("panel", av_style)
			av_panel.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
			
			av_panel.add_child(avatar)
			hbox.add_child(av_panel)
		else:
			var av_panel = Panel.new()
			av_panel.custom_minimum_size = Vector2(40, 40)
			av_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			var av_style = StyleBoxFlat.new()
			av_style.bg_color = Color(0.8, 0.5, 0.5, 1)
			av_style.corner_radius_top_left = 20
			av_style.corner_radius_top_right = 20
			av_style.corner_radius_bottom_left = 20
			av_style.corner_radius_bottom_right = 20
			av_panel.add_theme_stylebox_override("panel", av_style)
			hbox.add_child(av_panel)
			
		if is_voice:
			bubble_row.add_child(bubble_panel)
			
			var transcribe_btn = Button.new()
			transcribe_btn.text = "转文字"
			transcribe_btn.add_theme_font_size_override("font_size", 12)
			transcribe_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			
			var transcribe_style = StyleBoxFlat.new()
			transcribe_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
			transcribe_style.corner_radius_top_left = 12
			transcribe_style.corner_radius_top_right = 12
			transcribe_style.corner_radius_bottom_left = 12
			transcribe_style.corner_radius_bottom_right = 12
			transcribe_style.content_margin_left = 8
			transcribe_style.content_margin_right = 8
			transcribe_style.content_margin_top = 4
			transcribe_style.content_margin_bottom = 4
			transcribe_btn.add_theme_stylebox_override("normal", transcribe_style)
			transcribe_btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
			# transcribe_btn.hide() # 现在让它一直显示
			
			var red_dot = Label.new()
			red_dot.text = "•"
			red_dot.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
			red_dot.add_theme_font_size_override("font_size", 24)
			red_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			
			bubble_row.add_child(red_dot)
			bubble_row.add_child(transcribe_btn)
			
			content_vbox.add_child(bubble_row)
			
			var transcribed_panel = PanelContainer.new()
			var t_style = StyleBoxFlat.new()
			t_style.bg_color = Color(0.2, 0.2, 0.2, 1)
			t_style.corner_radius_top_left = 4
			t_style.corner_radius_top_right = 15
			t_style.corner_radius_bottom_left = 15
			t_style.corner_radius_bottom_right = 15
			transcribed_panel.add_theme_stylebox_override("panel", t_style)
			transcribed_panel.hide()
			
			var t_margin = MarginContainer.new()
			t_margin.add_theme_constant_override("margin_left", 16)
			t_margin.add_theme_constant_override("margin_right", 16)
			t_margin.add_theme_constant_override("margin_top", 12)
			t_margin.add_theme_constant_override("margin_bottom", 12)
			
			var t_label = RichTextLabel.new()
			t_label.bbcode_enabled = true
			t_label.text = "[color=#dddddd]%s[/color]" % text
			t_label.fit_content = true
			t_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			t_label.custom_minimum_size = Vector2(50, 0)
			
			var t_max_w = 260
			t_label.custom_minimum_size.x = min(t_max_w, t_label.get_theme_font("normal_font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 20)
			if t_label.custom_minimum_size.x > t_max_w:
				t_label.custom_minimum_size.x = t_max_w
				
			t_label.add_theme_font_size_override("normal_font_size", 14)
			
			t_margin.add_child(t_label)
			transcribed_panel.add_child(t_margin)
			
			content_vbox.add_child(transcribed_panel)
			
			var is_read = msg.get("is_read", false)
			
			if not is_read:
				red_dot.show()
			else:
				red_dot.hide()
			
			transcribe_btn.pressed.connect(func():
				transcribed_panel.visible = not transcribed_panel.visible
				if transcribed_panel.visible:
					transcribe_btn.hide()
				if not is_read:
					red_dot.hide()
					_mark_message_read(text)
					
				# 延迟一帧等待布局更新，然后再滚动到底部
				await get_tree().process_frame
				scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value
			)
			
			bubble_panel.mouse_filter = Control.MOUSE_FILTER_PASS
			bubble_panel.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					if not is_read:
						red_dot.hide() # 点击播放也会隐藏小红点
						_mark_message_read(text)
					_play_voice_message(text)
			)
			
			hbox.add_child(content_vbox)
		else:
			hbox.add_child(bubble_panel)
	elif speaker == "player":
		hbox.add_child(bubble_panel)
		
		var av_panel = Panel.new()
		av_panel.custom_minimum_size = Vector2(40, 40)
		av_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var av_style = StyleBoxFlat.new()
		av_style.bg_color = Color(0.5, 0.8, 0.5, 1)
		av_style.corner_radius_top_left = 20
		av_style.corner_radius_top_right = 20
		av_style.corner_radius_bottom_left = 20
		av_style.corner_radius_bottom_right = 20
		av_panel.add_theme_stylebox_override("panel", av_style)
		
		hbox.add_child(av_panel)
	else:
		hbox.add_child(bubble_panel)
		
	message_list.add_child(hbox)
	
	# Scroll down
	await get_tree().process_frame
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

func _play_voice_message(text: String) -> void:
	if not doubao_tts:
		return
		
	if GameDataManager.config.voice_enabled:
		var v_type = "ICL_zh_female_bingruoshaonv_tob"
		if GameDataManager.config.character_voice_types.has(current_char_id):
			v_type = GameDataManager.config.character_voice_types[current_char_id]
			
		doubao_tts.synthesize(text, {"voice_type": v_type})

func _load_mobile_history() -> void:
	chat_history.clear()
	for child in message_list.get_children():
		child.queue_free()
		
	var path = "user://saves/%s/mobile_chat_history.json" % current_char_id
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var content = file.get_as_text()
		var json = JSON.new()
		if json.parse(content) == OK and json.data is Array:
			chat_history = json.data

func _render_history() -> void:
	for msg in chat_history:
		var is_voice = msg.get("is_voice", false)
		var duration = int(msg.get("duration", 0))
		_add_message_bubble(msg.speaker, msg.text, is_voice, duration, msg)

func _mark_message_read(text: String) -> void:
	var changed = false
	for msg in chat_history:
		if msg.text == text and not msg.get("is_read", false):
			msg["is_read"] = true
			changed = true
			
	if changed:
		var dir_path = "user://saves/%s" % current_char_id
		if not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.make_dir_recursive_absolute(dir_path)
			
		var path = "%s/mobile_chat_history.json" % dir_path
		var file = FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(chat_history, "\t"))

func _save_message_to_history(speaker: String, text: String, is_voice: bool = false, duration: int = 0) -> void:
	var new_msg = {
		"speaker": speaker,
		"text": text,
		"time": Time.get_datetime_string_from_system(),
		"is_voice": is_voice,
		"duration": duration,
		"is_read": false
	}
	chat_history.append(new_msg)
	
	var dir_path = "user://saves/%s" % current_char_id
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
		
	var path = "%s/mobile_chat_history.json" % dir_path
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(chat_history, "\t"))

func show_panel() -> void:
	show()
	position.x = size.x
	modulate.a = 0.0
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	
	# Scroll to bottom when shown
	await get_tree().create_timer(0.1).timeout
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

func hide_panel() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:x", size.x, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(self.hide)
