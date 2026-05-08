extends CanvasLayer
class_name SceneTransitionManagerClass

@onready var color_rect: ColorRect = $ColorRect

func _ready() -> void:
	layer = 100 # Ensure it is on top of everything
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_rect.color = Color(0, 0, 0, 0)
	hide()

func transition_to_scene(path: String, duration: float = 1.0) -> void:
	show()
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, duration / 2.0)
	await tween.finished
	
	get_tree().change_scene_to_file(path)
	
	tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, duration / 2.0)
	await tween.finished
	
	hide()
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
