extends Control

signal back_requested
signal character_selected(char_id: String)
signal cover_pick_requested

const RECENT_CHATS_SCENE = preload("res://scenes/ui/mobile/chat/mobile_contact_list.tscn")
const CONTACT_LIST_SCENE = preload("res://scenes/ui/mobile/wechat/wechat_contact_list.tscn")
const CHAT_PANEL_SCENE = preload("res://scenes/ui/mobile/chat/mobile_chat_panel.tscn")
const MOMENTS_PANEL_SCENE = preload("res://scenes/ui/mobile/moments/moments_panel.tscn")

enum PanelMode {
	CHAT,
	CONTACTS
}

@onready var dim_bg: ColorRect = $DimBg
@onready var window_panel: PanelContainer = $CenterContainer/WindowPanel
@onready var btn_chat: Button = $CenterContainer/WindowPanel/MainHBox/NavPanel/NavMargin/NavVBox/BtnChat
@onready var btn_contacts: Button = $CenterContainer/WindowPanel/MainHBox/NavPanel/NavMargin/NavVBox/BtnContacts
@onready var btn_moments: Button = $CenterContainer/WindowPanel/MainHBox/NavPanel/NavMargin/NavVBox/BtnMoments
@onready var btn_close: Button = $CenterContainer/WindowOverlay/BtnClose
@onready var list_title: Label = $CenterContainer/WindowPanel/MainHBox/ListPanel/ListVBox/HeaderVBox/Title
@onready var list_subtitle: Label = $CenterContainer/WindowPanel/MainHBox/ListPanel/ListVBox/HeaderVBox/SubTitle
@onready var list_container: Control = $CenterContainer/WindowPanel/MainHBox/ListPanel/ListVBox/ListContainer
@onready var chat_empty_state: Control = $CenterContainer/WindowPanel/MainHBox/ContentPanel/ContentStack/ChatEmptyState
@onready var contact_empty_state: Control = $CenterContainer/WindowPanel/MainHBox/ContentPanel/ContentStack/ContactEmptyState
@onready var chat_container: Control = $CenterContainer/WindowPanel/MainHBox/ContentPanel/ContentStack/ChatContainer
@onready var contact_detail_panel: ScrollContainer = $CenterContainer/WindowPanel/MainHBox/ContentPanel/ContentStack/ContactDetailPanel
@onready var detail_avatar: TextureRect = $CenterContainer/WindowPanel/MainHBox/ContentPanel/ContentStack/ContactDetailPanel/DetailVBox/HeaderPanel/HeaderVBox/AvatarMask/Avatar
@onready var detail_name: Label = $CenterContainer/WindowPanel/MainHBox/ContentPanel/ContentStack/ContactDetailPanel/DetailVBox/HeaderPanel/HeaderVBox/Name
@onready var detail_meta: Label = $CenterContainer/WindowPanel/MainHBox/ContentPanel/ContentStack/ContactDetailPanel/DetailVBox/HeaderPanel/HeaderVBox/Meta
@onready var detail_tags: Label = $CenterContainer/WindowPanel/MainHBox/ContentPanel/ContentStack/ContactDetailPanel/DetailVBox/HeaderPanel/HeaderVBox/Tags
@onready var detail_desc: Label = $CenterContainer/WindowPanel/MainHBox/ContentPanel/ContentStack/ContactDetailPanel/DetailVBox/InfoPanel/InfoVBox/DescValue
@onready var detail_intimacy: Label = $CenterContainer/WindowPanel/MainHBox/ContentPanel/ContentStack/ContactDetailPanel/DetailVBox/StatsRow/IntimacyCard/CardVBox/Value
@onready var detail_trust: Label = $CenterContainer/WindowPanel/MainHBox/ContentPanel/ContentStack/ContactDetailPanel/DetailVBox/StatsRow/TrustCard/CardVBox/Value
@onready var detail_stage: Label = $CenterContainer/WindowPanel/MainHBox/ContentPanel/ContentStack/ContactDetailPanel/DetailVBox/StatsRow/StageCard/CardVBox/Value
@onready var btn_send_message: Button = $CenterContainer/WindowPanel/MainHBox/ContentPanel/ContentStack/ContactDetailPanel/DetailVBox/ActionRow/BtnSendMessage
@onready var btn_voice_call: Button = $CenterContainer/WindowPanel/MainHBox/ContentPanel/ContentStack/ContactDetailPanel/DetailVBox/ActionRow/BtnVoiceCall
@onready var btn_video_call: Button = $CenterContainer/WindowPanel/MainHBox/ContentPanel/ContentStack/ContactDetailPanel/DetailVBox/ActionRow/BtnVideoCall
@onready var moments_popup_overlay: Control = $MomentsPopupOverlay
@onready var moments_popup_window: PanelContainer = $MomentsPopupOverlay/FloatingWindow
@onready var moments_popup_title_bar: PanelContainer = $MomentsPopupOverlay/FloatingWindow/WindowRoot/TitleBar
@onready var moments_popup_title: Label = $MomentsPopupOverlay/FloatingWindow/WindowRoot/TitleBar/HBox/Title
@onready var moments_popup_close_btn: Button = $MomentsPopupOverlay/FloatingWindow/WindowRoot/TitleBar/HBox/CloseBtn
@onready var moments_popup_host: Control = $MomentsPopupOverlay/FloatingWindow/WindowRoot/ContentHost
@onready var floating_call_overlay: Control = $FloatingCallOverlay
@onready var floating_call_window: PanelContainer = $FloatingCallOverlay/FloatingWindow
@onready var floating_call_title_bar: PanelContainer = $FloatingCallOverlay/FloatingWindow/VBox/TitleBar
@onready var floating_call_title: Label = $FloatingCallOverlay/FloatingWindow/VBox/TitleBar/HBox/Title
@onready var floating_call_close_btn: Button = $FloatingCallOverlay/FloatingWindow/VBox/TitleBar/HBox/CloseBtn
@onready var floating_call_host: Control = $FloatingCallOverlay/FloatingWindow/VBox/ContentHost

