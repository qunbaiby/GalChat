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

    # 清空场景里用于编辑器预览的占位文案，避免事件触发前短暂闪出默认文本。
    if name_label:
        name_label.text = ""
    if rich_text_label:
        rich_text_label.text = ""
    
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

func set_story_mode(enabled: bool) -> void:
    is_story_mode = enabled
    if is_story_mode and end_chat_button:
        end_chat_button.hide()
    elif not is_story_mode and end_chat_button:
        end_chat_button.show()

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
        # 修复需求：即使是 hide_input == true 的固定单句对话，如果处于故事模式，依然隐藏结束按钮
        if end_chat_button:
            if is_story_mode:
                end_chat_button.hide()
            else:
                end_chat_button.hide() # hide_input 状态下本身就不该显示，保持隐藏
    else:
        if quick_option_layer: quick_option_layer.show()
        if input_layer: input_layer.show()
        if history_button: history_button.show()
        # 修复需求：自由对话模式下，如果在故事模式中也隐藏结束按钮
        if end_chat_button:
            if is_story_mode:
                end_chat_button.hide()
            else:
                end_chat_button.show()
    
    show()
    if dialogue_layer: dialogue_layer.show()
    _start_typewriter()

func _start_typewriter():
    if current_text.is_empty():
        _finish_single_line()
        return
        
    var display_text = current_text
    
    # 强制清理：只保留最开头的一个动作描述，移除其余所有动作描述
    var extract_regex = RegEx.new()
    extract_regex.compile("（.*?）|\\(.*?\\)")
    var matches = extract_regex.search_all(display_text)
    if matches.size() > 0:
        var first_action = matches[0].get_string()
        var no_action_text = extract_regex.sub(display_text, "", true).strip_edges()
        display_text = first_action + " " + no_action_text
        current_text = display_text # Update current_text so TTS text also uses the cleaned version
        
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
