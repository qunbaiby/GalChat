extends Control

signal app_opened(app_name: String)
signal phone_closing

const MemoryAlbumManagerScript = preload("res://scripts/data/memory_album_manager.gd")
const PhotoMemoryManagerScript = preload("res://scripts/data/photo_memory_manager.gd")
const AffectionPanelScene = preload("res://scenes/ui/mobile/affection_panel.tscn")

@onready var animation_player: AnimationPlayer = $AnimationPlayer

@onready var archive_btn: Button = $PhonePanel/MainMargin/VBox/PlayerInfoArea/InteractionArea/LevelVBox/BtnHBox/ArchiveBtn
@onready var pomodoro_btn: Button = $PhonePanel/MainMargin/VBox/CardsHBox/ButtonContainer/PomodoroContainer/PomodoroBtn
@onready var affection_btn: Button = $PhonePanel/MainMargin/VBox/PlayerInfoArea/InteractionArea/LevelVBox/BtnHBox/AffectionButton
@onready var settings_btn: Button = $PhonePanel/MainMargin/VBox/CardsHBox/ButtonContainer/CameraContainer/SettingsBtn
@onready var save_btn: Button = $PhonePanel/MainMargin/VBox/CardsHBox/ButtonContainer/CameraContainer/SaveBtn
@onready var load_btn: Button = $PhonePanel/MainMargin/VBox/CardsHBox/ButtonContainer/VBoxContainer/LoadBtn
@onready var album_btn: Button = $PhonePanel/MainMargin/VBox/CardsHBox/ButtonContainer/VBoxContainer/AlbumBtn
@onready var preview_image: TextureRect = $PhonePanel/MainMargin/VBox/CardsHBox/ImagePreview/ImageCard/Image
@onready var power_btn: Button = $PhonePanel/MainMargin/VBox/PowerBtn
@onready var between_entry_panel: PanelContainer = $PhonePanel/MainMargin/VBox/ListCards/BetweenEntry
@onready var between_entry_btn: Button = $PhonePanel/MainMargin/VBox/ListCards/BetweenEntry/BetweenEntryBtn
@onready var between_entry_title: Label = $PhonePanel/MainMargin/VBox/ListCards/BetweenEntry/EntryMargin/EntryHBox/EntryTextVBox/BetweenEntryTitle
@onready var between_entry_text: Label = $PhonePanel/MainMargin/VBox/ListCards/BetweenEntry/EntryMargin/EntryHBox/EntryTextVBox/BetweenEntryContent/BetweenEntryText
@onready var between_entry_icon: Label = $PhonePanel/MainMargin/VBox/ListCards/BetweenEntry/EntryMargin/EntryHBox/BetweenEntryIcon/BetweenEntryIconLabel

@onready var player_name_lbl: Label = $PhonePanel/MainMargin/VBox/PlayerInfoArea/InteractionArea/PlayerVBox/NamePlate/HBox/PlayerName
@onready var char_name_lbl: Label = $PhonePanel/MainMargin/VBox/PlayerInfoArea/InteractionArea/CharVBox/NamePlate/HBox/CharName
@onready var char_avatar_rect: TextureRect = $PhonePanel/MainMargin/VBox/PlayerInfoArea/InteractionArea/CharVBox/AvatarContainer/AvatarMask/Avatar
@onready var player_avatar_rect: TextureRect = $PhonePanel/MainMargin/VBox/PlayerInfoArea/InteractionArea/PlayerVBox/AvatarContainer/AvatarMask/Avatar
@onready var lvl_num_lbl: Label = $PhonePanel/MainMargin/VBox/PlayerInfoArea/InteractionArea/LevelVBox/TopHBox/LevelNum
@onready var lvl_progress_lbl: Label = $PhonePanel/MainMargin/VBox/PlayerInfoArea/InteractionArea/LevelVBox/TopHBox/TextVBox/LevelProgress
@onready var exp_bar: ProgressBar = $PhonePanel/MainMargin/VBox/PlayerInfoArea/InteractionArea/LevelVBox/ExpBar

@onready var affection_panel = $PhonePanel/AffectionPanel