var ui_context: Node = null
var recent_chats_instance: Control = null
var contacts_instance: Control = null
var chat_session_instance: Control = null
var moments_instance: Panel = null

var _current_mode: int = PanelMode.CHAT
var _current_chat_char_id: String = ""
var _current_contact_char_id: String = ""
var _floating_call_panel: Control = null
var _moments_popup_open: bool = false
var _drag_window_target: Control = null
var _drag_window_kind: String = ""
var _drag_mouse_offset: Vector2 = Vector2.ZERO
var _drag_press_global: Vector2 = Vector2.ZERO
var _drag_window_origin: Vector2 = Vector2.ZERO
var _drag_started: bool = false
const WINDOW_DRAG_THRESHOLD := 8.0

func _make_embedded_shell_transparent(target: Control) -> void:
	if target == null:
		return
	var panel := target.get_node_or_null("Panel") as Control
	if panel:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(1, 1, 1, 0.0)
		panel.add_theme_stylebox_override("panel", flat)

func _ready() -> void:
	hide()
	btn_chat.pressed.connect(func(): _switch_mode(PanelMode.CHAT))
	btn_contacts.pressed.connect(func(): _switch_mode(PanelMode.CONTACTS))
	btn_moments.pressed.connect(_open_moments_popup)
	btn_close.pressed.connect(func(): back_requested.emit())
	btn_send_message.pressed.connect(_on_send_message_pressed)
	btn_voice_call.pressed.connect(_on_contact_voice_call_pressed)
	btn_video_call.pressed.connect(_on_contact_video_call_pressed)
	moments_popup_close_btn.pressed.connect(_close_moments_popup)
	floating_call_close_btn.pressed.connect(_on_floating_call_close_pressed)
	_refresh_nav_state()
	_show_chat_empty_state()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_begin_window_drag(get_global_mouse_position())
		else:
			_finish_window_drag()
	elif event is InputEventMouseMotion and _drag_window_target:
		_update_window_drag(get_global_mouse_position())

func set_ui_context(context: Node) -> void:
	ui_context = context
	if is_instance_valid(chat_session_instance):
		chat_session_instance.set_ui_context(context)

