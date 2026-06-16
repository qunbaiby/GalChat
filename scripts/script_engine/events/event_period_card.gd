extends "res://scripts/script_engine/script_event.gd"

var bg_id: String
var period_label: String
var location_name: String
var hold_duration: float

func _init(data: Dictionary) -> void:
	super(data)
	bg_id = str(data.get("bg_id", "")).strip_edges()
	period_label = str(data.get("period_label", "")).strip_edges()
	location_name = str(data.get("location_name", "")).strip_edges()
	hold_duration = float(data.get("hold_duration", 2.0))

func process_event(manager: Node) -> bool:
	var actual_path := bg_id
	var bg_manager = manager.get_node_or_null("/root/ImageManager")
	if bg_manager and bg_manager.get("image_data") and typeof(bg_manager.image_data) == TYPE_DICTIONARY:
		if bg_manager.image_data.has(bg_id):
			if bg_manager.has_method("get_image_path"):
				actual_path = bg_manager.get_image_path(bg_id)
			else:
				actual_path = bg_manager.image_data[bg_id]

	print("[ScriptEngine] Period Card: ", period_label, " / ", location_name, " -> ", actual_path)
	manager.emit_signal("on_period_card_requested", period_label, location_name, actual_path, hold_duration)
	return true
