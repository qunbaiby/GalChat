extends RefCounted
class_name MusicLibrary

const AUDIO_DATA_PATH: String = "res://assets/data/audio/audio_data.json"
const IMPORTED_MUSIC_DIR: String = "user://imported_music"
const DEFAULT_PLAYLIST_TRACK_ID: String = "luna_bgm"

static func load_tracks() -> Array:
	var tracks: Array = []
	if FileAccess.file_exists(AUDIO_DATA_PATH):
		var file: FileAccess = FileAccess.open(AUDIO_DATA_PATH, FileAccess.READ)
		if file != null:
			var content: String = file.get_as_text()
			file.close()
			var json = JSON.parse_string(content)
			if json is Dictionary and json.has("bgm") and json["bgm"] is Array:
				for raw_track in json["bgm"]:
					if raw_track is Dictionary and raw_track.has("path"):
						tracks.append(_normalize_track(raw_track))
	if tracks.is_empty():
		tracks = _load_fallback_tracks()
	return _ensure_default_playlist_track(tracks)

static func load_playlist_tracks() -> Array:
	var tracks: Array = []
	for track in load_tracks():
		if bool(track.get("in_playlist", false)):
			tracks.append(track)
	return tracks

static func save_tracks(tracks: Array) -> void:
	tracks = _ensure_default_playlist_track(tracks)
	var json_data: Dictionary = {
		"bgm": [],
		"bgs": [],
		"se": []
	}
	if FileAccess.file_exists(AUDIO_DATA_PATH):
		var file: FileAccess = FileAccess.open(AUDIO_DATA_PATH, FileAccess.READ)
		if file != null:
			var old_json = JSON.parse_string(file.get_as_text())
			file.close()
			if old_json is Dictionary:
				if old_json.has("bgs"):
					json_data["bgs"] = old_json["bgs"]
				if old_json.has("se"):
					json_data["se"] = old_json["se"]
	for track in tracks:
		json_data["bgm"].append(_serialize_track(track))
	var write_file: FileAccess = FileAccess.open(AUDIO_DATA_PATH, FileAccess.WRITE)
	if write_file != null:
		write_file.store_string(JSON.stringify(json_data, "  "))
		write_file.close()

static func update_track_fields(track_id: String, updates: Dictionary) -> Array:
	if track_id.strip_edges() == "":
		return load_tracks()
	var tracks: Array = load_tracks()
	for i in range(tracks.size()):
		if str(tracks[i].get("id", "")) != track_id:
			continue
		for key in updates.keys():
			tracks[i][key] = updates[key]
		break
	save_tracks(tracks)
	return tracks

static func is_playlist_locked(track_or_id: Variant) -> bool:
	if track_or_id is Dictionary:
		return str(track_or_id.get("id", "")) == DEFAULT_PLAYLIST_TRACK_ID
	return str(track_or_id) == DEFAULT_PLAYLIST_TRACK_ID

static func import_local_files(file_paths: PackedStringArray, existing_tracks: Array) -> Array:
	var imported_tracks: Array = []
	for file_path in file_paths:
		var imported_track: Dictionary = _import_single_music_file(file_path, existing_tracks, imported_tracks)
		if not imported_track.is_empty():
			imported_tracks.append(imported_track)
	return imported_tracks

static func get_track_title(track: Dictionary) -> String:
	var display_name: String = str(track.get("display_name", "")).strip_edges()
	if not display_name.is_empty():
		return display_name
	return str(track.get("path", "")).get_file().get_basename()

static func get_track_category(track: Dictionary) -> String:
	return "本地上传" if bool(track.get("is_local", false)) else "官方曲库"

static func get_track_type(track: Dictionary) -> String:
	var track_type: String = str(track.get("track_type", "")).strip_edges()
	if not track_type.is_empty():
		return track_type
	return "本地" if bool(track.get("is_local", false)) else "原声"

