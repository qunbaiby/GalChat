extends PanelContainer

signal back_requested

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

const PLAYLIST_ITEM_SCENE = preload("res://scenes/ui/desktop_pet/desktop_pet_music_list_item.tscn")
const IMPORT_POPUP_SCENE = preload("res://scenes/ui/main/music/music_import_popup.tscn")
const IMPORTED_MUSIC_DIR := "user://imported_music"

@onready var back_button: Button = $Margin/VBox/TopBar/BackButton
@onready var title_label: Label = $Margin/VBox/NowPlayingCard/Margin/VBox/TrackRow/TextVBox/TitleLabel
@onready var artist_label: Label = $Margin/VBox/NowPlayingCard/Margin/VBox/TrackRow/TextVBox/ArtistLabel
@onready var state_label: Label = $Margin/VBox/NowPlayingCard/Margin/VBox/TrackRow/StateLabel
@onready var progress_bar: ProgressBar = $Margin/VBox/NowPlayingCard/Margin/VBox/ProgressBar
@onready var volume_btn: Button = $Margin/VBox/NowPlayingCard/Margin/VBox/ControlsHBox/VolumeBtn
@onready var shuffle_btn: Button = $Margin/VBox/NowPlayingCard/Margin/VBox/ControlsHBox/ShuffleBtn
@onready var prev_btn: Button = $Margin/VBox/NowPlayingCard/Margin/VBox/ControlsHBox/PrevBtn
@onready var play_pause_btn: Button = $Margin/VBox/NowPlayingCard/Margin/VBox/ControlsHBox/PlayPauseBtn
@onready var next_btn: Button = $Margin/VBox/NowPlayingCard/Margin/VBox/ControlsHBox/NextBtn
@onready var repeat_btn: Button = $Margin/VBox/NowPlayingCard/Margin/VBox/ControlsHBox/RepeatBtn
@onready var cover_btn: Button = $Margin/VBox/NowPlayingCard/Margin/VBox/TrackRow/CoverBtn
@onready var category_option: OptionButton = $Margin/VBox/PlaylistCard/Margin/VBox/HeaderRow/CategoryOption
@onready var import_btn: Button = $Margin/VBox/PlaylistCard/Margin/VBox/HeaderRow/ImportBtn
@onready var list_container: VBoxContainer = $Margin/VBox/PlaylistCard/Margin/VBox/Scroll/ListContainer
@onready var volume_popup: PanelContainer = $VolumePopup
@onready var volume_slider: VSlider = $VolumePopup/Margin/VolumeSlider

var audio_player: AudioStreamPlayer = null
var current_bgm_index: int = 0
var bgm_list: Array = []

enum PlayMode { LOOP_LIST = 0, SHUFFLE = 1, REPEAT_ONE = 2 }
var current_mode: PlayMode = PlayMode.LOOP_LIST

var current_category: int = 0
var _is_hovering_volume: bool = false
var _volume_hide_timer: Timer = null
var import_popup_instance = null

func _ready() -> void:
	back_button.pressed.connect(func(): back_requested.emit())
	cover_btn.pressed.connect(_on_play_pause_pressed)
	play_pause_btn.pressed.connect(_on_play_pause_pressed)
	next_btn.pressed.connect(_on_next_pressed)
	prev_btn.pressed.connect(_on_prev_pressed)
	shuffle_btn.pressed.connect(_on_shuffle_pressed)
	repeat_btn.pressed.connect(_on_repeat_pressed)
	category_option.item_selected.connect(_on_category_selected)
	import_btn.pressed.connect(_on_import_pressed)

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

	cover_btn.icon = ICON_COVER
	prev_btn.icon = ICON_PREV
	next_btn.icon = ICON_NEXT
	volume_popup.top_level = true
	volume_slider.value = GameDataManager.config.bgm_volume

	_setup_category_options()
	_update_mode_ui()
	_load_bgm_list()
	call_deferred("_ensure_import_popup")
	call_deferred("_update_volume_popup_position")

