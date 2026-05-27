extends Panel

signal back_requested
signal cover_pick_requested

@onready var back_btn: Button = $TopBar/BackBtn
@onready var title_label: Label = $TopBar/Title
@onready var top_bar_bg: ColorRect = $TopBarBg
@onready var scroll: ScrollContainer = $Scroll

@onready var header: Control = $Scroll/ContentVBox/Header
@onready var cover_image: TextureRect = $Scroll/ContentVBox/Header/CoverImage
@onready var change_cover_btn: Button = $Scroll/ContentVBox/Header/ChangeCoverBtn
@onready var player_name: Label = $Scroll/ContentVBox/Header/PlayerName
@onready var player_avatar: TextureRect = $Scroll/ContentVBox/Header/AvatarBg/PlayerAvatar

@onready var moment_list: VBoxContainer = $Scroll/ContentVBox/MomentListMargin/MomentList

@onready var image_viewer: ColorRect = $ImageViewer
@onready var full_image: TextureRect = $ImageViewer/FullImage
@onready var close_viewer_btn: Button = $ImageViewer/CloseViewerBtn

@onready var avatar_bg: ColorRect = $Scroll/ContentVBox/Header/AvatarBg

var moment_item_scene = preload("res://scenes/ui/mobile/moments/moment_item.tscn")
var _is_cover_expanded: bool = false
var _original_header_height: float = 350.0
var _local_cover_path: String = ""

func _ready() -> void:
    back_btn.pressed.connect(_on_back_pressed)
    scroll.get_v_scroll_bar().value_changed.connect(_on_scroll_changed)
    
    cover_image.gui_input.connect(_on_cover_gui_input)
    change_cover_btn.pressed.connect(_on_change_cover_pressed)
    
    close_viewer_btn.pressed.connect(_on_close_viewer_pressed)
    
    call_deferred("_connect_signals")
    hide()

func _connect_signals() -> void:
    var deepseek_client = _get_deepseek_client()
    if deepseek_client:
        if deepseek_client.has_signal("moment_reply_generated") and not deepseek_client.moment_reply_generated.is_connected(_on_ai_reply_generated):
            deepseek_client.moment_reply_generated.connect(_on_ai_reply_generated)
        if deepseek_client.has_signal("moment_generated") and not deepseek_client.moment_generated.is_connected(_on_ai_moment_generated):
            deepseek_client.moment_generated.connect(_on_ai_moment_generated)

func _get_deepseek_client() -> Node:
    var llm_manager = get_node_or_null("/root/LLMManager")
    if llm_manager and llm_manager.has("deepseek_client"):
        return llm_manager.deepseek_client
    if get_tree().current_scene and get_tree().current_scene.has_node("DeepSeekClient"):
        return get_tree().current_scene.get_node("DeepSeekClient")
    if get_node_or_null("/root/DeepSeekClient"):
        return get_node("/root/DeepSeekClient")
    if get_tree().root.has_node("MainScene/DeepSeekClient"):
        return get_node("/root/MainScene/DeepSeekClient")
    return null

func _process(delta: float) -> void:
    if visible:
        _connect_signals()

func _on_ai_moment_generated(moment_data: Dictionary) -> void:
    if visible:
        refresh_list()

func _on_ai_reply_generated(post_id: String, reply_text: String) -> void:
    # MomentsManager already handles appending to data, just refresh UI
    if visible:
        refresh_list()

func show_panel() -> void:
    show()
    MomentsManager.mark_all_read()
    # 强制在显示时清理旧的 _local_cover_path，以防止打开时卡在旧的局部变量上
    _local_cover_path = ""
    _update_header()
    refresh_list()
    _on_scroll_changed(scroll.scroll_vertical)

func _on_scroll_changed(value: float) -> void:
    # 顶部渐变黑底和文字，只有当滚动超过封面高度的一大半时才开始渐现
    var fade_start = _original_header_height - 120.0
    var fade_end = _original_header_height - 20.0
    
    var alpha = 0.0
    if value > fade_start:
        alpha = clamp((value - fade_start) / (fade_end - fade_start), 0.0, 0.95)
        
    top_bar_bg.color = Color(0.15, 0.15, 0.18, alpha)
    title_label.modulate.a = alpha

func _on_cover_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _toggle_cover()

