extends Control

const MusicLibrary = preload("res://scripts/data/music_library.gd")
const PLAY_ICON: Texture2D = preload("res://assets/images/icons/ui/music/play-fill.png")
const PAUSE_ICON: Texture2D = preload("res://assets/images/icons/ui/music/pause-circle-fill.png")

signal close_requested
signal preview_started
signal preview_stopped
signal playlist_updated

const ITEM_SCENE: PackedScene = preload("res://scenes/ui/main/music/creation_music_item.tscn")
const IMPORT_POPUP_SCENE: PackedScene = preload("res://scenes/ui/main/music/music_import_popup.tscn")

const CATEGORY_BUILTIN: int = 0
const CATEGORY_FAVORITE: int = 1
const CATEGORY_LOCAL: int = 2
const PANEL_ENTER_OFFSET_X: float = -72.0
const PANEL_ENTER_DURATION: float = 0.24
const PANEL_EXIT_DURATION: float = 0.2

@onready var panel_root: PanelContainer = $CenterContainer/PanelRoot
@onready var close_button: Button = get_node_or_null("CenterContainer/PanelRoot/RootMargin/RootVBox/TopBar/CloseButton")
@onready var builtin_tab_button: Button = get_node_or_null("CenterContainer/PanelRoot/RootMargin/RootVBox/MainVBox/LeftColumn/CategoryRow/BuiltinTabButton")
@onready var favorite_tab_button: Button = get_node_or_null("CenterContainer/PanelRoot/RootMargin/RootVBox/MainVBox/LeftColumn/CategoryRow/FavoriteTabButton")
@onready var local_tab_button: Button = get_node_or_null("CenterContainer/PanelRoot/RootMargin/RootVBox/MainVBox/LeftColumn/CategoryRow/LocalTabButton")
@onready var track_list_container: VBoxContainer = get_node_or_null("CenterContainer/PanelRoot/RootMargin/RootVBox/MainVBox/LeftColumn/ListCard/ListMargin/ListScroll/TrackListContainer")
@onready var playlist_list_container: VBoxContainer = get_node_or_null("CenterContainer/PanelRoot/RootMargin/RootVBox/MainVBox/RightColumn/PlaylistCard/PlaylistMargin/PlaylistVBox/PlaylistScroll/PlaylistListContainer")
@onready var add_local_button: Button = get_node_or_null("CenterContainer/PanelRoot/RootMargin/RootVBox/MainVBox/RightColumn/PlaylistCard/PlaylistMargin/PlaylistVBox/AddLocalButton")
@onready var playlist_count_label: Label = get_node_or_null("CenterContainer/PanelRoot/RootMargin/RootVBox/MainVBox/RightColumn/PlaylistCard/PlaylistMargin/PlaylistVBox/PlaylistHeader/PlaylistCountLabel")
@onready var shuffle_button: Button = get_node_or_null("CenterContainer/PanelRoot/RootMargin/RootVBox/BottomBar/BottomMargin/BottomVBox/ControlsRow/ShuffleButton")
@onready var prev_button: Button = get_node_or_null("CenterContainer/PanelRoot/RootMargin/RootVBox/BottomBar/BottomMargin/BottomVBox/ControlsRow/PrevButton")
@onready var play_pause_button: Button = get_node_or_null("CenterContainer/PanelRoot/RootMargin/RootVBox/BottomBar/BottomMargin/BottomVBox/ControlsRow/PlayPauseButton")
@onready var next_button: Button = get_node_or_null("CenterContainer/PanelRoot/RootMargin/RootVBox/BottomBar/BottomMargin/BottomVBox/ControlsRow/NextButton")
@onready var volume_button: Button = get_node_or_null("CenterContainer/PanelRoot/RootMargin/RootVBox/BottomBar/BottomMargin/BottomVBox/ControlsRow/VolumeButton")
@onready var current_time_label: Label = get_node_or_null("CenterContainer/PanelRoot/RootMargin/RootVBox/BottomBar/BottomMargin/BottomVBox/TimelineRow/CurrentTimeLabel")
@onready var progress_bar: ProgressBar = get_node_or_null("CenterContainer/PanelRoot/RootMargin/RootVBox/BottomBar/BottomMargin/BottomVBox/TimelineRow/ProgressBar")
@onready var total_time_label: Label = get_node_or_null("CenterContainer/PanelRoot/RootMargin/RootVBox/BottomBar/BottomMargin/BottomVBox/TimelineRow/TotalTimeLabel")

