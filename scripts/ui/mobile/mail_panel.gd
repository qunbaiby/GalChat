extends Control

signal back_requested

const POPUP_MIN_SIZE: Vector2 = Vector2(1120, 700)
const MAIL_ICON_PATH := "res://assets/images/icons/ui/mobile/home/mail_box.svg"
const REWARD_ICON_PRIMARY := "res://assets/images/icons/ui/mobile/home/album_gallery.svg"
const REWARD_ICON_SECONDARY := "res://assets/images/icons/ui/mobile/home/memory_notes.svg"

@onready var background_panel: Panel = $Background
@onready var panel_root: PanelContainer = $CenterContainer/PanelRoot
@onready var back_btn: Button = $CenterContainer/PanelRoot/VBox/HeaderPanel/Margin/TopBar/BackBtn
@onready var counter_label: Label = $CenterContainer/PanelRoot/VBox/HeaderPanel/Margin/TopBar/CounterLabel
@onready var mail_list: VBoxContainer = $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/LeftPane/LeftVBox/MailScroll/MailList
@onready var claim_all_btn: Button = $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/LeftPane/LeftVBox/FooterBar/FooterHBox/ClaimAllBtn
@onready var delete_read_btn: Button = $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/LeftPane/LeftVBox/FooterBar/FooterHBox/DeleteReadBtn
@onready var detail_title: Label = $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/RightPane/RightMargin/RightVBox/DetailTitle
@onready var sender_label: Label = $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/RightPane/RightMargin/RightVBox/MetaHBox/SenderLabel
@onready var date_label: Label = $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/RightPane/RightMargin/RightVBox/MetaHBox/DateLabel
@onready var receiver_label: Label = $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/RightPane/RightMargin/RightVBox/ReceiverLabel
@onready var body_label: Label = $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/RightPane/RightMargin/RightVBox/BodyLabel
@onready var attachment_grid: GridContainer = $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/RightPane/RightMargin/RightVBox/AttachmentPanel/AttachmentMargin/AttachmentGrid
@onready var delete_btn: Button = $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/RightPane/RightMargin/RightVBox/BottomBar/DeleteBtn

var _panel_tween: Tween = null
var _mails: Array[Dictionary] = []
var _mail_buttons: Array[Button] = []
var _selected_mail_id: String = ""
var _row_normal_style: StyleBoxFlat
var _row_selected_style: StyleBoxFlat
var _footer_button_style: StyleBoxFlat
var _delete_button_style: StyleBoxFlat

func _ready() -> void:
	back_btn.pressed.connect(_on_back_pressed)
	claim_all_btn.pressed.connect(_on_claim_all_pressed)
	delete_read_btn.pressed.connect(_on_delete_read_pressed)
	delete_btn.pressed.connect(_on_delete_current_pressed)
	background_panel.gui_input.connect(_on_background_gui_input)
	resized.connect(_on_panel_resized)
	_prepare_styles()
	_seed_mails()
	_build_mail_list()
	hide()

