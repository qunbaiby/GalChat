extends Control

const PhotoMemoryManagerScript = preload("res://scripts/data/photo_memory_manager.gd")

signal incoming_call_ended

@onready var title_label: Label = $MobileChatMargin/Panel/VBox/TopBar/Title
@onready var more_btn: Button = $MobileChatMargin/Panel/VBox/TopBar/MoreBtn
@onready var more_menu_popup: PanelContainer = $MobileChatMargin/Panel/MoreMenuPopup
@onready var voice_call_option_btn: Button = $MobileChatMargin/Panel/MoreMenuPopup/PopupMargin/PopupVBox/VoiceCallOption
@onready var video_call_option_btn: Button = $MobileChatMargin/Panel/MoreMenuPopup/PopupMargin/PopupVBox/VideoCallOption
@onready var panel_bg: Panel = $MobileChatMargin/Panel
@onready var top_bar: HBoxContainer = $MobileChatMargin/Panel/VBox/TopBar
@onready var scroll_margin: MarginContainer = $MobileChatMargin/Panel/VBox/ScrollContainer/Margin
@onready var bottom_area: VBoxContainer = $MobileChatMargin/Panel/VBox/BottomArea
@onready var attachment_panel: PanelContainer = $MobileChatMargin/Panel/VBox/BottomArea/AttachmentPanel
@onready var attachment_row: HBoxContainer = $MobileChatMargin/Panel/VBox/BottomArea/AttachmentPanel/AttachmentMargin/AttachmentRow
@onready var message_list: VBoxContainer = $MobileChatMargin/Panel/VBox/ScrollContainer/Margin/MessageList
@onready var input_row: HBoxContainer = $MobileChatMargin/Panel/VBox/BottomArea/InputRow
@onready var input_edit: LineEdit = $MobileChatMargin/Panel/VBox/BottomArea/InputRow/InputEdit
@onready var send_btn: Button = $MobileChatMargin/Panel/VBox/BottomArea/InputRow/SendBtn
@onready var plus_btn: Button = $MobileChatMargin/Panel/VBox/BottomArea/InputRow/PlusBtn
@onready var fixed_options_container: VBoxContainer = $MobileChatMargin/Panel/VBox/BottomArea/FixedOptionsContainer
@onready var image_btn: TextureButton = $MobileChatMargin/Panel/VBox/BottomArea/AttachmentPanel/AttachmentMargin/AttachmentRow/ImageBtn/Btn
@onready var red_packet_btn: TextureButton = $MobileChatMargin/Panel/VBox/BottomArea/AttachmentPanel/AttachmentMargin/AttachmentRow/RedPacketBtn/Btn
@onready var scroll_container: ScrollContainer = $MobileChatMargin/Panel/VBox/ScrollContainer
@onready var deepseek_client = $DeepSeekClient

@onready var image_overlay: Control = $ImageOverlay
@onready var full_image: TextureRect = $ImageOverlay/FullImage
@onready var close_viewer_btn: Button = $ImageOverlay/CloseViewerBtn
@onready var save_to_album_btn: Button = $ImageOverlay/SaveToAlbumBtn

@onready var red_packet_overlay: Control = $RedPacketOverlay
@onready var rp_close_btn: Button = $RedPacketOverlay/VBox/TopBar/CloseBtn
@onready var rp_amount_input: LineEdit = $RedPacketOverlay/VBox/Margin/FormVBox/AmountPanel/HBox/AmountInput
@onready var rp_text_input: LineEdit = $RedPacketOverlay/VBox/Margin/FormVBox/TextPanel/TextInput
@onready var rp_display_amount: Label = $RedPacketOverlay/VBox/Margin/FormVBox/DisplayAmount
@onready var rp_send_btn: Button = $RedPacketOverlay/VBox/Margin/FormVBox/SendRPBtn

var audio_player: AudioStreamPlayer = null

var current_char_id: String = ""
var char_profile: CharacterProfile = null
var chat_history: Array = []
var current_call_history: Array = [] # 专门用于通话上下文的独立历史记录
var voice_call_panel_instance = null
var is_voice_call_mode: bool = false
var video_call_panel_instance = null
var _current_call_is_incoming: bool = false
var _current_viewing_image_path: String = ""
var _pending_memory_observation_text: String = ""
var ui_context: Node = null
var call_window_host: Node = null
var is_embedded_mode: bool = false
var _default_panel_style: StyleBox = null
var _default_panel_minimum_size: Vector2 = Vector2.ZERO
var _default_top_bar_height: float = 60.0

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

func _ready() -> void:
	more_btn.pressed.connect(_on_more_btn_pressed)
	send_btn.pressed.connect(_on_send_pressed)
	plus_btn.pressed.connect(_on_plus_btn_pressed)
	input_edit.text_submitted.connect(_on_input_submitted)
	input_edit.gui_input.connect(_on_input_edit_gui_input)
	scroll_container.gui_input.connect(_on_message_area_gui_input)
	voice_call_option_btn.pressed.connect(_on_voice_call_option_pressed)
	video_call_option_btn.pressed.connect(_on_video_call_option_pressed)
	image_btn.pressed.connect(_on_image_btn_pressed)
	red_packet_btn.pressed.connect(_on_red_packet_pressed)
	
	close_viewer_btn.pressed.connect(_on_close_viewer_pressed)
	save_to_album_btn.pressed.connect(_on_save_to_album_pressed)
	
	rp_close_btn.pressed.connect(_on_rp_close_pressed)
	rp_amount_input.text_changed.connect(_on_rp_amount_changed)
	rp_send_btn.pressed.connect(_on_rp_send_pressed)
	
	if deepseek_client:
		deepseek_client.realize_turn_completed.connect(_on_realize_turn_completed)
		deepseek_client.realize_turn_failed.connect(_on_realize_turn_failed)
		
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	TTSManager.tts_success.connect(_on_tts_success)
	TTSManager.tts_failed.connect(_on_tts_failed)
	_default_panel_style = panel_bg.get_theme_stylebox("panel")
	_default_panel_minimum_size = custom_minimum_size
	_default_top_bar_height = top_bar.custom_minimum_size.y
	_hide_attachment_panel()
	_hide_more_menu()
	_apply_panel_mode()
	
	if MobileFixedChatManager.has_signal("unread_count_changed"):
		MobileFixedChatManager.unread_count_changed.connect(_on_fixed_chat_unread_changed)
	if MobileFixedChatManager.has_signal("character_typing_state_changed"):
		MobileFixedChatManager.character_typing_state_changed.connect(_on_character_typing_state_changed)

