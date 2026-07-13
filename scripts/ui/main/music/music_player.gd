extends PanelContainer

const MusicLibraryData = preload("res://scripts/data/music_library.gd")

signal close_requested

const ICON_COVER = preload("res://assets/images/icons/ui/music/mv-ai-fill.png")
const ICON_VOLUME_LINE = preload("res://assets/images/icons/ui/music/volume-up-line.png")
const ICON_VOLUME_FILL = preload("res://assets/images/icons/ui/music/volume-up-fill.png")
const ICON_SHUFFLE_FILL = preload("res://assets/images/icons/ui/music/shuffle-fill.png")
const ICON_ORDER_PLAY = preload("res://assets/images/icons/ui/music/order-play-line.png")
const ICON_PREV = preload("res://assets/images/icons/ui/music/skip-back-fill.png")
const ICON_PLAY = preload("res://assets/images/icons/ui/music/play-fill.png")
const ICON_PAUSE = preload("res://assets/images/icons/ui/music/pause-circle-fill.png")
const ICON_NEXT = preload("res://assets/images/icons/ui/music/skip-forward-fill.png")
const ICON_REPEAT_LIST = preload("res://assets/images/icons/ui/music/repeat-2-line.png")
const ICON_REPEAT_ONE = preload("res://assets/images/icons/ui/music/repeat-one-line.png")

@onready var title_label: Label = $Margin/VBox/TopHBox/InfoVBox/TitleLabel
@onready var artist_label: Label = $Margin/VBox/TopHBox/InfoVBox/ArtistLabel
@onready var progress_bar: ProgressBar = $Margin/VBox/ProgressBar
@onready var volume_btn: Button = $Margin/VBox/TopHBox/ControlsHBox/VolumeBtn
@onready var shuffle_btn: Button = $Margin/VBox/TopHBox/ControlsHBox/ShuffleBtn
@onready var prev_btn: Button = $Margin/VBox/TopHBox/ControlsHBox/PrevBtn
@onready var play_pause_btn: Button = $Margin/VBox/TopHBox/ControlsHBox/PlayPauseBtn
@onready var next_btn: Button = $Margin/VBox/TopHBox/ControlsHBox/NextBtn
@onready var repeat_btn: Button = $Margin/VBox/TopHBox/ControlsHBox/RepeatBtn
@onready var cover_btn: Button = $Margin/VBox/TopHBox/CoverBtn

@onready var volume_popup: PanelContainer = $VolumePopup
@onready var volume_slider: VSlider = $VolumePopup/Margin/VolumeSlider
@onready var close_button: Button = $CloseButton

const PLAYLIST_ITEM_SCENE = preload("res://scenes/ui/main/music/music_playlist_item.tscn")
const PLAYLIST_POPUP_SCENE = preload("res://scenes/ui/main/music/music_playlist_popup.tscn")

var audio_player: AudioStreamPlayer = null
var current_bgm_index: int = 0
var bgm_list: Array = []

enum PlayMode { LOOP_LIST = 0, SHUFFLE = 1, REPEAT_ONE = 2 }
var current_mode: PlayMode = PlayMode.REPEAT_ONE

var _is_hovering_volume: bool = false
var _volume_hide_timer: Timer = null
var playlist_popup_instance = null
var _desktop_pet_mode: bool = false
var _desktop_control_style: StyleBoxFlat = null
var _desktop_control_hover_style: StyleBoxFlat = null

