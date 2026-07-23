@tool
extends VBoxContainer

signal event_applied(event_data: Dictionary)

const ChoiceOptionsEditorScene = preload("res://addons/story_editor/ui/story_choice_options_editor.tscn")

const EVENT_TYPES := [
	"dialogue", "background", "audio", "bgm", "show_character",
	"move_character", "hide_character", "period_card", "choice", "jump",
	"set_variable", "ai_chat", "guided_ai_chat", "start_free_chat", "voice_call",
	"show_player_call_name_popup"
]

const EVENT_TYPE_INFO := {
	"dialogue": ["对白", "编辑角色发言、表情、情绪和正文。"],
	"background": ["切换背景", "切换场景背景并设置过渡方式。"],
	"audio": ["音效", "播放或停止环境音和一次性音效。"],
	"bgm": ["背景音乐", "控制背景音乐、循环和淡入淡出。"],
	"show_character": ["显示角色", "让角色以指定表情和位置进入画面。"],
	"move_character": ["移动角色", "调整已显示角色的位置、表情和焦点。"],
	"hide_character": ["隐藏角色", "让指定角色离开画面。"],
	"period_card": ["时段卡片", "展示地点与时段之间的转场卡片。"],
	"choice": ["玩家选项", "创建玩家选择及其效果和目标章节。"],
	"jump": ["跳转章节", "结束当前顺序流并跳转到目标章节。"],
	"set_variable": ["设置变量", "写入剧情变量供后续条件和分支使用。"],
	"ai_chat": ["AI 对话", "启动受 Prompt 控制的 AI 对话事件。"],
	"guided_ai_chat": ["引导式 AI 主线对话", "在作者设定的剧情锚点、必达信息和回合预算内进行自然语言对话，并由角色自动收束。"],
	"start_free_chat": ["自由聊天", "进入限定轮数的自由聊天流程。"],
	"voice_call": ["语音通话", "播放一个已注册的固定语音通话。"],
	"show_player_call_name_popup": ["称呼设置弹窗", "请求玩家设置角色对自己的称呼。"]
}

const EVENT_SCHEMAS := {
	"dialogue": [
		["speaker", "发言者", "resource", "character"], ["character", "角色 ID", "resource", "character"],
		["expression", "表情", "resource", "expression"], ["display_name", "显示名", "string"],
		["mood", "情绪", "string"], ["focus", "聚焦", "bool"],
		["voice_instruction", "语音指令（TTS 2.0）", "string"],
		["content", "对白内容", "multiline"]
	],
	"background": [
		["bg_id", "背景 ID", "resource", "image"], ["transition_type", "过渡类型", "string"],
		["duration", "过渡时长", "number"]
	],
	"audio": [
		["audio_id", "音频 ID", "resource", "audio"], ["audio_type", "音频类型", "string"],
		["action", "动作", "string"], ["fade_time", "淡入淡出", "number"],
		["loop", "循环", "bool"]
	],
	"bgm": [
		["audio_id", "音频 ID", "resource", "audio"], ["audio_path", "兼容路径", "string"],
		["action", "动作", "string"], ["fade_time", "淡入淡出", "number"],
		["loop", "循环", "bool"]
	],
	"show_character": [
		["character", "角色 ID", "resource", "character"], ["position", "位置", "string"],
		["expression", "表情", "resource", "expression"], ["animation", "动画", "string"],
		["display_name", "显示名", "string"], ["focus", "聚焦", "bool"]
	],
	"move_character": [
		["character", "角色 ID", "resource", "character"], ["position", "位置", "string"],
		["expression", "表情", "resource", "expression"], ["animation", "动画", "string"],
		["display_name", "显示名", "string"], ["focus", "聚焦", "bool"]
	],
	"hide_character": [
		["character", "角色 ID", "resource", "character"], ["animation", "动画", "string"]
	],
	"period_card": [
		["bg_id", "背景 ID", "resource", "image"], ["period_label", "时段", "string"],
		["location_name", "地点名", "string"], ["hold_duration", "停留时长", "number"]
	],
	"choice": [["options", "选项列表", "choice_options"]],
	"jump": [["target_chapter", "目标章节", "chapter"]],
	"set_variable": [["var_name", "变量名", "string"], ["var_value", "变量值", "json"]],
	"ai_chat": [["prompt_override", "Prompt 覆盖", "multiline"]],
	"guided_ai_chat": [
		["session_id", "会话 ID", "string"],
		["narrative_anchor", "剧情锚点", "multiline"],
		["scene_objective", "场景目标", "multiline"],
		["allowed_topics", "允许讨论范围", "json"],
		["forbidden_facts", "禁止改写事实", "json"],
		["required_beats", "必达剧情点", "json"],
		["redirect_instruction", "偏题回拉策略", "multiline"],
		["max_player_rounds", "最大玩家回合", "integer"],
		["game_minutes", "完成后推进分钟", "integer"],
		["action_cost", "进入所需行动力", "integer"],
		["allow_early_completion", "允许达标后提前收束", "bool"],
		["hide_manual_end", "隐藏主动结束", "bool"],
		["closing_instruction", "自然收束指令", "multiline"],
		["fallback_closing_text", "失败兜底收束台词", "multiline"],
		["outcome_branches", "结果章节映射", "json"]
	],
	"start_free_chat": [["strategy", "对话策略", "multiline"], ["max_rounds", "最大轮数", "integer"]],
	"voice_call": [["call_id", "固定通话 ID", "resource", "call"]],
	"show_player_call_name_popup": []
}