func _on_character_typing_state_changed(char_id: String, is_typing: bool) -> void:
	if char_id != current_char_id or not is_visible_in_tree():
		return

	# Find existing typing bubble
	var existing_typing_bubble = null
	for child in message_list.get_children():
		if child.has_meta("is_typing_bubble") and not child.is_queued_for_deletion():
			existing_typing_bubble = child
			break

	if is_typing:
		if existing_typing_bubble == null:
			var character_bubble_scene = load("res://scenes/ui/mobile/chat/bubbles/character_bubble.tscn")
			var bubble = character_bubble_scene.instantiate()
			message_list.add_child(bubble)
			message_list.move_child(bubble, -1)
			bubble.set_meta("is_typing_bubble", true)
			var msg = {
				"speaker": current_char_id,
				"type": "typing",
				"text": "..."
			}
			var c_profile_dict = {}
			if char_profile:
				c_profile_dict["avatar_path"] = char_profile.avatar
			bubble.setup(msg, c_profile_dict)
			
			await get_tree().process_frame
			scroll_container.scroll_vertical = roundi(scroll_container.get_v_scroll_bar().max_value)
	else:
		if existing_typing_bubble != null:
			existing_typing_bubble.queue_free()

func _on_fixed_chat_unread_changed(char_id: String, unread_count: int) -> void:
	if char_id == current_char_id and is_visible_in_tree():
		_latest_fixed_chat_unread_count = unread_count
		if _fixed_chat_refresh_queued:
			return
		_fixed_chat_refresh_queued = true
		call_deferred("_refresh_fixed_chat_view_from_manager")

func _refresh_fixed_chat_view_from_manager() -> void:
	_fixed_chat_refresh_queued = false
	# 强制销毁可能残留的正在输入气泡
	for child in message_list.get_children():
		if child.has_meta("is_typing_bubble") and not child.is_queued_for_deletion():
			child.queue_free()
			break
	_load_mobile_history()
	if _latest_fixed_chat_unread_count > 0:
		_mark_all_incoming_messages_read()
	_render_history()
	_check_fixed_chat_state()

var _fixed_chat_completion_reported: bool = false
var _fixed_chat_refresh_queued: bool = false
var _latest_fixed_chat_unread_count: int = 0

func _check_fixed_chat_state() -> void:
	var is_free_chat_enabled = true
	if GameDataManager.config:
		is_free_chat_enabled = GameDataManager.config.free_chat_enabled

	var active_script = MobileFixedChatManager.get_active_script_for_char(current_char_id)
	if active_script != "":
		_fixed_chat_completion_reported = false
		input_row.hide()
		var options = MobileFixedChatManager.get_current_options(active_script)
		if options.size() > 0:
			if input_edit.text == "对方正在输入...":
				input_edit.text = ""
			_show_fixed_options(options, active_script)
		else:
			_hide_fixed_options()
			input_edit.editable = false
			send_btn.disabled = true
			input_edit.text = "对方正在输入..."
	else:
		_hide_fixed_options()
		if has_fixed_chat_completion_notice():
			input_row.hide()
			input_edit.editable = false
			send_btn.disabled = true
			input_edit.text = ""
			more_btn.hide()
			plus_btn.hide()
		elif not is_free_chat_enabled:
			input_row.hide()
			input_edit.editable = false
			send_btn.disabled = true
			input_edit.text = "自由聊天已关闭"
			more_btn.hide()
			plus_btn.hide()
		else:
			input_row.show()
			input_edit.editable = true
			send_btn.disabled = false
			input_edit.text = ""
			more_btn.show()
			plus_btn.show()
	_try_report_fixed_chat_conversation_finished()

func _show_fixed_options(options: Array, script_id: String) -> void:
	_hide_fixed_options()
	fixed_options_container.show()
	input_row.hide()
	input_edit.editable = false
	send_btn.disabled = true
	input_edit.text = ""
	for opt in options:
		var btn = Button.new()
		btn.text = opt.get("text", "")
		btn.custom_minimum_size = Vector2(0, 36)
		btn.pressed.connect(_on_fixed_option_pressed.bind(script_id, opt.get("id", ""), btn.text))
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.9, 0.9, 0.9, 1.0)
		style.border_color = Color(0.8, 0.8, 0.8, 1.0)
		style.border_width_bottom = 1
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.content_margin_left = 12
		style.content_margin_right = 12
		btn.add_theme_stylebox_override("normal", style)
		
		var hover_style = style.duplicate()
		hover_style.bg_color = Color(0.85, 0.85, 0.85, 1.0)
		btn.add_theme_stylebox_override("hover", hover_style)
		
		btn.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(0.1, 0.1, 0.1, 1.0))
		
		fixed_options_container.add_child(btn)
	call_deferred("_refresh_current_guide_highlight")

func _hide_fixed_options() -> void:
	fixed_options_container.hide()
	for child in fixed_options_container.get_children():
		child.queue_free()

func _on_fixed_option_pressed(script_id: String, option_id: String, text: String) -> void:
	if not _is_guide_interaction_allowed("wechat.fixed_option"):
		_notify_guide_interaction_blocked()
		return
	_report_guide_action("wechat_select_player_option")
	_hide_fixed_options()
	MobileFixedChatManager.submit_player_option(script_id, option_id, text)

func set_ui_context(context: Node) -> void:
	ui_context = context

func set_call_window_host(host: Node) -> void:
	call_window_host = host

func set_embedded_mode(enabled: bool) -> void:
	is_embedded_mode = enabled
	if is_node_ready():
		_apply_panel_mode()

