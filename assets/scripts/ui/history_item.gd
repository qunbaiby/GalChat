extends VBoxContainer

@onready var name_label: Label = $HeaderHBox/NameLabel
@onready var play_button: Button = $HeaderHBox/PlayButton
@onready var content_label: RichTextLabel = $ContentLabel
@onready var time_label: Label = $TimeLabel

signal play_voice_requested(cache_key: String)

var _voice_cache_key: String = ""

func setup(msg: Dictionary) -> void:
    if msg["speaker"] == "玩家":
        name_label.add_theme_color_override("font_color", Color("#55aaff"))
        name_label.text = "玩家"
    else:
        name_label.add_theme_color_override("font_color", Color("#ff77aa"))
        name_label.text = msg["speaker"]
        
    content_label.text = msg["text"]
    time_label.text = "[" + msg["time"] + "]"
    
    if msg["speaker"] == "ayrrha" and msg.has("voice_cache_key") and msg["voice_cache_key"] != "":
        play_button.show()
        _voice_cache_key = msg["voice_cache_key"]
        play_button.pressed.connect(_on_play_button_pressed)
    else:
        play_button.hide()

func _on_play_button_pressed() -> void:
    if _voice_cache_key != "":
        play_voice_requested.emit(_voice_cache_key)
