extends Panel

signal call_accepted(char_id: String, is_video: bool, is_fixed: bool)
signal call_rejected(char_id: String)

@onready var avatar_rect: TextureRect = $HBoxContainer/AvatarRect
@onready var name_label: Label = $HBoxContainer/VBoxContainer/NameLabel
@onready var type_label: Label = $HBoxContainer/VBoxContainer/TypeLabel
@onready var accept_btn: Button = $HBoxContainer/AcceptButton
@onready var reject_btn: Button = $HBoxContainer/RejectButton

var current_char_id: String = ""
var is_video_call: bool = false

func _ready() -> void:
	accept_btn.pressed.connect(_on_accept_pressed)
	reject_btn.pressed.connect(_on_reject_pressed)
	hide()
	
	# 设置头像圆角裁剪
	var av_parent = avatar_rect.get_parent()
	av_parent.remove_child(avatar_rect)
	
	var mask_panel = PanelContainer.new()
	mask_panel.custom_minimum_size = Vector2(60, 60)
	mask_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var mask_style = StyleBoxFlat.new()
	mask_style.bg_color = Color.WHITE
	mask_style.corner_radius_top_left = 30
	mask_style.corner_radius_top_right = 30
	mask_style.corner_radius_bottom_left = 30
	mask_style.corner_radius_bottom_right = 30
	mask_panel.add_theme_stylebox_override("panel", mask_style)
	mask_panel.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	
	av_parent.add_child(mask_panel)
	av_parent.move_child(mask_panel, 0) # 保持在最左侧
	
	mask_panel.add_child(avatar_rect)
	avatar_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

var is_fixed_mode: bool = false

func show_incoming_call(char_id: String, is_video: bool, is_fixed: bool = false) -> void:
	current_char_id = char_id
	is_video_call = is_video
	is_fixed_mode = is_fixed
	
	var profile = CharacterProfile.new()
	profile.load_profile(char_id)
	
	name_label.text = profile.char_name
	if is_video:
		type_label.text = "邀请你视频通话"
		accept_btn.text = "📹"
	else:
		type_label.text = "邀请你语音通话"
		accept_btn.text = "📞"
		
	reject_btn.text = "☎"
	
	if is_fixed_mode:
		reject_btn.show()
		reject_btn.disabled = true
	else:
		reject_btn.show()
		reject_btn.disabled = false
		
	var avatar_path = profile.avatar
	if avatar_path != "" and ResourceLoader.exists(avatar_path):
		avatar_rect.texture = load(avatar_path)
	else:
		avatar_rect.texture = load("res://assets/images/characters/desktop_pet/Q_desktop.png")
		
	# 弹窗动画
	modulate.a = 0.0
	position.y = -100
	show()
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", 20.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func hide_notification() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", -100.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(self.hide)

func _on_accept_pressed() -> void:
	call_accepted.emit(current_char_id, is_video_call, is_fixed_mode)
	hide_notification()

func _on_reject_pressed() -> void:
	call_rejected.emit(current_char_id)
	hide_notification()