func _apply_panel_mode() -> void:
	if more_btn:
		more_btn.visible = true
	if not is_instance_valid(panel_bg):
		return
	if is_embedded_mode:
		custom_minimum_size = Vector2.ZERO
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		top_bar.custom_minimum_size = Vector2(0, 34)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		scroll_margin.add_theme_constant_override("margin_left", 16)
		scroll_margin.add_theme_constant_override("margin_top", 4)
		scroll_margin.add_theme_constant_override("margin_right", 16)
		scroll_margin.add_theme_constant_override("margin_bottom", 10)
		bottom_area.add_theme_constant_override("separation", 10)
		attachment_row.add_theme_constant_override("separation", 16)
		attachment_row.alignment = BoxContainer.ALIGNMENT_CENTER
		var embedded_style := StyleBoxFlat.new()
		embedded_style.bg_color = Color(1, 1, 1, 0.0)
		embedded_style.border_width_left = 0
		embedded_style.border_width_top = 0
		embedded_style.border_width_right = 0
		embedded_style.border_width_bottom = 0
		panel_bg.add_theme_stylebox_override("panel", embedded_style)
	else:
		custom_minimum_size = _default_panel_minimum_size
		top_bar.custom_minimum_size = Vector2(0, _default_top_bar_height)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		scroll_margin.add_theme_constant_override("margin_left", 15)
		scroll_margin.add_theme_constant_override("margin_top", 15)
		scroll_margin.add_theme_constant_override("margin_right", 15)
		scroll_margin.add_theme_constant_override("margin_bottom", 15)
		bottom_area.add_theme_constant_override("separation", 15)
		attachment_row.add_theme_constant_override("separation", 20)
		attachment_row.alignment = BoxContainer.ALIGNMENT_CENTER
		if _default_panel_style:
			panel_bg.add_theme_stylebox_override("panel", _default_panel_style)

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	var point := mouse_event.position
	if attachment_panel.visible:
		if not _is_point_inside_control(attachment_panel, point) and not _is_point_inside_control(plus_btn, point):
			_hide_attachment_panel()
	if more_menu_popup.visible:
		if not _is_point_inside_control(more_menu_popup, point) and not _is_point_inside_control(more_btn, point):
			_hide_more_menu()

func _is_point_inside_control(control: Control, point: Vector2) -> bool:
	if control == null or not is_instance_valid(control) or not control.visible:
		return false
	return control.get_global_rect().has_point(point)

func _toggle_attachment_panel() -> void:
	if attachment_panel.visible:
		_hide_attachment_panel()
	else:
		_hide_more_menu()
		attachment_panel.show()

func _hide_attachment_panel() -> void:
	if attachment_panel:
		attachment_panel.hide()

func _toggle_more_menu() -> void:
	if more_menu_popup.visible:
		_hide_more_menu()
	else:
		_hide_attachment_panel()
		more_menu_popup.show()

func _hide_more_menu() -> void:
	if more_menu_popup:
		more_menu_popup.hide()

func _on_more_btn_pressed() -> void:
	if not _is_guide_interaction_allowed("wechat.more"):
		_notify_guide_interaction_blocked()
		return
	_toggle_more_menu()

func _on_plus_btn_pressed() -> void:
	if not _is_guide_interaction_allowed("wechat.plus"):
		_notify_guide_interaction_blocked()
		return
	_toggle_attachment_panel()

func _on_input_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not _is_guide_interaction_allowed("wechat.input_edit"):
			_notify_guide_interaction_blocked()
			accept_event()
			return
		_hide_attachment_panel()
		_hide_more_menu()

func _on_message_area_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	var guide_manager = get_node_or_null("/root/GuideManager")
	if guide_manager and guide_manager.has_method("get_current_step_id"):
		if str(guide_manager.get_current_step_id()) == "explain_wechat_chat_session" and guide_manager.has_method("report_action"):
			guide_manager.report_action("wechat_view_chat_session")
			accept_event()
			return

func _on_voice_call_option_pressed() -> void:
	_hide_more_menu()
	_on_voice_call_pressed()

func _on_video_call_option_pressed() -> void:
	_hide_more_menu()
	_on_video_call_pressed()

func _resolve_ui_context() -> Node:
	if is_instance_valid(ui_context):
		return ui_context
	var current := get_parent()
	while current:
		if current.has_method("_on_album_app_pressed") or current.has_method("_update_social_entry_labels"):
			return current
		current = current.get_parent()
	return null

func _refresh_top_status_panel() -> void:
	var top_panel = get_tree().get_root().find_child("TopStatusPanel", true, false)
	if top_panel and top_panel.has_method("_update_ui"):
		top_panel._update_ui()

func _mount_call_panel(panel: Control, window_title: String, default_size: Vector2) -> void:
	if is_instance_valid(call_window_host) and call_window_host.has_method("attach_floating_call_panel"):
		call_window_host.attach_floating_call_panel(panel, window_title, default_size)
		return

	if panel.get_parent() != self:
		if panel.get_parent():
			panel.get_parent().remove_child(panel)
		add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func get_message_area_target() -> Control:
	return scroll_container

func get_message_list_target() -> Control:
	return message_list

func get_first_character_message_target() -> Control:
	for child in message_list.get_children():
		if child is Control and str(child.get_meta("guide_message_speaker", "")) == "char" and child.is_visible_in_tree():
			return child as Control
	return message_list

func get_first_character_message_focus_entry() -> Dictionary:
	var message_row := get_first_character_message_target()
	if message_row == message_list:
		return {}
	var avatar_margin := message_row.get_node_or_null("AvatarMargin") as Control
	var bubble_panel := message_row.get_node_or_null("BubblePanel") as Control
	if not is_instance_valid(avatar_margin) or not is_instance_valid(bubble_panel):
		return {}
	var rect := avatar_margin.get_global_rect().merge(bubble_panel.get_global_rect())
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return {}
	return {
		"rect": rect,
		"shape": "rect",
		"shape_params": {
			"corner_radius": 18.0
		}
	}

func get_fixed_options_target() -> Control:
	if is_instance_valid(fixed_options_container) and fixed_options_container.visible and fixed_options_container.get_child_count() > 0:
		return fixed_options_container
	return bottom_area

func get_input_edit_target() -> Control:
	return input_row

func get_send_button_target() -> Control:
	return send_btn

func is_fixed_options_ready_for_guide() -> bool:
	return is_instance_valid(fixed_options_container) and fixed_options_container.is_visible_in_tree() and fixed_options_container.get_child_count() > 0

func is_input_edit_ready_for_guide() -> bool:
	return is_instance_valid(input_edit) and input_edit.is_visible_in_tree()

func is_send_button_ready_for_guide() -> bool:
	return is_instance_valid(send_btn) and send_btn.is_visible_in_tree()

func has_fixed_chat_completion_notice() -> bool:
	if chat_history.is_empty():
		return false
	for index in range(chat_history.size() - 1, -1, -1):
		var raw_msg: Variant = chat_history[index]
		if not (raw_msg is Dictionary):
			continue
		var msg: Dictionary = raw_msg
		var text := str(msg.get("text", "")).strip_edges()
		if text.find("对话已结束") != -1:
			return true
		if str(msg.get("speaker", "")).strip_edges() != "system":
			break
	return false

