@tool
extends GraphNode

signal message_activated(message_index: int)

const FLOW_COLOR := Color("#d7e1e8")
const OPTION_COLOR := Color("#58c99b")
const SPEAKER_COLORS := {
	"player_options": Color("#58c99b"),
	"system": Color("#8b96a0")
}

var message_index := -1
var message_data: Dictionary = {}
var option_rows: Array[Label] = []

@onready var type_accent: ColorRect = %TypeAccent
@onready var speaker_label: Label = %SpeakerLabel
@onready var content_label: Label = %ContentLabel


func setup(next_message_index: int, next_message_data: Dictionary) -> void:
	message_index = next_message_index
	message_data = next_message_data
	name = node_name(message_index)
	var stored_position := message_data.get("_editor_position", {}) as Dictionary
	position_offset = Vector2(
		float(stored_position.get("x", 80.0 + (message_index % 4) * 300.0)),
		float(stored_position.get("y", 80.0 + floori(message_index / 4.0) * 190.0))
	)
	_refresh_content()


func refresh(next_message_data: Dictionary) -> void:
	message_data = next_message_data
	_refresh_content()


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	if not message_data.is_empty():
		_refresh_content()


func get_option_index(port: int) -> int:
	return port if str(message_data.get("speaker", "")) == "player_options" else -1


func _refresh_content() -> void:
	if not is_node_ready():
		return
	var message_id := str(message_data.get("id", "未命名"))
	var speaker := str(message_data.get("speaker", "未指定"))
	var accent := SPEAKER_COLORS.get(speaker, Color("#4fa3d1")) as Color
	title = "%02d  %s" % [message_index + 1, message_id]
	type_accent.color = accent
	speaker_label.text = _speaker_title(speaker)
	speaker_label.add_theme_color_override("font_color", accent.lightened(0.22))
	content_label.text = _content_summary(speaker)
	_clear_option_rows()
	set_slot(0, true, 0, FLOW_COLOR, speaker != "player_options", 0, FLOW_COLOR)
	if speaker == "player_options":
		_add_option_ports()


func _add_option_ports() -> void:
	var options := message_data.get("options", []) as Array
	for option_index in options.size():
		var option_value: Variant = options[option_index]
		var option := option_value as Dictionary if option_value is Dictionary else {}
		var row := Label.new()
		row.text = "%d. %s" % [option_index + 1, str(option.get("text", "未命名选项"))]
		row.tooltip_text = "下一消息：%s" % str(option.get("next", "按顺序继续"))
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.custom_minimum_size = Vector2(222, 26)
		add_child(row)
		option_rows.append(row)
		set_slot(row.get_index(), false, 0, Color.WHITE, true, 1, OPTION_COLOR)


func _clear_option_rows() -> void:
	for row in option_rows:
		if is_instance_valid(row):
			remove_child(row)
			row.free()
	option_rows.clear()


func _speaker_title(speaker: String) -> String:
	match speaker:
		"player_options":
			return "玩家选项"
		"system":
			return "系统消息"
		_:
			return speaker


func _content_summary(speaker: String) -> String:
	if speaker == "player_options":
		return "%d 个可选回复" % (message_data.get("options", []) as Array).size()
	if not str(message_data.get("image", "")).is_empty():
		return "图片 · %s" % str(message_data.get("image", ""))
	var text := str(message_data.get("text", ""))
	if bool(message_data.get("is_voice", false)):
		text = "语音 %.1fs · %s" % [float(message_data.get("duration", 0.0)), text]
	return text.replace("\n", " ").left(72)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		message_activated.emit(message_index)


static func node_name(next_message_index: int) -> String:
	return "message_%d" % next_message_index