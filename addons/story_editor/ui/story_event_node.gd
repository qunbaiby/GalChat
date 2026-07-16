@tool
extends GraphNode

signal event_activated(chapter_id: String, event_index: int)

const FLOW_COLOR := Color("#d7e1e8")
const BRANCH_COLOR := Color("#58c99b")
const DEFAULT_TYPE_COLOR := Color("#7f8b96")
const EVENT_TYPE_INFO := {
	"dialogue": ["对白", Color("#4fa3d1")],
	"background": ["切换背景", Color("#d19a4f")],
	"audio": ["音效", Color("#a978c4")],
	"bgm": ["背景音乐", Color("#a978c4")],
	"show_character": ["显示角色", Color("#de6f7d")],
	"move_character": ["移动角色", Color("#de6f7d")],
	"hide_character": ["隐藏角色", Color("#de6f7d")],
	"period_card": ["时段卡片", Color("#d19a4f")],
	"choice": ["玩家选项", Color("#58c99b")],
	"jump": ["跳转章节", Color("#58c99b")],
	"set_variable": ["设置变量", Color("#7f8b96")],
	"ai_chat": ["AI 对话", Color("#4fa3d1")],
	"start_free_chat": ["自由聊天", Color("#4fa3d1")],
	"voice_call": ["语音通话", Color("#a978c4")],
	"show_player_call_name_popup": ["称呼设置弹窗", Color("#7f8b96")]
}

var chapter_id := ""
var event_index := -1
var event_data: Dictionary = {}
var option_rows: Array[Label] = []
var type_color := DEFAULT_TYPE_COLOR

@onready var type_accent: ColorRect = %TypeAccent
@onready var summary_label: Label = %SummaryLabel
@onready var details_label: Label = %DetailsLabel


func setup(next_chapter_id: String, next_event_index: int, next_event_data: Dictionary) -> void:
	chapter_id = next_chapter_id
	event_index = next_event_index
	event_data = next_event_data
	name = _node_name(chapter_id, event_index)
	var stored_position := event_data.get("_editor_position", {}) as Dictionary
	position_offset = Vector2(
		float(stored_position.get("x", 80.0 + (event_index % 4) * 300.0)),
		float(stored_position.get("y", 80.0 + floori(event_index / 4.0) * 190.0))
	)
	_refresh_content()


func refresh(next_event_data: Dictionary) -> void:
	event_data = next_event_data
	_refresh_content()


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	if not event_data.is_empty():
		_refresh_content()


func _refresh_content() -> void:
	if not is_node_ready():
		return
	var event_type := str(event_data.get("type", "unknown"))
	var type_info := EVENT_TYPE_INFO.get(event_type, [event_type, DEFAULT_TYPE_COLOR]) as Array
	type_color = type_info[1] as Color
	title = "%02d  %s · %s" % [event_index + 1, str(type_info[0]), event_type]
	type_accent.color = type_color.lightened(0.18) if selected else type_color
	summary_label.add_theme_color_override("font_color", type_color.lightened(0.22))
	summary_label.text = _event_summary(event_type)
	details_label.text = _event_details(event_type)
	_clear_option_rows()
	var has_linear_output := event_type != "jump" and event_type != "choice"
	var output_type := 1 if event_type == "jump" else 0
	var output_color := BRANCH_COLOR if event_type == "jump" else FLOW_COLOR
	set_slot(0, event_index > 0, 0, FLOW_COLOR, event_type == "jump" or has_linear_output, output_type, output_color)
	if event_type == "choice":
		_add_choice_ports()


func set_highlighted(highlighted: bool) -> void:
	selected = highlighted
	if is_node_ready():
		type_accent.color = type_color.lightened(0.28) if highlighted else type_color


func get_branch_option_index(port: int) -> int:
	return port if str(event_data.get("type", "")) == "choice" else -1


func _add_choice_ports() -> void:
	var options := event_data.get("options", []) as Array
	for option_index in options.size():
		var option_value: Variant = options[option_index]
		var option := option_value as Dictionary if option_value is Dictionary else {}
		var row := Label.new()
		row.text = "%d. %s" % [option_index + 1, str(option.get("text", option.get("label", "未命名选项")))]
		row.tooltip_text = str(option.get("target_chapter", "未连接时继续下一事件"))
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.custom_minimum_size = Vector2(222, 26)
		add_child(row)
		option_rows.append(row)
		set_slot(row.get_index(), false, 0, Color.WHITE, true, 1, BRANCH_COLOR)


func _clear_option_rows() -> void:
	for row in option_rows:
		if is_instance_valid(row):
			remove_child(row)
			row.free()
	option_rows.clear()


func _event_summary(event_type: String) -> String:
	match event_type:
		"dialogue":
			return str(event_data.get("speaker", "未指定角色"))
		"background", "period_card":
			return str(event_data.get("bg_id", "未指定背景"))
		"audio", "bgm":
			return str(event_data.get("audio_id", event_data.get("audio_path", "未指定音频")))
		"show_character", "move_character", "hide_character":
			return str(event_data.get("character", "未指定角色"))
		"jump":
			return "跳转到 %s" % str(event_data.get("target_chapter", "?"))
		"choice":
			var options := event_data.get("options", []) as Array
			return "%d 个选项" % options.size()
		_:
			return "事件参数"


func _event_details(event_type: String) -> String:
	var details := ""
	match event_type:
		"dialogue":
			details = str(event_data.get("content", ""))
		"background":
			details = "%s · %.1fs" % [str(event_data.get("transition_type", "fade")), float(event_data.get("duration", 0.0))]
		"audio", "bgm":
			details = "%s · %s" % [str(event_data.get("action", "play")), str(event_data.get("audio_type", "bgm"))]
		"show_character", "move_character":
			details = "%s · %s" % [str(event_data.get("position", "center")), str(event_data.get("expression", "default"))]
		"hide_character":
			details = str(event_data.get("animation", "fade_out"))
		"period_card":
			details = "%s · %s" % [str(event_data.get("period_label", "未设置时段")), str(event_data.get("location_name", "未设置地点"))]
		"choice":
			details = "从选项端口连接到目标章节"
		"jump":
			details = "跳转后不再执行当前章节后续事件"
		"set_variable":
			details = "%s = %s" % [str(event_data.get("var_name", "未命名变量")), str(event_data.get("var_value", ""))]
		"ai_chat":
			details = str(event_data.get("prompt_override", "使用默认 AI 提示词"))
		"start_free_chat":
			details = "%s · 最多 %d 轮" % [str(event_data.get("strategy", "默认策略")), int(event_data.get("max_rounds", 3))]
		"voice_call":
			details = str(event_data.get("call_id", "未指定通话"))
		"show_player_call_name_popup":
			details = "打开玩家称呼设置"
		_:
			details = "未识别事件，使用 Inspector 查看原始字段"
	return details.replace("\n", " ").left(72)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not event.ctrl_pressed and not event.shift_pressed:
		event_activated.emit(chapter_id, event_index)


static func _node_name(next_chapter_id: String, next_event_index: int) -> String:
	return "event_%s_%d" % [next_chapter_id.validate_node_name(), next_event_index]