func _ready() -> void:
	play_pause_btn.pressed.connect(_on_play_pause_pressed)
	next_btn.pressed.connect(_on_next_pressed)
	prev_btn.pressed.connect(_on_prev_pressed)
	shuffle_btn.pressed.connect(_on_shuffle_pressed)
	repeat_btn.pressed.connect(_on_repeat_pressed)
	cover_btn.pressed.connect(_on_cover_pressed)
	if close_button != null:
		close_button.pressed.connect(func(): close_requested.emit())

	call_deferred("_ensure_playlist_popup")
	
	volume_btn.mouse_entered.connect(_on_volume_mouse_entered)
	volume_btn.mouse_exited.connect(_on_volume_mouse_exited)
	volume_popup.mouse_entered.connect(_on_volume_mouse_entered)
	volume_popup.mouse_exited.connect(_on_volume_mouse_exited)
	volume_slider.mouse_entered.connect(_on_volume_mouse_entered)
	volume_slider.mouse_exited.connect(_on_volume_mouse_exited)
	volume_slider.value_changed.connect(_on_volume_slider_changed)
	
	_volume_hide_timer = Timer.new()
	_volume_hide_timer.wait_time = 0.5
	_volume_hide_timer.one_shot = true
	_volume_hide_timer.timeout.connect(_on_volume_hide_timer_timeout)
	add_child(_volume_hide_timer)
	
	# 初始化音量同步
	volume_slider.value = GameDataManager.config.bgm_volume
	volume_popup.top_level = true
	
	call_deferred("_update_volume_popup_position")
	
	cover_btn.icon = ICON_COVER
	prev_btn.icon = ICON_PREV
	next_btn.icon = ICON_NEXT
	_update_mode_ui()
	reload_library()

func set_desktop_pet_mode(enabled: bool) -> void:
	_desktop_pet_mode = enabled
	if close_button != null:
		close_button.visible = enabled

func set_desktop_mode(enabled: bool) -> void:
	var controls := [volume_btn, shuffle_btn, prev_btn, play_pause_btn, next_btn, repeat_btn, cover_btn]
	if enabled and _desktop_control_style == null:
		_desktop_control_style = StyleBoxFlat.new()
		_desktop_control_style.bg_color = Color(0, 0, 0, 0)
		_desktop_control_hover_style = StyleBoxFlat.new()
		_desktop_control_hover_style.bg_color = Color(0.55, 0.9, 0.83, 0.2)
		_desktop_control_hover_style.corner_radius_top_left = 10
		_desktop_control_hover_style.corner_radius_top_right = 10
		_desktop_control_hover_style.corner_radius_bottom_right = 10
		_desktop_control_hover_style.corner_radius_bottom_left = 10
	for control in controls:
		if not is_instance_valid(control):
			continue
		if enabled:
			control.add_theme_stylebox_override("normal", _desktop_control_style)
			control.add_theme_stylebox_override("hover", _desktop_control_hover_style)
			control.add_theme_stylebox_override("pressed", _desktop_control_hover_style)
		else:
			control.remove_theme_stylebox_override("normal")
			control.remove_theme_stylebox_override("hover")
			control.remove_theme_stylebox_override("pressed")

func hide_panel() -> void:
	if is_instance_valid(playlist_popup_instance):
		playlist_popup_instance.hide()
	if volume_popup != null:
		volume_popup.hide()
	hide()

func _update_volume_popup_position() -> void:
	var popup_size := volume_popup.get_combined_minimum_size()
	if popup_size == Vector2.ZERO:
		popup_size = volume_popup.size
	if popup_size == Vector2.ZERO:
		popup_size = Vector2(34, 124)
	popup_size.x = maxf(popup_size.x, 34.0)
	popup_size.y = maxf(popup_size.y, 124.0)
	volume_popup.size = popup_size

	var btn_rect := volume_btn.get_global_rect()
	var x := btn_rect.position.x + (btn_rect.size.x - popup_size.x) * 0.5
	var y := btn_rect.position.y - popup_size.y - 6
	volume_popup.global_position = Vector2(round(x), round(y))
	_update_volume_icon(volume_slider.value)

func _process(_delta: float) -> void:
	if is_instance_valid(audio_player) and audio_player.stream:
		var current_time = audio_player.get_playback_position()
		var total_time = audio_player.stream.get_length()
		if total_time > 0:
			progress_bar.value = current_time / total_time