func _try_report_fixed_chat_conversation_finished() -> void:
	if _fixed_chat_completion_reported:
		return
	if current_char_id == "":
		return
	if MobileFixedChatManager.get_active_script_for_char(current_char_id) != "":
		return
	if not has_fixed_chat_completion_notice():
		return
	var guide_manager := _get_guide_manager()
	if guide_manager == null or not guide_manager.has_method("get_current_step_id"):
		return
	if str(guide_manager.get_current_step_id()) != "explain_wechat_fixed_conversation":
		return
	_fixed_chat_completion_reported = true
	if guide_manager.has_method("report_action"):
		guide_manager.report_action("wechat_fixed_conversation_finished")

func _get_guide_manager() -> Node:
	return get_node_or_null("/root/GuideManager")

func _report_guide_action(action_id: String) -> void:
	var guide_manager := _get_guide_manager()
	if guide_manager and guide_manager.has_method("report_action"):
		guide_manager.report_action(action_id)

func _refresh_current_guide_highlight() -> void:
	var guide_manager := _get_guide_manager()
	if guide_manager and guide_manager.has_method("refresh_current_step_display"):
		guide_manager.refresh_current_step_display()

func _is_guide_interaction_allowed(interaction_id: String) -> bool:
	var guide_manager := _get_guide_manager()
	if guide_manager and guide_manager.has_method("is_guide_interaction_allowed"):
		return bool(guide_manager.is_guide_interaction_allowed(interaction_id))
	return true

func _notify_guide_interaction_blocked() -> void:
	if typeof(ToastManager) != TYPE_NIL and ToastManager.has_method("show_system_toast"):
		ToastManager.show_system_toast("请先按当前高亮区域完成引导操作")
		
func _on_tts_success(stream: AudioStream, _text: String) -> void:
	if audio_player:
		audio_player.stream = stream
		audio_player.play()

func _on_tts_failed(err_msg: String, _text: String) -> void:
	print("Mobile Chat TTS Failed: ", err_msg)

func setup(char_id: String) -> void:
	current_char_id = char_id
	_fixed_chat_completion_reported = false
	
	# Load profile
	char_profile = CharacterProfile.new()
	char_profile.load_profile(char_id)
	
	title_label.text = char_profile.char_name
	
	# Load history
	_load_mobile_history()
	_mark_all_incoming_messages_read()
	_render_history()
	_notify_mobile_social_changed()
	_check_fixed_chat_state()

func _on_red_packet_pressed() -> void:
	_hide_attachment_panel()
	red_packet_overlay.show()
	rp_amount_input.text = ""
	rp_text_input.text = ""
	rp_display_amount.text = "¥ 0.00"

func _on_rp_close_pressed() -> void:
	red_packet_overlay.hide()

func _on_rp_amount_changed(new_text: String) -> void:
	var amount = new_text.to_int()
	rp_display_amount.text = "¥ " + str(amount) + ".00"

func _on_rp_send_pressed() -> void:
	var amount = rp_amount_input.text.to_int()
	if amount <= 0:
		return
	if GameDataManager.profile.gold < amount:
		# 钱不够
		return
	
	GameDataManager.profile.gold -= amount
	GameDataManager.profile.save_profile()
	
	_refresh_top_status_panel()
	
	red_packet_overlay.hide()
	
	var text = rp_text_input.text
	if text == "":
		text = "恭喜发财，大吉大利"
		
	# 发送红包消息
	var msg_data = {
		"speaker": "player",
		"type": "red_packet",
		"text": text,
		"amount": amount,
		"status": "unclaimed" # unclaimed, claimed, expired
	}
	_add_message_to_ui(msg_data)
	chat_history.append(msg_data)
	_save_mobile_history()
	
	# 模拟AI领取红包
	await get_tree().create_timer(1.5).timeout
	if msg_data["status"] == "unclaimed":
		msg_data["status"] = "claimed"
		var sys_msg = {
			"speaker": "system",
			"type": "system",
			"text": current_char_id.capitalize() + "领取了你的红包"
		}
		chat_history.append(sys_msg)
		_save_mobile_history()
		_load_mobile_history()
		_render_history()
		
		var recent_messages: Array = []
		var recent = chat_history.slice(-10)
		for msg in recent:
			var normalized_msg = _normalize_history_message(msg)
			var msg_speaker = normalized_msg.get("speaker", "")
			var msg_text = normalized_msg.get("text", "")
			if normalized_msg.get("type", "") == "red_packet" and (msg_speaker == "player" or msg_speaker == "user") and str(msg_text) == text:
				continue
			var role = "user" if msg_speaker == "player" or msg_speaker == "user" or msg_speaker == "system" else "assistant"
			var msg_content = str(msg_text)
			
			if normalized_msg.get("type", "") == "system":
				msg_content = "【系统提示：%s】" % msg_content
			elif normalized_msg.get("type", "") == "red_packet":
				msg_content = "【系统提示：[%s发了一个红包: %s]】" % [
					"玩家" if msg_speaker == "player" or msg_speaker == "user" else "你", 
					msg_content
				]
			elif msg_content.begins_with("[img]") and msg_content.ends_with("[/img]"):
				msg_content = "【系统提示：[%s发送了一张照片]】" % ("玩家" if msg_speaker == "player" or msg_speaker == "user" else "你")
				
			recent_messages.append({"role": role, "content": msg_content})
		
		input_edit.editable = false
		send_btn.disabled = true
		_pending_memory_observation_text = ""
		deepseek_client.send_realize_turn_message(text, "mobile_chat", {
			"channel": "mobile_red_packet",
			"recent_messages": recent_messages,
			"additional_authoritative_context": "玩家刚刚向角色发送了一个%dG红包，红包留言原文见 current_player_turn；角色已经领取该红包。" % amount
		})

func _on_image_btn_pressed() -> void:
	_hide_attachment_panel()
	print("Image button pressed!")
	var mobile_interface = _resolve_ui_context()
	var has_album_handler: Variant = "null"
	if mobile_interface:
		has_album_handler = mobile_interface.has_method("_on_album_app_pressed")
	print("mobile_interface: ", mobile_interface, ", has method: ", has_album_handler)
	if mobile_interface and mobile_interface.has_method("_on_album_app_pressed"):
		mobile_interface._on_album_app_pressed()
		
		# Set picker mode for album
		if mobile_interface.album_panel_instance:
			mobile_interface.album_panel_instance.set_picker_mode(true)
			# We need to connect once
			if not mobile_interface.album_panel_instance.is_connected("photo_picked", _on_photo_picked):
				mobile_interface.album_panel_instance.photo_picked.connect(_on_photo_picked)