@onready var phone_panel: Panel = $PhonePanel
@onready var color_rect: ColorRect = $ColorRect

var archive_panel_instance = null
var contact_list_instance = null
var chat_panel_instance = null
var settings_panel_instance = null
var save_load_panel_instance = null
var album_panel_instance = null
var moments_panel_instance = null
var between_panel_instance = null
var pomodoro_panel_instance = null

var _photo_manager = PhotoMemoryManagerScript.new()
var _album_photos: Array = []
var _current_photo_idx: int = 0
var _photo_timer: float = 0.0
const PHOTO_CHANGE_INTERVAL: float = 5.0
const AFFECTION_OPEN_SOURCE_PHONE := "phone"
const AFFECTION_OPEN_SOURCE_MAIN := "main"
var _affection_open_source: String = AFFECTION_OPEN_SOURCE_PHONE

var preview_image_next: TextureRect = null
var _preview_tween: Tween
var _slide_tween: Tween

func _ready() -> void:
    visible = false
    phone_panel.position.x = 1280.0 # 初始在屏幕右侧外
    color_rect.color.a = 0.0
    color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    
    if is_instance_valid(preview_image):
        preview_image_next = preview_image.duplicate()
        var parent = preview_image.get_parent()
        parent.add_child(preview_image_next)
        if parent.has_node("ImageFrame"):
            var frame = parent.get_node("ImageFrame")
            parent.move_child(frame, -1)
        preview_image_next.position.x = preview_image.size.x
        preview_image_next.hide()

    animation_player.animation_finished.connect(_on_animation_finished)
    
    $ColorRect.gui_input.connect(_on_color_rect_gui_input)
    
    # 绑定信号
    archive_btn.pressed.connect(_on_archive_app_pressed)
    pomodoro_btn.pressed.connect(_on_pomodoro_app_pressed)
    settings_btn.pressed.connect(_on_settings_app_pressed)
    save_btn.pressed.connect(_on_save_app_pressed)
    load_btn.pressed.connect(_on_load_app_pressed)
    album_btn.pressed.connect(_on_album_app_pressed)
    affection_btn.pressed.connect(_on_affection_button_pressed)
    power_btn.pressed.connect(_on_close_pressed)
    between_entry_btn.pressed.connect(_on_between_entry_pressed)
    if is_instance_valid(affection_panel) and affection_panel.has_signal("back_requested"):
        affection_panel.back_requested.connect(_on_affection_back_pressed)
    # camera_btn.pressed.connect(_on_camera_app_pressed)
    if MomentsManager and MomentsManager.has_signal("moments_updated"):
        MomentsManager.moments_updated.connect(_update_social_entry_labels)
    _configure_entry_cards()

func _process(delta: float) -> void:
    _update_time()
    if visible and phone_panel.position.x < 1200:
        if _album_photos.size() > 1:
            _photo_timer += delta
            if _photo_timer >= PHOTO_CHANGE_INTERVAL:
                _photo_timer = 0.0
                _current_photo_idx = (_current_photo_idx + 1) % _album_photos.size()
                _update_preview_image()

func _update_time() -> void:
    pass

