extends "res://scripts/script_engine/script_event.gd"

var bg_id: String
var transition_type: String
var duration: float

func _init(data: Dictionary) -> void:
	super(data)
	bg_id = data.get("bg_id", "")
	# Backwards compatibility
	if bg_id == "" and data.has("bg_path"):
		# Try to extract an ID from the path as fallback, or just pass the path if it's legacy
		bg_id = data.get("bg_path")
		
	# Supported transition_types: 
	# fade, blur, shatter, pixelate, dissolve, glitch, wipe_right, wipe_left, wipe_up, wipe_down, slide_left, slide_up, zoom
	transition_type = data.get("transition_type", "fade")
	duration = data.get("duration", data.get("fade_time", 0.5))

func process_event(manager: Node) -> bool:
	var actual_path = bg_id
	
	# Try to get background manager safely using get_node
	var bg_manager = manager.get_node_or_null("/root/BackgroundManager")
	if bg_manager and bg_manager.get("bg_data") and typeof(bg_manager.bg_data) == TYPE_DICTIONARY:
		if bg_manager.bg_data.has(bg_id):
			if bg_manager.has_method("get_bg_path"):
				actual_path = bg_manager.get_bg_path(bg_id)
			else:
				actual_path = bg_manager.bg_data[bg_id]
	
	print("[ScriptEngine] Change Background: ", bg_id, " -> ", actual_path, " [", transition_type, "]")
	manager.emit_signal("on_background_requested", actual_path, duration, transition_type)
	return duration > 0.0 # 如果有过渡动画，则阻塞等待动画播放完成