func _on_photo_picked(path: String) -> void:
	var msg_text = "[img]%s[/img]" % path
	_send_player_message(msg_text)
	
	# After picking, we should return to chat
	var mobile_interface = _resolve_ui_context()
	if mobile_interface and mobile_interface.album_panel_instance:
		mobile_interface.album_panel_instance.hide_panel()
		mobile_interface.album_panel_instance.set_picker_mode(false)

func _on_voice_call_pressed() -> void:
	_hide_more_menu()
	start_voice_call(false)

func start_voice_call(is_incoming: bool, is_fixed: bool = false) -> void:
	current_call_history.clear()
	_current_call_is_incoming = is_incoming
	if voice_call_panel_instance == null:
		var VoiceCallObj = load("res://scenes/ui/mobile/chat/voice_call_panel.tscn")
		voice_call_panel_instance = VoiceCallObj.instantiate()
		voice_call_panel_instance.call_ended.connect(_on_voice_call_ended)
		voice_call_panel_instance.message_sent.connect(_on_voice_call_message_sent)
	_mount_call_panel(voice_call_panel_instance, "语音通话", Vector2(460, 400))
		
	voice_call_panel_instance.setup(current_char_id, char_profile, is_incoming, is_fixed)
	voice_call_panel_instance.show()
	is_voice_call_mode = true
	
	if not is_fixed:
		_request_proactive_call_message(is_incoming, false)

func _on_voice_call_ended() -> void:
	if voice_call_panel_instance:
		voice_call_panel_instance.hide()
	if is_instance_valid(call_window_host) and call_window_host.has_method("detach_floating_call_panel"):
		call_window_host.detach_floating_call_panel(voice_call_panel_instance)
			
	is_voice_call_mode = false
	
	if deepseek_client:
		deepseek_client.cancel_realize_turn_requests()
		
	input_edit.editable = true
	send_btn.disabled = false
		
	if _current_call_is_incoming:
		incoming_call_ended.emit()

func _on_video_call_pressed() -> void:
	_hide_more_menu()
	start_video_call(false)

func start_video_call(is_incoming: bool, is_fixed: bool = false) -> void:
	current_call_history.clear()
	_current_call_is_incoming = is_incoming
	if video_call_panel_instance == null:
		var VideoCallObj = load("res://scenes/ui/mobile/chat/video_call_panel.tscn")
		video_call_panel_instance = VideoCallObj.instantiate()
		video_call_panel_instance.call_ended.connect(_on_video_call_ended)
		video_call_panel_instance.message_sent.connect(_on_voice_call_message_sent)
	_mount_call_panel(video_call_panel_instance, "视频通话", Vector2(720, 420))
		
	video_call_panel_instance.setup(current_char_id, char_profile, is_incoming, is_fixed)
	
	# 可以根据场景设置不同的背景
	# video_call_panel_instance.set_background("res://assets/images/backgrounds/room_night.png")
	
	video_call_panel_instance.show()
	is_voice_call_mode = true
	
	if not is_fixed:
		_request_proactive_call_message(is_incoming, true)

func _on_video_call_ended() -> void:
	if video_call_panel_instance:
		video_call_panel_instance.hide()
	if is_instance_valid(call_window_host) and call_window_host.has_method("detach_floating_call_panel"):
		call_window_host.detach_floating_call_panel(video_call_panel_instance)
			
	is_voice_call_mode = false
	
	if deepseek_client:
		deepseek_client.cancel_realize_turn_requests()
		
	input_edit.editable = true
	send_btn.disabled = false
		
	if _current_call_is_incoming:
		incoming_call_ended.emit()

func _on_voice_call_message_sent(text: String) -> void:
	current_call_history.append({"speaker": "player", "text": text})
	
	# Disable input while waiting
	input_edit.editable = false
	send_btn.disabled = true
	
	if voice_call_panel_instance and voice_call_panel_instance.visible:
		voice_call_panel_instance.set_loading_state()
	elif video_call_panel_instance and video_call_panel_instance.visible:
		video_call_panel_instance.set_loading_state()
		
	_request_ai_call_response(text)

func _on_send_pressed() -> void:
	if not _is_guide_interaction_allowed("wechat.send"):
		_notify_guide_interaction_blocked()
		return
	var text = input_edit.text.strip_edges()
	if text == "": return
	
	_hide_attachment_panel()
	_hide_more_menu()
	input_edit.text = ""
	
	_send_player_message(text)

func _on_input_submitted(_text: String) -> void:
	_on_send_pressed()

func _send_player_message(text: String) -> void:
	_add_message_bubble("player", text)
	_save_message_to_history("player", text)
	
	# Disable input while waiting
	input_edit.editable = false
	send_btn.disabled = true
	
	_request_ai_response(text)

func _request_proactive_call_message(is_incoming: bool, is_video: bool) -> void:
	if not deepseek_client: return
	
	var call_type_str = "视频通话" if is_video else "语音通话"
	var scenario: String
	if is_incoming:
		scenario = "角色主动发起的%s刚刚被玩家接通。" % call_type_str
	else:
		scenario = "玩家发起的%s刚刚被角色接通。" % call_type_str
	
	input_edit.editable = false
	send_btn.disabled = true
	if voice_call_panel_instance and voice_call_panel_instance.visible:
		voice_call_panel_instance.set_loading_state()
	elif video_call_panel_instance and video_call_panel_instance.visible:
		video_call_panel_instance.set_loading_state()
		
	deepseek_client.send_realize_turn_message(scenario, "mobile_chat", {
		"channel": "mobile_call",
		"call_type": "video" if is_video else "voice",
		"turn_origin": "program_event",
		"recent_messages": [],
		"additional_authoritative_context": "通话已经接通；角色现在需要自然地说出第一句话。"
	})

