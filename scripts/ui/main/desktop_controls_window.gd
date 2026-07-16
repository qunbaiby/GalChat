extends Window

signal return_requested
signal chat_requested

const WINDOW_SIZE := Vector2i(380, 400)
const SCREEN_MARGIN := 28

@onready var return_button: Button = $DockPanel/ReturnButton
@onready var chat_button: Button = $DockPanel/ChatButton
@onready var music_player: Control = $DockPanel/MusicPlayer

func _ready() -> void:
	borderless = true
	transparent = true
	transparent_bg = true
	always_on_top = false
	transient = false
	exclusive = false
	unresizable = true
	size = WINDOW_SIZE
	return_button.pressed.connect(return_requested.emit)
	chat_button.pressed.connect(chat_requested.emit)
	close_requested.connect(return_requested.emit)

func show_on_screen(screen_index: int) -> void:
	var screen_rect := DisplayServer.screen_get_usable_rect(screen_index)
	size = WINDOW_SIZE
	position = Vector2i(
		screen_rect.end.x - WINDOW_SIZE.x - SCREEN_MARGIN,
		screen_rect.end.y - WINDOW_SIZE.y - SCREEN_MARGIN
	)
	show()
	DisplayServer.window_set_mouse_passthrough(PackedVector2Array(), get_window_id())

func hide_controls() -> void:
	hide()