var current_event: Dictionary = {}
var field_controls: Dictionary = {}
var resource_catalog: Dictionary = {}
var chapter_ids: Array[String] = ["end"]
var loading := false

@onready var type_select: OptionButton = %TypeSelect
@onready var fields_container: VBoxContainer = %FieldsContainer
@onready var advanced_json_edit: CodeEdit = %AdvancedJsonEdit
@onready var apply_button: Button = %ApplyButton
@onready var error_label: Label = %ErrorLabel


func _ready() -> void:
	for event_type in EVENT_TYPES:
		var info := EVENT_TYPE_INFO.get(event_type, [event_type, ""]) as Array
		type_select.add_item(str(info[0]))
		type_select.set_item_metadata(type_select.item_count - 1, event_type)
	type_select.item_selected.connect(_on_type_selected)
	apply_button.pressed.connect(_apply_structured)
	%ApplyJsonButton.pressed.connect(_apply_json)
	clear_event()


func load_event(event_data: Dictionary) -> void:
	current_event = event_data.duplicate(true)
	loading = true
	_select_type(str(current_event.get("type", "dialogue")))
	_rebuild_fields()
	advanced_json_edit.text = JSON.stringify(current_event, "    ", false)
	apply_button.disabled = false
	%ApplyJsonButton.disabled = false
	error_label.text = ""
	loading = false


func set_resource_catalog(catalog: Dictionary) -> void:
	resource_catalog = catalog
	if not current_event.is_empty():
		_rebuild_fields()


func set_chapter_ids(values: Array) -> void:
	chapter_ids.clear()
	for value in values:
		chapter_ids.append(str(value))
	if not chapter_ids.has("end"):
		chapter_ids.append("end")
	if not current_event.is_empty() and str(current_event.get("type", "")) in ["choice", "jump"]:
		_rebuild_fields()


func clear_event() -> void:
	current_event = {}
	_clear_fields()
	advanced_json_edit.text = ""
	apply_button.disabled = true
	%ApplyJsonButton.disabled = true
	error_label.text = "选择一个节点后编辑事件。"
	%TypeDescription.text = "选择画布中的事件节点后，这里会显示常用字段。"


func _on_type_selected(_index: int) -> void:
	if loading or current_event.is_empty():
		return
	current_event["type"] = str(type_select.get_item_metadata(type_select.selected))
	_rebuild_fields()


func _rebuild_fields() -> void:
	_clear_fields()
	var event_type := str(type_select.get_item_metadata(type_select.selected))
	var info := EVENT_TYPE_INFO.get(event_type, [event_type, ""]) as Array
	%TypeDescription.text = str(info[1])
	var schema := EVENT_SCHEMAS.get(event_type, []) as Array
	for field_value in schema:
		var field := field_value as Array
		var key := str(field[0])
		var label_text := str(field[1])
		var kind := str(field[2])
		var resource_type := str(field[3]) if field.size() > 3 else ""
		var control := _create_field_control(key, label_text, kind, resource_type)
		field_controls[key] = {"control": control, "kind": kind}
		_set_control_value(control, kind, current_event.get(key))