func set_audio_player(player: AudioStreamPlayer) -> void:
	if is_instance_valid(audio_player) and audio_player.finished.is_connected(_on_audio_player_finished):
		audio_player.finished.disconnect(_on_audio_player_finished)
	audio_player = player
	if is_instance_valid(audio_player) and not audio_player.finished.is_connected(_on_audio_player_finished):
		audio_player.finished.connect(_on_audio_player_finished)
	_apply_loop_mode_to_current_stream()
	_sync_index_to_current_stream()
	_update_ui()

func _apply_loop_mode_to_stream(stream: AudioStream) -> void:
	if stream == null:
		return
	var should_loop := current_mode == PlayMode.REPEAT_ONE
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = should_loop

func _apply_loop_mode_to_current_stream() -> void:
	if not is_instance_valid(audio_player):
		return
	_apply_loop_mode_to_stream(audio_player.stream)

func _on_audio_player_finished() -> void:
	if not is_instance_valid(audio_player) or audio_player.stream_paused:
		return
	if current_mode == PlayMode.REPEAT_ONE:
		audio_player.play()
		_update_ui()
		return
	_on_next_pressed(true)

func reload_library() -> void:
	var current_track_id: String = _get_current_track_id()
	bgm_list = MusicLibraryData.load_playlist_tracks()
	if bgm_list.is_empty():
		current_bgm_index = 0
		_clear_missing_current_track()
	else:
		var current_index: int = _find_track_index_by_id(current_track_id)
		if current_index != -1:
			current_bgm_index = current_index
		else:
			current_bgm_index = clampi(current_bgm_index, 0, bgm_list.size() - 1)
			if current_track_id != "":
				_clear_missing_current_track()
		_sync_index_to_current_stream()
	_build_playlist_ui()
	_update_ui()

func _clear_missing_current_track() -> void:
	if not is_instance_valid(audio_player):
		return
	audio_player.stop()
	audio_player.stream = null
	audio_player.remove_meta("music_track_id")

func _get_current_track_id() -> String:
	if is_instance_valid(audio_player) and audio_player.has_meta("music_track_id"):
		return str(audio_player.get_meta("music_track_id", ""))
	if current_bgm_index >= 0 and current_bgm_index < bgm_list.size():
		return str(bgm_list[current_bgm_index].get("id", ""))
	return ""

func _ensure_playlist_popup() -> void:
	if is_instance_valid(playlist_popup_instance):
		return

	playlist_popup_instance = PLAYLIST_POPUP_SCENE.instantiate()
	var host: Node = get_parent()
	if host == null:
		host = get_tree().current_scene if get_tree().current_scene else get_tree().root
	host.add_child(playlist_popup_instance)

	playlist_popup_instance.close_requested.connect(_on_playlist_close_pressed)
	playlist_popup_instance.get_category_option().hide()
	playlist_popup_instance.get_import_btn().hide()
	_build_playlist_ui()

func _build_playlist_ui() -> void:
	if not is_instance_valid(playlist_popup_instance):
		return

	var playlist_container: VBoxContainer = playlist_popup_instance.get_playlist_container()
	for child in playlist_container.get_children():
		child.queue_free()

	if bgm_list.is_empty():
		var empty_label := Label.new()
		empty_label.text = "还没有加入桌面播单"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.44, 0.49, 0.58, 1))
		playlist_container.add_child(empty_label)
		return

	for i in range(bgm_list.size()):
		var item_data: Dictionary = bgm_list[i]
		var item = PLAYLIST_ITEM_SCENE.instantiate()
		playlist_container.add_child(item)
		item.setup(
			i,
			MusicLibraryData.get_track_title(item_data),
			MusicLibraryData.get_track_subtitle(item_data),
			i == current_bgm_index and is_instance_valid(audio_player) and audio_player.playing and not audio_player.stream_paused,
			bool(item_data.get("is_favorite", false))
		)
		if item.has_method("get_star_btn"):
			var star_btn: Button = item.get_star_btn()
			if star_btn != null:
				star_btn.hide()
		item.item_clicked.connect(_on_playlist_item_clicked)

	_update_playlist_ui()

