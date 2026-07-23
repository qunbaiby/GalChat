class_name PlayerEmotionStateManager
extends Node

const SafeFileAccessUtil = preload("res://scripts/utils/safe_file_access.gd")
const SAVE_FILE_NAME := "player_emotion_state.json"
const SCHEMA_VERSION := 1
const SOURCE_PLAYER_EXPLICIT := "player_explicit"
const MIN_CONFIDENCE := 0.70
const DEFAULT_TTL_SECONDS := 7200.0
const VALID_EMOTION_IDS := ["broken", "low", "calm", "pleasant", "ecstatic"]

signal state_changed

var state: Dictionary = {}
var save_path_override := ""

func get_save_path() -> String:
	if not save_path_override.is_empty():
		return save_path_override
	return GameDataManager.get_archive_state_path(SAVE_FILE_NAME)

func set_explicit_state(emotion_id: String, confidence: float = 1.0, ttl_seconds: float = DEFAULT_TTL_SECONDS, observed_at_unix: float = -1.0) -> bool:
	var normalized_id := emotion_id.strip_edges().to_lower()
	if not VALID_EMOTION_IDS.has(normalized_id) or confidence < 0.0 or confidence > 1.0 or ttl_seconds <= 0.0:
		return false
	var observed_unix := observed_at_unix if observed_at_unix >= 0.0 else Time.get_unix_time_from_system()
	state = {
		"emotion_id": normalized_id,
		"confidence": confidence,
		"source": SOURCE_PLAYER_EXPLICIT,
		"observed_at_unix": observed_unix,
		"expires_at_unix": observed_unix + ttl_seconds
	}
	var saved := save_state()
	state_changed.emit()
	return saved

func clear_state() -> bool:
	state.clear()
	var path := get_save_path()
	var cleared := true
	if FileAccess.file_exists(path):
		cleared = DirAccess.remove_absolute(path) == OK
	state_changed.emit()
	return cleared

func get_state_evaluation(now_unix: float = -1.0) -> Dictionary:
	var reference_unix := now_unix if now_unix >= 0.0 else Time.get_unix_time_from_system()
	var emotion_id := str(state.get("emotion_id", "")).strip_edges().to_lower()
	var confidence := float(state.get("confidence", 0.0))
	var source := str(state.get("source", ""))
	var observed_at_unix := float(state.get("observed_at_unix", 0.0))
	var expires_at_unix := float(state.get("expires_at_unix", 0.0))
	var reason := "usable"
	if state.is_empty():
		reason = "missing"
	elif source != SOURCE_PLAYER_EXPLICIT:
		reason = "untrusted_source"
	elif not VALID_EMOTION_IDS.has(emotion_id):
		reason = "invalid_emotion"
	elif confidence < MIN_CONFIDENCE:
		reason = "low_confidence"
	elif observed_at_unix <= 0.0 or expires_at_unix <= observed_at_unix:
		reason = "invalid_time_range"
	elif reference_unix >= expires_at_unix:
		reason = "expired"
	return {
		"emotion_id": emotion_id,
		"confidence": confidence,
		"source": source,
		"observed_at_unix": observed_at_unix,
		"expires_at_unix": expires_at_unix,
		"usable": reason == "usable",
		"reason": reason
	}

func build_emotion_context(now_unix: float = -1.0) -> Dictionary:
	var evaluation := get_state_evaluation(now_unix)
	if not bool(evaluation.get("usable", false)):
		return {}
	return {
		"macro_mood_id": str(evaluation.get("emotion_id", "")),
		"confidence": float(evaluation.get("confidence", 0.0)),
		"source": str(evaluation.get("source", "")),
		"observed_at_unix": float(evaluation.get("observed_at_unix", 0.0)),
		"expires_at_unix": float(evaluation.get("expires_at_unix", 0.0))
	}

func load_state() -> void:
	state.clear()
	var path := get_save_path()
	if not FileAccess.file_exists(path):
		state_changed.emit()
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		state_changed.emit()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary and int(parsed.get("schema_version", 0)) == SCHEMA_VERSION and parsed.get("state", {}) is Dictionary:
		state = parsed.get("state", {}).duplicate(true)
	state_changed.emit()

func save_state() -> bool:
	return SafeFileAccessUtil.store_string(get_save_path(), JSON.stringify({
		"schema_version": SCHEMA_VERSION,
		"state": state
	}, "\t"))