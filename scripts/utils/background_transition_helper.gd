class_name BackgroundTransitionHelper
extends RefCounted

## 背景过渡渲染助手
## 将所有涉及背景 TextureRect 节点及其着色器过渡的逻辑从 dialogue_manager.gd 中剥离到此处

static func execute_transition(bg_node: TextureRect, tex: Texture2D, duration: float, transition_type: String, on_complete: Callable) -> void:
	if duration <= 0.0:
		bg_node.texture = tex
		on_complete.call()
		return
		
	var tween = bg_node.create_tween()
	
	if transition_type == "blur":
		var blur_overlay = bg_node.get_node_or_null("BlurOverlay")
		if blur_overlay:
			var blur_shader = load("res://scenes/ui/story/blur_shader.gdshader")
			var blur_mat = ShaderMaterial.new()
			blur_mat.shader = blur_shader
			blur_mat.set_shader_parameter("lod", 0.0)
			blur_overlay.material = blur_mat
			
			tween.tween_property(blur_mat, "shader_parameter/lod", 5.0, duration / 2.0).set_trans(Tween.TRANS_SINE)
			tween.tween_callback(func(): bg_node.texture = tex)
			tween.tween_property(blur_mat, "shader_parameter/lod", 0.0, duration / 2.0).set_trans(Tween.TRANS_SINE)
			tween.tween_callback(func(): 
				blur_overlay.material = null
				on_complete.call()
			)
		else:
			_default_fade(bg_node, tween, tex, duration, on_complete)
			
	elif transition_type == "shatter":
		var blur_overlay = bg_node.get_node_or_null("BlurOverlay")
		if blur_overlay:
			var shatter_shader = load("res://scenes/ui/story/shatter_shader.gdshader")
			var shatter_mat = ShaderMaterial.new()
			shatter_mat.shader = shatter_shader
			shatter_mat.set_shader_parameter("progress", 0.0)
			blur_overlay.material = shatter_mat
			
			tween.tween_property(shatter_mat, "shader_parameter/progress", 1.0, duration / 2.0).set_trans(Tween.TRANS_CUBIC)
			tween.tween_callback(func(): bg_node.texture = tex)
			tween.tween_callback(func(): 
				blur_overlay.material = null
				on_complete.call()
			)
		else:
			_default_fade(bg_node, tween, tex, duration, on_complete)
			
	elif transition_type == "pixelate":
		var blur_overlay = bg_node.get_node_or_null("BlurOverlay")
		if blur_overlay:
			var pixelate_shader = load("res://scenes/ui/story/pixelate_shader.gdshader")
			var pixelate_mat = ShaderMaterial.new()
			pixelate_mat.shader = pixelate_shader
			pixelate_mat.set_shader_parameter("pixel_size", 1.0)
			blur_overlay.material = pixelate_mat
			
			tween.tween_property(pixelate_mat, "shader_parameter/pixel_size", 50.0, duration / 2.0).set_trans(Tween.TRANS_SINE)
			tween.tween_callback(func(): bg_node.texture = tex)
			tween.tween_property(pixelate_mat, "shader_parameter/pixel_size", 1.0, duration / 2.0).set_trans(Tween.TRANS_SINE)
			tween.tween_callback(func(): 
				blur_overlay.material = null
				on_complete.call()
			)
		else:
			_default_fade(bg_node, tween, tex, duration, on_complete)
			
	elif transition_type == "dissolve":
		var dissolve_shader = load("res://scenes/ui/story/dissolve_shader.gdshader")
		var dissolve_mat = ShaderMaterial.new()
		dissolve_mat.shader = dissolve_shader
		dissolve_mat.set_shader_parameter("progress", 0.0)
		dissolve_mat.set_shader_parameter("old_texture", bg_node.texture)
		bg_node.material = dissolve_mat
		bg_node.texture = tex
		
		tween.tween_property(dissolve_mat, "shader_parameter/progress", 1.0, duration).set_trans(Tween.TRANS_LINEAR)
		tween.tween_callback(func(): 
			bg_node.material = null
			on_complete.call()
		)
		
	elif transition_type == "glitch":
		var glitch_shader = load("res://scenes/ui/story/glitch_shader.gdshader")
		var glitch_mat = ShaderMaterial.new()
		glitch_mat.shader = glitch_shader
		glitch_mat.set_shader_parameter("progress", 0.0)
		glitch_mat.set_shader_parameter("old_texture", bg_node.texture)
		bg_node.material = glitch_mat
		bg_node.texture = tex
		
		tween.tween_property(glitch_mat, "shader_parameter/progress", 1.0, duration).set_trans(Tween.TRANS_BOUNCE)
		tween.tween_callback(func(): 
			bg_node.material = null
			on_complete.call()
		)
		
	elif transition_type.begins_with("wipe_"):
		var wipe_shader = load("res://scenes/ui/story/wipe_shader.gdshader")
		var wipe_mat = ShaderMaterial.new()
		wipe_mat.shader = wipe_shader
		wipe_mat.set_shader_parameter("progress", 0.0)
		wipe_mat.set_shader_parameter("old_texture", bg_node.texture)
		
		var dir = Vector2(1.0, 0.0)
		if transition_type == "wipe_left": dir = Vector2(-1.0, 0.0)
		elif transition_type == "wipe_down": dir = Vector2(0.0, 1.0)
		elif transition_type == "wipe_up": dir = Vector2(0.0, -1.0)
		
		wipe_mat.set_shader_parameter("direction", dir)
		bg_node.material = wipe_mat
		bg_node.texture = tex
		
		tween.tween_property(wipe_mat, "shader_parameter/progress", 1.0, duration).set_trans(Tween.TRANS_LINEAR)
		tween.tween_callback(func(): 
			bg_node.material = null
			on_complete.call()
		)
		
	elif transition_type == "slide_left":
		var original_x = bg_node.position.x
		var viewport_w = bg_node.get_viewport_rect().size.x
		tween.tween_property(bg_node, "position:x", original_x - viewport_w, duration / 2.0).set_trans(Tween.TRANS_QUAD)
		tween.tween_callback(func(): 
			bg_node.texture = tex
			bg_node.position.x = original_x + viewport_w
		)
		tween.tween_property(bg_node, "position:x", original_x, duration / 2.0).set_trans(Tween.TRANS_QUAD)
		tween.tween_callback(on_complete)
		
	elif transition_type == "slide_up":
		var original_y = bg_node.position.y
		var viewport_h = bg_node.get_viewport_rect().size.y
		tween.tween_property(bg_node, "position:y", original_y - viewport_h, duration / 2.0).set_trans(Tween.TRANS_QUAD)
		tween.tween_callback(func(): 
			bg_node.texture = tex
			bg_node.position.y = original_y + viewport_h
		)
		tween.tween_property(bg_node, "position:y", original_y, duration / 2.0).set_trans(Tween.TRANS_QUAD)
		tween.tween_callback(on_complete)
		
	elif transition_type == "zoom":
		tween.tween_property(bg_node, "scale", Vector2(1.5, 1.5), duration / 2.0)
		tween.parallel().tween_property(bg_node, "modulate:a", 0.0, duration / 2.0)
		tween.tween_callback(func(): 
			bg_node.texture = tex
			bg_node.scale = Vector2(0.5, 0.5)
		)
		tween.tween_property(bg_node, "scale", Vector2(1.0, 1.0), duration / 2.0)
		tween.parallel().tween_property(bg_node, "modulate:a", 1.0, duration / 2.0)
		tween.tween_callback(on_complete)
		
	else:
		_default_fade(bg_node, tween, tex, duration, on_complete)

static func _default_fade(bg_node: TextureRect, tween: Tween, tex: Texture2D, duration: float, on_complete: Callable) -> void:
	tween.tween_property(bg_node, "modulate:a", 0.0, duration / 2.0)
	tween.tween_callback(func(): bg_node.texture = tex)
	tween.tween_property(bg_node, "modulate:a", 1.0, duration / 2.0)
	tween.tween_callback(on_complete)