func _create_field_control(key: String, label_text: String, kind: String, resource_type: String) -> Control:
	var row := VBoxContainer.new()
	row.name = "Field_%s" % key.validate_node_name()
	fields_container.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.modulate = Color("#9eb2bd")
	row.add_child(label)
	var control: Control
	match kind:
		"choice_options":
			control = ChoiceOptionsEditorScene.instantiate()
		"chapter":
			var chapter_select := OptionButton.new()
			for chapter_id in chapter_ids:
				chapter_select.add_item("剧情结束" if chapter_id == "end" else chapter_id)
				chapter_select.set_item_metadata(chapter_select.item_count - 1, chapter_id)
			control = chapter_select
		"resource":
			var option_button := OptionButton.new()
			option_button.fit_to_longest_item = false
			option_button.add_item("未指定")
			option_button.set_item_metadata(0, "")
			for entry_value in resource_catalog.get(resource_type, []):
				var entry := entry_value as Dictionary
				option_button.add_item(str(entry.get("label", entry.get("id", ""))))
				option_button.set_item_metadata(option_button.item_count - 1, str(entry.get("id", "")))
				option_button.set_item_tooltip(option_button.item_count - 1, str(entry.get("path", "")))
			control = option_button
		"multiline", "json":
			var text_edit := TextEdit.new()
			text_edit.custom_minimum_size = Vector2(0, 110 if kind == "multiline" else 150)
			text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			control = text_edit
		"number", "integer":
			var spin_box := SpinBox.new()
			spin_box.min_value = -100000.0
			spin_box.max_value = 100000.0
			spin_box.step = 1.0 if kind == "integer" else 0.1
			spin_box.allow_greater = true
			spin_box.allow_lesser = true
			control = spin_box
		"bool":
			var check_box := CheckBox.new()
			check_box.text = "启用"
			control = check_box
		_:
			control = LineEdit.new()
	row.add_child(control)
	return control


func _set_control_value(control: Control, kind: String, value: Variant) -> void:
	match kind:
		"choice_options":
			control.setup(value as Array if value is Array else [], chapter_ids)
		"chapter":
			var target := "end" if value == null else str(value)
			for index in control.item_count:
				if str(control.get_item_metadata(index)) == target:
					control.select(index)
					break
		"resource":
			var resource_id := "" if value == null else str(value)
			var selected_index := -1
			for index in control.item_count:
				if str(control.get_item_metadata(index)) == resource_id:
					selected_index = index
					break
			if selected_index < 0 and not resource_id.is_empty():
				control.add_item("未注册 · %s" % resource_id)
				control.set_item_metadata(control.item_count - 1, resource_id)
				selected_index = control.item_count - 1
			control.select(maxi(selected_index, 0))
		"multiline", "string":
			control.text = "" if value == null else str(value)
		"json":
			control.text = JSON.stringify(value, "    ", false)
		"number", "integer":
			control.value = 0.0 if value == null else float(value)
		"bool":
			control.button_pressed = false if value == null else bool(value)


func _apply_structured() -> void:
	var updated := current_event.duplicate(true)
	updated["type"] = str(type_select.get_item_metadata(type_select.selected))
	for key_value in field_controls.keys():
		var key := str(key_value)
		var entry := field_controls[key] as Dictionary
		var value_result := _read_control_value(entry.control, str(entry.kind), key)
		if not value_result.get("ok", false):
			error_label.text = str(value_result.get("error", "字段格式错误。"))
			return
		updated[key] = value_result.get("value")
	current_event = updated
	advanced_json_edit.text = JSON.stringify(current_event, "    ", false)
	error_label.text = "已应用到剧情，记得保存文件。"
	error_label.modulate = Color("#73d9b0")
	event_applied.emit(current_event.duplicate(true))


func _read_control_value(control: Control, kind: String, key: String) -> Dictionary:
	match kind:
		"choice_options":
			return {"ok": true, "value": control.get_options()}
		"chapter":
			return {"ok": true, "value": str(control.get_item_metadata(control.selected))}
		"resource":
			return {"ok": true, "value": str(control.get_item_metadata(control.selected))}
		"multiline", "string":
			return {"ok": true, "value": control.text}
		"number":
			return {"ok": true, "value": float(control.value)}
		"integer":
			return {"ok": true, "value": int(control.value)}
		"bool":
			return {"ok": true, "value": bool(control.button_pressed)}
		"json":
			var parser := JSON.new()
			var parse_error := parser.parse(control.text)
			if parse_error != OK:
				return {"ok": false, "error": "%s 的 JSON 第 %d 行错误：%s" % [key, parser.get_error_line(), parser.get_error_message()]}
			return {"ok": true, "value": parser.data}
	return {"ok": false, "error": "不支持的字段类型：%s" % kind}


func _apply_json() -> void:
	var parser := JSON.new()
	var parse_error := parser.parse(advanced_json_edit.text)
	if parse_error != OK:
		error_label.text = "JSON 第 %d 行错误：%s" % [parser.get_error_line(), parser.get_error_message()]
		return
	if not parser.data is Dictionary:
		error_label.text = "事件必须是 JSON 对象。"
		return
	load_event(parser.data)
	error_label.text = "高级 JSON 已应用到剧情，记得保存文件。"
	error_label.modulate = Color("#73d9b0")
	event_applied.emit(current_event.duplicate(true))


func _select_type(event_type: String) -> void:
	var index := EVENT_TYPES.find(event_type)
	type_select.select(maxi(index, 0))


func _clear_fields() -> void:
	field_controls.clear()
	for child in fields_container.get_children():
		fields_container.remove_child(child)
		child.queue_free()