func show_phone() -> void:
    _affection_open_source = AFFECTION_OPEN_SOURCE_PHONE
    if GameDataManager.config and GameDataManager.profile:
        var profile = GameDataManager.profile
        if is_instance_valid(player_name_lbl):
            player_name_lbl.text = profile.player_name if profile.player_name.strip_edges() != "" else GameDataManager.config.player_name
        if is_instance_valid(player_avatar_rect):
            player_avatar_rect.texture = profile.get_player_avatar_texture()
        
        var c_name = profile.char_name
        if c_name == "": c_name = "未知角色"
        if is_instance_valid(char_name_lbl): char_name_lbl.text = c_name
        
        if profile.avatar != "" and is_instance_valid(char_avatar_rect):
            var tex = load(profile.avatar)
            if tex: char_avatar_rect.texture = tex
            
        var current_stage = profile.current_stage
        var conf = profile.get_current_stage_config()
        
        if is_instance_valid(lvl_num_lbl): lvl_num_lbl.text = str(current_stage)
        
        var current_resonance = profile.intimacy + profile.trust
        var res_threshold = 9999.0
        if not conf.is_empty():
            res_threshold = float(conf.get("resonance_threshold", 9999))
            
        var display_res_max = res_threshold
        if res_threshold >= 9999:
            display_res_max = max(current_resonance, 100)
            
        if is_instance_valid(lvl_progress_lbl): 
            lvl_progress_lbl.text = "%.1f/MAX" % current_resonance if res_threshold >= 9999 else "%.1f/%d" % [current_resonance, int(res_threshold)]
            
        if is_instance_valid(exp_bar):
            exp_bar.min_value = 0
            exp_bar.max_value = display_res_max
            exp_bar.value = min(current_resonance, display_res_max)

    _update_time()
    _load_album_photos()
    _update_social_entry_labels()
    _update_between_entry_card()
    if is_instance_valid(affection_panel):
        affection_panel.hide()
    
    show()
    color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
    if _slide_tween:
        _slide_tween.kill()
    _slide_tween = create_tween()
    _slide_tween.set_parallel(true)
    _slide_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    _slide_tween.tween_property(phone_panel, "position:x", 791.0, 0.4)
    _slide_tween.tween_property(color_rect, "color:a", 0.3, 0.4)

func _update_social_entry_labels() -> void:
    if wechat_panel_instance and wechat_panel_instance.recent_chats_instance and wechat_panel_instance.recent_chats_instance.visible:
        wechat_panel_instance.recent_chats_instance._load_contacts()
    if wechat_panel_instance and wechat_panel_instance.moments_instance and wechat_panel_instance.moments_instance.visible and wechat_panel_instance.moments_instance.has_method("refresh_list"):
        wechat_panel_instance.moments_instance.refresh_list()
    elif moments_panel_instance and moments_panel_instance.visible and moments_panel_instance.has_method("refresh_list"):
        moments_panel_instance.refresh_list()
    _update_between_entry_card()

func _configure_entry_cards() -> void:
    if is_instance_valid(between_entry_panel):
        between_entry_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _update_between_entry_card() -> void:
    var manager = MemoryAlbumManagerScript.new()
    var entries = manager.build_entries()
    var summary = manager.get_summary(entries)
    if is_instance_valid(between_entry_title):
        between_entry_title.text = "你我之间"
    if is_instance_valid(between_entry_text):
        var total = int(summary.get("total", 0))
        var memory_count = int(summary.get("memory", 0))
        var diary_count = int(summary.get("diary", 0))
        var photo_count = int(summary.get("photo", 0))
        if total <= 0:
            between_entry_text.text = "还没有被收录的共同回忆。\n点开这里整理你们的纪念册。"
        else:
            between_entry_text.text = "已收录 %d 段回忆\n回忆 %d 条 · 日记 %d 页 · 相片 %d 张" % [total, memory_count, diary_count, photo_count]
    if is_instance_valid(between_entry_icon):
        between_entry_icon.text = "♡"

func _on_between_entry_pressed() -> void:
    if between_panel_instance == null:
        var BetweenPanelObj = load("res://scenes/ui/mobile/between_panel.tscn")
        between_panel_instance = BetweenPanelObj.instantiate()
        phone_panel.add_child(between_panel_instance)
        between_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        between_panel_instance.back_requested.connect(_on_between_panel_back)
    else:
        phone_panel.move_child(between_panel_instance, -1)
    between_panel_instance.show_panel()

func _on_between_panel_back() -> void:
    _update_between_entry_card()

func _get_total_sms_unread_count() -> int:
    var total = 0
    var char_dirs = [
        "res://assets/data/characters",
		"res://assets/data/characters/npc"
    ]
    for dir_path in char_dirs:
        var dir = DirAccess.open(dir_path)
        if dir == null:
            continue
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.ends_with(".json") and not file_name.ends_with("_stages.json"):
                var char_id = file_name.replace(".json", "")
                total += _get_unread_count_for_char(char_id)
            file_name = dir.get_next()
    return total

