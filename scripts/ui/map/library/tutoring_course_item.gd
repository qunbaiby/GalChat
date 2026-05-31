extends PanelContainer

signal course_clicked(course_data: Dictionary)

@onready var name_label: Label = $Margin/VBox/HeaderHBox/NameLabel
@onready var increment_label: Label = $Margin/VBox/HeaderHBox/IncrementLabel
@onready var exp_cost_label: Label = $Margin/VBox/CostHBox/ExpCostLabel
@onready var progress_label: Label = $Margin/VBox/ProgressContainer/ProgressHBox/ProgressLabel
@onready var progress_bar: ProgressBar = $Margin/VBox/ProgressContainer/ProgressBar
@onready var button: Button = $Button

var _course_data: Dictionary = {}
var _cur_prog: int = 0
var _max_prog: int = 100
var _increment: int = 0

var style_normal: StyleBoxFlat
var style_selected: StyleBoxFlat

func _ready() -> void:
	button.pressed.connect(_on_button_pressed)
	_init_styles()

func _init_styles() -> void:
	style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(1, 1, 1, 0.98)
	style_normal.corner_radius_top_left = 18
	style_normal.corner_radius_top_right = 18
	style_normal.corner_radius_bottom_right = 18
	style_normal.corner_radius_bottom_left = 18
	style_normal.border_width_left = 1
	style_normal.border_width_top = 1
	style_normal.border_width_right = 1
	style_normal.border_width_bottom = 1
	style_normal.border_color = Color(0.87, 0.9, 0.95, 1)
	style_normal.shadow_color = Color(0, 0, 0, 0.05)
	style_normal.shadow_size = 8
	
	style_selected = style_normal.duplicate()
	style_selected.bg_color = Color(1, 0.982, 0.955, 1)
	style_selected.border_width_left = 2
	style_selected.border_width_top = 2
	style_selected.border_width_right = 2
	style_selected.border_width_bottom = 2
	style_selected.border_color = Color(0.96, 0.64, 0.31, 0.95)
	style_selected.shadow_color = Color(0.94, 0.56, 0.23, 0.14)
	style_selected.shadow_size = 10

func setup(course: Dictionary, cur: int, max_p: int) -> void:
	_course_data = course
	_cur_prog = cur
	_max_prog = max_p
	_increment = course.get("progress_increment", 0)
	
	name_label.text = course.get("name", "未知课程")
	exp_cost_label.text = "互动经验 -%d" % (_increment * 5)
	increment_label.text = "+%d/次" % _increment
	
	progress_bar.max_value = max_p
	progress_bar.value = cur
	
	update_state(0)

func update_state(planned_count: int) -> void:
	var preview_prog = min(_cur_prog + planned_count * _increment, _max_prog)
	progress_bar.value = preview_prog
	
	if planned_count > 0:
		progress_label.text = "%d (+%d) / %d" % [_cur_prog, preview_prog - _cur_prog, _max_prog]
		progress_label.add_theme_color_override("font_color", Color(0.88, 0.53, 0.2))
		name_label.add_theme_color_override("font_color", Color(0.25, 0.22, 0.2))
		increment_label.add_theme_color_override("font_color", Color(0.95, 0.51, 0.14))
		exp_cost_label.add_theme_color_override("font_color", Color(0.77, 0.48, 0.22))
		add_theme_stylebox_override("panel", style_selected)
	else:
		progress_label.text = "%d / %d" % [_cur_prog, _max_prog]
		progress_label.add_theme_color_override("font_color", Color(0.52, 0.56, 0.62))
		name_label.add_theme_color_override("font_color", Color(0.22, 0.24, 0.28))
		increment_label.add_theme_color_override("font_color", Color(0.96, 0.53, 0.19))
		exp_cost_label.add_theme_color_override("font_color", Color(0.45, 0.49, 0.55))
		add_theme_stylebox_override("panel", style_normal)

func _on_button_pressed() -> void:
	course_clicked.emit(_course_data)
