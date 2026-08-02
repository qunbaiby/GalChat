extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_data_manager := root.get_node_or_null("GameDataManager")
	_expect(game_data_manager != null and game_data_manager.profile != null, "CharacterProfile 未初始化。")
	if game_data_manager == null or game_data_manager.profile == null:
		_finish()
		return
	var profile = game_data_manager.profile
	var fallback := {"primary_id": "", "primary_score": 0.0}
	var null_result: Dictionary = profile._dictionary_or_default(null, fallback)
	var invalid_result: Dictionary = profile._dictionary_or_default([], fallback)
	var valid_result: Dictionary = profile._dictionary_or_default({"primary_id": "calm"}, fallback)

	_expect(null_result == fallback, "null Dictionary 字段没有回退到默认值。")
	_expect(invalid_result == fallback, "错误类型的 Dictionary 字段没有回退到默认值。")
	_expect(valid_result == {"primary_id": "calm"}, "有效 Dictionary 字段在读档清洗时被改写。")
	null_result["primary_id"] = "changed"
	_expect(str(fallback.get("primary_id", "")) == "", "读档回退字典与默认值共享了可变引用。")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CHARACTER_PROFILE_NULL_DICTIONARY_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("CHARACTER_PROFILE_NULL_DICTIONARY_SMOKE: %s" % failure)
	quit(1)