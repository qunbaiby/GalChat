extends SceneTree


func _init() -> void:
	var theme := Theme.new()

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.2, 0.3, 0.4, 0.5)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(1, 1, 1, 0.5)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.corner_radius_bottom_left = 12

	theme.set_stylebox("panel", "Panel", panel_style)
	theme.set_color("font_color", "Label", Color(1, 1, 1, 1))

	var save_path := "res://.tmp_theme_dump.tres"
	var err := ResourceSaver.save(theme, save_path)
	print("SAVE_ERR=", err)
	quit(err)
