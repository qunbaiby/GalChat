extends Control

@onready var dialogue_layer = $DialogueLayer
@onready var name_label = $DialogueLayer/VBox/NameLabel if has_node("DialogueLayer/VBox/NameLabel") else null
@onready var rich_text_label = $DialogueLayer/VBox/RichTextLabel if has_node("DialogueLayer/VBox/RichTextLabel") else null
@onready var quick_option_layer = $QuickOptionLayer
@onready var input_layer = $InputLayer
@onready var history_button = $HistoryButton
@onready var end_chat_button = $EndChatButton

@onready var input_field = $InputLayer/HBoxContainer/InputField if has_node("InputLayer/HBoxContainer/InputField") else null
@onready var char_count_label = $InputLayer/HBoxContainer/InputField/CharCountLabel if has_node("InputLayer/HBoxContainer/InputField/CharCountLabel") else null
@onready var send_btn = $InputLayer/HBoxContainer/SendButton if has_node("InputLayer/HBoxContainer/SendButton") else null
@onready var gift_btn = $InputLayer/HBoxContainer/GiftButton if has_node("InputLayer/HBoxContainer/GiftButton") else null
@onready var quick_options_container = $QuickOptionLayer/ScrollContainer/QuickOptions if has_node("QuickOptionLayer/ScrollContainer/QuickOptions") else null

signal dialogue_finished
signal panel_clicked(event: InputEvent)
signal message_sent(text: String)

var _typewriter_tween: Tween = null
var audio_player: AudioStreamPlayer = null
var current_text: String = ""
var is_playing_single_line: bool = false
var character_id: String = ""
var is_story_mode: bool = false

const MAX_CHARS = 200

func _ready():
    gui_input.connect(_on_gui_input)
    if dialogue_layer:
        dialogue_layer.gui_input.connect(_on_gui_input)
    mouse_filter = Control.MOUSE_FILTER_STOP
    
    if end_chat_button:
        end_chat_button.pressed.connect(_on_end_chat_pressed)
    
    if GameDataManager.config.voice_enabled:
        TTSManager.tts_success.connect(_on_tts_success)
        audio_player = AudioStreamPlayer.new()
        add_child(audio_player)

    # Determine if in story mode
    var p = get_parent()
    var in_story = false
    while p:
        if p.name == "ChatScene" or "Story" in p.name:
            in_story = true
            break
        p = p.get_parent()
    set_story_mode(in_story)

    # Input Field logic
    if input_field:
        input_field.text_changed.connect(_on_input_text_changed)
        input_field.gui_input.connect(_on_input_gui_input)
        _update_char_count()

    # Gift Button logic
    if gift_btn:
        if not gift_btn.pressed.is_connected(_on_gift_pressed):
            gift_btn.pressed.connect(_on_gift_pressed)
        
    if quick_options_container:
        quick_options_container.child_entered_tree.connect(_on_quick_option_added)

func set_story_mode(enabled: bool) -> void:
    is_story_mode = enabled
    if gift_btn:
        gift_btn.visible = !is_story_mode
        if is_story_mode:
            if gift_btn.pressed.is_connected(_on_gift_pressed):
                gift_btn.pressed.disconnect(_on_gift_pressed)
        else:
            if not gift_btn.pressed.is_connected(_on_gift_pressed):
                gift_btn.pressed.connect(_on_gift_pressed)

func _on_gift_pressed():
    var gift_popup_path = "res://scenes/ui/gift/gift_panel.tscn"
    if FileAccess.file_exists(gift_popup_path):
        var gift_popup_scene = load(gift_popup_path)
        if gift_popup_scene:
            var popup = gift_popup_scene.instantiate()
            add_child(popup)
            # Try to connect the gift_sent signal to main_scene/dialogue_manager if needed
            var parent = get_parent()
            while parent:
                if parent.has_method("_on_gift_sent"):
                    popup.gift_sent.connect(parent._on_gift_sent)
                    break
                parent = parent.get_parent()
            
            if popup.has_method("show_panel"):
                popup.show_panel()
    else:
        print("[DialoguePanel] Gift panel scene not found at ", gift_popup_path)

