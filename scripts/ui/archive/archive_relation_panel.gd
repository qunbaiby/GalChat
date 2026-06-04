extends Control

@onready var close_btn: Button = $Panel/VBoxContainer/TopBar/CloseButton
@onready var relation_graph_view = $Panel/VBoxContainer/ScrollContainer/RelationGraphView


func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)


func show_panel(char_id: String = "") -> void:
	var target_char_id := char_id
	if target_char_id == "" and GameDataManager.config and GameDataManager.config.current_character_id != "":
		target_char_id = GameDataManager.config.current_character_id
	if target_char_id == "":
		target_char_id = "luna"

	_load_relation_archive(target_char_id)
	show()

	position.x = size.x
	modulate.a = 0.0
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


func _load_relation_archive(char_id: String) -> void:
	var temp_profile := CharacterProfile.new()
	temp_profile.load_profile(char_id)
	if is_instance_valid(relation_graph_view):
		relation_graph_view.set_archive_data(char_id, temp_profile)


func _on_close_pressed() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:x", size.x, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(hide)
