extends Control

signal screen_selected(screen_index: int)

@onready var screen_dialog: ConfirmationDialog = $ScreenSelectionDialog
@onready var screen_option: OptionButton = $ScreenSelectionDialog/ScreenMargin/ScreenVBox/ScreenOption

func _ready() -> void:
	screen_dialog.confirmed.connect(func() -> void:
		screen_selected.emit(screen_option.get_selected_id())
	)
	screen_dialog.canceled.connect(func() -> void:
		screen_selected.emit(-1)
	)

func request_screen_selection(screen_names: Array[String], current_screen: int) -> void:
	screen_option.clear()
	for screen_index in range(screen_names.size()):
		screen_option.add_item(screen_names[screen_index], screen_index)
	screen_option.select(clampi(current_screen, 0, screen_names.size() - 1))
	screen_dialog.popup_centered(Vector2i(430, 190))

func hide_desktop_controls() -> void:
	screen_dialog.hide()
	hide()