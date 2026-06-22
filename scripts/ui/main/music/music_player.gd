extends PanelContainer

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

const PLAYLIST_ITEM_SCENE = preload("res://scenes/ui/main/music/music_playlist_item.tscn")
const PLAYLIST_POPUP_SCENE = preload("res://scenes/ui/main/music/music_playlist_popup.tscn")
const IMPORT_POPUP_SCENE = preload("res://scenes/ui/main/music/music_import_popup.tscn")
const IMPORTED_MUSIC_DIR := "user://imported_music"

var audio_player: AudioStreamPlayer = null
var current_bgm_index: int = 0
var bgm_list: Array = []

enum PlayMode { LOOP_LIST = 0, SHUFFLE = 1, REPEAT_ONE = 2 }
var current_mode: PlayMode = PlayMode.REPEAT_ONE

var _is_hovering_volume: bool = false
var _volume_hide_timer: Timer = null
var playlist_popup_instance = null
var import_popup_instance = null

var current_category: int = 0 # 0: 全部, 1: 本地导入, 2: 收藏

func _ready() -> void:
    play_pause_btn.pressed.connect(_on_play_pause_pressed)
    next_btn.pressed.connect(_on_next_pressed)
    prev_btn.pressed.connect(_on_prev_pressed)
    shuffle_btn.pressed.connect(_on_shuffle_pressed)
    repeat_btn.pressed.connect(_on_repeat_pressed)
    cover_btn.pressed.connect(_on_cover_pressed)

    call_deferred("_ensure_playlist_popup")
    call_deferred("_ensure_import_popup")
    
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
    _load_bgm_list()

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

func _load_bgm_list() -> void:
    bgm_list.clear()
    
    # 从 audio_data.json 读取数据
    var json_path = "res://assets/data/audio/audio_data.json"
    if FileAccess.file_exists(json_path):
        var file = FileAccess.open(json_path, FileAccess.READ)
        if file:
            var content = file.get_as_text()
            file.close()
            var json = JSON.parse_string(content)
            if json is Dictionary and json.has("bgm"):
                for bgm_item in json["bgm"]:
                    if bgm_item.has("path"):
                        var item_data = {
                            "id": bgm_item.get("id", ""),
                            "path": bgm_item["path"],
                            "is_favorite": bgm_item.get("is_favorite", false),
                            "is_local": bgm_item.get("is_local", false)
                        }
                        bgm_list.append(item_data)
    
    # 如果 json 中没有，则尝试扫描本地目录作为回退
    if bgm_list.is_empty():
        var path = "res://assets/audio/bgm/"
        if DirAccess.dir_exists_absolute(path):
            var dir = DirAccess.open(path)
            if dir:
                dir.list_dir_begin()
                var file_name = dir.get_next()
                while file_name != "":
                    if not dir.current_is_dir() and (file_name.ends_with(".mp3") or file_name.ends_with(".ogg")):
                        var item_data = {
                            "id": file_name.get_basename(),
                            "path": path + file_name,
                            "is_favorite": false,
                            "is_local": false
                        }
                        bgm_list.append(item_data)
                    file_name = dir.get_next()
    
    _build_playlist_ui()

func _ensure_playlist_popup() -> void:
    if is_instance_valid(playlist_popup_instance):
        return

    playlist_popup_instance = PLAYLIST_POPUP_SCENE.instantiate()
    var host := get_tree().current_scene if get_tree().current_scene else get_tree().root
    host.add_child(playlist_popup_instance)

    playlist_popup_instance.close_requested.connect(_on_playlist_close_pressed)
    playlist_popup_instance.get_category_option().item_selected.connect(_on_category_selected)
    playlist_popup_instance.get_import_btn().pressed.connect(_on_import_pressed)
    playlist_popup_instance.setup_category_options(current_category)
    _build_playlist_ui()

func _ensure_import_popup() -> void:
    if is_instance_valid(import_popup_instance):
        return
    
    import_popup_instance = IMPORT_POPUP_SCENE.instantiate()
    var host := get_tree().current_scene if get_tree().current_scene else get_tree().root
    host.add_child(import_popup_instance)
    import_popup_instance.import_confirmed.connect(_on_import_confirmed)

func _build_playlist_ui() -> void:
    if not is_instance_valid(playlist_popup_instance):
        return

    var playlist_container: VBoxContainer = playlist_popup_instance.get_playlist_container()
    for child in playlist_container.get_children():
        child.queue_free()

    for i in range(bgm_list.size()):
        var item_data = bgm_list[i]

        # 筛选逻辑
        if current_category == 1 and not item_data["is_local"]:
            continue
        if current_category == 2 and not item_data["is_favorite"]:
            continue

        var path = item_data["path"]
        var filename = path.get_file().get_basename()
        var artist = "Local Music" if item_data["is_local"] else "Game Music"

        var item = PLAYLIST_ITEM_SCENE.instantiate()
        playlist_container.add_child(item)
        item.setup(i, filename, artist, false, item_data["is_favorite"])
        item.item_clicked.connect(_on_playlist_item_clicked)
        item.star_toggled.connect(_on_star_toggled)

    _update_playlist_ui()

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
    var imported_count: int = 0
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
        if is_instance_valid(playlist_popup_instance):
            playlist_popup_instance.get_category_option().select(1)
    
    _build_playlist_ui()
    if ToastManager:
        ToastManager.show_system_toast("已导入 %d 首本地音乐" % imported_count, Color(0.57, 0.82, 0.76, 1))