func open_default_mode() -> void:
	_current_chat_char_id = ""
	_current_contact_char_id = ""
	if recent_chats_instance and recent_chats_instance.has_method("clear_selection"):
		recent_chats_instance.clear_selection()
	if contacts_instance and contacts_instance.has_method("clear_selection"):
		contacts_instance.clear_selection()
	_switch_mode(PanelMode.CHAT)

func _on_tab_pressed(index: int) -> void:
	match index:
		0:
			_switch_mode(PanelMode.CHAT)
		1:
			_switch_mode(PanelMode.CONTACTS)
		2:
			_open_moments_popup()

func _switch_mode(mode: int) -> void:
	_current_mode = mode
	_refresh_nav_state()
	match mode:
		PanelMode.CHAT:
			list_title.text = "聊天列表"
			list_subtitle.text = "最近对话与未读消息"
			_ensure_recent_chats()
			recent_chats_instance.show()
			if contacts_instance:
				contacts_instance.hide()
			recent_chats_instance._load_contacts()
			if _current_chat_char_id != "":
				recent_chats_instance.select_character(_current_chat_char_id, false)
				_open_chat_session(_current_chat_char_id, false)
			else:
				recent_chats_instance.clear_selection()
				_show_chat_empty_state()
		PanelMode.CONTACTS:
			list_title.text = "联系人"
			list_subtitle.text = "查看角色资料与快捷操作"
			_ensure_contacts_list()
			contacts_instance.show()
			if recent_chats_instance:
				recent_chats_instance.hide()
			contacts_instance._load_contacts()
			if _current_contact_char_id != "":
				contacts_instance.select_character(_current_contact_char_id, false)
				_show_contact_detail(_current_contact_char_id)
			else:
				contacts_instance.clear_selection()
				_show_contact_empty_state()

func _refresh_nav_state() -> void:
	_apply_nav_button_state(btn_chat, _current_mode == PanelMode.CHAT)
	_apply_nav_button_state(btn_contacts, _current_mode == PanelMode.CONTACTS)
	_apply_nav_button_state(btn_moments, _moments_popup_open)

func _apply_nav_button_state(button: Button, is_active: bool) -> void:
	var bg := Color(0.90, 0.97, 0.95, 1.0) if is_active else Color(1, 1, 1, 0.0)
	var border := Color(0.57, 0.82, 0.76, 1.0) if is_active else Color(0.88, 0.90, 0.94, 0.0)
	var font_color := Color(0.20, 0.45, 0.38, 1.0) if is_active else Color(0.47, 0.50, 0.57, 1.0)
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_right = 18
	style.corner_radius_bottom_left = 18
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.get_node("Text").add_theme_color_override("font_color", font_color)
	(button.get_node("Icon") as TextureRect).modulate = font_color

func _ensure_recent_chats() -> void:
	if recent_chats_instance:
		return
	recent_chats_instance = RECENT_CHATS_SCENE.instantiate()
	list_container.add_child(recent_chats_instance)
	recent_chats_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_make_embedded_shell_transparent(recent_chats_instance)
	var top_bar = recent_chats_instance.get_node_or_null("Panel/VBox/TopBar")
	if top_bar:
		top_bar.hide()
	recent_chats_instance.character_selected.connect(_on_chat_list_character_selected)

func _ensure_contacts_list() -> void:
	if contacts_instance:
		return
	contacts_instance = CONTACT_LIST_SCENE.instantiate()
	list_container.add_child(contacts_instance)
	contacts_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_make_embedded_shell_transparent(contacts_instance)
	contacts_instance.character_selected.connect(_on_contact_selected)

func _ensure_chat_session() -> void:
	if chat_session_instance:
		return
	chat_session_instance = CHAT_PANEL_SCENE.instantiate()
	chat_container.add_child(chat_session_instance)
	chat_session_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chat_session_instance.set_ui_context(ui_context)
	chat_session_instance.set_embedded_mode(true)
	chat_session_instance.set_call_window_host(self)

