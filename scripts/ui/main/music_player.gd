extends Panel

@onready var title_label: Label = $HBox/InfoVBox/TitleLabel
@onready var artist_label: Label = $HBox/InfoVBox/ArtistLabel
@onready var progress_bar: ProgressBar = $HBox/InfoVBox/ProgressBar
@onready var play_pause_btn: Button = $HBox/ControlsHBox/PlayPauseBtn
@onready var next_btn: Button = $HBox/ControlsHBox/NextBtn

var audio_player: AudioStreamPlayer = null
var current_bgm_index: int = 0
var bgm_list: Array = []

func _ready() -> void:
	play_pause_btn.pressed.connect(_on_play_pause_pressed)
	next_btn.pressed.connect(_on_next_pressed)
	
	_load_bgm_list()

func _process(_delta: float) -> void:
	if is_instance_valid(audio_player) and audio_player.stream:
		var current_time = audio_player.get_playback_position()
		var total_time = audio_player.stream.get_length()
		if total_time > 0:
			progress_bar.value = current_time / total_time
			
		if not audio_player.playing and not audio_player.stream_paused and current_time > 0:
			_on_next_pressed()

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
		play_pause_btn.text = ">"
	else:
		audio_player.stream_paused = false
		if not audio_player.stream:
			_play_current_index()
		else:
			audio_player.play(audio_player.get_playback_position())
		play_pause_btn.text = "||"

func _on_next_pressed() -> void:
	if bgm_list.is_empty() or not is_instance_valid(audio_player): return
	
	current_bgm_index = (current_bgm_index + 1) % bgm_list.size()
	_play_current_index()

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
		play_pause_btn.text = ">"
		return
		
	var path = audio_player.stream.resource_path
	var filename = path.get_file().get_basename()
	
	title_label.text = filename
	artist_label.text = "Local Music"
	
	if audio_player.playing and not audio_player.stream_paused:
		play_pause_btn.text = "||"
	else:
		play_pause_btn.text = ">"