func _import_single_music_file(source_path: String) -> bool:
    if source_path == "":
        return false
    if not FileAccess.file_exists(source_path):
        return false
    
    var extension: String = source_path.get_extension().to_lower()
    if extension != "mp3" and extension != "ogg":
        return false
    
    var target_path: String = _build_unique_import_path(source_path)
    if target_path == "":
        return false
    
    var source_file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
    if source_file == null:
        return false
    var buffer: PackedByteArray = source_file.get_buffer(source_file.get_length())
    source_file.close()
    
    var target_file: FileAccess = FileAccess.open(target_path, FileAccess.WRITE)
    if target_file == null:
        return false
    target_file.store_buffer(buffer)
    target_file.close()
    
    var new_id: String = "local_" + str(Time.get_unix_time_from_system()) + "_" + str(randi())
    var item_data := {
        "id": new_id,
        "path": target_path,
        "is_favorite": false,
        "is_local": true
    }
    
    for existing_item in bgm_list:
        if str(existing_item.get("path", "")) == target_path:
            return false
    
    bgm_list.append(item_data)
    return true

func _build_unique_import_path(source_path: String) -> String:
    DirAccess.make_dir_recursive_absolute(IMPORTED_MUSIC_DIR)
    
    var extension: String = source_path.get_extension().to_lower()
    var base_name: String = source_path.get_file().get_basename().strip_edges()
    if base_name == "":
        base_name = "music"
    
    var candidate_path: String = "%s/%s.%s" % [IMPORTED_MUSIC_DIR, base_name, extension]
    var suffix: int = 1
    while FileAccess.file_exists(candidate_path):
        candidate_path = "%s/%s_%d.%s" % [IMPORTED_MUSIC_DIR, base_name, suffix, extension]
        suffix += 1
    
    return candidate_path

func _save_audio_data() -> void:
    var json_path = "res://assets/data/audio/audio_data.json"
    var json_data = {"bgm": [], "bgs": [], "se": []}
    
    # 先读取原有的数据以保留 bgs 和 se
    if FileAccess.file_exists(json_path):
        var file = FileAccess.open(json_path, FileAccess.READ)
        if file:
            var content = file.get_as_text()
            file.close()
            var old_json = JSON.parse_string(content)
            if old_json is Dictionary:
                if old_json.has("bgs"): json_data["bgs"] = old_json["bgs"]
                if old_json.has("se"): json_data["se"] = old_json["se"]
    
    # 写入新的 bgm
    for item in bgm_list:
        var bgm_node = {
            "id": item["id"],
            "path": item["path"]
        }
        if item["is_favorite"]: bgm_node["is_favorite"] = true
        if item["is_local"]: bgm_node["is_local"] = true
        json_data["bgm"].append(bgm_node)
        
    var file = FileAccess.open(json_path, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(json_data, "  "))
        file.close()

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
            var item_index = item.get("_index") if item.has_method("get") else i
            var is_playing = (item_index == current_bgm_index) and audio_player and audio_player.playing and not audio_player.stream_paused
            item.set_playing(is_playing)

func _on_play_pause_pressed() -> void:
    if not is_instance_valid(audio_player): return
    
    if audio_player.playing:
        audio_player.stream_paused = true
        play_pause_btn.icon = ICON_PLAY
    else:
        audio_player.stream_paused = false
        if not audio_player.stream:
            _play_current_index()
        else:
            audio_player.play(audio_player.get_playback_position())
        play_pause_btn.icon = ICON_PAUSE

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
    if bgm_list.is_empty() or not is_instance_valid(audio_player): return
    
    var stream_path = bgm_list[current_bgm_index]["path"]
    var stream = null
    
    # 处理加载
    if stream_path.begins_with("res://"):
        stream = load(stream_path)
    else:
        # 对 user:// 和绝对路径都按外部文件处理，避免未导入资源无法直接 load。
        if stream_path.ends_with(".mp3"):
            var file = FileAccess.open(stream_path, FileAccess.READ)
            if file:
                var sound = AudioStreamMP3.new()
                sound.data = file.get_buffer(file.get_length())
                stream = sound
        elif stream_path.ends_with(".ogg"):
            stream = AudioStreamOggVorbis.load_from_file(stream_path)
    
    if stream:
        _apply_loop_mode_to_stream(stream)
        audio_player.stream = stream
        audio_player.play()
        audio_player.stream_paused = false
        _update_ui()

func _update_ui() -> void:
    if not is_instance_valid(audio_player) or not audio_player.stream:
        title_label.text = "无正在播放的音乐"
        artist_label.text = "-"
        progress_bar.value = 0
        play_pause_btn.icon = ICON_PLAY
        _update_playlist_ui()
        return
        
    var path = ""
    if audio_player.stream and audio_player.stream.resource_path != "":
        path = audio_player.stream.resource_path
    elif not bgm_list.is_empty() and current_bgm_index < bgm_list.size():
        path = bgm_list[current_bgm_index]["path"]
        
    var filename = path.get_file().get_basename()
    var artist = "Game Music"
    if not bgm_list.is_empty() and current_bgm_index < bgm_list.size():
        if bgm_list[current_bgm_index].get("is_local", false):
            artist = "Local Music"
            
    title_label.text = filename
    artist_label.text = artist
    
    if audio_player.playing and not audio_player.stream_paused:
        play_pause_btn.icon = ICON_PAUSE
    else:
        play_pause_btn.icon = ICON_PLAY
        
    _update_playlist_ui()
