extends SceneTree

const NPC_IDS: PackedStringArray = ["jing", "ya", "shuo", "ling", "aili", "luna_father"]

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_resource = load("res://scenes/ui/map/core/quick_location_scene.tscn")
	_expect(scene_resource != null, "快捷地点场景无法加载。")
	if scene_resource == null:
		_finish()
		return
	var scene = scene_resource.instantiate()
	scene.location_id = "library"
	root.add_child(scene)
	await process_frame

	var fallback := "先把课程问题列出来，我不想听你泛泛而谈。"
	var ooc_line := "这段涉及古代精灵语词根，你昨晚预习时应该标记过疑问点了吧。"
	_expect(scene._normalize_bubble_line(ooc_line, fallback) == fallback, "精灵语越界台词没有回退到静的本地模板。")
	_expect(scene._normalize_bubble_line("这段咒文需要重新记忆。", fallback) == fallback, "咒文越界台词没有回退。")
	_expect(scene._normalize_bubble_line("先把最没把握的部分列出来。", fallback) != fallback, "正常现实台词被错误拦截。")

	var prompt: String = str(scene._build_bubble_polish_prompt("jing", "静", {"name": "静"}, fallback, "action_open", "study"))
	_expect(prompt.contains("图书馆学业支持与资料管理"), "静的地图气泡提示词没有注入真实身份背景。")
	_expect(prompt.contains("不得编造角色设定中不存在的课程"), "地图气泡提示词没有禁止编造课程和知识点。")
	_expect(prompt.contains("禁止出现精灵、魔法、咒语"), "地图气泡提示词没有明确现代现实世界观边界。")

	for npc_id in NPC_IDS:
		var path := "res://assets/data/characters/npc/%s.json" % npc_id
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_expect(data is Dictionary and str((data as Dictionary).get("identity_background", "")).strip_edges() != "", "%s 缺少可注入的身份背景。" % npc_id)

	var npc_prompt_template := FileAccess.get_file_as_string("res://scripts/templates/prompts/npc_event.txt")
	_expect(npc_prompt_template.contains("{identity_background}"), "通用 NPC 事件模板没有身份背景占位。")
	_expect(npc_prompt_template.contains("基础事件未明确提供的专有名词、课程名、书名和知识点也不得自行编造"), "通用 NPC 事件模板没有阻止虚构知识点。")
	var game_data_manager = root.get_node_or_null("GameDataManager")
	_expect(game_data_manager != null and game_data_manager.prompt_manager != null, "PromptManager 未初始化。")
	if game_data_manager != null and game_data_manager.prompt_manager != null:
		var system_prompt: String = game_data_manager.prompt_manager.build_npc_event_prompt(
			"静",
			"干练、严格、外冷内热",
			"Luna",
			1,
			"普通朋友",
			"图书馆即时气泡",
			0.0,
			0.0,
			{"identity_background": "静负责图书馆学业支持与资料管理。", "character_tags": "导师、图书馆"}
		)
		_expect(system_prompt.contains("静负责图书馆学业支持与资料管理"), "最终 NPC 系统提示没有注入静的真实身份。")
		_expect(system_prompt.contains("禁止出现精灵、魔法、咒语"), "最终 NPC 系统提示没有现代现实世界观禁区。")
	scene.queue_free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("NPC_BUBBLE_PERSONA_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("NPC_BUBBLE_PERSONA_SMOKE: %s" % failure)
	quit(1)
