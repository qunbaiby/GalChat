extends Control

signal edit_submitted(layer: String, memory_id: String, content: String)

@onready var content_edit: TextEdit = %ContentEdit
@onready var status_label: Label = %StatusLabel
@onready var cancel_button: Button = %CancelButton
@onready var save_button: Button = %SaveButton

var _layer := ""
var _memory_id := ""

func _ready() -> void:
	cancel_button.pressed.connect(queue_free)
	save_button.pressed.connect(_on_save_pressed)
	content_edit.text_changed.connect(func() -> void: status_label.text = "")
	content_edit.grab_focus()

func setup(layer: String, memory_id: String, content: String) -> void:
	_layer = layer
	_memory_id = memory_id
	if is_node_ready():
		content_edit.text = content
		content_edit.set_caret_line(content_edit.get_line_count() - 1)
	else:
		set_meta("initial_content", content)

func _notification(what: int) -> void:
	if what == NOTIFICATION_READY and has_meta("initial_content"):
		content_edit.text = str(get_meta("initial_content"))
		content_edit.set_caret_line(content_edit.get_line_count() - 1)

func _on_save_pressed() -> void:
	var final_content := content_edit.text.strip_edges()
	if final_content.is_empty():
		status_label.text = "记忆内容不能为空"
		return
	edit_submitted.emit(_layer, _memory_id, final_content)
	queue_free()