func _ensure_moments_popup() -> void:
	if moments_instance:
		return
	moments_instance = MOMENTS_PANEL_SCENE.instantiate()
	moments_popup_host.add_child(moments_instance)
	moments_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top_bar = moments_instance.get_node_or_null("TopBar")
	if top_bar:
		top_bar.hide()
	var top_bar_bg = moments_instance.get_node_or_null("TopBarBg")
	if top_bar_bg:
		top_bar_bg.hide()
	if moments_instance.has_signal("top_style_progress_changed"):
		moments_instance.top_style_progress_changed.connect(_on_moments_top_style_progress_changed)
	moments_instance.back_requested.connect(_close_moments_popup)
	moments_instance.cover_pick_requested.connect(func(): cover_pick_requested.emit())

func _on_chat_list_character_selected(char_id: String) -> void:
	_current_chat_char_id = char_id
	character_selected.emit(char_id)
	_open_chat_session(char_id, false)

func _on_contact_selected(char_id: String) -> void:
	_current_contact_char_id = char_id
	_show_contact_detail(char_id)

func _open_chat_session(char_id: String, emit_signal: bool = true) -> void:
	if char_id == "":
		_show_chat_empty_state()
		return
	_ensure_chat_session()
	chat_session_instance.setup(char_id)
	chat_session_instance.show_panel()
	chat_empty_state.hide()
	contact_empty_state.hide()
	contact_detail_panel.hide()
	chat_container.show()
	if emit_signal:
		character_selected.emit(char_id)

func _show_chat_empty_state() -> void:
	chat_empty_state.show()
	contact_empty_state.hide()
	contact_detail_panel.hide()
	chat_container.hide()

func _show_contact_empty_state() -> void:
	contact_empty_state.show()
	chat_empty_state.hide()
	contact_detail_panel.hide()
	chat_container.hide()

func _show_contact_detail(char_id: String) -> void:
	if char_id == "":
		_show_contact_empty_state()
		return
	var profile := CharacterProfile.new()
	profile.load_profile(char_id)

	detail_name.text = profile.char_name if profile.char_name != "" else char_id
	detail_meta.text = "阶段 %d  ·  好感 %.0f  ·  信任 %.0f" % [profile.current_stage, profile.intimacy, profile.trust]
	if profile.tags.is_empty():
		detail_tags.text = "暂无标签"
	else:
		detail_tags.text = " / ".join(profile.tags)
	detail_desc.text = profile.description if profile.description.strip_edges() != "" else "暂未记录更多资料。"
	detail_intimacy.text = str(int(round(profile.intimacy)))
	detail_trust.text = str(int(round(profile.trust)))
	detail_stage.text = "Lv.%d" % profile.current_stage
	if profile.avatar != "" and ResourceLoader.exists(profile.avatar):
		detail_avatar.texture = load(profile.avatar)
	else:
		detail_avatar.texture = preload("res://icon.svg")

	contact_detail_panel.scroll_vertical = 0
	contact_detail_panel.show()
	chat_empty_state.hide()
	contact_empty_state.hide()
	chat_container.hide()

func _on_send_message_pressed() -> void:
	if _current_contact_char_id == "":
		return
	_current_chat_char_id = _current_contact_char_id
	_switch_mode(PanelMode.CHAT)
	if recent_chats_instance:
		recent_chats_instance.select_character(_current_chat_char_id, false)
	_open_chat_session(_current_chat_char_id)

func _on_contact_voice_call_pressed() -> void:
	if _current_contact_char_id == "":
		return
	_open_chat_session_for_call(_current_contact_char_id, false)

func _on_contact_video_call_pressed() -> void:
	if _current_contact_char_id == "":
		return
	_open_chat_session_for_call(_current_contact_char_id, true)

func _open_chat_session_for_call(char_id: String, is_video: bool) -> void:
	_ensure_chat_session()
	chat_session_instance.setup(char_id)
	chat_session_instance.set_call_window_host(self)
	if is_video:
		chat_session_instance.start_video_call(false)
	else:
		chat_session_instance.start_voice_call(false)

func _open_moments_popup() -> void:
	_ensure_moments_popup()
	_moments_popup_open = true
	_refresh_nav_state()
	moments_popup_overlay.show()
	moments_popup_window.show()
	moments_instance.show_panel()
	_on_moments_top_style_progress_changed(0.0)
	call_deferred("_center_moments_window")

