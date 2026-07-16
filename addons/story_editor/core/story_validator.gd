@tool
extends RefCounted

const KNOWN_EVENT_TYPES := {
	"dialogue": true, "background": true, "audio": true, "bgm": true,
	"show_character": true, "move_character": true, "hide_character": true,
	"period_card": true, "choice": true, "jump": true, "set_variable": true,
	"ai_chat": true, "start_free_chat": true, "voice_call": true,
	"show_player_call_name_popup": true
}


static func validate(data: Dictionary) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	if str(data.get("script_id", "")).strip_edges().is_empty():
		_add(diagnostics, "error", "根节点", "缺少 script_id。")
	var chapters_value: Variant = data.get("chapters")
	if not chapters_value is Dictionary:
		_add(diagnostics, "error", "根节点", "chapters 必须是对象。")
		return diagnostics
	var chapters := chapters_value as Dictionary
	if not chapters.has("start"):
		_add(diagnostics, "error", "根节点", "chapters 必须包含 start 章节。")
	for chapter_id_value in chapters.keys():
		var chapter_id := str(chapter_id_value)
		var chapter_value: Variant = chapters[chapter_id_value]
		if not chapter_value is Dictionary:
			_add(diagnostics, "error", chapter_id, "章节必须是对象。")
			continue
		var events_value: Variant = (chapter_value as Dictionary).get("events")
		if not events_value is Array:
			_add(diagnostics, "error", chapter_id, "events 必须是数组。")
			continue
		var events := events_value as Array
		for event_index in events.size():
			_validate_event(events[event_index], chapter_id, event_index, chapters, diagnostics)
	_validate_reachable_chapters(chapters, diagnostics)
	return diagnostics


static func _validate_event(event_value: Variant, chapter_id: String, event_index: int, chapters: Dictionary, diagnostics: Array[Dictionary]) -> void:
	var location := "%s / #%d" % [chapter_id, event_index + 1]
	if not event_value is Dictionary:
		_add(diagnostics, "error", location, "事件必须是对象。")
		return
	var event := event_value as Dictionary
	var event_type := str(event.get("type", ""))
	if event_type.is_empty():
		_add(diagnostics, "error", location, "事件缺少 type。")
		return
	if not KNOWN_EVENT_TYPES.has(event_type):
		_add(diagnostics, "error", location, "未知事件类型：%s" % event_type)
	if event_type == "dialogue" and str(event.get("content", "")).strip_edges().is_empty():
		_add(diagnostics, "error", location, "对白内容不能为空。")
	if event_type == "dialogue" and str(event.get("voice_instruction", "")).length() > 80:
		_add(diagnostics, "error", location, "TTS 2.0 语音指令不能超过 80 个字符。")
	if event_type == "background" and str(event.get("bg_id", "")).is_empty():
		_add(diagnostics, "error", location, "背景事件缺少 bg_id。")
	if event_type == "choice":
		var options_value: Variant = event.get("options")
		if not options_value is Array or (options_value as Array).is_empty():
			_add(diagnostics, "error", location, "选择事件至少需要一个选项。")
		else:
			_validate_choice_options(options_value as Array, location, chapters, diagnostics)
	if event_type == "jump":
		var target := str(event.get("target_chapter", ""))
		if target.is_empty():
			_add(diagnostics, "error", location, "跳转事件缺少 target_chapter。")
		elif target != "end" and not chapters.has(target):
			_add(diagnostics, "error", location, "目标章节不存在：%s" % target)


static func _validate_choice_options(options: Array, location: String, chapters: Dictionary, diagnostics: Array[Dictionary]) -> void:
	var option_ids := {}
	for option_index in options.size():
		var option_location := "%s / 选项 #%d" % [location, option_index + 1]
		var option_value: Variant = options[option_index]
		if not option_value is Dictionary:
			_add(diagnostics, "error", option_location, "选项必须是对象。")
			continue
		var option := option_value as Dictionary
		if str(option.get("text", option.get("label", ""))).strip_edges().is_empty():
			_add(diagnostics, "error", option_location, "选项文本不能为空。")
		var option_id := str(option.get("id", "")).strip_edges()
		if not option_id.is_empty():
			if option_ids.has(option_id):
				_add(diagnostics, "error", option_location, "选项 ID 重复：%s" % option_id)
			option_ids[option_id] = true
		var target := str(option.get("target_chapter", "")).strip_edges()
		if target.is_empty():
			_add(diagnostics, "warning", option_location, "分支未连接，将继续执行下一事件。")
		elif target != "end" and not chapters.has(target):
			_add(diagnostics, "error", option_location, "目标章节不存在：%s" % target)


static func _validate_reachable_chapters(chapters: Dictionary, diagnostics: Array[Dictionary]) -> void:
	if not chapters.has("start"):
		return
	var reachable := {"start": true}
	var pending: Array[String] = ["start"]
	while not pending.is_empty():
		var chapter_id := pending.pop_front()
		var chapter := chapters.get(chapter_id, {}) as Dictionary
		var events := chapter.get("events", []) as Array
		for event_value in events:
			if not event_value is Dictionary:
				continue
			var event := event_value as Dictionary
			var targets: Array[String] = []
			if str(event.get("type", "")) == "jump":
				targets.append(str(event.get("target_chapter", "")))
			elif str(event.get("type", "")) == "choice":
				for option_value in event.get("options", []):
					if option_value is Dictionary:
						targets.append(str((option_value as Dictionary).get("target_chapter", "")))
			for target in targets:
				if target != "end" and chapters.has(target) and not reachable.has(target):
					reachable[target] = true
					pending.append(target)
	for chapter_id_value in chapters.keys():
		var chapter_id := str(chapter_id_value)
		if not reachable.has(chapter_id):
			_add(diagnostics, "warning", chapter_id, "章节无法从 start 的分支路径到达。")


static func _add(diagnostics: Array[Dictionary], severity: String, location: String, message: String) -> void:
	diagnostics.append({"severity": severity, "location": location, "message": message})