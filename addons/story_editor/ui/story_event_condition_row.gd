@tool
extends HBoxContainer

signal delete_requested(row: Control)

const CONDITION_TYPES := [
	{"id": "location", "label": "地点", "field_a": "value", "label_a": "地点 ID"},
	{"id": "time_period", "label": "时段", "field_a": "value", "label_a": "时段"},
	{"id": "weather", "label": "天气", "field_a": "value", "label_a": "天气"},
	{"id": "time", "label": "小时范围", "field_a": "start_hour", "label_a": "开始小时", "field_b": "end_hour", "label_b": "结束小时", "numeric": true},
	{"id": "stat", "label": "属性", "field_a": "stat_name", "label_a": "属性名", "field_b": "value", "label_b": "最低值", "numeric_b": true},
	{"id": "stage", "label": "好感阶段", "field_a": "min_stage", "label_a": "最低阶段", "numeric": true},
	{"id": "npc_stage", "label": "NPC 阶段", "field_a": "npc_id", "label_a": "NPC ID", "field_b": "min_stage", "label_b": "最低阶段", "numeric_b": true}
]

var original_condition: Dictionary = {}


func _ready() -> void:
	for definition in CONDITION_TYPES:
		%TypeSelect.add_item(str(definition.label))
		%TypeSelect.set_item_metadata(%TypeSelect.item_count - 1, str(definition.id))
	%TypeSelect.item_selected.connect(_update_fields)
	%DeleteButton.pressed.connect(delete_requested.emit.bind(self))


func setup(condition: Dictionary) -> void:
	original_condition = condition.duplicate(true)
	var condition_type := str(condition.get("type", "location"))
	var selected_index := _find_type_index(condition_type)
	%TypeSelect.select(selected_index)
	_update_fields(selected_index)
	var definition := CONDITION_TYPES[selected_index] as Dictionary
	%FieldAEdit.text = str(condition.get(definition.get("field_a", ""), ""))
	%FieldBEdit.text = str(condition.get(definition.get("field_b", ""), "")) if definition.has("field_b") else ""


func get_condition() -> Dictionary:
	var result := original_condition.duplicate(true)
	var definition := CONDITION_TYPES[%TypeSelect.selected] as Dictionary
	result["type"] = str(definition.id)
	var field_a := str(definition.get("field_a", ""))
	var field_b := str(definition.get("field_b", ""))
	if not field_a.is_empty():
		result[field_a] = int(%FieldAEdit.text) if bool(definition.get("numeric", false)) else %FieldAEdit.text.strip_edges()
	if not field_b.is_empty():
		result[field_b] = int(%FieldBEdit.text) if bool(definition.get("numeric_b", false)) else %FieldBEdit.text.strip_edges()
	return result


func _update_fields(selected_index: int) -> void:
	var definition := CONDITION_TYPES[selected_index] as Dictionary
	%FieldALabel.text = str(definition.get("label_a", ""))
	%FieldAEdit.placeholder_text = str(definition.get("label_a", ""))
	var has_field_b := definition.has("field_b")
	%FieldBLabel.visible = has_field_b
	%FieldBEdit.visible = has_field_b
	%FieldBLabel.text = str(definition.get("label_b", ""))
	%FieldBEdit.placeholder_text = str(definition.get("label_b", ""))


func _find_type_index(condition_type: String) -> int:
	for type_index in CONDITION_TYPES.size():
		if str(CONDITION_TYPES[type_index].id) == condition_type:
			return type_index
	return 0