var _panel_base_position: Vector2 = Vector2.ZERO
var _panel_tween: Tween = null
var _tracks: Array = []
var _selected_track_id: String = ""
var _playing_track_id: String = ""
var _current_category: int = CATEGORY_BUILTIN
var _preview_active: bool = false
var _import_popup_instance: Control = null
var _preview_player: AudioStreamPlayer = null
var _shuffle_enabled: bool = false

func _ready() -> void:
	if builtin_tab_button != null:
		builtin_tab_button.toggle_mode = true
		builtin_tab_button.pressed.connect(func() -> void: _switch_category(CATEGORY_BUILTIN))
	if favorite_tab_button != null:
		favorite_tab_button.toggle_mode = true
		favorite_tab_button.pressed.connect(func() -> void: _switch_category(CATEGORY_FAVORITE))
	if local_tab_button != null:
		local_tab_button.toggle_mode = true
		local_tab_button.pressed.connect(func() -> void: _switch_category(CATEGORY_LOCAL))
	if close_button != null:
		close_button.pressed.connect(_on_close_pressed)
	if add_local_button != null:
		add_local_button.pressed.connect(_on_add_local_pressed)
	if shuffle_button != null:
		shuffle_button.toggle_mode = true
		shuffle_button.pressed.connect(_on_shuffle_pressed)
	if play_pause_button != null:
		play_pause_button.pressed.connect(_on_play_pause_pressed)
	if prev_button != null:
		prev_button.pressed.connect(_on_prev_pressed)
	if next_button != null:
		next_button.pressed.connect(_on_next_pressed)
	if volume_button != null:
		volume_button.disabled = true
	_preview_player = AudioStreamPlayer.new()
	_preview_player.bus = "BGM"
	_preview_player.finished.connect(_on_preview_finished)
	add_child(_preview_player)
	_panel_base_position = panel_root.position
	hide()
	reload_tracks()

func _process(_delta: float) -> void:
	if _preview_player == null or _preview_player.stream == null or not _preview_active:
		progress_bar.value = 0.0 if _playing_track_id == "" else progress_bar.value
		return
	var total_length: float = maxf(_preview_player.stream.get_length(), 0.0)
	var current_position: float = _preview_player.get_playback_position()
	if total_length > 0.0:
		progress_bar.value = current_position / total_length
	current_time_label.text = MusicLibrary.format_duration(current_position)
	total_time_label.text = MusicLibrary.format_duration(total_length)

