extends VBoxContainer

@onready var name_label: Label = $HeaderHBox/NameLabel
@onready var play_button: Button = $HeaderHBox/PlayButton
@onready var content_label: RichTextLabel = $ContentLabel
@onready var time_label: Label = $TimeLabel

signal play_voice_requested(cache_key: String)

var _voice_cache_key: String = ""

func setup(msg: Dictionary) -> void:
    if msg["speaker"] == "玩家" or msg["speaker"] == "我" or msg["speaker"] == "player":
        name_label.add_theme_color_override("font_color", Color("#55aaff"))
        name_label.text = "玩家"
    else:
        name_label.add_theme_color_override("font_color", Color("#ff77aa"))
        name_label.text = GameDataManager.profile.char_name if msg["speaker"] == "char" else msg["speaker"]
        
    content_label.text = msg["text"]
    var time_str = msg["time"].replace("T", " ")
    time_label.text = "[" + time_str + "]"
    
    if msg["speaker"] == GameDataManager.profile.char_name or msg["speaker"] == "char":
        play_button.show()
        if msg.has("voice_cache_key") and msg["voice_cache_key"] != "":
            _voice_cache_key = msg["voice_cache_key"]
            play_button.pressed.connect(_on_play_button_pressed)
        else:
            # 没有语音缓存也留着按钮（或者可以选择置灰/隐藏，这里为了对齐需求保持显示）
            pass
    else:
        play_button.hide()

func _on_play_button_pressed() -> void:
    if _voice_cache_key != "":
        play_voice_requested.emit(_voice_cache_key)
