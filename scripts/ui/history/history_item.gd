extends MarginContainer

@onready var avatar_rect: TextureRect = %AvatarRect
@onready var name_label: Label = %NameLabel
@onready var content_label: RichTextLabel = %ContentLabel
@onready var time_label: Label = %TimeLabel
@onready var play_button: Button = %PlayButton
@onready var choice_panel: PanelContainer = %ChoicePanel
@onready var choice_label: Label = %ChoiceLabel

signal play_voice_requested(cache_key: String)

var _voice_cache_key: String = ""

func _load_texture_from_path(path: String) -> Texture2D:
    var final_path = path.strip_edges()
    if final_path == "":
        return null

    if final_path.begins_with("res://") and ResourceLoader.exists(final_path):
        var res = load(final_path)
        return res if res is Texture2D else null

    if FileAccess.file_exists(final_path):
        var image = Image.load_from_file(final_path)
        if image and not image.is_empty():
            return ImageTexture.create_from_image(image)

    return null

func _resolve_avatar_texture(speaker: String) -> Texture2D:
    if speaker == "" or speaker == "系统" or speaker == "旁白":
        return null

    if speaker == "玩家":
        if GameDataManager.profile and GameDataManager.profile.has_method("get_player_avatar_texture"):
            return GameDataManager.profile.get_player_avatar_texture()
        return null

    if GameDataManager.profile:
        var profile_name = str(GameDataManager.profile.char_name).strip_edges()
        if speaker == "char" or speaker == profile_name:
            var profile_avatar = str(GameDataManager.profile.avatar).strip_edges()
            var texture = _load_texture_from_path(profile_avatar)
            if texture:
                return texture

            var current_id = str(GameDataManager.profile.current_character_id).strip_edges()
            if current_id != "":
                var fallback_avatar = "res://assets/images/characters/avatar/%s.png" % current_id
                texture = _load_texture_from_path(fallback_avatar)
                if texture:
                    return texture
                var fallback_portrait = "res://assets/images/characters/%s/%s.png" % [current_id, current_id]
                texture = _load_texture_from_path(fallback_portrait)
                if texture:
                    return texture

    return null

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
    avatar_rect.texture = _resolve_avatar_texture(speaker)
            
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
            play_button.show()
        else:
            _voice_cache_key = ""
            play_button.hide()
    else:
        _voice_cache_key = ""
        play_button.hide()

func _on_play_button_pressed() -> void:
    if _voice_cache_key != "":
        play_voice_requested.emit(_voice_cache_key)