func _get_unread_count_for_char(char_id: String) -> int:
    var path = "user://saves/%s/mobile_chat_history.json" % char_id
    if not FileAccess.file_exists(path):
        return 0
    var file = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return 0
    var json = JSON.new()
    var result = json.parse(file.get_as_text())
    file.close()
    if result != OK or not json.data is Array:
        return 0
    var unread = 0
    var normalized_history: Array = []
    var has_legacy_fields := false
    for raw_msg in json.data:
        if not raw_msg is Dictionary:
            continue
        var msg: Dictionary = raw_msg.duplicate(true)
        if msg.has("role"):
            has_legacy_fields = true
            var role = str(msg.get("role", ""))
            match role:
                "user":
                    msg["speaker"] = "player"
                "assistant":
                    msg["speaker"] = "char"
                _:
                    msg["speaker"] = role
            msg.erase("role")
        if msg.has("content"):
            has_legacy_fields = true
            msg["text"] = str(msg.get("content", ""))
            msg.erase("content")
        if not msg.has("speaker"):
            msg["speaker"] = ""
        if not msg.has("text"):
            msg["text"] = ""
        normalized_history.append(msg)
        var speaker = msg.get("speaker", "")
        if speaker != "player" and not msg.get("is_read", false):
            unread += 1
    if has_legacy_fields:
        var save_file = FileAccess.open(path, FileAccess.WRITE)
        if save_file:
            save_file.store_string(JSON.stringify(normalized_history, "\t"))
            save_file.close()
    return unread

func hide_phone(emit_closing: bool = true) -> void:
    if emit_closing:
        phone_closing.emit()
    color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if _slide_tween:
        _slide_tween.kill()
    _slide_tween = create_tween()
    _slide_tween.set_parallel(true)
    _slide_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    _slide_tween.tween_property(phone_panel, "position:x", 1280.0, 0.4)
    _slide_tween.tween_property(color_rect, "color:a", 0.0, 0.4)
    _slide_tween.chain().tween_callback(func():
        hide()
        if affection_panel:
            affection_panel.hide()
        if between_panel_instance:
            between_panel_instance.hide()
        if chat_panel_instance:
            chat_panel_instance.hide_panel(true)
            if chat_panel_instance.voice_call_panel_instance:
                chat_panel_instance.voice_call_panel_instance.hide()
            if chat_panel_instance.video_call_panel_instance:
                chat_panel_instance.video_call_panel_instance.hide()
        if wechat_panel_instance:
            wechat_panel_instance.hide_panel(true)
    )

func _on_close_pressed() -> void:
    hide_phone()

func _on_color_rect_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        hide_phone()

func _on_affection_button_pressed() -> void:
    _affection_open_source = AFFECTION_OPEN_SOURCE_PHONE
    if is_instance_valid(affection_panel) and affection_panel.has_method("show_panel"):
        affection_panel.show_panel(GameDataManager.profile)

func _on_affection_back_pressed() -> void:
    if _affection_open_source == AFFECTION_OPEN_SOURCE_MAIN:
        hide_phone()
        return
    if is_instance_valid(affection_panel):
        affection_panel.hide()

func open_affection_directly() -> void:
    _affection_open_source = AFFECTION_OPEN_SOURCE_MAIN
    if is_instance_valid(affection_panel) and affection_panel.has_method("show_panel"):
        affection_panel.show_panel(GameDataManager.profile)

func _on_archive_app_pressed() -> void:
    if archive_panel_instance == null:
        var ArchivePanelObj = load("res://scenes/ui/archive/archive_panel.tscn")
        archive_panel_instance = ArchivePanelObj.instantiate()
        phone_panel.add_child(archive_panel_instance)
        archive_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    else:
        phone_panel.move_child(archive_panel_instance, -1)
    archive_panel_instance.show_panel()

func _on_pomodoro_app_pressed() -> void:
    if pomodoro_panel_instance == null:
        var PomodoroPanelObj = load("res://scenes/ui/main/pomodoro_panel.tscn")
        pomodoro_panel_instance = PomodoroPanelObj.instantiate()
        phone_panel.add_child(pomodoro_panel_instance)
        pomodoro_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        pomodoro_panel_instance.back_requested.connect(func(): pomodoro_panel_instance.hide())
    else:
        phone_panel.move_child(pomodoro_panel_instance, -1)
    pomodoro_panel_instance.show()

