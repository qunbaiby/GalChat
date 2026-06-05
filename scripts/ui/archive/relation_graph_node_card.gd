extends Control

signal pressed(node_id: String)
signal node_dragged(node_id: String, new_anchor_pos: Vector2)

const CARD_SIZE: Vector2 = Vector2(92, 116)
const AVATAR_ANCHOR_OFFSET: Vector2 = Vector2(46, 34)
const DRAG_START_DISTANCE: float = 4.0

@onready var avatar_container: Control = $AvatarContainer
@onready var avatar_glow: Panel = $AvatarContainer/AvatarGlow
@onready var avatar_mask: Panel = $AvatarContainer/AvatarMask
@onready var avatar_border: Panel = $AvatarContainer/AvatarBorder
@onready var avatar_rect: TextureRect = $AvatarContainer/AvatarMask/Avatar
@onready var avatar_hit_button: Button = $AvatarContainer/AvatarHitButton
@onready var placeholder_label: Label = $AvatarContainer/Placeholder
@onready var name_label: Label = $NameLabel
@onready var subtitle_label: Label = $SubtitleLabel
@onready var lock_label: Label = $LockLabel

var current_node_id: String = ""
var _is_pointer_down: bool = false
var _is_dragging: bool = false
var _press_global_pos: Vector2 = Vector2.ZERO
var _press_local_offset: Vector2 = Vector2.ZERO

var _cached_base_color: Color = Color.WHITE
var _cached_active_color: Color = Color(0.58, 0.88, 1.0, 0.95)
var _is_selected: bool = false
var _is_locked: bool = false
var _is_hovered: bool = false

func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	avatar_hit_button.gui_input.connect(_on_avatar_gui_input)
	avatar_hit_button.mouse_entered.connect(_on_mouse_entered)
	avatar_hit_button.mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	_is_hovered = true
	_update_styles()

func _on_mouse_exited() -> void:
	_is_hovered = false
	_update_styles()

func _on_avatar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_pointer_tracking(event.global_position)
		else:
			_finish_pointer_tracking()
		accept_event()
	elif event is InputEventMouseMotion and _is_pointer_down:
		_update_drag(event.global_position)
		accept_event()

func _begin_pointer_tracking(pointer_global_pos: Vector2) -> void:
	_is_pointer_down = true
	_is_dragging = false
	_press_global_pos = pointer_global_pos
	_press_local_offset = pointer_global_pos - global_position

func _finish_pointer_tracking() -> void:
	var should_emit_pressed: bool = _is_pointer_down and not _is_dragging and current_node_id != ""
	_is_pointer_down = false
	_is_dragging = false
	if should_emit_pressed:
		pressed.emit(current_node_id)

func _update_drag(pointer_global_pos: Vector2) -> void:
	if current_node_id == "":
		return
	if not _is_dragging and pointer_global_pos.distance_to(_press_global_pos) < DRAG_START_DISTANCE:
		return

	_is_dragging = true
	var new_global_pos: Vector2 = pointer_global_pos - _press_local_offset
	var parent_control: Control = get_parent() as Control
	var new_local_pos: Vector2 = parent_control.get_global_transform().affine_inverse() * new_global_pos if parent_control != null else new_global_pos
	node_dragged.emit(current_node_id, new_local_pos + get_avatar_anchor_offset() * scale.x)

func setup_from_node(
	node: Dictionary,
	tooltip_text_value: String,
	avatar_texture,
	placeholder_text: String
) -> void:
	current_node_id = str(node.get("id", ""))
	tooltip_text = tooltip_text_value
	name_label.text = str(node.get("name", ""))
	subtitle_label.text = ""
	avatar_rect.texture = avatar_texture
	placeholder_label.text = placeholder_text
	placeholder_label.visible = avatar_rect.texture == null
	lock_label.visible = false

func update_visual(_node: Dictionary, subtitle_text: String, base_color: Color, active_color: Color, is_selected: bool, is_locked: bool) -> void:
	subtitle_label.text = subtitle_text
	_cached_base_color = base_color
	_cached_active_color = active_color
	_is_selected = is_selected
	_is_locked = is_locked
	_update_styles()

func _update_styles() -> void:
	var text_color: Color = Color(0.2, 0.2, 0.2, 1.0)
	var sub_color: Color = Color(0.45, 0.45, 0.45, 1.0)
	if _is_locked:
		text_color = Color(0.5, 0.5, 0.5, 0.9)
		sub_color = Color(0.6, 0.6, 0.6, 0.9)

	name_label.add_theme_color_override("font_color", text_color)
	subtitle_label.add_theme_color_override("font_color", sub_color)
	lock_label.visible = _is_locked
	lock_label.add_theme_color_override("font_color", Color("#c08b5e"))
	lock_label.text = "未解锁"
	avatar_rect.modulate = Color(1, 1, 1, 0.42) if _is_locked else Color(1, 1, 1, 1)
	placeholder_label.add_theme_color_override("font_color", text_color)
	placeholder_label.visible = avatar_rect.texture == null

	# Neon Glow Effect
	var active_color: Color = _cached_active_color

	var border_color: Color = Color(1.0, 1.0, 1.0, 0.1)
	var glow_color: Color = Color(0, 0, 0, 0)
	var glow_size: int = 0
	
	if _is_selected:
		border_color = active_color
		glow_color = active_color
		glow_color.a = 0.45
		glow_size = 12
	elif _is_hovered and not _is_locked:
		border_color = active_color.lightened(0.15)
		glow_color = active_color
		glow_color.a = 0.25
		glow_size = 8

	var mask_style: StyleBoxFlat = StyleBoxFlat.new()
	mask_style.bg_color = _cached_base_color.darkened(0.12) if not _is_locked else Color(0.25, 0.28, 0.33, 0.75)
	mask_style.corner_radius_top_left = 40
	mask_style.corner_radius_top_right = 40
	mask_style.corner_radius_bottom_left = 40
	mask_style.corner_radius_bottom_right = 40
	avatar_mask.add_theme_stylebox_override("panel", mask_style)

	var border_style: StyleBoxFlat = StyleBoxFlat.new()
	border_style.draw_center = false
	border_style.border_width_left = 2
	border_style.border_width_top = 2
	border_style.border_width_right = 2
	border_style.border_width_bottom = 2
	border_style.border_color = border_color
	border_style.corner_radius_top_left = 40
	border_style.corner_radius_top_right = 40
	border_style.corner_radius_bottom_left = 40
	border_style.corner_radius_bottom_right = 40
	avatar_border.add_theme_stylebox_override("panel", border_style)

	var glow_style: StyleBoxFlat = StyleBoxFlat.new()
	glow_style.bg_color = Color(0, 0, 0, 0)
	glow_style.border_width_left = 2
	glow_style.border_width_top = 2
	glow_style.border_width_right = 2
	glow_style.border_width_bottom = 2
	glow_style.border_color = glow_color
	glow_style.corner_radius_top_left = 40
	glow_style.corner_radius_top_right = 40
	glow_style.corner_radius_bottom_left = 40
	glow_style.corner_radius_bottom_right = 40
	glow_style.shadow_color = glow_color
	glow_style.shadow_size = glow_size
	avatar_glow.add_theme_stylebox_override("panel", glow_style)

func set_anchor_position(anchor_position: Vector2) -> void:
	position = anchor_position - get_avatar_anchor_offset() * scale.x

func get_card_size() -> Vector2:
	return CARD_SIZE

func get_avatar_anchor_offset() -> Vector2:
	return AVATAR_ANCHOR_OFFSET

func get_anchor_local() -> Vector2:
	return position + get_avatar_anchor_offset() * scale.x
