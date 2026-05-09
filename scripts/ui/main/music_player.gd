extends Panel

@onready var title_label: Label = $VBox/TopHBox/InfoVBox/TitleLabel
@onready var artist_label: Label = $VBox/TopHBox/InfoVBox/ArtistLabel
@onready var progress_bar: ProgressBar = $VBox/ProgressBar
@onready var volume_btn: Button = $VBox/TopHBox/ControlsHBox/VolumeBtn
@onready var shuffle_btn: Button = $VBox/TopHBox/ControlsHBox/ShuffleBtn
@onready var prev_btn: Button = $VBox/TopHBox/ControlsHBox/PrevBtn
@onready var play_pause_btn: Button = $VBox/TopHBox/ControlsHBox/PlayPauseBtn
@onready var next_btn: Button = $VBox/TopHBox/ControlsHBox/NextBtn
@onready var repeat_btn: Button = $VBox/TopHBox/ControlsHBox/RepeatBtn

@onready var volume_popup: PanelContainer = $VolumePopup
@onready var volume_slider: VSlider = $VolumePopup/Margin/VolumeSlider

var audio_player: AudioStreamPlayer = null
var current_bgm_index: int = 0
var bgm_list: Array = []

enum PlayMode { LOOP_LIST = 0, SHUFFLE = 1, REPEAT_ONE = 2 }
var current_mode: PlayMode = PlayMode.LOOP_LIST

var _is_hovering_volume: bool = false
var _volume_hide_timer: Timer = null

func _ready() -> void:
	play_pause_btn.pressed.connect(_on_play_pause_pressed)
	next_btn.pressed.connect(_on_next_pressed)
	prev_btn.pressed.connect(_on_prev_pressed)
	shuffle_btn.pressed.connect(_on_shuffle_pressed)
	repeat_btn.pressed.connect(_on_repeat_pressed)
	
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
	
	call_deferred("_update_volume_popup_position")
	
	_update_mode_ui()
	_load_bgm_list()

func _update_volume_popup_position() -> void:
	volume_popup.position.x = volume_btn.global_position.x - global_position.x - 5
	volume_popup.position.y = -110
	_update_volume_icon(volume_slider.value)

func _process(_delta: float) -> void:
	if is_instance_valid(audio_player) and audio_player.stream:
		var current_time = audio_player.get_playback_position()
		var total_time = audio_player.stream.get_length()
		if total_time > 0:
			progress_bar.value = current_time / total_time
			
		if not audio_player.playing and not audio_player.stream_paused and current_time > 0:
			_on_next_pressed(true)

func set_audio_player(player: AudioStreamPlayer) -> void:
	audio_player = player
	_update_ui()

func _load_bgm_list() -> void:
	bgm_list.clear()
	var path = "res://assets/audio/bgm/"
	if DirAccess.dir_exists_absolute(path):
		var dir = DirAccess.open(path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and (file_name.ends_with(".mp3") or file_name.ends_with(".ogg")):
					bgm_list.append(path + file_name)
				file_name = dir.get_next()
	
	if bgm_list.size() > 0:
		bgm_list.sort()

func _on_play_pause_pressed() -> void:
	if not is_instance_valid(audio_player): return
	
	if audio_player.playing:
		audio_player.stream_paused = true
		play_pause_btn.text = "▶"
	else:
		audio_player.stream_paused = false
		if not audio_player.stream:
			_play_current_index()
		else:
			audio_player.play(audio_player.get_playback_position())
		play_pause_btn.text = "⏸"

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
	_update_mode_ui()

func _on_repeat_pressed() -> void:
	if current_mode == PlayMode.REPEAT_ONE:
		current_mode = PlayMode.LOOP_LIST
	else:
		current_mode = PlayMode.REPEAT_ONE
	_update_mode_ui()

func _update_mode_ui() -> void:
	shuffle_btn.add_theme_color_override("font_color", Color(0.5, 0.9, 1, 1) if current_mode == PlayMode.SHUFFLE else Color(0.7, 0.7, 0.7, 1))
	repeat_btn.add_theme_color_override("font_color", Color(0.5, 0.9, 1, 1) if current_mode == PlayMode.REPEAT_ONE else Color(0.7, 0.7, 0.7, 1))

func _on_volume_mouse_entered() -> void:
	_is_hovering_volume = true
	_volume_hide_timer.stop()
	# 确保音量条显示在最上层
	volume_popup.move_to_front()
	volume_popup.show()

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
	if value <= 0:
		volume_btn.text = "🔇"
	elif value < 0.5:
		volume_btn.text = "🔉"
	else:
		volume_btn.text = "🔊"

func _play_current_index() -> void:
	if bgm_list.is_empty() or not is_instance_valid(audio_player): return
	
	var stream_path = bgm_list[current_bgm_index]
	var stream = load(stream_path)
	if stream:
		audio_player.stream = stream
		audio_player.play()
		audio_player.stream_paused = false
		_update_ui()

func _update_ui() -> void:
	if not is_instance_valid(audio_player) or not audio_player.stream:
		title_label.text = "无正在播放的音乐"
		artist_label.text = "-"
		progress_bar.value = 0
		play_pause_btn.text = "▶"
		return
		
	var path = audio_player.stream.resource_path
	var filename = path.get_file().get_basename()
	
	title_label.text = filename
	artist_label.text = "Local Music"
	
	if audio_player.playing and not audio_player.stream_paused:
		play_pause_btn.text = "⏸"
	else:
		play_pause_btn.text = "▶"