static func get_track_subtitle(track: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append(get_track_category(track))
	var imported_at: String = str(track.get("imported_at", "")).strip_edges()
	if not imported_at.is_empty():
		parts.append(imported_at)
	return " · ".join(parts)

static func get_track_duration(track: Dictionary) -> float:
	var stream: AudioStream = load_audio_stream(str(track.get("path", "")))
	if stream == null:
		return 0.0
	return maxf(stream.get_length(), 0.0)

static func format_duration(seconds: float) -> String:
	var total_seconds: int = maxi(int(round(seconds)), 0)
	var minutes: int = total_seconds / 60
	var remain_seconds: int = total_seconds % 60
	return "%d:%02d" % [minutes, remain_seconds]

static func load_audio_stream(path: String) -> AudioStream:
	if path.strip_edges() == "":
		return null
	if path.begins_with("res://"):
		return load(path)
	if path.ends_with(".mp3"):
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			return null
		var sound := AudioStreamMP3.new()
		sound.data = file.get_buffer(file.get_length())
		file.close()
		return sound
	if path.ends_with(".ogg"):
		return AudioStreamOggVorbis.load_from_file(path)
	return null

static func _normalize_track(raw_track: Dictionary) -> Dictionary:
	var track_id: String = str(raw_track.get("id", ""))
	var in_playlist: bool = bool(raw_track.get("in_playlist", false))
	if track_id == DEFAULT_PLAYLIST_TRACK_ID:
		in_playlist = true
	return {
		"id": track_id,
		"path": str(raw_track.get("path", "")),
		"display_name": str(raw_track.get("display_name", "")),
		"is_favorite": bool(raw_track.get("is_favorite", false)),
		"is_local": bool(raw_track.get("is_local", false)),
		"in_playlist": in_playlist,
		"track_type": str(raw_track.get("track_type", "")),
		"imported_at": str(raw_track.get("imported_at", ""))
	}

static func _serialize_track(track: Dictionary) -> Dictionary:
	var serialized: Dictionary = {
		"id": str(track.get("id", "")),
		"path": str(track.get("path", ""))
	}
	var display_name: String = str(track.get("display_name", "")).strip_edges()
	if not display_name.is_empty():
		serialized["display_name"] = display_name
	if bool(track.get("is_favorite", false)):
		serialized["is_favorite"] = true
	if bool(track.get("is_local", false)):
		serialized["is_local"] = true
	if bool(track.get("in_playlist", false)):
		serialized["in_playlist"] = true
	var track_type: String = str(track.get("track_type", "")).strip_edges()
	if not track_type.is_empty():
		serialized["track_type"] = track_type
	var imported_at: String = str(track.get("imported_at", "")).strip_edges()
	if not imported_at.is_empty():
		serialized["imported_at"] = imported_at
	return serialized

static func _load_fallback_tracks() -> Array:
	var tracks: Array = []
	var path: String = "res://assets/audio/bgm/"
	if not DirAccess.dir_exists_absolute(path):
		return tracks
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return tracks
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and (file_name.ends_with(".mp3") or file_name.ends_with(".ogg")):
			tracks.append(_normalize_track({
				"id": file_name.get_basename(),
				"path": path + file_name
			}))
		file_name = dir.get_next()
	return tracks

static func _import_single_music_file(source_path: String, existing_tracks: Array, imported_tracks: Array) -> Dictionary:
	if source_path.strip_edges() == "" or not FileAccess.file_exists(source_path):
		return {}
	var extension: String = source_path.get_extension().to_lower()
	if extension != "mp3" and extension != "ogg":
		return {}
	var target_path: String = _build_unique_import_path(source_path)
	if target_path == "":
		return {}
	var source_file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		return {}
	var buffer: PackedByteArray = source_file.get_buffer(source_file.get_length())
	source_file.close()
	var target_file: FileAccess = FileAccess.open(target_path, FileAccess.WRITE)
	if target_file == null:
		return {}
	target_file.store_buffer(buffer)
	target_file.close()
	for track in existing_tracks:
		if str(track.get("path", "")) == target_path:
			return {}
	for track in imported_tracks:
		if str(track.get("path", "")) == target_path:
			return {}
	return _normalize_track({
		"id": "local_" + str(Time.get_unix_time_from_system()) + "_" + str(randi()),
		"path": target_path,
		"display_name": source_path.get_file().get_basename(),
		"is_local": true,
		"track_type": "本地",
		"imported_at": Time.get_datetime_string_from_system(false).substr(0, 10)
	})

static func _build_unique_import_path(source_path: String) -> String:
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

static func _ensure_default_playlist_track(tracks: Array) -> Array:
	for i in range(tracks.size()):
		var track: Dictionary = tracks[i]
		if str(track.get("id", "")) != DEFAULT_PLAYLIST_TRACK_ID:
			continue
		track["in_playlist"] = true
		tracks[i] = track
		break
	return tracks