func _close_moments_popup() -> void:
	_moments_popup_open = false
	_refresh_nav_state()
	_cancel_window_drag_if_target(moments_popup_window)
	moments_popup_window.hide()
	moments_popup_overlay.hide()
	if moments_instance:
		moments_instance.hide()

func attach_floating_call_panel(panel: Control, window_title: String, default_size: Vector2) -> void:
	if panel == null:
		return
	_floating_call_panel = panel
	floating_call_title.text = window_title
	floating_call_window.custom_minimum_size = default_size
	floating_call_window.size = default_size
	if panel.get_parent():
		panel.get_parent().remove_child(panel)
	floating_call_host.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.show()

	var ended_callable := Callable(self, "_on_floating_call_panel_ended").bind(panel)
	if panel.has_signal("call_ended") and not panel.call_ended.is_connected(ended_callable):
		panel.call_ended.connect(ended_callable)

	floating_call_overlay.show()
	floating_call_window.show()
	_center_floating_call_window()

func detach_floating_call_panel(panel: Control = null) -> void:
	if panel != null and panel != _floating_call_panel:
		return
	if _floating_call_panel and _floating_call_panel.get_parent() == floating_call_host:
		floating_call_host.remove_child(_floating_call_panel)
	_floating_call_panel = null
	_cancel_window_drag_if_target(floating_call_window)
	floating_call_window.hide()
	floating_call_overlay.hide()

func _on_floating_call_panel_ended(panel: Control) -> void:
	detach_floating_call_panel(panel)

func _on_floating_call_close_pressed() -> void:
	if _floating_call_panel and _floating_call_panel.has_method("_on_hangup_pressed"):
		_floating_call_panel._on_hangup_pressed()
	else:
		detach_floating_call_panel(_floating_call_panel)

func _center_floating_call_window() -> void:
	var viewport_size := get_viewport_rect().size
	var target := (viewport_size - floating_call_window.size) * 0.5
	target += Vector2(130, -10)
	_set_floating_window_position(target)

func _set_floating_window_position(target: Vector2) -> void:
	var viewport_size := get_viewport_rect().size
	var max_x := maxf(0.0, viewport_size.x - floating_call_window.size.x)
	var max_y := maxf(0.0, viewport_size.y - floating_call_window.size.y)
	floating_call_window.position = Vector2(
		clampf(target.x, 0.0, max_x),
		clampf(target.y, 0.0, max_y)
	)

func _center_moments_window() -> void:
	var viewport_size := get_viewport_rect().size
	var window_size: Vector2 = moments_popup_window.size
	if window_size.x <= 1.0 or window_size.y <= 1.0:
		window_size = moments_popup_window.get_combined_minimum_size()
	if window_size.x <= 1.0 or window_size.y <= 1.0:
		window_size = moments_popup_window.custom_minimum_size
	if window_size.x <= 1.0 or window_size.y <= 1.0:
		window_size = Vector2(720, 640)
	moments_popup_window.size = window_size
	var target := (viewport_size - window_size) * 0.5
	_set_moments_window_position(target)

func _set_moments_window_position(target: Vector2) -> void:
	var viewport_size := get_viewport_rect().size
	var max_x := maxf(0.0, viewport_size.x - moments_popup_window.size.x)
	var max_y := maxf(0.0, viewport_size.y - moments_popup_window.size.y)
	moments_popup_window.position = Vector2(
		clampf(target.x, 0.0, max_x),
		clampf(target.y, 0.0, max_y)
	)

func _try_begin_window_drag(mouse_pos: Vector2) -> void:
	if _moments_popup_open and moments_popup_window.visible and _point_in_control(mouse_pos, moments_popup_window):
		if moments_popup_close_btn.get_global_rect().has_point(mouse_pos):
			return
		if _is_pointer_over_interactive(moments_popup_window, mouse_pos, [moments_popup_close_btn]):
			return
		_begin_window_drag("moments", moments_popup_window, mouse_pos)
		return
	if floating_call_window.visible and _floating_call_panel and _point_in_control(mouse_pos, floating_call_window):
		if floating_call_close_btn.get_global_rect().has_point(mouse_pos):
			return
		if _is_pointer_over_interactive(floating_call_window, mouse_pos, [floating_call_close_btn]):
			return
		_begin_window_drag("call", floating_call_window, mouse_pos)

