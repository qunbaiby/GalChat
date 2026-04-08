extends SceneTree

func _init():
	var gifts = {
		"flower": Color(1.0, 0.4, 0.6),
		"chocolate": Color(0.4, 0.2, 0.1),
		"book": Color(0.2, 0.6, 0.8),
		"necklace": Color(0.9, 0.9, 0.9),
		"handmade": Color(0.9, 0.6, 0.2)
	}
	
	for key in gifts.keys():
		var tex = GradientTexture2D.new()
		tex.width = 128
		tex.height = 128
		var grad = Gradient.new()
		var col = gifts[key]
		grad.set_color(0, col)
		grad.set_color(1, col.darkened(0.5))
		tex.gradient = grad
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1, 1)
		
		ResourceSaver.save(tex, "res://assets/icons/gifts/icon_" + key + ".tres")
	
	print("Gift icons generated successfully!")
	quit()