func _process(_delta: float) -> void:
	if is_instance_valid(audio_player) and audio_player.stream:
		var current_time := audio_player.get_playback_position()
		var total_time := audio_player.stream.get_length()
		if total_time > 0.0:
			progress_bar.value = current_time / total_time
		if not audio_player.playing and not audio_player.stream_paused and current_time > 0.0:
			_on_next_pressed(true)

func set_audio_player(player: AudioStreamPlayer) -> void:
	audio_player = player
	_sync_index_to_current_stream()
	_update_ui()

func _setup_category_options() -> void:
	category_option.clear()
	category_option.add_item("全部", 0)
	category_option.add_item("本地导入", 1)
	category_option.add_item("收藏", 2)
	category_option.select(clampi(current_category, 0, 2))

func _load_bgm_list() -> void:
	bgm_list.clear()
	var json_path := "res://assets/data/audio/audio_data.json"
	if FileAccess.file_exists(json_path):
		var file := FileAccess.open(json_path, FileAccess.READ)
		if file:
			var content := file.get_as_text()
			file.close()
			var json = JSON.parse_string(content)
			if json is Dictionary and json.has("bgm"):
				for bgm_item in json["bgm"]:
					if bgm_item.has("path"):
						bgm_list.append({
							"id": bgm_item.get("id", ""),
							"path": bgm_item["path"],
							"is_favorite": bgm_item.get("is_favorite", false),
							"is_local": bgm_item.get("is_local", false)
						})

	if bgm_list.is_empty():
		var path := "res://assets/audio/bgm/"
		if DirAccess.dir_exists_absolute(path):
			var dir := DirAccess.open(path)
			if dir:
				dir.list_dir_begin()
				var file_name := dir.get_next()
				while file_name != "":
					if not dir.current_is_dir() and (file_name.ends_with(".mp3") or file_name.ends_with(".ogg")):
						bgm_list.append({
							"id": file_name.get_basename(),
							"path": path + file_name,
							"is_favorite": false,
							"is_local": false
						})
					file_name = dir.get_next()

	_sync_index_to_current_stream()
	_build_playlist_ui()
	_update_ui()

func _build_playlist_ui() -> void:
	for child in list_container.get_children():
		child.queue_free()

	for i in range(bgm_list.size()):
		var item_data = bgm_list[i]
		if current_category == 1 and not item_data["is_local"]:
			continue
		if current_category == 2 and not item_data["is_favorite"]:
			continue

		var path := str(item_data["path"])
		var filename := path.get_file().get_basename()
		var artist := "Local Music" if item_data["is_local"] else "Game Music"
		var item = PLAYLIST_ITEM_SCENE.instantiate()
		list_container.add_child(item)
		item.setup(
			i,
			filename,
			artist,
			i == current_bgm_index and is_instance_valid(audio_player) and audio_player.playing and not audio_player.stream_paused,
			item_data["is_favorite"]
		)
		item.item_clicked.connect(_on_playlist_item_clicked)
		item.star_toggled.connect(_on_star_toggled)

func _sync_index_to_current_stream() -> void:
	if not is_instance_valid(audio_player) or audio_player.stream == null:
		return
	var current_path := str(audio_player.stream.resource_path)
	if current_path == "":
		return
	for i in range(bgm_list.size()):
		if str(bgm_list[i].get("path", "")) == current_path:
			current_bgm_index = i
			return

func _ensure_import_popup() -> void:
	if is_instance_valid(import_popup_instance):
		return
	import_popup_instance = IMPORT_POPUP_SCENE.instantiate()
	var host := get_tree().current_scene if get_tree().current_scene else get_tree().root
	host.add_child(import_popup_instance)
	import_popup_instance.import_confirmed.connect(_on_import_confirmed)

func _update_volume_popup_position() -> void:
	var popup_size := volume_popup.get_combined_minimum_size()
	if popup_size == Vector2.ZERO:
		popup_size = volume_popup.size
	if popup_size == Vector2.ZERO:
		popup_size = Vector2(30, 104)
	popup_size.x = maxf(popup_size.x, 30.0)
	popup_size.y = maxf(popup_size.y, 104.0)
	volume_popup.size = popup_size

	var btn_rect := volume_btn.get_global_rect()
	var x := btn_rect.position.x + (btn_rect.size.x - popup_size.x) * 0.5
	var y := btn_rect.position.y - popup_size.y - 6.0
	volume_popup.global_position = Vector2(round(x), round(y))
	_update_volume_icon(volume_slider.value)