func _toggle_cover() -> void:
    _is_cover_expanded = !_is_cover_expanded
    var target_height = 500.0 if _is_cover_expanded else _original_header_height
    var target_alpha = 0.0 if _is_cover_expanded else 1.0
    
    var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(header, "custom_minimum_size:y", target_height, 0.3)
    tween.tween_property(player_name, "modulate:a", target_alpha, 0.3)
    tween.tween_property(avatar_bg, "modulate:a", target_alpha, 0.3)
    
    if _is_cover_expanded:
        change_cover_btn.show()
        change_cover_btn.modulate.a = 0.0
        tween.tween_property(change_cover_btn, "modulate:a", 1.0, 0.3)
    else:
        tween.tween_property(change_cover_btn, "modulate:a", 0.0, 0.2)
        tween.chain().tween_callback(func(): change_cover_btn.hide())

func _on_change_cover_pressed() -> void:
    cover_pick_requested.emit()

func update_cover_from_album(path: String) -> void:
    _local_cover_path = path
    if GameDataManager.config:
        GameDataManager.config.moments_cover_path = path
        if GameDataManager.config.has_method("save_config"):
            GameDataManager.config.save_config()
            
    _update_header()
    
    # 强制立刻重新绘制一下，以防 Godot 缓存
    if is_inside_tree():
        cover_image.queue_redraw()
        
    # 如果处于展开状态，点击换封面后要立刻收起并滚动到顶部，否则可能看不到效果
    if _is_cover_expanded:
        _toggle_cover()
    if scroll:
        scroll.scroll_vertical = 0

func show_image_viewer(tex: Texture2D) -> void:
    if tex:
        full_image.texture = tex
        image_viewer.show()
        image_viewer.modulate.a = 0.0
        var tween = create_tween()
        tween.tween_property(image_viewer, "modulate:a", 1.0, 0.2)

func _on_close_viewer_pressed() -> void:
    var tween = create_tween()
    tween.tween_property(image_viewer, "modulate:a", 0.0, 0.2)
    tween.tween_callback(func(): image_viewer.hide())

func _update_header() -> void:
    if GameDataManager.config:
        player_name.text = GameDataManager.config.player_name
        
        var cover_path = _local_cover_path
        if cover_path == "" and GameDataManager.config.get("moments_cover_path") != null:
            cover_path = GameDataManager.config.moments_cover_path
            
        if cover_path != null and cover_path != "":
            # 在 Godot 中，使用 load 替代 Image.load_from_file 有时更稳妥，特别是图片没有被识别时
            var global_path = ProjectSettings.globalize_path(cover_path)
            
            var img_loaded = false
            
            # 第一尝试：直接用 FileAccess + Image.load_from_file 加载绝对物理路径
            var abs_path = global_path
            if not FileAccess.file_exists(abs_path):
                abs_path = cover_path
                
            if FileAccess.file_exists(abs_path):
                var img = Image.load_from_file(abs_path)
                if img and not img.is_empty():
                    cover_image.texture = ImageTexture.create_from_image(img)
                    img_loaded = true
                
            # 第二尝试：有些时候 Godot 的 user:// 不支持 globalize_path 得到的文件直接读取，或者路径有坑
            # 这里强制用 Image.load_from_file 尝试 user:// 原始路径
            if not img_loaded and cover_path.begins_with("user://"):
                if FileAccess.file_exists(cover_path):
                    var img = Image.new()
                    var err = img.load(cover_path) # 注意 Godot4 中 Image 没有直接接收 user:// 的 load_from_file 宏，需要用 img.load
                    if err == OK and not img.is_empty():
                        cover_image.texture = ImageTexture.create_from_image(img)
                        img_loaded = true
                
            # 第三尝试：通过 ResourceLoader 强制加载
            if not img_loaded:
                var tex = load(cover_path)
                if tex is Texture2D:
                    cover_image.texture = tex
                    img_loaded = true
                    
            if not img_loaded:
                var fallback_path = ImageManager.get_image_path("cg_luna_door_sunset")
                if fallback_path != "" and ResourceLoader.exists(fallback_path):
                    cover_image.texture = load(fallback_path)
                
        else:
            var fallback_path = ImageManager.get_image_path("cg_luna_door_sunset")
            if fallback_path != "" and ResourceLoader.exists(fallback_path):
                cover_image.texture = load(fallback_path)
    
    # Avatar
    var profile = GameDataManager.profile
    if profile and profile.avatar != "" and FileAccess.file_exists(profile.avatar):
        player_avatar.texture = load(profile.avatar)
    else:
        player_avatar.texture = preload("res://icon.svg")

func hide_panel() -> void:
    hide()
    back_requested.emit()

func _on_back_pressed() -> void:
    hide_panel()

func refresh_list() -> void:
    # Clear list
    for child in moment_list.get_children():
        child.queue_free()
        
    var moments = MomentsManager.get_all_moments()
    for moment_data in moments:
        var item = moment_item_scene.instantiate()
        moment_list.add_child(item)
        item.setup(moment_data)
