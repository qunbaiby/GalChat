extends PanelContainer

signal close_requested
signal import_confirmed(file_paths: PackedStringArray)

@onready var close_btn: Button = $Margin/VBox/HeaderHBox/CloseBtn
@onready var drop_panel: PanelContainer = $Margin/VBox/DropPanel
@onready var drop_hint_label: Label = $Margin/VBox/DropPanel/DropMargin/DropVBox/HintLabel
@onready var count_label: Label = $Margin/VBox/DropPanel/DropMargin/DropVBox/CountLabel
@onready var file_list_container: VBoxContainer = $Margin/VBox/ListPanel/ListMargin/Scroll/FileList
@onready var empty_label: Label = $Margin/VBox/ListPanel/ListMargin/Scroll/FileList/EmptyLabel
@onready var clear_btn: Button = $Margin/VBox/FooterHBox/ClearBtn
@onready var cancel_btn: Button = $Margin/VBox/FooterHBox/CancelBtn
@onready var import_btn: Button = $Margin/VBox/FooterHBox/ImportBtn

const SUPPORTED_EXTENSIONS := ["mp3", "ogg"]

var _pending_files: PackedStringArray = PackedStringArray()

func _ready() -> void:
	top_level = true
	close_btn.pressed.connect(_on_close_pressed)
	clear_btn.pressed.connect(_on_clear_pressed)
	cancel_btn.pressed.connect(_on_close_pressed)
	import_btn.pressed.connect(_on_import_pressed)
	
	if get_window() and not get_window().files_dropped.is_connected(_on_files_dropped):
		get_window().files_dropped.connect(_on_files_dropped)
	
	_refresh_list()

func _exit_tree() -> void:
	if get_window() and get_window().files_dropped.is_connected(_on_files_dropped):
		get_window().files_dropped.disconnect(_on_files_dropped)

func show_popup(target: Control = null) -> void:
	clear_pending_files()
	show()
	move_to_front()
	call_deferred("_update_popup_position", target)

func clear_pending_files() -> void:
	_pending_files = PackedStringArray()
	_refresh_list()

func _update_popup_position(target: Control) -> void:
	var popup_size: Vector2 = get_combined_minimum_size()
	if popup_size == Vector2.ZERO:
		popup_size = size
	if popup_size == Vector2.ZERO:
		popup_size = Vector2(420, 360)
	
	popup_size.x = maxf(popup_size.x, 420.0)
	popup_size.y = maxf(popup_size.y, 360.0)
	size = popup_size
	
	var viewport_rect: Rect2 = get_viewport_rect()
	var position := (viewport_rect.size - popup_size) * 0.5
	if is_instance_valid(target):
		var target_rect: Rect2 = target.get_global_rect()
		position = Vector2(
			target_rect.position.x + (target_rect.size.x - popup_size.x) * 0.5,
			target_rect.position.y - popup_size.y - 14.0
		)
	
	position.x = clampf(position.x, 12.0, maxf(12.0, viewport_rect.size.x - popup_size.x - 12.0))
	position.y = clampf(position.y, 12.0, maxf(12.0, viewport_rect.size.y - popup_size.y - 12.0))
	global_position = position.round()

func _on_files_dropped(files: PackedStringArray) -> void:
	if not visible:
		return
	
	var valid_files: PackedStringArray = PackedStringArray()
	for file_path in files:
		var lower_path := str(file_path).to_lower()
		for ext in SUPPORTED_EXTENSIONS:
			if lower_path.ends_with("." + ext):
				if not _pending_files.has(file_path) and not valid_files.has(file_path):
					valid_files.append(file_path)
				break
	
	if valid_files.is_empty():
		if ToastManager:
			ToastManager.show_system_toast("请拖入 mp3 或 ogg 音乐文件", Color.RED)
		return
	
	for file_path in valid_files:
		_pending_files.append(file_path)
	
	_refresh_list()

func _refresh_list() -> void:
	for child in file_list_container.get_children():
		if child != empty_label:
			child.queue_free()
	
	empty_label.visible = _pending_files.is_empty()
	count_label.text = "待导入 %d 首" % _pending_files.size()
	drop_hint_label.text = "将 mp3 / ogg 文件拖到这个弹窗里"
	import_btn.disabled = _pending_files.is_empty()
	clear_btn.disabled = _pending_files.is_empty()
	
	for file_path in _pending_files:
		var item_label := Label.new()
		item_label.text = str(file_path).get_file()
		item_label.clip_text = true
		item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item_label.add_theme_font_size_override("font_size", 13)
		item_label.add_theme_color_override("font_color", Color(0.28, 0.31, 0.36, 1.0))
		file_list_container.add_child(item_label)

func _on_clear_pressed() -> void:
	clear_pending_files()

func _on_close_pressed() -> void:
	hide()
	close_requested.emit()

func _on_import_pressed() -> void:
	if _pending_files.is_empty():
		if ToastManager:
			ToastManager.show_system_toast("请先拖入音乐文件", Color.RED)
		return
	
	import_confirmed.emit(_pending_files)
	hide()
	close_requested.emit()