func _on_category_selected(index: int) -> void:
	current_category = index
	_build_playlist_ui()

func _on_star_toggled(index: int, is_starred: bool) -> void:
	if index >= 0 and index < bgm_list.size():
		bgm_list[index]["is_favorite"] = is_starred
		_save_audio_data()

func _on_import_pressed() -> void:
	_ensure_import_popup()
	if is_instance_valid(import_popup_instance):
		import_popup_instance.show_popup(self)

func _on_import_confirmed(file_paths: PackedStringArray) -> void:
	var imported_count := 0
	for file_path in file_paths:
		if _import_single_music_file(file_path):
			imported_count += 1

	if imported_count <= 0:
		if ToastManager:
			ToastManager.show_system_toast("没有可导入的音乐文件", Color.RED)
		return

	_save_audio_data()
	if current_category != 0 and current_category != 1:
		current_category = 1
		category_option.select(1)
	_build_playlist_ui()
	if ToastManager:
		ToastManager.show_system_toast("已导入 %d 首本地音乐" % imported_count, Color(0.57, 0.82, 0.76, 1))

func _import_single_music_file(source_path: String) -> bool:
	if source_path == "" or not FileAccess.file_exists(source_path):
		return false

	var extension := source_path.get_extension().to_lower()
	if extension != "mp3" and extension != "ogg":
		return false

	var target_path := _build_unique_import_path(source_path)
	if target_path == "":
		return false

	var source_file := FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		return false
	var buffer := source_file.get_buffer(source_file.get_length())
	source_file.close()

	var target_file := FileAccess.open(target_path, FileAccess.WRITE)
	if target_file == null:
		return false
	target_file.store_buffer(buffer)
	target_file.close()

	for existing_item in bgm_list:
		if str(existing_item.get("path", "")) == target_path:
			return false

	bgm_list.append({
		"id": "local_" + str(Time.get_unix_time_from_system()) + "_" + str(randi()),
		"path": target_path,
		"is_favorite": false,
		"is_local": true
	})
	return true

func _build_unique_import_path(source_path: String) -> String:
	DirAccess.make_dir_recursive_absolute(IMPORTED_MUSIC_DIR)
	var extension := source_path.get_extension().to_lower()
	var base_name := source_path.get_file().get_basename().strip_edges()
	if base_name == "":
		base_name = "music"

	var candidate_path := "%s/%s.%s" % [IMPORTED_MUSIC_DIR, base_name, extension]
	var suffix := 1
	while FileAccess.file_exists(candidate_path):
		candidate_path = "%s/%s_%d.%s" % [IMPORTED_MUSIC_DIR, base_name, suffix, extension]
		suffix += 1
	return candidate_path

func _save_audio_data() -> void:
	var json_path := "res://assets/data/audio/audio_data.json"
	var json_data := {"bgm": [], "bgs": [], "se": []}
	if FileAccess.file_exists(json_path):
		var file := FileAccess.open(json_path, FileAccess.READ)
		if file:
			var content := file.get_as_text()
			file.close()
			var old_json = JSON.parse_string(content)
			if old_json is Dictionary:
				if old_json.has("bgs"):
					json_data["bgs"] = old_json["bgs"]
				if old_json.has("se"):
					json_data["se"] = old_json["se"]

	for item in bgm_list:
		var bgm_node := {"id": item["id"], "path": item["path"]}
		if item["is_favorite"]:
			bgm_node["is_favorite"] = true
		if item["is_local"]:
			bgm_node["is_local"] = true
		json_data["bgm"].append(bgm_node)

	var write_file := FileAccess.open(json_path, FileAccess.WRITE)
	if write_file:
		write_file.store_string(JSON.stringify(json_data, "  "))
		write_file.close()