func _request_ai_call_response(player_text: String) -> void:
	if not deepseek_client: return
	var recent_messages: Array = []
	var recent = current_call_history.slice(-10)
	for msg in recent:
		var normalized_msg = _normalize_history_message(msg)
		var msg_speaker = normalized_msg.get("speaker", "")
		var msg_text = normalized_msg.get("text", "")
		var role = "user" if msg_speaker == "player" or msg_speaker == "user" else "assistant"
		recent_messages.append({"role": role, "content": msg_text})
	var is_video: bool = video_call_panel_instance != null and bool(video_call_panel_instance.visible)
	deepseek_client.send_realize_turn_message(player_text, "mobile_chat", {
		"channel": "mobile_call",
		"call_type": "video" if is_video else "voice",
		"recent_messages": recent_messages,
		"additional_authoritative_context": "玩家与角色当前正在%s中；角色的回复会被立即朗读。" % ("视频通话" if is_video else "语音通话")
	})

func _request_ai_response(player_text: String) -> void:
	if not deepseek_client: return
	_pending_memory_observation_text = player_text.strip_edges()
	
	var processed_text = player_text
	if player_text.begins_with("[img]") and player_text.ends_with("[/img]"):
		processed_text = "【系统动作：玩家向你发送了一张刚刚拍摄的照片。】"
		
	var recent_messages: Array = []
	var recent = chat_history.slice(-10)
	for message_index in range(recent.size()):
		var msg = recent[message_index]
		var normalized_msg = _normalize_history_message(msg)
		var msg_speaker = normalized_msg.get("speaker", "")
		var msg_text = normalized_msg.get("text", "")
		if message_index == recent.size() - 1 and (msg_speaker == "player" or msg_speaker == "user") and str(msg_text) == player_text:
			continue
		var role = "user" if msg_speaker == "player" or msg_speaker == "user" or msg_speaker == "system" else "assistant"
		var msg_content = str(msg_text)
		
		if normalized_msg.get("type", "") == "system":
			msg_content = "【系统提示：%s】" % msg_content
		elif normalized_msg.get("type", "") == "red_packet":
			msg_content = "【系统提示：[%s发了一个红包: %s]】" % [
				"玩家" if msg_speaker == "player" or msg_speaker == "user" else "你", 
				msg_content
			]
		elif msg_content.begins_with("[img]") and msg_content.ends_with("[/img]"):
			msg_content = "【系统提示：[%s发送了一张照片]】" % ("玩家" if msg_speaker == "player" or msg_speaker == "user" else "你")
			
		recent_messages.append({"role": role, "content": msg_content})
	var request_context := {
		"channel": "mobile_chat",
		"recent_messages": recent_messages
	}
	if processed_text != player_text:
		request_context["additional_authoritative_context"] = processed_text
	deepseek_client.send_realize_turn_message(player_text, "mobile_chat", request_context)

func _on_realize_turn_completed(realized_turn: Dictionary, request_context: Dictionary) -> void:
	if str(request_context.get("channel", "")) == "mobile_call":
		_accept_realized_call_turn(realized_turn, request_context)
		return
	var channel := str(request_context.get("channel", ""))
	if (channel != "mobile_chat" and channel != "mobile_red_packet") or is_voice_call_mode:
		return
	input_edit.editable = true
	send_btn.disabled = false
	var segments: Variant = realized_turn.get("segments")
	if not segments is Array or segments.is_empty():
		_on_realize_turn_failed("角色回复没有可展示内容。", request_context)
		return
	var accepted_speech: Array[String] = []
	for index in range(segments.size()):
		var segment: Variant = segments[index]
		if not segment is Dictionary:
			continue
		var speech := str(segment.get("speech", "")).strip_edges()
		var message := {
			"speaker": "char",
			"text": speech,
			"time": Time.get_datetime_string_from_system(),
			"is_voice": randf() < 0.2,
			"duration": maxi(1, int(speech.length() / 4.0)),
			"is_read": visible,
			"delivery_instruction": str(segment.get("delivery_instruction", "")).strip_edges(),
			"reply_pipeline": str(request_context.get("reply_pipeline", "realize_turn_v6")),
			"ai_request_id": str(request_context.get("request_id", "")),
			"memory_trace_id": str(request_context.get("trace_id", "")),
			"response_segment_index": index,
			"response_adopted": true
		}
		if not message["is_voice"]:
			message["duration"] = 0
		_append_history_message(message, visible)
		if GameDataManager.memory_retrieval_trace_service:
			GameDataManager.memory_retrieval_trace_service.mark_response_adopted(str(request_context.get("trace_id", "")), speech, index)
		accepted_speech.append(speech)
	var observed_player_text := _pending_memory_observation_text
	_pending_memory_observation_text = ""
	if GameDataManager.memory_observation_service and not observed_player_text.is_empty():
		GameDataManager.memory_observation_service.observe_completed_turn("mobile_chat", observed_player_text, "\n".join(accepted_speech))
	await get_tree().create_timer(0.1).timeout
	scroll_container.scroll_vertical = roundi(scroll_container.get_v_scroll_bar().max_value)

func _on_realize_turn_failed(error_message: String, request_context: Dictionary) -> void:
	if str(request_context.get("channel", "")) == "mobile_call":
		input_edit.editable = true
		send_btn.disabled = false
		var call_panel = video_call_panel_instance if str(request_context.get("call_type", "")) == "video" else voice_call_panel_instance
		if call_panel and call_panel.visible:
			call_panel.status_label.text = "网络错误: " + error_message
			call_panel.record_btn.disabled = false
		return
	var channel := str(request_context.get("channel", ""))
	if (channel != "mobile_chat" and channel != "mobile_red_packet") or is_voice_call_mode:
		return
	_on_ai_error(error_message)

func _accept_realized_call_turn(realized_turn: Dictionary, request_context: Dictionary) -> void:
	input_edit.editable = true
	send_btn.disabled = false
	var call_panel = video_call_panel_instance if str(request_context.get("call_type", "")) == "video" else voice_call_panel_instance
	if call_panel == null or not call_panel.visible:
		return
	var segments: Variant = realized_turn.get("segments")
	if not segments is Array or segments.is_empty():
		_on_realize_turn_failed("角色回复没有可播放内容。", request_context)
		return
	var accepted_speech: Array[String] = []
	for index in range(segments.size()):
		var segment: Variant = segments[index]
		if not segment is Dictionary:
			continue
		var speech := str(segment.get("speech", "")).strip_edges()
		var call_message := {
			"speaker": "char",
			"text": speech,
			"voice_instruction": str(segment.get("delivery_instruction", "")).strip_edges(),
			"reply_pipeline": str(request_context.get("reply_pipeline", "realize_turn_v6")),
			"ai_request_id": str(request_context.get("request_id", "")),
			"memory_trace_id": str(request_context.get("trace_id", "")),
			"response_segment_index": index,
			"response_adopted": true
		}
		current_call_history.append(call_message)
		call_panel.add_character_message(call_message)
		if GameDataManager.memory_retrieval_trace_service:
			GameDataManager.memory_retrieval_trace_service.mark_response_adopted(str(request_context.get("trace_id", "")), speech, index)
		accepted_speech.append(speech)
	if GameDataManager.memory_observation_service and str(request_context.get("turn_origin", "player_input")) == "player_input":
		GameDataManager.memory_observation_service.observe_completed_turn("mobile_call", str(request_context.get("player_text", "")), "\n".join(accepted_speech))

