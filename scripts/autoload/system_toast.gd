extends Control

@onready var panel = $CenterContainer/PanelContainer
@onready var label = $CenterContainer/PanelContainer/MarginContainer/Label

var display_time: float = 2.0

func setup(message: String, color: Color) -> void:
	label.text = message
	label.add_theme_color_override("font_color", color)
	
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	stylebox.corner_radius_top_left = 10
	stylebox.corner_radius_top_right = 10
	stylebox.corner_radius_bottom_left = 10
	stylebox.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", stylebox)
	
	call_deferred("_animate_in")

func _animate_in() -> void:
	panel.modulate.a = 0.0
	
	# Wait for layout to update
	await get_tree().process_frame
	
	var original_y = panel.position.y
	panel.position.y = original_y + 20
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "position:y", original_y, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	
	tween.chain().tween_interval(display_time)
	
	tween.chain().tween_property(panel, "position:y", original_y - 20, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(panel, "modulate:a", 0.0, 0.3)
	
	tween.finished.connect(queue_free)