func show_panel() -> void:
	_update_popup_layout()
	show()
	background_panel.modulate.a = 0.0
	panel_root.modulate.a = 0.0
	panel_root.scale = Vector2(0.97, 0.97)
	_kill_panel_tween()
	_panel_tween = create_tween()
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(background_panel, "modulate:a", 1.0, 0.18)
	_panel_tween.tween_property(panel_root, "modulate:a", 1.0, 0.22)
	_panel_tween.tween_property(panel_root, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func hide_panel() -> void:
	_kill_panel_tween()
	_panel_tween = create_tween()
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(background_panel, "modulate:a", 0.0, 0.15)
	_panel_tween.tween_property(panel_root, "modulate:a", 0.0, 0.15)
	_panel_tween.tween_property(panel_root, "scale", Vector2(0.97, 0.97), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_panel_tween.set_parallel(false)
	_panel_tween.tween_callback(hide)

func _on_back_pressed() -> void:
	hide_panel()
	back_requested.emit()

func _on_background_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		hide_panel()

func _on_panel_resized() -> void:
	if visible:
		_update_popup_layout()

func _update_popup_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var target_size: Vector2 = POPUP_MIN_SIZE
	target_size.x = minf(target_size.x, viewport_size.x - 72.0)
	target_size.y = minf(target_size.y, viewport_size.y - 72.0)
	panel_root.custom_minimum_size = target_size
	panel_root.size = target_size
	panel_root.pivot_offset = target_size * 0.5

func _kill_panel_tween() -> void:
	if _panel_tween != null:
		_panel_tween.kill()
		_panel_tween = null

func _prepare_styles() -> void:
	_row_normal_style = StyleBoxFlat.new()
	_row_normal_style.bg_color = Color(0.93, 0.94, 0.95, 0.98)
	_row_normal_style.border_width_left = 1
	_row_normal_style.border_width_top = 1
	_row_normal_style.border_width_right = 1
	_row_normal_style.border_width_bottom = 1
	_row_normal_style.border_color = Color(0.8, 0.82, 0.85, 0.98)
	_row_normal_style.corner_radius_top_left = 12
	_row_normal_style.corner_radius_top_right = 12
	_row_normal_style.corner_radius_bottom_left = 12
	_row_normal_style.corner_radius_bottom_right = 12

	_row_selected_style = _row_normal_style.duplicate()
	_row_selected_style.border_width_left = 2
	_row_selected_style.border_width_top = 2
	_row_selected_style.border_width_right = 2
	_row_selected_style.border_width_bottom = 2
	_row_selected_style.border_color = Color(0.96, 0.72, 0.28, 0.98)
	_row_selected_style.shadow_color = Color(0.92, 0.62, 0.2, 0.14)
	_row_selected_style.shadow_size = 8

	_footer_button_style = StyleBoxFlat.new()
	_footer_button_style.bg_color = Color(0.97, 0.97, 0.98, 1)
	_footer_button_style.border_width_left = 1
	_footer_button_style.border_width_top = 1
	_footer_button_style.border_width_right = 1
	_footer_button_style.border_width_bottom = 1
	_footer_button_style.border_color = Color(0.83, 0.85, 0.88, 1)
	_footer_button_style.corner_radius_top_left = 12
	_footer_button_style.corner_radius_top_right = 12
	_footer_button_style.corner_radius_bottom_left = 12
	_footer_button_style.corner_radius_bottom_right = 12

	_delete_button_style = StyleBoxFlat.new()
	_delete_button_style.bg_color = Color(0.78, 0.34, 0.45, 1)
	_delete_button_style.corner_radius_top_left = 18
	_delete_button_style.corner_radius_top_right = 18
	_delete_button_style.corner_radius_bottom_left = 18
	_delete_button_style.corner_radius_bottom_right = 18

func _seed_mails() -> void:
	_mails = [
		{
			"id": "mail_1",
			"title": "国服公测物玩礼",
			"sender": "卡尼思梦境",
			"time_left": "28天20小时",
			"sent_time": "2026-06-07 12:00",
			"receiver": "ligereny 敬启",
			"body": "感谢领航者参与公测巡测，今日物玩礼包已送达，请及时查收。内含纪念藏品与额外道具，可用于后续活动与记录收藏。",
			"is_read": false,
			"attachments": [
				{"name": "纪念徽章", "amount": 2, "icon_path": REWARD_ICON_PRIMARY},
				{"name": "梦境档案", "amount": 20, "icon_path": REWARD_ICON_SECONDARY}
			]
		},
		{
			"id": "mail_2",
			"title": "单元币",
			"sender": "卡尼思梦境",
			"time_left": "28天4小时",
			"sent_time": "2026-06-06 08:20",
			"receiver": "ligereny 敬启",
			"body": "你的阶段奖励已经完成结算，本次邮件附带单元币补给。建议在商店或活动兑换页面内优先使用。",
			"is_read": false,
			"attachments": [
				{"name": "单元币", "amount": 8, "icon_path": REWARD_ICON_SECONDARY}
			]
		},
		{
			"id": "mail_3",
			"title": "国服公测十日体验问卷调研",
			"sender": "卡尼思梦境",
			"time_left": "2小时51分钟",
			"sent_time": "2026-06-05 20:10",
			"receiver": "ligereny 敬启",
			"body": "欢迎参与十日体验问卷调研。完成后将获得额外纪念奖励，感谢你为项目提供建议与反馈。",
			"is_read": true,
			"attachments": [
				{"name": "调研奖励", "amount": 1, "icon_path": MAIL_ICON_PATH}
			]
		},
		{
			"id": "mail_4",
			"title": "国服公测物玩礼",
			"sender": "卡尼思梦境",
			"time_left": "28天21小时",
			"sent_time": "2026-06-04 12:00",
			"receiver": "ligereny 敬启",
			"body": "新的物玩礼已经整理完毕，请在邮件有效期内领取。若已领取，本邮件将自动归档为已读。",
			"is_read": true,
			"attachments": [
				{"name": "纪念徽章", "amount": 1, "icon_path": REWARD_ICON_PRIMARY}
			]
		}
	]
	_selected_mail_id = str(_mails[0].get("id", "")) if not _mails.is_empty() else ""

func _build_mail_list() -> void:
	for child in mail_list.get_children():
		child.queue_free()
	_mail_buttons.clear()

	for mail_data in _mails:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 82)
		button.focus_mode = Control.FOCUS_NONE
		button.flat = false
		button.add_theme_stylebox_override("normal", _row_selected_style if str(mail_data.get("id", "")) == _selected_mail_id else _row_normal_style)
		button.add_theme_stylebox_override("hover", _row_selected_style)
		button.add_theme_stylebox_override("pressed", _row_selected_style)
		button.pressed.connect(func(target_id := str(mail_data.get("id", ""))): _select_mail(target_id))

		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 10.0
		row.offset_top = 10.0
		row.offset_right = -10.0
		row.offset_bottom = -10.0
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 12)
		button.add_child(row)

		var icon_panel := PanelContainer.new()
		icon_panel.custom_minimum_size = Vector2(52, 52)
		var icon_style := StyleBoxFlat.new()
		icon_style.bg_color = Color(0.18, 0.18, 0.22, 0.96)
		icon_style.corner_radius_top_left = 10
		icon_style.corner_radius_top_right = 10
		icon_style.corner_radius_bottom_left = 10
		icon_style.corner_radius_bottom_right = 10
		icon_panel.add_theme_stylebox_override("panel", icon_style)
		row.add_child(icon_panel)

		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(30, 30)
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.texture = _load_texture(MAIL_ICON_PATH)
		icon_panel.add_child(icon_rect)

		var text_vbox := VBoxContainer.new()
		text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_vbox.add_theme_constant_override("separation", 4)
		row.add_child(text_vbox)

		var title := Label.new()
		title.text = str(mail_data.get("title", "未命名邮件"))
		title.add_theme_font_size_override("font_size", 18)
		title.add_theme_color_override("font_color", Color(0.22, 0.22, 0.24, 1))
		text_vbox.add_child(title)

		var sender := Label.new()
		sender.text = "寄件人：%s" % str(mail_data.get("sender", "未知寄件人"))
		sender.add_theme_font_size_override("font_size", 13)
		sender.add_theme_color_override("font_color", Color(0.52, 0.53, 0.56, 1))
		text_vbox.add_child(sender)

		var time_label := Label.new()
		time_label.text = str(mail_data.get("time_left", ""))
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		time_label.add_theme_font_size_override("font_size", 13)
		time_label.add_theme_color_override("font_color", Color(0.58, 0.6, 0.64, 1))
		time_label.custom_minimum_size = Vector2(92, 0)
		row.add_child(time_label)

		mail_list.add_child(button)
		_mail_buttons.append(button)

	_update_counter()
	_refresh_detail()

