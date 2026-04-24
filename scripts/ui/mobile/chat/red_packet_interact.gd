extends Control

signal opened
signal closed

var msg_data: Dictionary
var is_sender: bool
var char_name: String
var char_avatar: Texture2D
var player_avatar: Texture2D

@onready var bg_red = $BgRed
@onready var bg_white = $BgWhite
@onready var top_bar = $TopBar
@onready var close_btn = $TopBar/CloseBtn

@onready var receive_ui = $ReceiveUI
@onready var r_top_flap = $ReceiveUI/TopFlap
@onready var r_avatar_panel = $ReceiveUI/VBox/AvatarPanel
@onready var r_avatar = $ReceiveUI/VBox/AvatarPanel/Avatar
@onready var r_name_label = $ReceiveUI/VBox/NameLabel
@onready var r_text_label = $ReceiveUI/VBox/TextLabel
@onready var r_open_btn = $ReceiveUI/VBox/BtnCenter/OpenBtn

@onready var detail_ui = $DetailUI
@onready var d_curve_panel = $DetailUI/CurvePanel
@onready var d_avatar_panel = $DetailUI/VBox/AvatarPanel
@onready var d_avatar = $DetailUI/VBox/AvatarPanel/Avatar
@onready var d_name_label = $DetailUI/VBox/NameLabel
@onready var d_text_label = $DetailUI/VBox/TextLabel
@onready var d_status_label = $DetailUI/VBox/StatusLabel
@onready var d_amount_label = $DetailUI/VBox/AmountLabel

func setup(msg: Dictionary, _is_sender: bool, _char_name: String, _char_avatar: Texture2D, _player_avatar: Texture2D):
	msg_data = msg
	is_sender = _is_sender
	char_name = _char_name
	char_avatar = _char_avatar
	player_avatar = _player_avatar

func _ready():
	_init_styles()
	
	close_btn.pressed.connect(func():
		closed.emit()
		queue_free()
	)
	
	r_open_btn.pressed.connect(func():
		opened.emit()
		_show_detail_ui()
	)
	
	var status = msg_data.get("status", "unclaimed")
	
	if status == "unclaimed" and not is_sender:
		_show_receive_ui()
	else:
		_show_detail_ui()

func _init_styles():
	# Receive UI Styles
	var flap_style = StyleBoxFlat.new()
	flap_style.bg_color = Color(0.85, 0.28, 0.20, 1)
	flap_style.corner_radius_bottom_left = 250
	flap_style.corner_radius_bottom_right = 250
	r_top_flap.add_theme_stylebox_override("panel", flap_style)
	
	var r_avatar_style = StyleBoxFlat.new()
	r_avatar_style.corner_radius_top_left = 40
	r_avatar_style.corner_radius_top_right = 40
	r_avatar_style.corner_radius_bottom_left = 40
	r_avatar_style.corner_radius_bottom_right = 40
	r_avatar_style.bg_color = Color.WHITE
	r_avatar_panel.add_theme_stylebox_override("panel", r_avatar_style)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(1, 0.8, 0.4)
	btn_style.corner_radius_top_left = 50
	btn_style.corner_radius_top_right = 50
	btn_style.corner_radius_bottom_left = 50
	btn_style.corner_radius_bottom_right = 50
	btn_style.border_width_left = 4
	btn_style.border_width_top = 4
	btn_style.border_width_right = 4
	btn_style.border_width_bottom = 4
	btn_style.border_color = Color(1, 0.9, 0.5)
	btn_style.shadow_color = Color(0, 0, 0, 0.2)
	btn_style.shadow_size = 8
	btn_style.shadow_offset = Vector2(0, 4)
	r_open_btn.add_theme_stylebox_override("normal", btn_style)
	r_open_btn.add_theme_stylebox_override("hover", btn_style)
	r_open_btn.add_theme_stylebox_override("pressed", btn_style)
	
	# Detail UI Styles
	var curve_style = StyleBoxFlat.new()
	curve_style.bg_color = Color(0.92, 0.35, 0.25, 1)
	curve_style.corner_radius_bottom_left = 1000
	curve_style.corner_radius_bottom_right = 1000
	d_curve_panel.add_theme_stylebox_override("panel", curve_style)
	
	var d_avatar_style = StyleBoxFlat.new()
	d_avatar_style.corner_radius_top_left = 30
	d_avatar_style.corner_radius_top_right = 30
	d_avatar_style.corner_radius_bottom_left = 30
	d_avatar_style.corner_radius_bottom_right = 30
	d_avatar_style.bg_color = Color.WHITE
	d_avatar_panel.add_theme_stylebox_override("panel", d_avatar_style)

func _show_receive_ui():
	receive_ui.visible = true
	detail_ui.visible = false
	bg_white.visible = false
	
	if char_avatar:
		r_avatar.texture = char_avatar
		
	r_name_label.text = char_name + "的红包"
	r_text_label.text = msg_data.get("content", "恭喜发财，大吉大利")

func _show_detail_ui():
	receive_ui.visible = false
	detail_ui.visible = true
	bg_white.visible = true
	
	if is_sender and player_avatar:
		d_avatar.texture = player_avatar
	elif not is_sender and char_avatar:
		d_avatar.texture = char_avatar
		
	var sender_name = "你" if is_sender else char_name
	d_name_label.text = sender_name + "的红包"
	d_text_label.text = msg_data.get("content", "恭喜发财，大吉大利")
	
	var amount = msg_data.get("amount", 0)
	var status = msg_data.get("status", "unclaimed")
	
	if is_sender and status == "unclaimed":
		d_status_label.text = "等待对方领取"
		d_amount_label.text = "¥" + str(amount) + ".00"
		d_status_label.visible = true
		d_amount_label.visible = true
	elif is_sender and status == "claimed":
		d_status_label.text = "对方已领取"
		d_amount_label.text = "¥" + str(amount) + ".00"
		d_status_label.visible = true
		d_amount_label.visible = true
	elif not is_sender:
		d_status_label.visible = false
		d_amount_label.text = "¥" + str(amount) + ".00"
		d_amount_label.visible = true