func show_panel() -> void:
	_stop_panel_tween()
	reload_tracks()
	show()
	modulate.a = 1.0
	panel_root.position = _panel_base_position + Vector2(PANEL_ENTER_OFFSET_X, 0.0)
	panel_root.modulate.a = 0.0
	_panel_tween = create_tween().set_parallel(true)
	_panel_tween.tween_property(panel_root, "position", _panel_base_position, PANEL_ENTER_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	_panel_tween.tween_property(panel_root, "modulate:a", 1.0, PANEL_ENTER_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)

func hide_panel() -> void:
	if not visible:
		return
	_stop_panel_tween()
	stop_preview()
	_panel_tween = create_tween().set_parallel(true)
	_panel_tween.tween_property(panel_root, "position", _panel_base_position, PANEL_EXIT_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	_panel_tween.tween_property(panel_root, "modulate:a", 0.0, PANEL_EXIT_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	_panel_tween.chain().tween_callback(_finish_hide_panel)

func reload_tracks() -> void:
	_tracks = MusicLibrary.load_tracks()
	if _selected_track_id == "" or _find_track_index(_selected_track_id) == -1:
		_selected_track_id = ""
	if _playing_track_id != "" and _find_track_index(_playing_track_id) == -1:
		_playing_track_id = ""
	_switch_category(_current_category, true)
	_update_bottom_bar()

func stop_preview(emit_signal_flag: bool = true) -> void:
	if _preview_player != null:
		_preview_player.stop()
	_preview_active = false
	_playing_track_id = ""
	if progress_bar != null:
		progress_bar.value = 0.0
	if current_time_label != null:
		current_time_label.text = "0:00"
	if total_time_label != null:
		total_time_label.text = "0:00"
	if play_pause_button != null:
		play_pause_button.icon = PLAY_ICON
	if emit_signal_flag:
		preview_stopped.emit()
	_refresh_track_list()

func _stop_panel_tween() -> void:
	if _panel_tween != null and _panel_tween.is_running():
		_panel_tween.kill()
	_panel_tween = null

func _finish_hide_panel() -> void:
	panel_root.position = _panel_base_position
	panel_root.modulate.a = 1.0
	hide()

func _switch_category(category: int, rebuild: bool = true) -> void:
	_current_category = category
	if builtin_tab_button != null:
		builtin_tab_button.button_pressed = category == CATEGORY_BUILTIN
	if favorite_tab_button != null:
		favorite_tab_button.button_pressed = category == CATEGORY_FAVORITE
	if local_tab_button != null:
		local_tab_button.button_pressed = category == CATEGORY_LOCAL
	if add_local_button != null:
		add_local_button.visible = category == CATEGORY_LOCAL
	if rebuild:
		_refresh_track_list()
	_refresh_playlist_list()

func _refresh_track_list() -> void:
	for child in track_list_container.get_children():
		child.queue_free()
	var order_index: int = 1
	for track in _tracks:
		if not _is_track_visible(track):
			continue
		var item: Control = ITEM_SCENE.instantiate()
		track_list_container.add_child(item)
		var duration_text: String = MusicLibrary.format_duration(MusicLibrary.get_track_duration(track))
		item.call("setup", track, order_index, duration_text, str(track.get("id", "")) == _selected_track_id, str(track.get("id", "")) == _playing_track_id)
		item.selected.connect(_on_track_selected)
		item.preview_requested.connect(_on_track_preview_requested)
		item.appreciate_requested.connect(_on_track_appreciate_requested)
		item.favorite_requested.connect(_on_track_favorite_requested)
		item.playlist_requested.connect(_on_track_playlist_requested)
		order_index += 1
	if order_index == 1:
		var empty_label := Label.new()
		empty_label.text = "当前分类下还没有音乐"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.62, 0.65, 0.72, 1))
		track_list_container.add_child(empty_label)

func _refresh_playlist_list() -> void:
	for child in playlist_list_container.get_children():
		child.queue_free()
	var playlist_tracks: Array = MusicLibrary.load_playlist_tracks()
	if playlist_count_label != null:
		playlist_count_label.text = str(playlist_tracks.size())
	for track in playlist_tracks:
		var row_panel: PanelContainer = PanelContainer.new()
		row_panel.custom_minimum_size = Vector2(0.0, 34.0)
		row_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color(0.965, 0.986, 0.989, 0.86)
		row_style.border_width_left = 1
		row_style.border_width_top = 1
		row_style.border_width_right = 1
		row_style.border_width_bottom = 1
		row_style.border_color = Color(0.82, 0.91, 0.92, 0.92)
		row_style.corner_radius_top_left = 10
		row_style.corner_radius_top_right = 10
		row_style.corner_radius_bottom_right = 10
		row_style.corner_radius_bottom_left = 10
		row_panel.add_theme_stylebox_override("panel", row_style)
		var row_margin: MarginContainer = MarginContainer.new()
		row_margin.add_theme_constant_override("margin_left", 8)
		row_margin.add_theme_constant_override("margin_top", 5)
		row_margin.add_theme_constant_override("margin_right", 8)
		row_margin.add_theme_constant_override("margin_bottom", 5)
		row_panel.add_child(row_margin)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row_margin.add_child(row)
		var title: Label = Label.new()
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.text = MusicLibrary.get_track_title(track)
		title.clip_text = true
		title.add_theme_color_override("font_color", Color(0.18, 0.31, 0.33, 1))
		title.add_theme_font_size_override("font_size", 11)
		var duration: Label = Label.new()
		duration.text = MusicLibrary.format_duration(MusicLibrary.get_track_duration(track))
		duration.add_theme_color_override("font_color", Color(0.41, 0.56, 0.58, 1))
		duration.add_theme_font_size_override("font_size", 10)
		row.add_child(title)
		row.add_child(duration)
		if not MusicLibrary.is_playlist_locked(track):
			var remove_button: Button = Button.new()
			remove_button.custom_minimum_size = Vector2(40, 22)
			remove_button.text = "移除"
			var remove_style := StyleBoxFlat.new()
			remove_style.bg_color = Color(0.94, 0.975, 0.98, 0.82)
			remove_style.border_width_left = 1
			remove_style.border_width_top = 1
			remove_style.border_width_right = 1
			remove_style.border_width_bottom = 1
			remove_style.border_color = Color(0.75, 0.87, 0.89, 0.92)
			remove_style.corner_radius_top_left = 8
			remove_style.corner_radius_top_right = 8
			remove_style.corner_radius_bottom_right = 8
			remove_style.corner_radius_bottom_left = 8
			remove_button.add_theme_stylebox_override("normal", remove_style)
			remove_button.add_theme_stylebox_override("hover", remove_style)
			remove_button.add_theme_stylebox_override("pressed", remove_style)
			remove_button.add_theme_color_override("font_color", Color(0.23, 0.41, 0.43, 1))
			remove_button.add_theme_font_size_override("font_size", 10)
			remove_button.pressed.connect(func() -> void:
				_on_playlist_remove_requested(str(track.get("id", "")))
			)
			row.add_child(remove_button)
		playlist_list_container.add_child(row_panel)
	if playlist_tracks.is_empty():
		var empty_label := Label.new()
		empty_label.text = "还没有加入桌面播单"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.41, 0.56, 0.58, 1))
		playlist_list_container.add_child(empty_label)

