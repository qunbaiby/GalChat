extends Control

signal app_opened(app_name: String)

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var phone_panel: PanelContainer = $PhonePanel

@onready var big_time: Label = $PhonePanel/MainMargin/VBox/TimeHBox/BigTime
@onready var date_lbl: Label = $PhonePanel/MainMargin/VBox/TimeHBox/DateLabel
@onready var archive_btn: Button = $PhonePanel/MainMargin/VBox/CardsHBox/Card2/ArchiveBtn
@onready var power_btn: Button = $PhonePanel/MainMargin/VBox/PowerBtn
@onready var sms_btn: Button = $PhonePanel/MainMargin/VBox/ListVBox/List1/SmsBtn

var archive_panel_instance = null
var contact_list_instance = null
var chat_panel_instance = null

func _ready() -> void:
    animation_player.animation_finished.connect(_on_animation_finished)
    
    # 绑定信号
    archive_btn.pressed.connect(_on_archive_app_pressed)
    power_btn.pressed.connect(_on_close_pressed)
    sms_btn.pressed.connect(_on_sms_app_pressed)

func _process(delta: float) -> void:
    if visible:
        _update_time()

func _update_time() -> void:
    if not is_instance_valid(big_time) or not is_instance_valid(date_lbl):
        return
        
    var time_dict = Time.get_time_dict_from_system()
    big_time.text = "%02d:%02d" % [time_dict.hour, time_dict.minute]
    
    var date_dict = Time.get_date_dict_from_system()
    var wdays = ["日", "一", "二", "三", "四", "五", "六"]
    date_lbl.text = "  %d月%d日 星期%s" % [date_dict.month, date_dict.day, wdays[date_dict.weekday]]

func show_phone() -> void:
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
        
    chat_panel_instance.setup(char_id)
    chat_panel_instance.show_panel()

func _on_chat_panel_back() -> void:
    if chat_panel_instance:
        chat_panel_instance.hide_panel()

func _on_animation_finished(anim_name: String) -> void:
    if anim_name == "slide_down":
        hide()