func _on_quick_option_added(node: Node):
    if node is Button:
        # Style override for dynamic options to match the visual novel style reference
        node.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
        node.add_theme_color_override("font_hover_color", Color(0.9, 0.9, 1.0, 1.0))
        node.add_theme_color_override("font_pressed_color", Color(0.7, 0.7, 0.8, 1.0))
        node.add_theme_font_size_override("font_size", 20)
        
        # We need a dark gradient/translucent bar for the options background
        var sb_normal = StyleBoxFlat.new()
        sb_normal.bg_color = Color(0.1, 0.05, 0.15, 0.8) # Dark purplish
        sb_normal.border_width_top = 1
        sb_normal.border_width_bottom = 1
        sb_normal.border_color = Color(0.4, 0.3, 0.6, 0.5)
        sb_normal.corner_radius_top_left = 2
        sb_normal.corner_radius_top_right = 2
        sb_normal.corner_radius_bottom_right = 2
        sb_normal.corner_radius_bottom_left = 2
        sb_normal.content_margin_left = 100.0
        sb_normal.content_margin_right = 100.0
        sb_normal.content_margin_top = 12.0
        sb_normal.content_margin_bottom = 12.0
        
        var sb_hover = sb_normal.duplicate()
        sb_hover.bg_color = Color(0.2, 0.1, 0.25, 0.9)
        
        var sb_pressed = sb_normal.duplicate()
        sb_pressed.bg_color = Color(0.05, 0.02, 0.1, 0.9)
        
        var sb_focus = StyleBoxEmpty.new()
        
        node.add_theme_stylebox_override("normal", sb_normal)
        node.add_theme_stylebox_override("hover", sb_hover)
        node.add_theme_stylebox_override("pressed", sb_pressed)
        node.add_theme_stylebox_override("focus", sb_focus)
        
        node.mouse_entered.connect(func():
            var t = create_tween()
            t.tween_property(node, "scale", Vector2(1.02, 1.02), 0.2).set_trans(Tween.TRANS_SINE)
        )
        node.mouse_exited.connect(func():
            var t = create_tween()
            t.tween_property(node, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE)
        )
        node.button_down.connect(func():
            var t = create_tween()
            t.tween_property(node, "scale", Vector2(0.98, 0.98), 0.1).set_trans(Tween.TRANS_SINE)
        )
        node.button_up.connect(func():
            var t = create_tween()
            t.tween_property(node, "scale", Vector2(1.02, 1.02), 0.1).set_trans(Tween.TRANS_SINE)
        )
        node.pivot_offset = node.size / 2.0
        node.resized.connect(func(): node.pivot_offset = node.size / 2.0)

func _on_input_text_changed():
    if not input_field: return
    
    var text = input_field.text
    
    # Check if Enter was pressed (indicated by a newline character)
    if "\n" in text:
        if Input.is_key_pressed(KEY_SHIFT) and is_story_mode:
            # Allow newline in story mode with Shift
            pass
        else:
            # Remove the newline
            input_field.text = text.replace("\n", "")
            input_field.set_caret_column(input_field.text.length())
            # Trigger send message
            _send_message()
            return
            
    # Max chars check
    text = input_field.text
    if text.length() > MAX_CHARS:
        input_field.text = text.substr(0, MAX_CHARS)
        input_field.set_caret_column(MAX_CHARS)
        _play_beep_sound()

    _update_char_count()

func _update_char_count():
    if not input_field: return
    if char_count_label:
        char_count_label.text = "%d/%d" % [input_field.text.length(), MAX_CHARS]
        if input_field.text.length() >= MAX_CHARS:
            char_count_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
        else:
            char_count_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

func _play_beep_sound():
    # Simple beep logic using AudioStreamPlayer with a generated sine wave or just print if no asset
    print("[DialoguePanel] BEEP! Max characters reached.")

func _on_input_gui_input(event: InputEvent):
    pass

