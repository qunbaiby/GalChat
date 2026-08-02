extends BoxContainer

const ICON_STATE_SHADER = preload("res://assets/shaders/ui/button_icon_state.gdshader")

@export var normal_color := Color("d6fff5")
@export var hover_color := Color("79f2d2")
@export var pressed_color := Color("f2fffb")
@export var disabled_color := Color("6f8f88")
@export var normal_outline_color := Color("123d38")
@export var hover_outline_color := Color("0b5f53")
@export var pressed_outline_color := Color("087565")
@export var disabled_outline_color := Color("273d39")
@export var normal_shadow_color := Color(0.02, 0.12, 0.11, 0.78)
@export var hover_shadow_color := Color(0.03, 0.45, 0.37, 0.9)
@export var pressed_shadow_color := Color(0.2, 0.95, 0.78, 0.72)
@export var disabled_shadow_color := Color(0.02, 0.08, 0.07, 0.45)
@export_range(0, 8, 1) var text_outline_size := 3
@export_range(0, 8, 1) var text_shadow_size := 3
@export_range(0.0, 4.0, 0.1) var icon_outline_size := 1.35
@export_range(0.0, 8.0, 0.1) var icon_shadow_size := 2.4

@onready var button: Button = get_parent() as Button
@onready var icon_node: TextureRect = get_node_or_null("Icon") as TextureRect
@onready var label_node: Label = get_node_or_null("Label") as Label

var _applied_color: Color
var _has_applied_color := false
var _icon_material: ShaderMaterial

func _ready() -> void:
	if is_instance_valid(icon_node):
		_icon_material = ShaderMaterial.new()
		_icon_material.shader = ICON_STATE_SHADER
		icon_node.material = _icon_material
	if is_instance_valid(label_node):
		label_node.add_theme_constant_override("outline_size", text_outline_size)
		label_node.add_theme_constant_override("shadow_offset_x", text_shadow_size)
		label_node.add_theme_constant_override("shadow_offset_y", text_shadow_size)
		label_node.add_theme_constant_override("shadow_outline_size", 1)

func _process(_delta: float) -> void:
	if not is_instance_valid(button):
		return
	var target_color := normal_color
	var target_outline_color := normal_outline_color
	var target_shadow_color := normal_shadow_color
	if button.disabled:
		target_color = disabled_color
		target_outline_color = disabled_outline_color
		target_shadow_color = disabled_shadow_color
	elif button.get_draw_mode() in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED]:
		target_color = pressed_color
		target_outline_color = pressed_outline_color
		target_shadow_color = pressed_shadow_color
	elif button.get_draw_mode() == BaseButton.DRAW_HOVER:
		target_color = hover_color
		target_outline_color = hover_outline_color
		target_shadow_color = hover_shadow_color
	if _has_applied_color and target_color == _applied_color:
		return
	_applied_color = target_color
	_has_applied_color = true
	if is_instance_valid(icon_node):
		icon_node.self_modulate = target_color
		if is_instance_valid(_icon_material):
			_icon_material.set_shader_parameter("outline_color", target_outline_color)
			_icon_material.set_shader_parameter("shadow_color", target_shadow_color)
			_icon_material.set_shader_parameter("outline_size", icon_outline_size)
			_icon_material.set_shader_parameter("shadow_size", icon_shadow_size)
	if is_instance_valid(label_node):
		label_node.add_theme_color_override("font_color", target_color)
		label_node.add_theme_color_override("font_outline_color", target_outline_color)
		label_node.add_theme_color_override("font_shadow_color", target_shadow_color)