func _load_album_photos() -> void:
    _album_photos.clear()
    var records = _photo_manager.get_album_records()
    for record in records:
        var path = str(record.get("photo_path", "")).strip_edges()
        if path != "":
            _album_photos.append(path)
            
    if _album_photos.size() > 0:
        _photo_timer = 0.0
        _update_preview_image(false)
    else:
        if GameDataManager.config and "default_image_path" in GameDataManager.config:
            var path = GameDataManager.config.default_image_path
            if FileAccess.file_exists(path):
                preview_image.texture = load(path)

func _update_preview_image(animate: bool = true) -> void:
    if _album_photos.size() > 0:
        var path = _album_photos[_current_photo_idx]
        var tex = _load_album_texture(path)
        if tex == null:
            return
        if not animate:
            if is_instance_valid(preview_image):
                preview_image.texture = tex
            return
            
        if is_instance_valid(preview_image) and is_instance_valid(preview_image_next):
            if _preview_tween:
                _preview_tween.kill()
            
            preview_image_next.texture = tex
            preview_image_next.position.x = preview_image.size.x
            preview_image_next.show()
            
            _preview_tween = create_tween()
            _preview_tween.set_parallel(true)
            _preview_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
            
            _preview_tween.tween_property(preview_image, "position:x", -preview_image.size.x, 0.4)
            _preview_tween.tween_property(preview_image_next, "position:x", 0, 0.4)
            
            _preview_tween.set_parallel(false)
            _preview_tween.tween_callback(func():
                preview_image.texture = tex
                preview_image.position.x = 0
                preview_image_next.hide()
            )

func _load_album_texture(path: String) -> Texture2D:
    if path == "":
        return null
    if path.begins_with("res://") and ResourceLoader.exists(path):
        var res = load(path)
        return res if res is Texture2D else null
    if FileAccess.file_exists(path):
        var img = Image.load_from_file(path)
        if img and not img.is_empty():
            return ImageTexture.create_from_image(img)
    return null

func _on_settings_app_pressed() -> void:
    if settings_panel_instance == null:
        var SettingsPanelObj = load("res://scenes/ui/settings/settings_scene.tscn")
        settings_panel_instance = SettingsPanelObj.instantiate()
        phone_panel.add_child(settings_panel_instance)
        settings_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    else:
        phone_panel.move_child(settings_panel_instance, -1)
    settings_panel_instance.show_panel()

func _on_save_app_pressed() -> void:
    if save_load_panel_instance == null:
        var SaveLoadPanelObj = load("res://scenes/ui/save_load/save_load_panel.tscn")
        save_load_panel_instance = SaveLoadPanelObj.instantiate()
        phone_panel.add_child(save_load_panel_instance)
        save_load_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    else:
        phone_panel.move_child(save_load_panel_instance, -1)
    save_load_panel_instance.show_panel(true)

func _on_load_app_pressed() -> void:
    if save_load_panel_instance == null:
        var SaveLoadPanelObj = load("res://scenes/ui/save_load/save_load_panel.tscn")
        save_load_panel_instance = SaveLoadPanelObj.instantiate()
        phone_panel.add_child(save_load_panel_instance)
        save_load_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    else:
        phone_panel.move_child(save_load_panel_instance, -1)
    save_load_panel_instance.show_panel(false)

func _on_album_app_pressed() -> void:
    if album_panel_instance == null:
        var AlbumPanelObj = load("res://scenes/ui/mobile/album_panel.tscn")
        album_panel_instance = AlbumPanelObj.instantiate()
        phone_panel.add_child(album_panel_instance)
        album_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    else:
        phone_panel.move_child(album_panel_instance, -1)
        
    # Reset picker mode when opening directly from app list
    album_panel_instance.set_picker_mode(false)
    if album_panel_instance.photo_picked.is_connected(_on_album_photo_picked_for_cover):
        album_panel_instance.photo_picked.disconnect(_on_album_photo_picked_for_cover)
    album_panel_instance.show_panel()

var wechat_panel_instance = null