func _send_message():
    if not input_field: return
    
    var text = input_field.text.strip_edges()
    if text == "":
        return
        
    # 先发送信号，让 main_scene 和 dialogue_manager 能读取到 text
    message_sent.emit(text)
    send_btn.pressed.emit()
    
    # 发送后再清空输入框和禁用按钮
    input_field.text = ""
    _update_char_count()
    
    input_field.editable = false
    send_btn.disabled = true
    
    # Wait 0.5s to re-enable
    var t = get_tree().create_timer(0.5)
    t.timeout.connect(func():
        if is_instance_valid(input_field): input_field.editable = true
        if is_instance_valid(send_btn): send_btn.disabled = false
    )

func play_single_line(char_id: String, char_name: String, text: String, hide_input: bool = true):
    if text.strip_edges() == "":
        text = "（微笑着将单品递给了你，没有说话）"
    
    if audio_player:
        audio_player.stop()
    
    character_id = char_id
    if name_label: name_label.text = char_name
    current_text = text
    is_playing_single_line = true
    
    if hide_input:
        if quick_option_layer: quick_option_layer.hide()
        if input_layer: input_layer.hide()
        if history_button: history_button.hide()
        if end_chat_button: end_chat_button.hide()
    else:
        if quick_option_layer: quick_option_layer.show()
        if input_layer: input_layer.show()
        if history_button: history_button.show()
        if end_chat_button: end_chat_button.show()
    
    show()
    if dialogue_layer: dialogue_layer.show()
    _start_typewriter()

func _start_typewriter():
    if current_text.is_empty():
        _finish_single_line()
        return
        
    var display_text = current_text
    var color_regex_zh = RegEx.new()
    color_regex_zh.compile("（(.*?)）")
    display_text = color_regex_zh.sub(display_text, "[color=green]（$1）[/color]", true)
    var color_regex_en = RegEx.new()
    color_regex_en.compile("\\((.*?)\\)")
    display_text = color_regex_en.sub(display_text, "[color=green]($1)[/color]", true)
        
    # Center text per requirement
    display_text = "[center]" + display_text + "[/center]"
        
    if rich_text_label:
        rich_text_label.bbcode_enabled = true
        rich_text_label.text = display_text
        rich_text_label.visible_ratio = 0.0
        
        if _typewriter_tween:
            _typewriter_tween.kill()
        
        _typewriter_tween = create_tween()
        var dur = max(0.5, current_text.length() * 0.05)
        _typewriter_tween.tween_property(rich_text_label, "visible_ratio", 1.0, dur)
    
    if GameDataManager.config.voice_enabled:
        var tts_text = current_text
        var action_regex = RegEx.new()
        action_regex.compile("（.*?）|\\(.*?\\)|\\*.*?\\*|\\[.*?\\]|~.*?~")
        tts_text = action_regex.sub(tts_text, "", true).strip_edges()
        tts_text = tts_text.replace("*", "")
        
        if tts_text != "":
            var options = {}
            if GameDataManager.config.character_voice_types.has(character_id):
                options["voice_type"] = GameDataManager.config.character_voice_types[character_id]
            TTSManager.synthesize(tts_text, options)

func _on_tts_success(audio_stream: AudioStream, text: String):
    if audio_player and audio_stream:
        audio_player.stream = audio_stream
        audio_player.play()

func _on_gui_input(event: InputEvent):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if is_playing_single_line:
            _advance_dialogue()
            get_viewport().set_input_as_handled()
        else:
            panel_clicked.emit(event)

func _advance_dialogue():
    if _typewriter_tween and _typewriter_tween.is_running():
        _typewriter_tween.kill()
        if rich_text_label:
            rich_text_label.visible_ratio = 1.0
    else:
        _finish_single_line()

func _finish_single_line():
    is_playing_single_line = false
    hide()
    if audio_player:
        audio_player.stop()
    dialogue_finished.emit()

func _on_skip_pressed():
    if is_playing_single_line:
        _advance_dialogue()

func _on_end_chat_pressed():
    if is_playing_single_line:
        _finish_single_line()