func _on_playlist_item_clicked(index: int) -> void:
	if current_bgm_index == index and audio_player and audio_player.stream:
		_on_play_pause_pressed()
	else:
		current_bgm_index = index
		_play_current_index()

func _on_cover_pressed() -> void:
	_ensure_playlist_popup()
	playlist_popup_instance.visible = not playlist_popup_instance.visible
	if playlist_popup_instance.visible:
		playlist_popup_instance.show_above_target(self)
		_update_playlist_ui()

func _on_playlist_close_pressed() -> void:
	if is_instance_valid(playlist_popup_instance):
		playlist_popup_instance.hide()

func _update_playlist_ui() -> void:
	if not is_instance_valid(playlist_popup_instance):
		return

	var playlist_container: VBoxContainer = playlist_popup_instance.get_playlist_container()
	for i in range(playlist_container.get_child_count()):
		var item = playlist_container.get_child(i)
		if item.has_method("set_playing"):
			var item_index: int = i
			if item.has_method("get"):
				item_index = int(item.get("_index"))
			var is_playing: bool = item_index == current_bgm_index and is_instance_valid(audio_player) and audio_player.playing and not audio_player.stream_paused
			item.set_playing(is_playing)

func _on_play_pause_pressed() -> void:
	if not is_instance_valid(audio_player) or bgm_list.is_empty():
		return
	
	if audio_player.playing and not audio_player.stream_paused:
		audio_player.stream_paused = true
		play_pause_btn.icon = ICON_PLAY
	elif audio_player.stream and audio_player.stream_paused:
		audio_player.stream_paused = false
		play_pause_btn.icon = ICON_PAUSE
	else:
		if not audio_player.stream:
			_play_current_index()
		else:
			audio_player.play(audio_player.get_playback_position())
			play_pause_btn.icon = ICON_PAUSE
	_update_ui()

func _on_next_pressed(natural_end: bool = false) -> void:
	if bgm_list.is_empty() or not is_instance_valid(audio_player): return
	
	if current_mode == PlayMode.SHUFFLE:
		current_bgm_index = randi() % bgm_list.size()
	elif current_mode == PlayMode.REPEAT_ONE and natural_end:
		# 自然播放结束触发下一首时，如果是单曲循环，则保持索引不变
		pass
	else:
		# 正常点击下一首，或者是列表循环的自然下一首
		current_bgm_index = (current_bgm_index + 1) % bgm_list.size()
		
	_play_current_index()

func _on_prev_pressed() -> void:
	if bgm_list.is_empty() or not is_instance_valid(audio_player): return
	
	if current_mode == PlayMode.SHUFFLE:
		current_bgm_index = randi() % bgm_list.size()
	else:
		current_bgm_index = (current_bgm_index - 1 + bgm_list.size()) % bgm_list.size()
		
	_play_current_index()

func _on_shuffle_pressed() -> void:
	if current_mode == PlayMode.SHUFFLE:
		current_mode = PlayMode.LOOP_LIST
	else:
		current_mode = PlayMode.SHUFFLE
	_apply_loop_mode_to_current_stream()
	_update_mode_ui()

func _on_repeat_pressed() -> void:
	if current_mode == PlayMode.REPEAT_ONE:
		current_mode = PlayMode.LOOP_LIST
	else:
		current_mode = PlayMode.REPEAT_ONE
	_apply_loop_mode_to_current_stream()
	_update_mode_ui()

func _update_mode_ui() -> void:
	shuffle_btn.icon = ICON_SHUFFLE_FILL if current_mode == PlayMode.SHUFFLE else ICON_ORDER_PLAY
	repeat_btn.icon = ICON_REPEAT_ONE if current_mode == PlayMode.REPEAT_ONE else ICON_REPEAT_LIST

