extends Control

@onready var dialogue_layer = $DialogueLayer
@onready var name_label = $DialogueLayer/NameLabel
@onready var rich_text_label = $DialogueLayer/RichTextLabel
@onready var quick_option_layer = $QuickOptionLayer
@onready var input_layer = $InputLayer
@onready var history_button = $DialogueLayer/HistoryButton
@onready var end_chat_button = $DialogueLayer/EndChatButton

signal dialogue_finished
signal panel_clicked(event: InputEvent)

var _typewriter_tween: Tween = null
var doubao_tts = null
var audio_player: AudioStreamPlayer = null
var current_text: String = ""
var is_playing_single_line: bool = false
var character_id: String = ""

func _ready():
    gui_input.connect(_on_gui_input)
    dialogue_layer.gui_input.connect(_on_gui_input)
    # 使得整个面板能够接收鼠标事件
    mouse_filter = Control.MOUSE_FILTER_STOP
    
    # 隐藏不需要的按钮，或者绑定默认事件
    end_chat_button.pressed.connect(_on_end_chat_pressed)
    
    # 初始化 TTS
    if GameDataManager.config.voice_enabled:
        var tts_script = load("res://scripts/api/doubao_TTS_Service.gd")
        if tts_script:
            doubao_tts = tts_script.new()
            add_child(doubao_tts)
            doubao_tts.tts_success.connect(_on_tts_success)
            doubao_tts.setup_auth(GameDataManager.config.doubao_app_id, GameDataManager.config.doubao_token, GameDataManager.config.doubao_cluster)
            
            audio_player = AudioStreamPlayer.new()
            add_child(audio_player)

# 供外部调用，播放单句台词
func play_single_line(char_id: String, char_name: String, text: String, hide_input: bool = true):
    if text.strip_edges() == "":
        text = "（微笑着将单品递给了你，没有说话）"
    
    if audio_player:
        audio_player.stop()
    
    character_id = char_id
    name_label.text = char_name
    current_text = text
    is_playing_single_line = true
    
    if hide_input:
        quick_option_layer.hide()
        input_layer.hide()
        # 隐藏结束对话等按钮，只需点击屏幕即可
        history_button.hide()
        end_chat_button.hide()
    else:
        quick_option_layer.show()
        input_layer.show()
        history_button.show()
        end_chat_button.show()
    
    show()
    dialogue_layer.show() # 显式确保黑色对话框背景也显示
    _start_typewriter()

func _start_typewriter():
    if current_text.is_empty():
        _finish_single_line()
        return
        
    rich_text_label.text = current_text
    rich_text_label.visible_ratio = 0.0
    
    if _typewriter_tween:
        _typewriter_tween.kill()
    
    _typewriter_tween = create_tween()
    var dur = max(0.5, current_text.length() * 0.05)
    _typewriter_tween.tween_property(rich_text_label, "visible_ratio", 1.0, dur)
    
    if doubao_tts and GameDataManager.config.voice_enabled:
        # 去掉动作描写括号()和（）用于发音
        var tts_text = current_text
        var action_regex = RegEx.new()
        action_regex.compile("（.*?）|\\(.*?\\)")
        tts_text = action_regex.sub(tts_text, "", true).strip_edges()
        
        if tts_text != "":
            var v_type = "ICL_zh_female_bingruoshaonv_tob"
            if GameDataManager.config.character_voice_types.has(character_id):
                v_type = GameDataManager.config.character_voice_types[character_id]
            var options = {"voice_type": v_type}
            doubao_tts.synthesize(tts_text, options)

func _on_tts_success(audio_stream: AudioStream, text: String):
    if audio_player and audio_stream:
        audio_player.stream = audio_stream
        audio_player.play()

func _on_gui_input(event: InputEvent):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if is_playing_single_line:
            # 单句模式（例如咖啡厅点单）：接管所有点击事件，点一下显示全本，再点一下直接关掉整个对话框
            _advance_dialogue()
            get_viewport().set_input_as_handled()
        else:
            # 持续对话模式（例如主界面、剧情模式）：
            # 外部管理器（main_scene / dialogue_manager）有自己的动画控制器和事件流，
            # 我们直接将点击事件广播出去，不再试图在内部强杀动画。
            panel_clicked.emit(event)
            # 这里可以选择不 set_input_as_handled，让事件也能穿透给底层的 unhandled_input


func _advance_dialogue():
    if _typewriter_tween and _typewriter_tween.is_running():
        # 如果打字机还在运行，点击直接显示全本
        _typewriter_tween.kill()
        rich_text_label.visible_ratio = 1.0
    else:
        # 否则结束对话
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