func _update_bottom_bar() -> void:
	var selected_track: Dictionary = _get_selected_track()
	var has_track: bool = not selected_track.is_empty()
	if shuffle_button != null:
		shuffle_button.button_pressed = _shuffle_enabled
	if play_pause_button != null:
		play_pause_button.disabled = not has_track
		play_pause_button.icon = PAUSE_ICON if _preview_active and _playing_track_id == _selected_track_id else PLAY_ICON
	if prev_button != null:
		prev_button.disabled = _get_visible_track_ids().is_empty()
	if next_button != null:
		next_button.disabled = _get_visible_track_ids().is_empty()
	if total_time_label != null:
		total_time_label.text = MusicLibrary.format_duration(MusicLibrary.get_track_duration(selected_track)) if has_track else "0:00"
	if not _preview_active or _playing_track_id != _selected_track_id:
		if current_time_label != null:
			current_time_label.text = "0:00"
		if progress_bar != null:
			progress_bar.value = 0.0

func _on_track_selected(track_id: String) -> void:
	_selected_track_id = track_id
	_refresh_track_list()
	_update_bottom_bar()

func _on_track_preview_requested(track_id: String) -> void:
	if _playing_track_id == track_id and _preview_active:
		stop_preview()
		_update_bottom_bar()
		return
	_selected_track_id = track_id
	_play_track(track_id)

func _on_track_appreciate_requested(track_id: String) -> void:
	var track: Dictionary = _get_track_by_id(track_id)
	if ToastManager and not track.is_empty():
		ToastManager.show_system_toast("赏析《%s》: 先闭眼听 15 秒，再注意它的情绪层次和空间感。" % MusicLibrary.get_track_title(track))

func _on_track_favorite_requested(track_id: String) -> void:
	var track: Dictionary = _get_track_by_id(track_id)
	if track.is_empty():
		return
	var next_state: bool = not bool(track.get("is_favorite", false))
	MusicLibrary.update_track_fields(track_id, {"is_favorite": next_state})
	reload_tracks()
	if ToastManager:
		var title: String = MusicLibrary.get_track_title(track)
		ToastManager.show_system_toast("已%s《%s》" % ["收藏" if next_state else "取消收藏", title], Color(0.57, 0.82, 0.76, 1))

func _on_track_playlist_requested(track_id: String) -> void:
	for i in range(_tracks.size()):
		if str(_tracks[i].get("id", "")) == track_id:
			_tracks[i]["in_playlist"] = true
			break
	MusicLibrary.save_tracks(_tracks)
	_tracks = MusicLibrary.load_tracks()
	_refresh_track_list()
	_refresh_playlist_list()
	playlist_updated.emit()

func _on_playlist_remove_requested(track_id: String) -> void:
	if MusicLibrary.is_playlist_locked(track_id):
		return
	for i in range(_tracks.size()):
		if str(_tracks[i].get("id", "")) != track_id:
			continue
		_tracks[i]["in_playlist"] = false
		break
	MusicLibrary.save_tracks(_tracks)
	_tracks = MusicLibrary.load_tracks()
	_refresh_track_list()
	_refresh_playlist_list()
	playlist_updated.emit()

func _on_add_local_pressed() -> void:
	_ensure_import_popup()
	if is_instance_valid(_import_popup_instance):
		_import_popup_instance.show_popup(add_local_button)

func _ensure_import_popup() -> void:
	if is_instance_valid(_import_popup_instance):
		return
	_import_popup_instance = IMPORT_POPUP_SCENE.instantiate()
	add_child(_import_popup_instance)
	_import_popup_instance.import_confirmed.connect(_on_import_confirmed)

