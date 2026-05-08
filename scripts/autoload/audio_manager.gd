extends Node

var audio_data: Dictionary = {"bgm": {}, "bgs": {}, "se": {}}

var bgm_player: AudioStreamPlayer
var bgs_player: AudioStreamPlayer
var se_players: Array[AudioStreamPlayer] = []
var max_se_players: int = 5

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

func play_bgm(audio_id: String, fade_time: float = 1.0) -> void:
	if not audio_data["bgm"].has(audio_id):
		push_warning("BGM ID not found: " + audio_id)
		return
		
	var path = audio_data["bgm"][audio_id]
	var stream = load(path)
	if stream:
		# 处理循环播放
		if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
			stream.loop = true
			
		if bgm_player.playing:
			if fade_time > 0:
				var tween = create_tween()
				tween.tween_property(bgm_player, "volume_db", -80.0, fade_time / 2.0)
				tween.tween_callback(func():
					bgm_player.stream = stream
					bgm_player.play()
				)
				tween.tween_property(bgm_player, "volume_db", 0.0, fade_time / 2.0)
			else:
				bgm_player.stream = stream
				bgm_player.play()
		else:
			bgm_player.stream = stream
			bgm_player.volume_db = -80.0 if fade_time > 0 else 0.0
			bgm_player.play()
			if fade_time > 0:
				var tween = create_tween()
				tween.tween_property(bgm_player, "volume_db", 0.0, fade_time)

func stop_bgm(fade_time: float = 1.0) -> void:
	if not bgm_player.playing:
		return
	if fade_time > 0:
		var tween = create_tween()
		tween.tween_property(bgm_player, "volume_db", -80.0, fade_time)
		tween.tween_callback(func(): bgm_player.stop())
	else:
		bgm_player.stop()

func play_bgs(audio_id: String, fade_time: float = 1.0) -> void:
	if not audio_data["bgs"].has(audio_id):
		push_warning("BGS ID not found: " + audio_id)
		return
		
	var path = audio_data["bgs"][audio_id]
	var stream = load(path)
	if stream:
		if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
			stream.loop = true
			
		if bgs_player.playing:
			if fade_time > 0:
				var tween = create_tween()
				tween.tween_property(bgs_player, "volume_db", -80.0, fade_time / 2.0)
				tween.tween_callback(func():
					bgs_player.stream = stream
					bgs_player.play()
				)
				tween.tween_property(bgs_player, "volume_db", 0.0, fade_time / 2.0)
			else:
				bgs_player.stream = stream
				bgs_player.play()
		else:
			bgs_player.stream = stream
			bgs_player.volume_db = -80.0 if fade_time > 0 else 0.0
			bgs_player.play()
			if fade_time > 0:
				var tween = create_tween()
				tween.tween_property(bgs_player, "volume_db", 0.0, fade_time)

func stop_bgs(fade_time: float = 1.0) -> void:
	if not bgs_player.playing:
		return
	if fade_time > 0:
		var tween = create_tween()
		tween.tween_property(bgs_player, "volume_db", -80.0, fade_time)
		tween.tween_callback(func(): bgs_player.stop())
	else:
		bgs_player.stop()

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