extends Control

@onready var background_panel: ColorRect = $Background
@onready var panel_root: Panel = $CenterContainer/Panel
@onready var close_btn: Button = $CenterContainer/Panel/CloseButton
@onready var relation_graph_view: RelationGraphView = $CenterContainer/Panel/VBoxContainer/BodyMargin/RelationGraphView

var _panel_tween: Tween = null


func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	background_panel.gui_input.connect(_on_background_gui_input)
	resized.connect(_on_panel_resized)
	hide()


func show_panel(char_id: String = "") -> void:
	var target_char_id: String = char_id
	if target_char_id == "" and GameDataManager.config and GameDataManager.config.current_character_id != "":
		target_char_id = GameDataManager.config.current_character_id
	if target_char_id == "":
		target_char_id = "luna"

	_load_relation_archive(target_char_id)
	_update_popup_layout()
	show()
	background_panel.modulate.a = 0.0
	panel_root.modulate.a = 0.0
	panel_root.scale = Vector2(0.97, 0.97)
	_kill_panel_tween()
	_panel_tween = create_tween()
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(background_panel, "modulate:a", 1.0, 0.18)
	_panel_tween.tween_property(panel_root, "modulate:a", 1.0, 0.22)
	_panel_tween.tween_property(panel_root, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _load_relation_archive(char_id: String) -> void:
	var temp_profile: CharacterProfile = CharacterProfile.new()
	temp_profile.load_profile(char_id)
	if is_instance_valid(relation_graph_view):
		relation_graph_view.set_archive_data(char_id, temp_profile)


func _on_close_pressed() -> void:
	hide_panel()

func hide_panel() -> void:
	if not visible:
		return
	_kill_panel_tween()
	_panel_tween = create_tween()
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(background_panel, "modulate:a", 0.0, 0.16)
	_panel_tween.tween_property(panel_root, "modulate:a", 0.0, 0.16)
	_panel_tween.tween_property(panel_root, "scale", Vector2(0.97, 0.97), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_panel_tween.set_parallel(false)
	_panel_tween.tween_callback(hide)

func _on_background_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		hide_panel()

func _on_panel_resized() -> void:
	if visible:
		_update_popup_layout()

func _update_popup_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var target_size: Vector2 = viewport_size
	panel_root.custom_minimum_size = target_size
	panel_root.size = target_size
	panel_root.pivot_offset = target_size * 0.5

func _kill_panel_tween() -> void:
	if _panel_tween != null:
		_panel_tween.kill()
		_panel_tween = null
