extends VBoxContainer

signal move_requested(row: Control, direction: int)
signal delete_requested(row: Control)

var source_option: Dictionary = {}


func _ready() -> void:
	%MoveUpButton.pressed.connect(move_requested.emit.bind(self, -1))
	%MoveDownButton.pressed.connect(move_requested.emit.bind(self, 1))
	%DeleteButton.pressed.connect(delete_requested.emit.bind(self))


func setup(option: Dictionary, chapter_ids: Array[String]) -> void:
	source_option = option.duplicate(true)
	%IdEdit.text = str(option.get("id", ""))
	%TextEdit.text = str(option.get("text", option.get("label", "")))
	%TargetSelect.clear()
	%TargetSelect.add_item("继续下一事件")
	%TargetSelect.set_item_metadata(0, "")
	for chapter_id in chapter_ids:
		%TargetSelect.add_item("剧情结束" if chapter_id == "end" else chapter_id)
		%TargetSelect.set_item_metadata(%TargetSelect.item_count - 1, chapter_id)
	var target := str(option.get("target_chapter", ""))
	for index in %TargetSelect.item_count:
		if str(%TargetSelect.get_item_metadata(index)) == target:
			%TargetSelect.select(index)
			break
	var effects := option.get("effects", {}) as Dictionary
	%IntimacySpin.value = float(effects.get("intimacy", 0))
	%TrustSpin.value = float(effects.get("trust", 0))


func set_index(index: int, count: int) -> void:
	%IndexLabel.text = "选项 #%d" % (index + 1)
	%MoveUpButton.disabled = index == 0
	%MoveDownButton.disabled = index >= count - 1


func get_option() -> Dictionary:
	var result := source_option.duplicate(true)
	result["id"] = %IdEdit.text.strip_edges()
	result["text"] = %TextEdit.text
	result.erase("label")
	var target := str(%TargetSelect.get_item_metadata(%TargetSelect.selected))
	if target.is_empty():
		result.erase("target_chapter")
	else:
		result["target_chapter"] = target
	var effects := result.get("effects", {}) as Dictionary
	effects["intimacy"] = int(%IntimacySpin.value)
	effects["trust"] = int(%TrustSpin.value)
	result["effects"] = effects
	return result