func _on_volume_mouse_entered() -> void:
	_is_hovering_volume = true
	_volume_hide_timer.stop()
	volume_popup.move_to_front()
	volume_popup.show()
	call_deferred("_update_volume_popup_position")

func _on_volume_mouse_exited() -> void:
	_is_hovering_volume = false
	_volume_hide_timer.start()

func _on_volume_hide_timer_timeout() -> void:
	if not _is_hovering_volume:
		volume_popup.hide()

func _on_volume_slider_changed(value: float) -> void:
	GameDataManager.config.bgm_volume = value
	GameDataManager.config.apply_settings()
	_update_volume_icon(value)

func _update_volume_icon(value: float) -> void:
	if value < 0.5:
		volume_btn.icon = ICON_VOLUME_LINE
	else:
		volume_btn.icon = ICON_VOLUME_FILL

func _play_current_index() -> void:
	if bgm_list.is_empty() or not is_instance_valid(audio_player):
		return
	
	var current_track: Dictionary = bgm_list[current_bgm_index]
	var stream: AudioStream = MusicLibraryData.load_audio_stream(str(current_track.get("path", "")))

	if stream == null:
		if ToastManager:
			ToastManager.show_system_toast("无法加载已加入播单的音乐", Color.RED)
		return

	_apply_loop_mode_to_stream(stream)
	audio_player.stream = stream
	audio_player.set_meta("music_track_id", str(current_track.get("id", "")))
	audio_player.play()
	audio_player.stream_paused = false
	_update_ui()

func _update_ui() -> void:
	_sync_index_to_current_stream()
	var current_track: Dictionary = _get_current_track()
	if bgm_list.is_empty():
		title_label.text = "桌面播单为空"
		artist_label.text = "请先在共创音乐面板加入歌曲"
		progress_bar.value = 0
		play_pause_btn.icon = ICON_PLAY
		_update_playlist_ui()
		return
	if current_track.is_empty():
		title_label.text = "无正在播放的音乐"
		artist_label.text = "从桌面播单中选择一首开始播放"
		progress_bar.value = 0
		play_pause_btn.icon = ICON_PLAY
		_update_playlist_ui()
		return

	title_label.text = MusicLibraryData.get_track_title(current_track)
	artist_label.text = MusicLibraryData.get_track_subtitle(current_track)
	
	if is_instance_valid(audio_player) and audio_player.playing and not audio_player.stream_paused:
		play_pause_btn.icon = ICON_PAUSE
	else:
		play_pause_btn.icon = ICON_PLAY
		
	_update_playlist_ui()

func _get_current_track() -> Dictionary:
	var current_track_id: String = _get_current_track_id()
	var current_index: int = _find_track_index_by_id(current_track_id)
	if current_index != -1:
		return bgm_list[current_index]
	if current_bgm_index >= 0 and current_bgm_index < bgm_list.size():
		return bgm_list[current_bgm_index]
	return {}

func _sync_index_to_current_stream() -> void:
	var current_track_id: String = _get_current_track_id()
	if current_track_id != "":
		var current_index: int = _find_track_index_by_id(current_track_id)
		if current_index != -1:
			current_bgm_index = current_index
			return

	if not is_instance_valid(audio_player) or audio_player.stream == null:
		return
	var current_path: String = str(audio_player.stream.resource_path)
	if current_path == "":
		return
	for i in range(bgm_list.size()):
		if str(bgm_list[i].get("path", "")) == current_path:
			current_bgm_index = i
			audio_player.set_meta("music_track_id", str(bgm_list[i].get("id", "")))
			return

func _find_track_index_by_id(track_id: String) -> int:
	for i in range(bgm_list.size()):
		if str(bgm_list[i].get("id", "")) == track_id:
			return i
	return -1
