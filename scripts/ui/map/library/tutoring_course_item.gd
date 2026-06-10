extends PanelContainer

signal course_clicked(course_data: Dictionary)

@onready var name_label: Label = $Margin/VBox/HeaderHBox/NameLabel
@onready var increment_label: Label = $Margin/VBox/HeaderHBox/IncrementLabel
@onready var energy_cost_label: Label = $Margin/VBox/CostHBox/EnergyCostLabel
@onready var progress_label: Label = $Margin/VBox/ProgressContainer/ProgressHBox/ProgressLabel
@onready var progress_bar: ProgressBar = $Margin/VBox/ProgressContainer/ProgressBar
@onready var button: Button = $Button

var _course_data: Dictionary = {}
var _cur_prog: int = 0
var _max_prog: int = 100
var _increment: int = 0

var style_normal: StyleBoxFlat
var style_selected: StyleBoxFlat

func _get_energy_cost() -> int:
	return max(1, int(ceil(float(_increment) / 5.0)))

func _ready() -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_on_button_pressed)
	_init_styles()

func _init_styles() -> void:
	style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.960784, 0.980392, 0.968627, 0.92)
	style_normal.corner_radius_top_left = 18
	style_normal.corner_radius_top_right = 18
	style_normal.corner_radius_bottom_right = 18
	style_normal.corner_radius_bottom_left = 18
	style_normal.border_width_left = 1
	style_normal.border_width_top = 1
	style_normal.border_width_right = 1
	style_normal.border_width_bottom = 1
	style_normal.border_color = Color(0.82, 0.9, 0.88, 0.95)
	style_normal.shadow_color = Color(0.18, 0.28, 0.33, 0.08)
	style_normal.shadow_size = 10
	style_normal.shadow_offset = Vector2(0, 3)
	
	style_selected = style_normal.duplicate()
	style_selected.bg_color = Color(0.945, 0.992, 0.989, 1)
	style_selected.border_width_left = 2
	style_selected.border_width_top = 2
	style_selected.border_width_right = 2
	style_selected.border_width_bottom = 2
	style_selected.border_color = Color(0.52, 0.84, 0.81, 0.96)
	style_selected.shadow_color = Color(0.18, 0.52, 0.5, 0.14)
	style_selected.shadow_size = 12

func setup(course: Dictionary, cur: int, max_p: int) -> void:
	_course_data = course
	_cur_prog = cur
	_max_prog = max_p
	_increment = course.get("progress_increment", 0)
	
	name_label.text = course.get("name", "未知课程")
	energy_cost_label.text = "行动力 -%d" % _get_energy_cost()
	increment_label.text = "+%d/次" % _increment
	
	progress_bar.max_value = max_p
	progress_bar.value = cur
	
	update_state(0)

func update_state(planned_count: int) -> void:
	var preview_prog = min(_cur_prog + planned_count * _increment, _max_prog)
	progress_bar.value = preview_prog
	
	if planned_count > 0:
		progress_label.text = "%d (+%d) / %d" % [_cur_prog, preview_prog - _cur_prog, _max_prog]
		progress_label.add_theme_color_override("font_color", Color(0.27, 0.62, 0.58, 1))
		name_label.add_theme_color_override("font_color", Color(0.18, 0.28, 0.31, 1))
		increment_label.add_theme_color_override("font_color", Color(0.36, 0.72, 0.68, 1))
		energy_cost_label.add_theme_color_override("font_color", Color(0.3, 0.56, 0.6, 1))
		add_theme_stylebox_override("panel", style_selected)
	else:
		progress_label.text = "%d / %d" % [_cur_prog, _max_prog]
		progress_label.add_theme_color_override("font_color", Color(0.47, 0.57, 0.61, 1))
		name_label.add_theme_color_override("font_color", Color(0.2, 0.31, 0.34, 1))
		increment_label.add_theme_color_override("font_color", Color(0.44, 0.77, 0.73, 1))
		energy_cost_label.add_theme_color_override("font_color", Color(0.38, 0.49, 0.53, 1))
		add_theme_stylebox_override("panel", style_normal)

func _on_button_pressed() -> void:
	course_clicked.emit(_course_data)
