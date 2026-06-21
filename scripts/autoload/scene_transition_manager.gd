extends CanvasLayer
class_name SceneTransitionManagerClass

signal transition_finished(scene_path: String)

@onready var color_rect: ColorRect = $ColorRect
var _is_transitioning: bool = false

func _ready() -> void:
	layer = 100 # Ensure it is on top of everything
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_rect.color = Color(0, 0, 0, 0)
	hide()

func transition_to_scene(path: String, duration: float = 1.0) -> void:
	await transition_to_scene_with_mid_callback(path, Callable(), duration)

func transition_to_scene_with_mid_callback(path: String, mid_callback: Callable = Callable(), duration: float = 1.0) -> void:
	_is_transitioning = true
	show()
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, duration / 2.0)
	await tween.finished
	if mid_callback.is_valid():
		mid_callback.call()
	
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	
	tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, duration / 2.0)
	await tween.finished
	
	hide()
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false
	transition_finished.emit(path)

func transition_to_scene_instance(instance: Node, duration: float = 1.0) -> void:
	_is_transitioning = true
	show()
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, duration / 2.0)
	await tween.finished
	
	if get_tree().current_scene:
		get_tree().current_scene.queue_free()
	
	get_tree().root.add_child(instance)
	get_tree().current_scene = instance
	await get_tree().process_frame
	await get_tree().process_frame
	
	tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, duration / 2.0)
	await tween.finished
	
	hide()
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false
	transition_finished.emit("")

func is_transitioning() -> bool:
	return _is_transitioning or color_rect.color.a > 0.01