func _on_playlist_item_clicked(index: int) -> void:
	if current_bgm_index == index and is_instance_valid(audio_player) and audio_player.stream:
		_on_play_pause_pressed()
		return
	current_bgm_index = index
	_play_current_index()

func _on_play_pause_pressed() -> void:
	if not is_instance_valid(audio_player):
		return
	if audio_player.playing:
		audio_player.stream_paused = true
		play_pause_btn.icon = ICON_PLAY
		state_label.text = "已暂停"
		return

	audio_player.stream_paused = false
	if not audio_player.stream:
		_play_current_index()
	else:
		audio_player.play(audio_player.get_playback_position())
		_update_ui()

func _on_next_pressed(natural_end: bool = false) -> void:
	if bgm_list.is_empty() or not is_instance_valid(audio_player):
		return

	if current_mode == PlayMode.SHUFFLE:
		current_bgm_index = randi() % bgm_list.size()
	elif current_mode == PlayMode.REPEAT_ONE and natural_end:
		pass
	else:
		current_bgm_index = (current_bgm_index + 1) % bgm_list.size()
	_play_current_index()

func _on_prev_pressed() -> void:
	if bgm_list.is_empty() or not is_instance_valid(audio_player):
		return
	if current_mode == PlayMode.SHUFFLE:
		current_bgm_index = randi() % bgm_list.size()
	else:
		current_bgm_index = (current_bgm_index - 1 + bgm_list.size()) % bgm_list.size()
	_play_current_index()

func _on_shuffle_pressed() -> void:
	current_mode = PlayMode.LOOP_LIST if current_mode == PlayMode.SHUFFLE else PlayMode.SHUFFLE
	_update_mode_ui()

func _on_repeat_pressed() -> void:
	current_mode = PlayMode.LOOP_LIST if current_mode == PlayMode.REPEAT_ONE else PlayMode.REPEAT_ONE
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
	volume_btn.icon = ICON_VOLUME_LINE if value < 0.5 else ICON_VOLUME_FILL

func _play_current_index() -> void:
	if bgm_list.is_empty() or not is_instance_valid(audio_player):
		return

	var stream_path := str(bgm_list[current_bgm_index]["path"])
	var stream = null
	if stream_path.begins_with("res://"):
		stream = load(stream_path)
	else:
		if stream_path.ends_with(".mp3"):
			var file := FileAccess.open(stream_path, FileAccess.READ)
			if file:
				var sound := AudioStreamMP3.new()
				sound.data = file.get_buffer(file.get_length())
				stream = sound
		elif stream_path.ends_with(".ogg"):
			stream = AudioStreamOggVorbis.load_from_file(stream_path)

	if stream:
		audio_player.stream = stream
		audio_player.play()
		audio_player.stream_paused = false
		_update_ui()

func _update_ui() -> void:
	_sync_index_to_current_stream()
	if not is_instance_valid(audio_player) or not audio_player.stream:
		title_label.text = "还没有播放音乐"
		artist_label.text = "点击下面的列表开始播放"
		state_label.text = "待机中"
		progress_bar.value = 0.0
		play_pause_btn.icon = ICON_PLAY
		_build_playlist_ui()
		return

	var path := ""
	if audio_player.stream.resource_path != "":
		path = audio_player.stream.resource_path
	elif not bgm_list.is_empty() and current_bgm_index < bgm_list.size():
		path = str(bgm_list[current_bgm_index]["path"])

	title_label.text = path.get_file().get_basename()
	artist_label.text = "Local Music" if _is_current_track_local() else "Game Music"
	if audio_player.playing and not audio_player.stream_paused:
		state_label.text = "播放中"
		play_pause_btn.icon = ICON_PAUSE
	else:
		state_label.text = "已暂停"
		play_pause_btn.icon = ICON_PLAY
	_build_playlist_ui()

func _is_current_track_local() -> bool:
	if current_bgm_index >= 0 and current_bgm_index < bgm_list.size():
		return bool(bgm_list[current_bgm_index].get("is_local", false))
	return false