func _select_mail(mail_id: String) -> void:
	_selected_mail_id = mail_id
	for mail_data in _mails:
		if str(mail_data.get("id", "")) == mail_id:
			mail_data["is_read"] = true
			break
	_build_mail_list()

func _refresh_detail() -> void:
	var mail_data: Dictionary = _get_selected_mail()
	detail_title.text = str(mail_data.get("title", "暂无邮件"))
	sender_label.text = "寄件人：%s" % str(mail_data.get("sender", "-"))
	date_label.text = str(mail_data.get("sent_time", "-"))
	receiver_label.text = "收件人：%s" % str(mail_data.get("receiver", "-"))
	body_label.text = str(mail_data.get("body", "暂无邮件内容。"))

	for child in attachment_grid.get_children():
		child.queue_free()

	var attachments: Array = mail_data.get("attachments", [])
	for attachment_data in attachments:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(96, 96)
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.97, 0.97, 0.98, 1)
		card_style.border_width_left = 1
		card_style.border_width_top = 1
		card_style.border_width_right = 1
		card_style.border_width_bottom = 1
		card_style.border_color = Color(0.85, 0.86, 0.9, 1)
		card_style.corner_radius_top_left = 12
		card_style.corner_radius_top_right = 12
		card_style.corner_radius_bottom_left = 12
		card_style.corner_radius_bottom_right = 12
		card.add_theme_stylebox_override("panel", card_style)
		attachment_grid.add_child(card)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		card.add_child(margin)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		margin.add_child(vbox)

		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(44, 44)
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture = _load_texture(str(attachment_data.get("icon_path", "")))
		vbox.add_child(icon_rect)

		var amount_label := Label.new()
		amount_label.text = "x%s" % str(attachment_data.get("amount", 1))
		amount_label.add_theme_font_size_override("font_size", 15)
		amount_label.add_theme_color_override("font_color", Color(0.22, 0.22, 0.24, 1))
		amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(amount_label)

	claim_all_btn.disabled = _mails.is_empty()
	delete_read_btn.disabled = _mails.is_empty()
	delete_btn.disabled = _mails.is_empty()

