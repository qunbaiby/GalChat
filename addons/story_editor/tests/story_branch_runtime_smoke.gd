extends SceneTree

const ScriptEngine = preload("res://scripts/script_engine/script_engine_manager.gd")

var failures: Array[String] = []
var requested_lines: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var engine := ScriptEngine.new()
	root.add_child(engine)
	engine.on_dialogue_requested.connect(_on_dialogue_requested)
	var loaded := engine.load_script_data({
		"script_id": "branch_runtime_smoke",
		"chapters": {
			"start": {"events": [{"type": "jump", "target_chapter": "target"}]},
			"target": {"events": [{"type": "dialogue", "speaker": "旁白", "content": "目标首事件"}]}
		}
	})
	_expect(loaded, "无法加载内存分支剧情。")
	engine.start_script()
	_expect(engine.current_chapter_id == "target", "Jump 没有切换到目标章节。")
	_expect(engine.current_event_index == 0, "Jump 后没有停在目标章节首事件。")
	_expect(requested_lines == ["目标首事件"], "目标章节首事件没有被执行。")
	var checkpoint := engine.get_checkpoint()
	_expect(str(checkpoint.get("chapter_id", "")) == "target", "剧情检查点没有记录当前章节。")
	_expect(int(checkpoint.get("event_index", -1)) == 0, "剧情检查点没有记录当前事件。")
	var restored_engine := ScriptEngine.new()
	root.add_child(restored_engine)
	var restored_lines: Array[String] = []
	restored_engine.on_dialogue_requested.connect(func(_speaker: String, content: String, _mood: String, _presentation: Dictionary): restored_lines.append(content))
	_expect(restored_engine.load_script_data(engine.current_script_data), "恢复测试无法重新加载剧情。")
	_expect(restored_engine.restore_checkpoint(checkpoint), "剧情检查点恢复失败。")
	_expect(restored_engine.current_chapter_id == "target", "恢复后剧情章节错误。")
	_expect(restored_engine.current_event_index == 0, "恢复后剧情事件游标错误。")
	_expect(restored_lines == ["目标首事件"], "恢复后没有重新呈现当前阻塞事件。")

	var checkpoint_engine := ScriptEngine.new()
	root.add_child(checkpoint_engine)
	var checkpoint_lines: Array[String] = []
	var saved_checkpoints: Array[Dictionary] = []
	checkpoint_engine.on_dialogue_requested.connect(func(_speaker: String, content: String, _mood: String, _presentation: Dictionary): checkpoint_lines.append(content))
	checkpoint_engine.checkpoint_changed.connect(func(state: Dictionary): saved_checkpoints.append(state.duplicate(true)))
	_expect(checkpoint_engine.load_script_data({
		"script_id": "checkpoint_wait_smoke",
		"chapters": {"start": {"events": [
			{"type": "dialogue", "speaker": "旁白", "content": "第一段"},
			{"type": "dialogue", "speaker": "旁白", "content": "第二段"}
		]}}
	}), "无法加载检查点等待测试剧情。")
	checkpoint_engine.start_script()
	_expect(checkpoint_lines == ["第一段"], "保存首个检查点时错误地自动推进了剧情。")
	_expect(checkpoint_engine.is_waiting_for_resume, "首段对话没有保持阻塞状态。")
	_expect(saved_checkpoints.size() == 1, "首段对话没有生成且仅生成一个检查点。")
	checkpoint_engine.resume()
	_expect(checkpoint_lines == ["第一段", "第二段"], "显式恢复后没有推进到第二段对话。")
	_expect(checkpoint_engine.is_waiting_for_resume, "第二段对话没有保持阻塞状态。")

	var topic_manager: Node = root.get_node_or_null("MainChatTopicManager")
	_expect(topic_manager != null, "MainChatTopicManager Autoload 不可用。")
	if topic_manager == null:
		_finish()
		return
	var claimed_topic: Dictionary = topic_manager.call("_normalize_topic_event", {
		"character_id": "luna",
		"event_id": "claimed_topic",
		"topic_text": "已经领取的话题",
		"auto_start_source_type": "fixed_chat_close",
		"auto_start_state": "claimed",
		"unlock_day_offset": 0
	})
	_expect(str(claimed_topic.get("auto_start_state", "")) == "claimed", "主聊天话题重载时丢失 claimed 状态。")
	var pending_topic: Dictionary = topic_manager.call("_normalize_topic_event", {
		"character_id": "luna",
		"event_id": "new_topic",
		"topic_text": "新话题",
		"auto_start_source_type": "fixed_chat_close",
		"unlock_day_offset": 0
	})
	_expect(str(pending_topic.get("auto_start_state", "")) == "pending", "新自动主聊天话题没有初始化为 pending。")
	var active_char_id := "story_branch_smoke_character"
	var rollback_event_id := "rollback_topic_smoke"
	_expect(topic_manager.activate_topic({
		"character_id": active_char_id,
		"event_id": rollback_event_id,
		"topic_text": "回滚测试话题",
		"auto_start_source_type": "fixed_chat_close",
		"unlock_day_offset": 0
	}), "无法激活自动主聊天回滚测试话题。")
	var claimed_for_rollback: Dictionary = topic_manager.claim_pending_auto_start_topic(active_char_id, "fixed_chat_close")
	_expect(str(claimed_for_rollback.get("auto_start_state", "")) == "claimed", "自动主聊天话题 claim 失败。")
	_expect(topic_manager.release_claimed_auto_start_topic(active_char_id, rollback_event_id), "启动失败后无法释放 claimed 话题。")
	var released_topic: Dictionary = topic_manager.get_active_topic_for(active_char_id)
	_expect(str(released_topic.get("auto_start_state", "")) == "pending", "释放 claimed 话题后没有恢复 pending。")
	topic_manager.consume_active_topic(active_char_id)

	var free_chat_engine := ScriptEngine.new()
	root.add_child(free_chat_engine)
	var free_chat_state := {"requested": false}
	free_chat_engine.on_start_free_chat_requested.connect(func(_strategy: String, _max_rounds: int): free_chat_state["requested"] = true)
	_expect(free_chat_engine.load_script_data({
		"script_id": "free_chat_runtime_smoke",
		"chapters": {"start": {"events": [{"type": "start_free_chat", "strategy": "围绕当前话题", "max_rounds": 2}]}}
	}), "无法加载自由聊天阻塞事件。")
	free_chat_engine.start_script()
	_expect(bool(free_chat_state.get("requested", false)), "start_free_chat 没有发出运行时请求。")
	_expect(free_chat_engine.is_waiting_for_resume, "start_free_chat 没有阻塞剧情推进。")

	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("STORY_BRANCH_RUNTIME_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("STORY_BRANCH_RUNTIME_SMOKE: %s" % failure)
	quit(1)


func _on_dialogue_requested(_speaker: String, content: String, _mood: String, _presentation: Dictionary) -> void:
	requested_lines.append(content)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)