func _on_ai_error(err_msg: String) -> void:
	_pending_memory_observation_text = ""
	input_edit.editable = true
	send_btn.disabled = false
	
	if is_voice_call_mode:
		if voice_call_panel_instance and voice_call_panel_instance.visible:
			voice_call_panel_instance.status_label.text = "网络错误: " + err_msg
			voice_call_panel_instance.record_btn.disabled = false
		elif video_call_panel_instance and video_call_panel_instance.visible:
			video_call_panel_instance.status_label.text = "网络错误: " + err_msg
			video_call_panel_instance.record_btn.disabled = false
	else:
		var sys_msg = {
			"speaker": "system",
			"type": "system",
			"text": "网络错误: " + err_msg
		}
		_add_message_to_ui(sys_msg)
		chat_history.append(sys_msg)
		_save_mobile_history()

func _add_message_to_ui(msg: Dictionary) -> void:
	var normalized_msg = _normalize_history_message(msg)
	_add_message_bubble(normalized_msg.get("speaker", ""), normalized_msg.get("text", ""), normalized_msg.get("is_voice", false), normalized_msg.get("duration", 0), normalized_msg)

func _add_message_bubble(speaker: String, text: String, is_voice: bool = false, duration: int = 0, msg: Dictionary = {}) -> void:
	var final_msg = _normalize_history_message(msg)
	if not final_msg.has("speaker") or str(final_msg.get("speaker", "")).strip_edges() == "":
		final_msg["speaker"] = speaker
	if not final_msg.has("text") or str(final_msg.get("text", "")).is_empty():
		final_msg["text"] = text
	speaker = str(final_msg.get("speaker", ""))
	if speaker == "user":
		speaker = "player"
	elif speaker == "assistant":
		speaker = "char"
	final_msg["speaker"] = speaker
	if not final_msg.has("is_voice"):
		final_msg["is_voice"] = is_voice
	if not final_msg.has("duration"):
		final_msg["duration"] = duration
		
	var msg_type = final_msg.get("type", "text")
	
	if speaker == "system" or msg_type == "system":
		var system_bubble = load("res://scenes/ui/mobile/chat/bubbles/system_bubble.tscn").instantiate()
		message_list.add_child(system_bubble)
		system_bubble.setup(final_msg)
	elif speaker == "player":
		var player_bubble = load("res://scenes/ui/mobile/chat/bubbles/player_bubble.tscn").instantiate()
		message_list.add_child(player_bubble)
		player_bubble.setup(final_msg)
	else:
		var char_bubble = load("res://scenes/ui/mobile/chat/bubbles/character_bubble.tscn").instantiate()
		message_list.add_child(char_bubble)
		char_bubble.set_meta("guide_message_speaker", "char")
		var c_profile_dict = {}
		if char_profile:
			c_profile_dict["avatar_path"] = char_profile.avatar
		char_bubble.setup(final_msg, c_profile_dict)
		
	# Scroll down
	await get_tree().process_frame
	scroll_container.scroll_vertical = roundi(scroll_container.get_v_scroll_bar().max_value)

func _on_red_packet_message_clicked(msg: Dictionary) -> void:
	var normalized_msg = _normalize_history_message(msg)
	var speaker = normalized_msg.get("speaker", "")
	var is_sender = speaker == "player"
	var status = msg.get("status", "unclaimed")
	
	var p_avatar = null
	if GameDataManager.profile and GameDataManager.profile.has_method("get_player_avatar_texture"):
		p_avatar = GameDataManager.profile.get_player_avatar_texture()
		
	var c_avatar = null
	if char_profile:
		c_avatar = _load_texture_from_path(char_profile.avatar)
	
	var rp_scene = load("res://scenes/ui/mobile/chat/red_packet_interact.tscn")
	var rp_ui = rp_scene.instantiate()
	rp_ui.setup(normalized_msg, is_sender, current_char_id, c_avatar, p_avatar)
	add_child(rp_ui)
	rp_ui.opened.connect(func():
		if is_sender or status == "claimed":
			return
			
		msg["status"] = "claimed"
		
		# Find the original message in chat_history and update it
		for i in range(chat_history.size() - 1, -1, -1):
			var h_msg = chat_history[i]
			if h_msg.get("type") == "red_packet" and h_msg.get("text", "") == msg.get("text", "") and h_msg.get("amount", 0) == msg.get("amount", 0):
				if h_msg.get("status", "unclaimed") == "unclaimed":
					h_msg["status"] = "claimed"
					break
		
		var amount = msg.get("amount", 0)
		if amount > 0:
			GameDataManager.profile.gold += amount
			GameDataManager.profile.save_profile()
			
			_refresh_top_status_panel()
		
		# 添加系统消息
		var sys_msg = {
			"speaker": "system",
			"type": "system",
			"text": "你领取了" + current_char_id.capitalize() + "的红包"
		}
		chat_history.append(sys_msg)
		
		_save_mobile_history()
		_load_mobile_history()
		_render_history()
	)

func _play_voice_message(text: String, msg: Dictionary = {}) -> void:
	if GameDataManager.config.voice_enabled:
		var options: Dictionary = {}
		if GameDataManager.config.tts_character_speakers.has(current_char_id):
			options["speaker"] = GameDataManager.config.tts_character_speakers[current_char_id]
		options.merge(TTSManager.build_tts_2_instruction_options(str(msg.get("delivery_instruction", ""))), true)
		TTSManager.synthesize(text, options)