func _get_selected_mail() -> Dictionary:
	for mail_data in _mails:
		if str(mail_data.get("id", "")) == _selected_mail_id:
			return mail_data
	if not _mails.is_empty():
		_selected_mail_id = str(_mails[0].get("id", ""))
		return _mails[0]
	return {}

func _update_counter() -> void:
	var unread_count: int = 0
	for mail_data in _mails:
		if not bool(mail_data.get("is_read", false)):
			unread_count += 1
	counter_label.text = "%03d / 100" % unread_count

func _on_claim_all_pressed() -> void:
	for mail_data in _mails:
		mail_data["is_read"] = true
	_build_mail_list()

func _on_delete_read_pressed() -> void:
	var remaining: Array[Dictionary] = []
	for mail_data in _mails:
		if not bool(mail_data.get("is_read", false)):
			remaining.append(mail_data)
	_mails = remaining
	if _mails.is_empty():
		_selected_mail_id = ""
	else:
		_selected_mail_id = str(_mails[0].get("id", ""))
	_build_mail_list()

func _on_delete_current_pressed() -> void:
	if _selected_mail_id == "":
		return
	var remaining: Array[Dictionary] = []
	for mail_data in _mails:
		if str(mail_data.get("id", "")) != _selected_mail_id:
			remaining.append(mail_data)
	_mails = remaining
	if _mails.is_empty():
		_selected_mail_id = ""
	else:
		_selected_mail_id = str(_mails[0].get("id", ""))
	_build_mail_list()

func _load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			return res as Texture2D
	return null
