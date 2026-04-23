extends Control

signal app_opened(app_name: String)

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var phone_panel: Panel = $PhonePanel

@onready var archive_btn: Button = $PhonePanel/MainMargin/VBox/CardsHBox/Card2/ArchiveBtn
@onready var camera_btn: Button = $PhonePanel/MainMargin/VBox/CardsHBox/Card3/CameraBtn
@onready var album_btn: Button = $PhonePanel/MainMargin/VBox/CardsHBox/Card4/AlbumBtn
@onready var power_btn: Button = $PhonePanel/MainMargin/VBox/PowerBtn
@onready var sms_btn: Button = $PhonePanel/MainMargin/VBox/ListVBox/List1/SmsBtn

@onready var player_name_lbl: Label = $PhonePanel/MainMargin/VBox/PlayerInfoArea/MainInfo/NameAndLevel/PlayerName
@onready var eq_level_lbl: Label = $PhonePanel/MainMargin/VBox/PlayerInfoArea/MainInfo/NameAndLevel/EqLevel
@onready var bio_lbl: Label = $PhonePanel/MainMargin/VBox/PlayerInfoArea/BioArea/BioLabel
@onready var tb_level_lbl: Label = $PhonePanel/MainMargin/VBox/PlayerInfoArea/TrailblazeLevel/Label
@onready var exp_bar: ProgressBar = $PhonePanel/MainMargin/VBox/PlayerInfoArea/ProgressBar

var archive_panel_instance = null
var contact_list_instance = null
var chat_panel_instance = null
var camera_panel_instance = null
var album_panel_instance = null

func _ready() -> void:
    animation_player.animation_finished.connect(_on_animation_finished)
    
    # 绑定信号
    archive_btn.pressed.connect(_on_archive_app_pressed)
    power_btn.pressed.connect(_on_close_pressed)
    sms_btn.pressed.connect(_on_sms_app_pressed)
    
    camera_btn.pressed.connect(_on_camera_app_pressed)
    album_btn.pressed.connect(_on_album_app_pressed)

func _process(delta: float) -> void:
    if visible:
        pass # removed time update

func _update_time() -> void:
    pass

func show_phone() -> void:
    if GameDataManager.config:
        if is_instance_valid(player_name_lbl): player_name_lbl.text = GameDataManager.config.player_name
        if is_instance_valid(bio_lbl): bio_lbl.text = GameDataManager.config.player_bio
        if is_instance_valid(eq_level_lbl): eq_level_lbl.text = "均衡等级 %d ⓘ" % GameDataManager.config.player_eq_level
        if is_instance_valid(tb_level_lbl): tb_level_lbl.text = "开拓等级 %d" % GameDataManager.config.player_level
        if is_instance_valid(exp_bar): exp_bar.value = 100.0 # 默认满级显示
    show()
    animation_player.play("slide_up")

func hide_phone() -> void:
    animation_player.play("slide_down")

func _on_close_pressed() -> void:
    hide_phone()

func _on_archive_app_pressed() -> void:
    if archive_panel_instance == null:
        var ArchivePanelObj = load("res://scenes/ui/archive/archive_panel.tscn")
        archive_panel_instance = ArchivePanelObj.instantiate()
        phone_panel.add_child(archive_panel_instance)
        archive_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    archive_panel_instance.show_panel()

func _on_camera_app_pressed() -> void:
    if camera_panel_instance == null:
        var CameraPanelObj = load("res://scenes/ui/mobile/camera_panel.tscn")
        camera_panel_instance = CameraPanelObj.instantiate()
        get_tree().get_root().add_child(camera_panel_instance)
        camera_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        camera_panel_instance.camera_closed.connect(_on_camera_closed)
        
    camera_panel_instance.show_panel()
    
    # 隐藏手机界面和主界面UI
    hide_phone()
    # 找到 MainScene 里的 UIPanel 并隐藏
    var main_scene = get_tree().get_root().get_node_or_null("MainScene")
    if main_scene and main_scene.has_node("UIPanel"):
        main_scene.get_node("UIPanel").visible = false

func _on_camera_closed() -> void:
    # 恢复主界面UI并显示手机
    var main_scene = get_tree().get_root().get_node_or_null("MainScene")
    if main_scene and main_scene.has_node("UIPanel"):
        main_scene.get_node("UIPanel").visible = true
    show_phone()

func _on_album_app_pressed() -> void:
    if album_panel_instance == null:
        var AlbumPanelObj = load("res://scenes/ui/mobile/album_panel.tscn")
        album_panel_instance = AlbumPanelObj.instantiate()
        phone_panel.add_child(album_panel_instance)
        album_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        
    # Reset picker mode when opening directly from app list
    album_panel_instance.set_picker_mode(false)
    album_panel_instance.show_panel()

func _on_sms_app_pressed() -> void:
    if contact_list_instance == null:
        var ContactListObj = load("res://scenes/ui/mobile/chat/mobile_contact_list.tscn")
        contact_list_instance = ContactListObj.instantiate()
        phone_panel.add_child(contact_list_instance)
        contact_list_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        contact_list_instance.back_requested.connect(_on_contact_list_back)
        contact_list_instance.character_selected.connect(_on_character_selected)
    contact_list_instance.show_panel()

func _on_contact_list_back() -> void:
    if contact_list_instance:
        contact_list_instance.hide_panel()

func _on_character_selected(char_id: String) -> void:
    if chat_panel_instance == null:
        var ChatPanelObj = load("res://scenes/ui/mobile/chat/mobile_chat_panel.tscn")
        chat_panel_instance = ChatPanelObj.instantiate()
        phone_panel.add_child(chat_panel_instance)
        chat_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        chat_panel_instance.back_requested.connect(_on_chat_panel_back)
        chat_panel_instance.incoming_call_ended.connect(_on_incoming_call_ended)
        
    chat_panel_instance.setup(char_id)
    chat_panel_instance.show_panel()

func _on_chat_panel_back() -> void:
    if chat_panel_instance:
        chat_panel_instance.hide_panel()

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
        
    chat_panel_instance.setup(char_id)
    chat_panel_instance.show_panel()
    
    # 延迟一帧等待 chat_panel 准备完毕，然后直接触发对应的通话按钮并传递参数
    await get_tree().process_frame
    if is_video:
        chat_panel_instance.start_video_call(true, is_fixed)
    else:
        chat_panel_instance.start_voice_call(true, is_fixed)

func _on_animation_finished(anim_name: String) -> void:
    if anim_name == "slide_down":
        hide()
        if chat_panel_instance:
            chat_panel_instance.hide_panel(true)
            if chat_panel_instance.voice_call_panel_instance:
                chat_panel_instance.voice_call_panel_instance.hide()
            if chat_panel_instance.video_call_panel_instance:
                chat_panel_instance.video_call_panel_instance.hide()

