extends Control

signal back_requested
signal character_selected
signal cover_pick_requested

const RECENT_CHATS_SCENE = preload("res://scenes/ui/mobile/chat/mobile_contact_list.tscn")
const CONTACT_LIST_SCENE = preload("res://scenes/ui/mobile/wechat/wechat_contact_list.tscn")
const MOMENTS_PANEL_SCENE = preload("res://scenes/ui/mobile/moments/moments_panel.tscn")

@onready var content_container = $ContentContainer
@onready var btn_chat = $BottomNav/HBox/BtnChat
@onready var btn_contacts = $BottomNav/HBox/BtnContacts
@onready var btn_moments = $BottomNav/HBox/BtnMoments
@onready var title_label = $TopBar/Title
@onready var back_btn = $TopBar/BackBtn
@onready var top_bar_bg: ColorRect = $TopBarBg

var recent_chats_instance = null
var contacts_instance = null
var moments_instance = null

func _ready() -> void:
    back_btn.pressed.connect(func(): back_requested.emit())
    btn_chat.pressed.connect(_on_tab_pressed.bind(0))
    btn_contacts.pressed.connect(_on_tab_pressed.bind(1))
    btn_moments.pressed.connect(_on_tab_pressed.bind(2))
    
    _on_tab_pressed(0)

func _on_tab_pressed(index: int) -> void:
    # Reset button styles/colors
    var inactive_color = Color(0.5, 0.5, 0.6)
    var active_color = Color(0.1, 0.8, 0.4)
    btn_chat.add_theme_color_override("font_color", inactive_color if index != 0 else active_color)
    btn_contacts.add_theme_color_override("font_color", inactive_color if index != 1 else active_color)
    btn_moments.add_theme_color_override("font_color", inactive_color if index != 2 else active_color)
    
    # Hide all contents
    if recent_chats_instance: recent_chats_instance.hide()
    if contacts_instance: contacts_instance.hide()
    if moments_instance: moments_instance.hide()
    
    if index == 0:
        title_label.text = "微聊"
        if not recent_chats_instance:
            recent_chats_instance = RECENT_CHATS_SCENE.instantiate()
            content_container.add_child(recent_chats_instance)
            recent_chats_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
            # Hide its own TopBar
            var top_bar = recent_chats_instance.get_node_or_null("Panel/VBox/TopBar")
            if top_bar: top_bar.hide()
            # Forward character_selected signal
            recent_chats_instance.character_selected.connect(func(char_id): character_selected.emit(char_id))
        recent_chats_instance.show()
        if recent_chats_instance.has_method("_load_contacts"):
            recent_chats_instance._load_contacts()
        _apply_standard_top_bar()
            
    elif index == 1:
        title_label.text = "通讯录"
        if not contacts_instance:
            contacts_instance = CONTACT_LIST_SCENE.instantiate()
            content_container.add_child(contacts_instance)
            contacts_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
            contacts_instance.character_selected.connect(func(char_id): character_selected.emit(char_id))
        contacts_instance.show()
        if contacts_instance.has_method("_load_contacts"):
            contacts_instance._load_contacts()
        _apply_standard_top_bar()
            
    elif index == 2:
        title_label.text = "朋友圈"
        if not moments_instance:
            moments_instance = MOMENTS_PANEL_SCENE.instantiate()
            content_container.add_child(moments_instance)
            moments_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
            # Hide its own TopBar
            var top_bar = moments_instance.get_node_or_null("TopBar")
            if top_bar: top_bar.hide()
            var top_bar_bg_node = moments_instance.get_node_or_null("TopBarBg")
            if top_bar_bg_node: top_bar_bg_node.hide()
            # connect cover pick
            moments_instance.cover_pick_requested.connect(func(): cover_pick_requested.emit())
            if moments_instance.has_signal("top_style_progress_changed"):
                moments_instance.top_style_progress_changed.connect(_apply_moments_top_style)
        moments_instance.show()
        if moments_instance.has_method("refresh_list"):
            moments_instance.refresh_list()
        if moments_instance and moments_instance.has_node("Scroll"):
            var scroll := moments_instance.get_node("Scroll") as ScrollContainer
            if scroll:
                _apply_moments_top_style(_get_moments_scroll_progress(scroll.scroll_vertical))
        else:
            _apply_moments_top_style(0.0)

func show_panel(animated: bool = true) -> void:
    show()
    if not animated:
        position.x = 0.0
        modulate.a = 1.0
        return
    # position slide in
    position.x = size.x
    modulate.a = 0.0
    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(self, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "modulate:a", 1.0, 0.2)

func hide_panel(immediate: bool = false) -> void:
    if immediate:
        hide()
        return
    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(self, "position:x", size.x, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    tween.tween_property(self, "modulate:a", 0.0, 0.2)
    tween.chain().tween_callback(self.hide)

func _apply_standard_top_bar() -> void:
    top_bar_bg.color = Color(0.985, 0.988, 0.995, 0.98)
    title_label.add_theme_color_override("font_color", Color(0.3, 0.35, 0.35, 1))
    back_btn.add_theme_color_override("font_color", Color(0.3, 0.35, 0.35, 1))

func _apply_moments_top_style(progress: float) -> void:
    top_bar_bg.color = Color(0.985, 0.988, 0.995, progress * 0.98)
    var font_color := Color(1, 1, 1, 1).lerp(Color(0.3, 0.35, 0.35, 1), progress)
    title_label.add_theme_color_override("font_color", font_color)
    back_btn.add_theme_color_override("font_color", font_color)

func _get_moments_scroll_progress(scroll_value: float) -> float:
    if not moments_instance or not moments_instance.has_method("get_header_height"):
        return 0.0
    var header_height := float(moments_instance.get_header_height())
    var fade_start := 32.0
    var fade_end := maxf(120.0, header_height - 92.0)
    return clamp((scroll_value - fade_start) / maxf(1.0, fade_end - fade_start), 0.0, 1.0)
