extends SceneTree

func _init():
	var categories = {
		"tech": Color(0.1, 0.4, 0.8),
		"business": Color(0.8, 0.6, 0.1),
		"art": Color(0.8, 0.2, 0.5),
		"sports": Color(0.2, 0.7, 0.2),
		"academic": Color(0.5, 0.2, 0.8),
		"rest": Color(0.4, 0.4, 0.4)
	}
	
	for key in categories.keys():
		var tex = GradientTexture2D.new()
		tex.width = 128
		tex.height = 128
		var grad = Gradient.new()
		var col = categories[key]
		grad.set_color(0, col)
		grad.set_color(1, col.darkened(0.5))
		tex.gradient = grad
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1, 1)
		
		ResourceSaver.save(tex, "res://assets/icons/activities/icon_" + key + ".tres")
	
	print("Icons generated successfully!")
	quit()
