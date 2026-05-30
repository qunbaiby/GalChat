extends VBoxContainer

@onready var avatar_rect: TextureRect = %AvatarRect
@onready var name_label: Label = %NameLabel
@onready var content_label: RichTextLabel = %ContentLabel
@onready var time_label: Label = %TimeLabel
@onready var play_button: Button = %PlayButton
@onready var choice_panel: PanelContainer = %ChoicePanel
@onready var choice_label: Label = %ChoiceLabel

signal play_voice_requested(cache_key: String)

var _voice_cache_key: String = ""

func _ready():
    play_button.pressed.connect(_on_play_button_pressed)

func setup(msg: Dictionary) -> void:
    var speaker = msg.get("speaker", "Unknown")
    var content = msg.get("text", "")
    var is_choice = msg.get("is_choice", false)
    
    if speaker == "玩家" or speaker == "我" or speaker == "player":
        name_label.add_theme_color_override("font_color", Color("#55aaff"))
        speaker = "玩家"
    else:
        name_label.add_theme_color_override("font_color", Color("#ff77aa"))
        if speaker == "char":
            speaker = GameDataManager.profile.char_name
            
    name_label.text = speaker
    content_label.text = content
    var time_str = msg.get("time", "00:00:00").replace("T", " ")
    time_label.text = "[%s]" % time_str
    
    # 动态获取头像
    var char_data = GameDataManager.get_character_data(speaker)
    if char_data and char_data.has("avatar"):
        var avatar_path = char_data.avatar
        if FileAccess.file_exists(avatar_path):
            avatar_rect.texture = load(avatar_path)
            
    # 如果是旁白（或者旁白/系统提示），名字用特定颜色，并且可以隐藏头像
    if speaker == "" or speaker == "系统" or speaker == "旁白":
        name_label.text = ""
        avatar_rect.get_parent().get_parent().hide()
    else:
        avatar_rect.get_parent().get_parent().show()
        
    # 如果是选项记录，则使用高亮面板
    if is_choice:
        content_label.hide()
        choice_panel.show()
        choice_label.text = content
        
        # 隐藏名字和头像（选项通常是玩家自己的行为）
        name_label.text = ""
        avatar_rect.get_parent().get_parent().hide()
    else:
        content_label.show()
        choice_panel.hide()
        
    if msg.get("speaker", "Unknown") == GameDataManager.profile.char_name or msg.get("speaker", "Unknown") == "char":
        if msg.has("voice_cache_key") and msg["voice_cache_key"] != "":
            _voice_cache_key = msg["voice_cache_key"]
            # 这里保留了播放按钮，但按要求在场景中通过visible=false隐藏了
            # play_button.show() 
        else:
            _voice_cache_key = ""
            play_button.hide()
    else:
        _voice_cache_key = ""
        play_button.hide()

func _on_play_button_pressed() -> void:
    if _voice_cache_key != "":
        play_voice_requested.emit(_voice_cache_key)