func _on_import_confirmed(file_paths: PackedStringArray) -> void:
	var imported_tracks: Array = MusicLibrary.import_local_files(file_paths, _tracks)
	if imported_tracks.is_empty():
		if ToastManager:
			ToastManager.show_system_toast("没有可导入的音乐文件", Color.RED)
		return
	for imported_track in imported_tracks:
		_tracks.append(imported_track)
	MusicLibrary.save_tracks(_tracks)
	_switch_category(CATEGORY_LOCAL, true)
	if ToastManager:
		ToastManager.show_system_toast("已导入 %d 首本地音乐" % imported_tracks.size(), Color(0.57, 0.82, 0.76, 1))
	playlist_updated.emit()

func _on_play_pause_pressed() -> void:
	if _selected_track_id == "":
		return
	if _playing_track_id == _selected_track_id and _preview_active and _preview_player.playing:
		stop_preview()
	else:
		_play_track(_selected_track_id)
	_update_bottom_bar()

func _on_prev_pressed() -> void:
	var visible_track_ids: Array[String] = _get_visible_track_ids()
	if visible_track_ids.is_empty():
		return
	if _shuffle_enabled and visible_track_ids.size() > 1:
		_selected_track_id = visible_track_ids[randi() % visible_track_ids.size()]
		_play_track(_selected_track_id)
		return
	if _selected_track_id == "":
		_selected_track_id = visible_track_ids[0]
	else:
		var current_index: int = visible_track_ids.find(_selected_track_id)
		current_index = (current_index - 1 + visible_track_ids.size()) % visible_track_ids.size()
		_selected_track_id = visible_track_ids[current_index]
	_play_track(_selected_track_id)

func _on_next_pressed() -> void:
	var visible_track_ids: Array[String] = _get_visible_track_ids()
	if visible_track_ids.is_empty():
		return
	if _shuffle_enabled and visible_track_ids.size() > 1:
		_selected_track_id = visible_track_ids[randi() % visible_track_ids.size()]
		_play_track(_selected_track_id)
		return
	if _selected_track_id == "":
		_selected_track_id = visible_track_ids[0]
	else:
		var current_index: int = visible_track_ids.find(_selected_track_id)
		current_index = (current_index + 1) % visible_track_ids.size()
		_selected_track_id = visible_track_ids[current_index]
	_play_track(_selected_track_id)

func _play_track(track_id: String) -> void:
	var track: Dictionary = _get_track_by_id(track_id)
	if track.is_empty():
		return
	var stream: AudioStream = MusicLibrary.load_audio_stream(str(track.get("path", "")))
	if stream == null:
		if ToastManager:
			ToastManager.show_system_toast("无法加载该音乐文件", Color.RED)
		return
	var should_emit_start: bool = not _preview_active
	_preview_player.stream = stream
	_preview_player.play()
	_preview_active = true
	_playing_track_id = track_id
	_selected_track_id = track_id
	if should_emit_start:
		preview_started.emit()
	_refresh_track_list()
	_update_bottom_bar()

func _on_preview_finished() -> void:
	stop_preview()
	_update_bottom_bar()

func _on_close_pressed() -> void:
	hide_panel()
	close_requested.emit()

func _on_shuffle_pressed() -> void:
	_shuffle_enabled = not _shuffle_enabled
	_update_bottom_bar()

func _get_track_by_id(track_id: String) -> Dictionary:
	for track in _tracks:
		if str(track.get("id", "")) == track_id:
			return track
	return {}

func _get_selected_track() -> Dictionary:
	return _get_track_by_id(_selected_track_id)

func _find_track_index(track_id: String) -> int:
	for i in range(_tracks.size()):
		if str(_tracks[i].get("id", "")) == track_id:
			return i
	return -1

func _get_visible_track_ids() -> Array[String]:
	var ids: Array[String] = []
	for track in _tracks:
		if not _is_track_visible(track):
			continue
		ids.append(str(track.get("id", "")))
	return ids

func _is_track_visible(track: Dictionary) -> bool:
	var is_local: bool = bool(track.get("is_local", false))
	var is_favorite: bool = bool(track.get("is_favorite", false))
	match _current_category:
		CATEGORY_BUILTIN:
			return not is_local
		CATEGORY_FAVORITE:
			return is_favorite
		CATEGORY_LOCAL:
			return is_local
	return true
