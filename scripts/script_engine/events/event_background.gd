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
		
	transition_type = data.get("transition_type", "fade")
	duration = data.get("duration", data.get("fade_time", 0.5))

func process_event(manager: Node) -> bool:
	var actual_path = bg_id
	if BackgroundManager.bg_data.has(bg_id):
		actual_path = BackgroundManager.get_bg_path(bg_id)
		
	print("[ScriptEngine] Change Background: ", bg_id, " -> ", actual_path, " [", transition_type, "]")
	manager.emit_signal("on_background_requested", actual_path, duration, transition_type)
	return false
