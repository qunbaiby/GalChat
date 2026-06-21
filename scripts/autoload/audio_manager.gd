extends Node

var audio_data: Dictionary = {"bgm": {}, "bgs": {}, "se": {}}

var bgm_player: AudioStreamPlayer
var bgs_player: AudioStreamPlayer
var se_players: Array[AudioStreamPlayer] = []
var max_se_players: int = 5
var _bgm_tween: Tween = null
var _bgs_tween: Tween = null

func _ready() -> void:
	_load_audio_data()
	
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "BGM"
	add_child(bgm_player)
	
	bgs_player = AudioStreamPlayer.new()
	bgs_player.bus = "BGM" # 或者单独的BGS Bus
	add_child(bgs_player)
	
	for i in range(max_se_players):
		var p = AudioStreamPlayer.new()
		p.bus = "SE"
		add_child(p)
		se_players.append(p)

func _load_audio_data() -> void:
	var path = "res://assets/data/audio/audio_data.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.data
			if typeof(data) == TYPE_DICTIONARY:
				for category in ["bgm", "bgs", "se"]:
					if data.has(category) and typeof(data[category]) == TYPE_ARRAY:
						for item in data[category]:
							if item.has("id") and item.has("path"):
								audio_data[category][item["id"]] = item["path"]

func _kill_tween_if_valid(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()

func _set_stream_loop(stream: AudioStream, should_loop: bool) -> void:
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = should_loop

func play_bgm(audio_id: String, fade_time: float = 1.0) -> void:
	if not audio_data["bgm"].has(audio_id):
		push_warning("BGM ID not found: " + audio_id)
		return
		
	var path = audio_data["bgm"][audio_id]
	var stream = load(path)
	if stream:
		_kill_tween_if_valid(_bgm_tween)
		_set_stream_loop(stream, true)
			
		if bgm_player.playing:
			if fade_time > 0:
				_bgm_tween = create_tween()
				_bgm_tween.tween_property(bgm_player, "volume_db", -80.0, fade_time / 2.0)
				_bgm_tween.tween_callback(func():
					bgm_player.stream = stream
					bgm_player.volume_db = -80.0
					bgm_player.play()
				)
				_bgm_tween.tween_property(bgm_player, "volume_db", 0.0, fade_time / 2.0)
			else:
				bgm_player.stream = stream
				bgm_player.volume_db = 0.0
				bgm_player.play()
		else:
			bgm_player.stream = stream
			bgm_player.volume_db = -80.0 if fade_time > 0 else 0.0
			bgm_player.play()
			if fade_time > 0:
				_bgm_tween = create_tween()
				_bgm_tween.tween_property(bgm_player, "volume_db", 0.0, fade_time)

func stop_bgm(fade_time: float = 1.0) -> void:
	if not bgm_player.playing:
		return
	_kill_tween_if_valid(_bgm_tween)
	if fade_time > 0:
		_bgm_tween = create_tween()
		_bgm_tween.tween_property(bgm_player, "volume_db", -80.0, fade_time)
		_bgm_tween.tween_callback(func():
			bgm_player.stop()
			bgm_player.volume_db = 0.0
		)
	else:
		bgm_player.stop()
		bgm_player.volume_db = 0.0

func switch_bgm(audio_id: String, fade_time: float = 1.0) -> void:
	play_bgm(audio_id, fade_time)

func play_bgs(audio_id: String, fade_time: float = 1.0) -> void:
	if not audio_data["bgs"].has(audio_id):
		push_warning("BGS ID not found: " + audio_id)
		return
		
	var path = audio_data["bgs"][audio_id]
	var stream = load(path)
	if stream:
		_kill_tween_if_valid(_bgs_tween)
		_set_stream_loop(stream, true)
			
		if bgs_player.playing:
			if fade_time > 0:
				_bgs_tween = create_tween()
				_bgs_tween.tween_property(bgs_player, "volume_db", -80.0, fade_time / 2.0)
				_bgs_tween.tween_callback(func():
					bgs_player.stream = stream
					bgs_player.volume_db = -80.0
					bgs_player.play()
				)
				_bgs_tween.tween_property(bgs_player, "volume_db", 0.0, fade_time / 2.0)
			else:
				bgs_player.stream = stream
				bgs_player.volume_db = 0.0
				bgs_player.play()
		else:
			bgs_player.stream = stream
			bgs_player.volume_db = -80.0 if fade_time > 0 else 0.0
			bgs_player.play()
			if fade_time > 0:
				_bgs_tween = create_tween()
				_bgs_tween.tween_property(bgs_player, "volume_db", 0.0, fade_time)

func stop_bgs(fade_time: float = 1.0) -> void:
	if not bgs_player.playing:
		return
	_kill_tween_if_valid(_bgs_tween)
	if fade_time > 0:
		_bgs_tween = create_tween()
		_bgs_tween.tween_property(bgs_player, "volume_db", -80.0, fade_time)
		_bgs_tween.tween_callback(func():
			bgs_player.stop()
			bgs_player.volume_db = 0.0
		)
	else:
		bgs_player.stop()
		bgs_player.volume_db = 0.0

func play_se(audio_id: String, loop: bool = false) -> void:
	if not audio_data["se"].has(audio_id):
		push_warning("SE ID not found: " + audio_id)
		return
		
	var path = audio_data["se"][audio_id]
	var stream = load(path)
	if stream:
		if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
			stream.loop = loop
			
		for p in se_players:
			if not p.playing:
				p.stream = stream
				p.volume_db = 0.0
				p.play()
				return
		
		# If all players are busy, override the first one
		se_players[0].stream = stream
		se_players[0].volume_db = 0.0
		se_players[0].play()

func stop_se(audio_id: String) -> void:
	if not audio_data["se"].has(audio_id):
		return
	var path = audio_data["se"][audio_id]
	for p in se_players:
		if p.playing and p.stream != null and p.stream.resource_path == path:
			p.stop()
