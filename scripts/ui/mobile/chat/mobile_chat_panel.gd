extends Control

signal back_requested

@onready var back_btn: Button = $Panel/VBox/TopBar/BackBtn
@onready var title_label: Label = $Panel/VBox/TopBar/Title
@onready var message_list: VBoxContainer = $Panel/VBox/ScrollContainer/Margin/MessageList
@onready var input_edit: LineEdit = $Panel/VBox/BottomBar/InputEdit
@onready var send_btn: Button = $Panel/VBox/BottomBar/SendBtn
@onready var scroll_container: ScrollContainer = $Panel/VBox/ScrollContainer
@onready var deepseek_client = $DeepSeekClient

var current_char_id: String = ""
var char_profile: CharacterProfile = null
var chat_history: Array = []

func _ready() -> void:
    back_btn.pressed.connect(_on_back_pressed)
    send_btn.pressed.connect(_on_send_pressed)
    input_edit.text_submitted.connect(_on_input_submitted)
    
    if deepseek_client:
        deepseek_client.chat_request_completed.connect(_on_ai_response)
        deepseek_client.chat_request_failed.connect(_on_ai_error)

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
        for part in parts:
            part = part.strip_edges()
            if part != "":
                _add_message_bubble("char", part)
                _save_message_to_history("char", part)
                
        # Scroll to bottom
        await get_tree().create_timer(0.1).timeout
        scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value
    else:
        _add_message_bubble("system", "消息发送失败...")

func _on_ai_error(err_msg: String) -> void:
    input_edit.editable = true
    send_btn.disabled = false
    _add_message_bubble("system", "网络错误: " + err_msg)

func _add_message_bubble(speaker: String, text: String) -> void:
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
        style.bg_color = Color(0.6, 0.8, 1.0, 1.0)
        hbox.alignment = HORIZONTAL_ALIGNMENT_RIGHT
    elif speaker == "char":
        style.bg_color = Color(1, 1, 1, 1)
        hbox.alignment = HORIZONTAL_ALIGNMENT_LEFT
    else:
        style.bg_color = Color(0.9, 0.9, 0.9, 1)
        hbox.alignment = HORIZONTAL_ALIGNMENT_CENTER
        
    bubble_panel.add_theme_stylebox_override("panel", style)
    
    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 12)
    margin.add_theme_constant_override("margin_right", 12)
    margin.add_theme_constant_override("margin_top", 10)
    margin.add_theme_constant_override("margin_bottom", 10)
    
    var label = RichTextLabel.new()
    label.bbcode_enabled = true
    label.text = "[color=black]%s[/color]" % text
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
    
    if speaker == "char":
        var avatar = TextureRect.new()
        avatar.custom_minimum_size = Vector2(40, 40)
        avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        # You can set character avatar texture here if available
        # avatar.texture = load("res://assets/images/portraits/...")
        
        # Temp placeholder
        var av_panel = Panel.new()
        av_panel.custom_minimum_size = Vector2(40, 40)
        var av_style = StyleBoxFlat.new()
        av_style.bg_color = Color(0.8, 0.5, 0.5, 1)
        av_style.corner_radius_top_left = 20
        av_style.corner_radius_top_right = 20
        av_style.corner_radius_bottom_left = 20
        av_style.corner_radius_bottom_right = 20
        av_panel.add_theme_stylebox_override("panel", av_style)
        
        hbox.add_child(av_panel)
        hbox.add_child(bubble_panel)
    elif speaker == "player":
        hbox.add_child(bubble_panel)
        
        var av_panel = Panel.new()
        av_panel.custom_minimum_size = Vector2(40, 40)
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
        _add_message_bubble(msg.speaker, msg.text)

func _save_message_to_history(speaker: String, text: String) -> void:
    chat_history.append({
        "speaker": speaker,
        "text": text,
        "time": Time.get_datetime_string_from_system()
    })
    
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
