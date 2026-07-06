extends Control

signal name_submitted(archive_name: String)

const INPUT_PLACEHOLDER := "例如 第一次相遇、夏日记忆、Luna 的新篇章"

@onready var name_input: LineEdit = get_node_or_null("PopupPanel/MarginContainer/VBoxContainer/NameInput") as LineEdit
@onready var confirm_btn: Button = get_node_or_null("PopupPanel/MarginContainer/VBoxContainer/ConfirmBtn") as Button

func _ready() -> void:
	if name_input == null or confirm_btn == null:
		push_error("ArchiveNamePopup 节点缺失，无法初始化命名弹窗。")
		return
	name_input.placeholder_text = INPUT_PLACEHOLDER
	name_input.text_submitted.connect(_on_text_submitted)
	confirm_btn.pressed.connect(_on_confirm_pressed)
	name_input.grab_focus()

func _on_text_submitted(_text: String) -> void:
	_on_confirm_pressed()

func _on_confirm_pressed() -> void:
	var final_name := name_input.text.strip_edges()
	if final_name == "":
		name_input.grab_focus()
		return
	name_submitted.emit(final_name)
