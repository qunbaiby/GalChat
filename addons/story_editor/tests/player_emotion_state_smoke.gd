extends Node

const PlayerEmotionStateManagerScript = preload("res://scripts/data/player_emotion_state_manager.gd")

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixed_now := float(Time.get_unix_time_from_datetime_string("2026-07-23T12:00:00"))
	var save_path := "user://player_emotion_state_smoke_%s.json" % str(Time.get_ticks_usec())
	var manager = PlayerEmotionStateManagerScript.new()
	manager.save_path_override = save_path
	add_child(manager)
	_expect(manager.get_state_evaluation(fixed_now).get("reason", "") == "missing", "空状态没有中性降级。")
	_expect(manager.set_explicit_state("low", 0.9, 3600.0, fixed_now), "显式玩家情绪状态保存失败。")
	var active: Dictionary = manager.get_state_evaluation(fixed_now + 1800.0)
	var context: Dictionary = manager.build_emotion_context(fixed_now + 1800.0)
	_expect(bool(active.get("usable", false)) and str(context.get("macro_mood_id", "")) == "low" and str(context.get("source", "")) == PlayerEmotionStateManagerScript.SOURCE_PLAYER_EXPLICIT, "有效显式状态没有生成可信情绪上下文。")
	_expect(manager.get_state_evaluation(fixed_now + 3600.0).get("reason", "") == "expired" and manager.build_emotion_context(fixed_now + 3600.0).is_empty(), "过期状态仍进入了情绪上下文。")
	_expect(manager.set_explicit_state("pleasant", 0.69, 3600.0, fixed_now), "低置信状态应允许保存以供审计。")
	_expect(manager.get_state_evaluation(fixed_now).get("reason", "") == "low_confidence", "低置信状态没有被门禁拦截。")
	_expect(not manager.set_explicit_state("angry", 1.0, 3600.0, fixed_now), "非法情绪标签被接受。")
	manager.state = {"emotion_id": "calm", "confidence": 1.0, "source": "text_inference", "observed_at_unix": fixed_now, "expires_at_unix": fixed_now + 3600.0}
	_expect(manager.get_state_evaluation(fixed_now).get("reason", "") == "untrusted_source", "文本推断来源没有被拒绝。")
	manager.state = {"emotion_id": "ecstatic", "confidence": 0.95, "source": PlayerEmotionStateManagerScript.SOURCE_PLAYER_EXPLICIT, "observed_at_unix": fixed_now, "expires_at_unix": fixed_now + 7200.0}
	_expect(manager.save_state(), "测试状态持久化失败。")
	var restored = PlayerEmotionStateManagerScript.new()
	restored.save_path_override = save_path
	add_child(restored)
	restored.load_state()
	_expect(str(restored.build_emotion_context(fixed_now).get("macro_mood_id", "")) == "ecstatic", "显式玩家情绪状态没有从存储恢复。")
	_expect(restored.clear_state() and restored.get_state_evaluation(fixed_now).get("reason", "") == "missing" and not FileAccess.file_exists(save_path), "清除状态没有删除持久化数据。")
	manager.queue_free()
	restored.queue_free()
	if failures.is_empty():
		print("PLAYER_EMOTION_STATE_SMOKE_OK")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error("PLAYER_EMOTION_STATE_SMOKE: %s" % failure)
	get_tree().quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)