func _load_mobile_history() -> void:
	chat_history.clear()
	for child in message_list.get_children():
		message_list.remove_child(child)
		child.queue_free()
		
	var path = GameDataManager.get_character_save_path("mobile_chat_history.json", current_char_id)
	var has_legacy_fields := false
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var content = file.get_as_text()
		var json = JSON.new()
		if json.parse(content) == OK and json.data is Array:
			for item in json.data:
				if item is Dictionary:
					if item.has("role") or item.has("content"):
						has_legacy_fields = true
					chat_history.append(_normalize_history_message(item))
	if has_legacy_fields:
		_save_mobile_history()

func _render_history() -> void:
	for msg in chat_history:
		var is_voice = msg.get("is_voice", false)
		var duration = int(msg.get("duration", 0))
		var msg_speaker = msg.get("speaker", "")
		var msg_text = msg.get("text", "")
		
		if msg.get("type", "") == "system":
			_add_message_to_ui(msg)
		elif msg.get("type", "") == "red_packet":
			_add_message_to_ui(msg)
		else:
			_add_message_bubble(msg_speaker, msg_text, is_voice, duration, msg)

func _show_image_fullscreen(tex: Texture2D, path: String, is_char: bool) -> void:
	print("Showing image fullscreen: ", path)
	_current_viewing_image_path = path
	full_image.texture = tex
	image_overlay.show()
	image_overlay.move_to_front() # Ensure it's on top of everything in MobileChatPanel
	
	if is_char:
		save_to_album_btn.show()
	else:
		save_to_album_btn.hide()
		
	image_overlay.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(image_overlay, "modulate:a", 1.0, 0.2)

func _on_close_viewer_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(image_overlay, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		image_overlay.hide()
		full_image.texture = null
		_current_viewing_image_path = ""
	)

func _on_save_to_album_pressed() -> void:
	if _current_viewing_image_path != "":
		var photo_manager = PhotoMemoryManagerScript.new()
		var save_dir = photo_manager.get_photo_dir()
		if not DirAccess.dir_exists_absolute(save_dir):
			DirAccess.make_dir_recursive_absolute(save_dir)
			
		var filename = "char_img_" + str(Time.get_unix_time_from_system()) + ".png"
		var new_path = save_dir + "/" + filename
		
		var img = Image.load_from_file(_current_viewing_image_path)
		if img:
			img.save_png(new_path)
			var memory_context = GameDataManager.memory_manager.build_story_memory_context() if GameDataManager.memory_manager else {}
			photo_manager.register_photo(new_path, "chat_image", {
				"memory_context": memory_context,
				"preferred_layers": ["bond", "emotion"],
				"origin_path": _current_viewing_image_path,
				"source_char_id": current_char_id
			})
			
		# 可以弹个提示或者简单关闭
		_on_close_viewer_pressed()

func _save_mobile_history() -> void:
	var path = GameDataManager.get_character_save_path("mobile_chat_history.json", current_char_id)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(chat_history, "\t"))
	_notify_mobile_social_changed()

func _mark_message_read(text: String) -> void:
	var has_changed = false
	for msg in chat_history:
		var msg_text = msg.get("text", "")
		if msg_text == text and not msg.get("is_read", false):
			msg["is_read"] = true
			has_changed = true
			
	if has_changed:
		_save_mobile_history()

func _save_message_to_history(speaker: String, text: String, is_voice: bool = false, duration: int = 0, is_read: bool = false) -> void:
	var new_msg = {
		"speaker": speaker,
		"text": text,
		"time": Time.get_datetime_string_from_system(),
		"is_voice": is_voice,
		"duration": duration,
		"is_read": is_read
	}
	if speaker == "char":
		new_msg.merge(deepseek_client.mark_chat_response_adopted(text), true)
	_append_history_message(new_msg, false)

func _append_history_message(msg: Dictionary, add_to_ui: bool = false) -> void:
	var normalized_msg = _normalize_history_message(msg)
	chat_history.append(normalized_msg)
	_save_mobile_history()
	if add_to_ui:
		_add_message_to_ui(normalized_msg)

func _mark_all_incoming_messages_read() -> void:
	var has_changed = false
	for msg in chat_history:
		var speaker = msg.get("speaker", "")
		if speaker != "player" and not msg.get("is_read", false):
			msg["is_read"] = true
			has_changed = true
	if has_changed:
		_save_mobile_history()
		
	var fixed_manager = get_node_or_null("/root/MobileFixedChatManager")
	if fixed_manager:
		fixed_manager.mark_as_read(current_char_id)

func _normalize_history_message(msg: Dictionary) -> Dictionary:
	var normalized = msg.duplicate(true)
	if normalized.has("role"):
		var role = str(normalized.get("role", ""))
		match role:
			"user":
				normalized["speaker"] = "player"
			"assistant":
				normalized["speaker"] = "char"
			_:
				normalized["speaker"] = role
		normalized.erase("role")
	if normalized.has("content"):
		normalized["text"] = str(normalized.get("content", ""))
		normalized.erase("content")
	if not normalized.has("speaker"):
		normalized["speaker"] = ""
	if not normalized.has("text"):
		normalized["text"] = ""
	return normalized

func _notify_mobile_social_changed() -> void:
	var curr = _resolve_ui_context()
	if curr and curr.has_method("_update_social_entry_labels"):
		curr._update_social_entry_labels()
		return
	curr = get_parent()
	while curr:
		if curr.has_method("_update_social_entry_labels"):
			curr._update_social_entry_labels()
			if curr.has_node("PhonePanel/MainMargin/VBox/ScrollContainer/ContactList"):
				pass
			return
		curr = curr.get_parent()

func show_panel() -> void:
	_hide_attachment_panel()
	_hide_more_menu()
	show()
	_mark_all_incoming_messages_read()
	_notify_mobile_social_changed()
	if is_embedded_mode:
		modulate.a = 1.0
		position = Vector2.ZERO
		await get_tree().process_frame
		scroll_container.scroll_vertical = roundi(scroll_container.get_v_scroll_bar().max_value)
		return
	position.x = size.x
	modulate.a = 0.0
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	
	# Scroll to bottom when shown
	await get_tree().create_timer(0.1).timeout
	scroll_container.scroll_vertical = roundi(scroll_container.get_v_scroll_bar().max_value)

func hide_panel(immediate: bool = false) -> void:
	_hide_attachment_panel()
	_hide_more_menu()
	if is_embedded_mode:
		modulate.a = 1.0
		position = Vector2.ZERO
		hide()
		return
	if immediate:
		modulate.a = 0.0
		position.x = size.x
		hide()
		return
		
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:x", size.x, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(self.hide)
