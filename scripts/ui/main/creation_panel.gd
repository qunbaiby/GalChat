extends Control
class_name CreationPanel

signal drawing_requested
signal music_requested
signal close_requested

@onready var dismiss_button: Button = get_node_or_null("DismissButton")
@onready var panel_canvas: Control = get_node_or_null("CenterContainer/PanelRoot/PanelCanvas")
@onready var close_button: Button = get_node_or_null("CenterContainer/PanelRoot/PanelCanvas/CloseButton")
@onready var drawing_button: Button = get_node_or_null("CenterContainer/PanelRoot/PanelCanvas/MainMargin/MainHBox/RightStage/RightMargin/RightVBox/ScrollContainer/GridContainer/DrawingButton")
@onready var music_button: Button = get_node_or_null("CenterContainer/PanelRoot/PanelCanvas/MainMargin/MainHBox/RightStage/RightMargin/RightVBox/ScrollContainer/GridContainer/MusicButton")

func _ready() -> void:
	hide()
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	if drawing_button:
		drawing_button.pressed.connect(func() -> void:
			drawing_requested.emit()
		)
	if music_button:
		music_button.pressed.connect(func() -> void:
			music_requested.emit()
		)
	set_process(true)

func show_panel() -> void:
	show()
	_update_close_button_visibility()

func hide_panel() -> void:
	hide()

func attach_overlay(overlay: Control) -> void:
	if overlay == null:
		return
	var host: Control = panel_canvas if panel_canvas != null else self
	if overlay.get_parent() != host:
		overlay.reparent(host, false)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.move_child(overlay, host.get_child_count() - 1)
	_update_close_button_visibility()

func _process(_delta: float) -> void:
	_update_close_button_visibility()

func _update_close_button_visibility() -> void:
	if close_button == null:
		return
	close_button.visible = not _has_visible_overlay()

func _has_visible_overlay() -> bool:
	var host: Control = panel_canvas if panel_canvas != null else self
	for child in host.get_children():
		if child == close_button:
			continue
		if child is Control and (child as Control).visible:
			var child_control: Control = child as Control
			if child_control.name == "MainMargin":
				continue
			if child_control.name == "ClipPanel":
				continue
			return true
	return false

func _on_close_pressed() -> void:
	hide_panel()
	close_requested.emit()