func _begin_window_drag(kind: String, target: Control, mouse_pos: Vector2) -> void:
	_drag_window_kind = kind
	_drag_window_target = target
	_drag_press_global = mouse_pos
	_drag_mouse_offset = mouse_pos - target.global_position
	_drag_window_origin = target.position
	_drag_started = false

func _update_window_drag(mouse_pos: Vector2) -> void:
	if not _drag_window_target:
		return
	if not _drag_started and mouse_pos.distance_to(_drag_press_global) >= WINDOW_DRAG_THRESHOLD:
		_drag_started = true
		if _drag_window_kind == "moments" and moments_instance and moments_instance.has_method("suppress_cover_click_once"):
			moments_instance.suppress_cover_click_once()
	if not _drag_started:
		return
	var parent_control := _drag_window_target.get_parent() as Control
	var parent_global := parent_control.global_position if parent_control else Vector2.ZERO
	var target_pos := mouse_pos - _drag_mouse_offset - parent_global
	if _drag_window_kind == "moments":
		_set_moments_window_position(target_pos)
	else:
		_set_floating_window_position(target_pos)

func _finish_window_drag() -> void:
	_drag_window_target = null
	_drag_window_kind = ""
	_drag_started = false

func _cancel_window_drag_if_target(target: Control) -> void:
	if _drag_window_target == target:
		_finish_window_drag()

func _point_in_control(point: Vector2, control: Control) -> bool:
	return control != null and control.get_global_rect().has_point(point)

func _is_pointer_over_interactive(root: Node, point: Vector2, excluded: Array = []) -> bool:
	if root is BaseButton:
		if excluded.has(root):
			return false
		return (root as Control).visible and (root as Control).get_global_rect().has_point(point)
	if root is Control:
		var control := root as Control
		if control.mouse_filter == Control.MOUSE_FILTER_IGNORE or not control.visible:
			pass
		else:
			if (control is LineEdit or control is TextEdit or control is RichTextLabel or control is OptionButton):
				if excluded.has(control):
					return false
				if control.get_global_rect().has_point(point):
					return true
	for child in root.get_children():
		if _is_pointer_over_interactive(child, point, excluded):
			return true
	return false

func _on_moments_top_style_progress_changed(progress: float) -> void:
	var title_bar_style := StyleBoxFlat.new()
	title_bar_style.bg_color = Color(0.985, 0.988, 0.995, progress * 0.96)
	title_bar_style.draw_center = progress > 0.01
	moments_popup_title_bar.add_theme_stylebox_override("panel", title_bar_style)
	var title_color := Color(1, 1, 1, 1).lerp(Color(0.30, 0.35, 0.35, 1), progress)
	moments_popup_title.add_theme_color_override("font_color", title_color)
	moments_popup_close_btn.add_theme_color_override("font_color", title_color)

func show_panel(animated: bool = true) -> void:
	open_default_mode()
	show()
	window_panel.scale = Vector2.ONE
	if not animated:
		dim_bg.color.a = 0.24
		window_panel.modulate.a = 1.0
		return

	dim_bg.color.a = 0.0
	window_panel.modulate.a = 0.0
	window_panel.scale = Vector2(0.96, 0.96)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(dim_bg, "color:a", 0.34, 0.18)
	tween.tween_property(window_panel, "modulate:a", 1.0, 0.22)
	tween.tween_property(window_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func hide_panel(immediate: bool = false) -> void:
	_close_moments_popup()
	detach_floating_call_panel(_floating_call_panel)
	if immediate:
		hide()
		return

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(dim_bg, "color:a", 0.0, 0.16)
	tween.tween_property(window_panel, "modulate:a", 0.0, 0.16)
	tween.tween_property(window_panel, "scale", Vector2(0.96, 0.96), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(hide)
