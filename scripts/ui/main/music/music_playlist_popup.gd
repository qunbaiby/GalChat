extends PanelContainer

signal close_requested

func _ready() -> void:
	top_level = true
	get_close_btn().pressed.connect(_on_close_pressed)

func get_close_btn() -> Button:
	return $Margin/VBox/HeaderHBox/CloseBtn

func get_playlist_container() -> VBoxContainer:
	return $Margin/VBox/Scroll/ListContainer

func get_category_option() -> OptionButton:
	return $Margin/VBox/CategoryOption

func get_import_btn() -> Button:
	return $Margin/VBox/ImportBtn

func setup_category_options(selected_index: int = 0) -> void:
	var category_option := get_category_option()
	category_option.clear()
	category_option.add_item("全部", 0)
	category_option.add_item("本地导入", 1)
	category_option.add_item("收藏", 2)
	category_option.select(clampi(selected_index, 0, max(category_option.item_count - 1, 0)))

func show_above_target(target: Control, gap: float = 10.0) -> void:
	show()
	move_to_front()
	call_deferred("_update_position_above_target", target, gap)

func _update_position_above_target(target: Control, gap: float) -> void:
	if not is_instance_valid(target):
		return

	var popup_size := get_combined_minimum_size()
	if popup_size == Vector2.ZERO:
		popup_size = size
	if popup_size == Vector2.ZERO:
		popup_size = Vector2(360, 154)

	popup_size.x = maxf(popup_size.x, 360.0)
	popup_size.y = maxf(popup_size.y, 154.0)
	size = popup_size

	var target_rect := target.get_global_rect()
	var viewport_rect := get_viewport_rect()
	var x := target_rect.position.x + (target_rect.size.x - popup_size.x) * 0.5
	var y := target_rect.position.y - popup_size.y - gap

	x = clampf(x, 8.0, maxf(8.0, viewport_rect.size.x - popup_size.x - 8.0))
	y = maxf(8.0, y)
	global_position = Vector2(round(x), round(y))

func _on_close_pressed() -> void:
	hide()
	close_requested.emit()
