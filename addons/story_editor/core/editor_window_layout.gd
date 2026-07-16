extends RefCounted

const HORIZONTAL_MARGIN := 24
const TITLE_BAR_MARGIN := 56
const BOTTOM_MARGIN := 32
const COMPACT_MIN_SIZE := Vector2i(640, 480)


func open_window(window: Window, preferred_size: Vector2i, preferred_min_size: Vector2i = COMPACT_MIN_SIZE) -> void:
	var screen_index := window.current_screen
	if screen_index < 0:
		screen_index = DisplayServer.get_primary_screen()
	var usable_rect := DisplayServer.screen_get_usable_rect(screen_index)
	var geometry := calculate_geometry(usable_rect, preferred_size, preferred_min_size)
	window.initial_position = Window.WINDOW_INITIAL_POSITION_ABSOLUTE
	window.wrap_controls = false
	window.min_size = geometry.min_size
	window.size = geometry.size
	window.position = geometry.position
	window.show()
	window.call_deferred("set_size", geometry.size)
	window.call_deferred("set_position", geometry.position)


func calculate_geometry(usable_rect: Rect2i, preferred_size: Vector2i, preferred_min_size: Vector2i = COMPACT_MIN_SIZE) -> Dictionary:
	var available_size := Vector2i(
		maxi(320, usable_rect.size.x - HORIZONTAL_MARGIN * 2),
		maxi(240, usable_rect.size.y - TITLE_BAR_MARGIN - BOTTOM_MARGIN)
	)
	var fitted_min := Vector2i(
		mini(preferred_min_size.x, available_size.x),
		mini(preferred_min_size.y, available_size.y)
	)
	var fitted_size := Vector2i(
		clampi(preferred_size.x, fitted_min.x, available_size.x),
		clampi(preferred_size.y, fitted_min.y, available_size.y)
	)
	var fitted_position := usable_rect.position + Vector2i(
		maxi(HORIZONTAL_MARGIN, (usable_rect.size.x - fitted_size.x) / 2),
		maxi(TITLE_BAR_MARGIN, (usable_rect.size.y - fitted_size.y) / 2)
	)
	return {"position": fitted_position, "size": fitted_size, "min_size": fitted_min}