func open_wechat_directly() -> void:
    if wechat_panel_instance == null:
        var WeChatPanelObj = load("res://scenes/ui/mobile/wechat/wechat_main_panel.tscn")
        wechat_panel_instance = WeChatPanelObj.instantiate()
        phone_panel.add_child(wechat_panel_instance)
        wechat_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        wechat_panel_instance.back_requested.connect(_on_wechat_panel_back)
        wechat_panel_instance.character_selected.connect(_on_character_selected)
        wechat_panel_instance.cover_pick_requested.connect(_on_moments_cover_pick_requested)
    else:
        phone_panel.move_child(wechat_panel_instance, -1)
    wechat_panel_instance.show_panel()
    if wechat_panel_instance.has_method("_on_tab_pressed"):
        wechat_panel_instance._on_tab_pressed(0)
    _update_social_entry_labels()

func _on_wechat_panel_back() -> void:
    _update_social_entry_labels()
    hide_phone()

func _on_moments_cover_pick_requested() -> void:
    if album_panel_instance == null:
        var AlbumPanelObj = load("res://scenes/ui/mobile/album_panel.tscn")
        album_panel_instance = AlbumPanelObj.instantiate()
        phone_panel.add_child(album_panel_instance)
        album_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    else:
        phone_panel.move_child(album_panel_instance, -1)
        
    album_panel_instance.set_picker_mode(true, "更换封面")
    if not album_panel_instance.photo_picked.is_connected(_on_album_photo_picked_for_cover):
        album_panel_instance.photo_picked.connect(_on_album_photo_picked_for_cover)
    album_panel_instance.show_panel()

func _on_album_photo_picked_for_cover(path: String) -> void:
    if album_panel_instance:
        if album_panel_instance.photo_picked.is_connected(_on_album_photo_picked_for_cover):
            album_panel_instance.photo_picked.disconnect(_on_album_photo_picked_for_cover)
        album_panel_instance.hide_panel()
        
    if wechat_panel_instance and wechat_panel_instance.moments_instance:
        wechat_panel_instance.moments_instance.update_cover_from_album(path)
    elif moments_panel_instance:
        moments_panel_instance.update_cover_from_album(path)



func _on_character_selected(char_id: String) -> void:
    if chat_panel_instance == null:
        var ChatPanelObj = load("res://scenes/ui/mobile/chat/mobile_chat_panel.tscn")
        chat_panel_instance = ChatPanelObj.instantiate()
        phone_panel.add_child(chat_panel_instance)
        chat_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        chat_panel_instance.back_requested.connect(_on_chat_panel_back)
        chat_panel_instance.incoming_call_ended.connect(_on_incoming_call_ended)
    else:
        phone_panel.move_child(chat_panel_instance, -1)
        
    chat_panel_instance.setup(char_id)
    chat_panel_instance.show_panel()

func _on_chat_panel_back() -> void:
    if chat_panel_instance:
        chat_panel_instance.hide_panel()
    if wechat_panel_instance:
        wechat_panel_instance.show_panel(false)
    _update_social_entry_labels()

func _on_incoming_call_ended() -> void:
    hide_phone()

func open_call_directly(char_id: String, is_video: bool, is_fixed: bool = false) -> void:
    if chat_panel_instance == null:
        var ChatPanelObj = load("res://scenes/ui/mobile/chat/mobile_chat_panel.tscn")
        chat_panel_instance = ChatPanelObj.instantiate()
        phone_panel.add_child(chat_panel_instance)
        chat_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        chat_panel_instance.back_requested.connect(_on_chat_panel_back)
        chat_panel_instance.incoming_call_ended.connect(_on_incoming_call_ended)
    else:
        phone_panel.move_child(chat_panel_instance, -1)
        
    chat_panel_instance.setup(char_id)
    chat_panel_instance.show_panel()
    
    # 延迟一帧等待 chat_panel 准备完毕，然后直接触发对应的通话按钮并传递参数
    await get_tree().process_frame
    if is_video:
        chat_panel_instance.start_video_call(true, is_fixed)
    else:
        chat_panel_instance.start_voice_call(true, is_fixed)

func _on_animation_finished(anim_name: String) -> void:
    pass
