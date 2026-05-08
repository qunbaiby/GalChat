extends Control

@onready var panel: PanelContainer = $PanelContainer
@onready var gradient_rect: TextureRect = $PanelContainer/GradientRect
@onready var icon_rect: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/IconRect
@onready var label: Label = $PanelContainer/MarginContainer/HBoxContainer/Label

var display_time: float = 3.0

func setup(message: String, color: Color, icon: Texture2D) -> void:
	label.text = message
	gradient_rect.modulate = color
	
	if icon != null:
		icon_rect.texture = icon
		icon_rect.show()
	else:
		icon_rect.hide()
		
	# Wait for a frame so sizes are calculated
	call_deferred("_animate_in")

func _animate_in() -> void:
	var target_width = panel.size.x
	custom_minimum_size = Vector2(target_width, panel.size.y)
	
	panel.position.x = -target_width - 20
	panel.modulate.a = 0.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "position:x", 0.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	
	tween.chain().tween_interval(display_time)
	
	tween.chain().tween_property(panel, "position:x", -target_width - 20, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(panel, "modulate:a", 0.0, 0.3)
	
	tween.finished.connect(queue_free)
