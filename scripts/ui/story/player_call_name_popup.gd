extends Control

signal title_submitted

const INPUT_PLACEHOLDER := "例如 老师、哥哥、小名"

var preferred_title: String = ""

@onready var title_input: LineEdit = %TitleInput
@onready var confirm_btn: Button = %ConfirmBtn

func _ready() -> void:
	if GameDataManager.profile:
		preferred_title = str(GameDataManager.profile.player_title).strip_edges()
	if preferred_title != "":
		title_input.text = preferred_title
	title_input.placeholder_text = INPUT_PLACEHOLDER
	title_input.text_submitted.connect(_on_text_submitted)
	confirm_btn.pressed.connect(_on_confirm_pressed)
	title_input.grab_focus()

func _on_text_submitted(_text: String) -> void:
	_on_confirm_pressed()

func _on_confirm_pressed() -> void:
	var final_title := title_input.text.strip_edges()
	if final_title == "":
		title_input.grab_focus()
		return

	preferred_title = final_title
	if GameDataManager.memory_manager:
		var player_name := ""
		if GameDataManager.profile:
			player_name = str(GameDataManager.profile.player_name).strip_edges()
		var core_memory := "玩家希望我称呼其为：%s" % preferred_title
		if player_name != "":
			core_memory = "玩家的真实姓名是：%s，希望我称呼其为：%s" % [player_name, preferred_title]
		GameDataManager.memory_manager.add_memory("core", core_memory)
	title_submitted.emit()
