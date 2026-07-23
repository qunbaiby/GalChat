@tool
extends RefCounted

const COMPLETION_EVENT_TYPES := ["activate_goal", "activate_main_chat_topic"]


static func validate(data: Dictionary, catalogs: Dictionary = {}) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	if str(data.get("id", "")).strip_edges().is_empty():
		_add(diagnostics, "error", "根节点", "缺少固定聊天 id。")
	var character_id := str(data.get("character_id", "")).strip_edges()
	if character_id.is_empty():
		_add(diagnostics, "error", "根节点", "缺少 character_id。")
	elif catalogs.has("character_ids") and not (catalogs.get("character_ids", []) as Array).has(character_id):
		_add(diagnostics, "error", "根节点", "角色不存在：%s" % character_id)
	var messages_value: Variant = data.get("messages")
	if not messages_value is Array or (messages_value as Array).is_empty():
		_add(diagnostics, "error", "根节点", "messages 必须是非空数组。")
		return diagnostics
	var messages := messages_value as Array
	var message_indices := {}
	for message_index in messages.size():
		var message_value: Variant = messages[message_index]
		var location := "消息 #%d" % (message_index + 1)
		if not message_value is Dictionary:
			_add(diagnostics, "error", location, "消息必须是对象。")
			continue
		var message := message_value as Dictionary
		var message_id := str(message.get("id", "")).strip_edges()
		if message_id.is_empty():
			_add(diagnostics, "error", location, "消息缺少 id。")
		elif message_indices.has(message_id):
			_add(diagnostics, "error", location, "消息 ID 重复：%s" % message_id)
		else:
			message_indices[message_id] = message_index
	_validate_messages(messages, message_indices, diagnostics)
	_validate_graph(messages, message_indices, diagnostics)
	_validate_completion_events(data.get("on_complete_events", []), catalogs, diagnostics)
	return diagnostics


static func _validate_messages(messages: Array, message_indices: Dictionary, diagnostics: Array[Dictionary]) -> void:
	var option_ids := {}
	for message_index in messages.size():
		if not messages[message_index] is Dictionary:
			continue
		var message := messages[message_index] as Dictionary
		var location := "消息 #%d" % (message_index + 1)
		var speaker := str(message.get("speaker", "")).strip_edges()
		if speaker.is_empty():
			_add(diagnostics, "error", location, "消息缺少 speaker。")
		if float(message.get("delay", 0.0)) < 0.0:
			_add(diagnostics, "error", location, "消息 delay 不能为负数。")
		if bool(message.get("is_voice", false)) and float(message.get("duration", 0.0)) <= 0.0:
			_add(diagnostics, "error", location, "语音消息 duration 必须大于 0。")
		if str(message.get("type", "")) == "red_packet" and float(message.get("amount", 0.0)) <= 0.0:
			_add(diagnostics, "error", location, "红包金额必须大于 0。")
		if speaker != "player_options":
			if str(message.get("text", "")).strip_edges().is_empty() and str(message.get("image", "")).strip_edges().is_empty():
				_add(diagnostics, "error", location, "消息至少需要 text 或 image。")
			continue
		var options_value: Variant = message.get("options")
		if not options_value is Array or (options_value as Array).is_empty():
			_add(diagnostics, "error", location, "玩家选项消息至少需要一个 option。")
			continue
		for option_index in (options_value as Array).size():
			var option_location := "%s / 选项 #%d" % [location, option_index + 1]
			var option_value: Variant = (options_value as Array)[option_index]
			if not option_value is Dictionary:
				_add(diagnostics, "error", option_location, "选项必须是对象。")
				continue
			var option := option_value as Dictionary
			var option_id := str(option.get("id", "")).strip_edges()
			if option_id.is_empty():
				_add(diagnostics, "error", option_location, "选项缺少 id。")
			elif option_ids.has(option_id):
				_add(diagnostics, "error", option_location, "选项 ID 重复：%s" % option_id)
			else:
				option_ids[option_id] = true
			if str(option.get("text", "")).strip_edges().is_empty():
				_add(diagnostics, "error", option_location, "选项文本不能为空。")
			var target := str(option.get("next", "")).strip_edges()
			if target.is_empty():
				_add(diagnostics, "warning", option_location, "选项缺少 next，运行时将顺序推进。")
			elif not message_indices.has(target):
				_add(diagnostics, "error", option_location, "目标消息不存在：%s" % target)


static func _validate_graph(messages: Array, message_indices: Dictionary, diagnostics: Array[Dictionary]) -> void:
	var edges: Array[Array] = []
	var reverse_edges: Array[Array] = []
	for index in messages.size():
		edges.append([])
		reverse_edges.append([])
	for message_index in messages.size():
		if not messages[message_index] is Dictionary:
			continue
		var message := messages[message_index] as Dictionary
		if str(message.get("speaker", "")) == "player_options":
			for option_value in message.get("options", []):
				if option_value is Dictionary:
					var target := str((option_value as Dictionary).get("next", ""))
					if message_indices.has(target):
						edges[message_index].append(int(message_indices[target]))
			if edges[message_index].is_empty() and message_index + 1 < messages.size():
				edges[message_index].append(message_index + 1)
		elif message_index + 1 < messages.size():
			edges[message_index].append(message_index + 1)
	for source_index in edges.size():
		for target_index in edges[source_index]:
			reverse_edges[int(target_index)].append(source_index)
	var reachable := _walk_graph(edges, 0)
	for message_index in messages.size():
		if not reachable.has(message_index):
			_add(diagnostics, "warning", "消息 #%d" % (message_index + 1), "消息无法从首节点到达。")
	var terminal_indices: Array[int] = []
	for message_index in edges.size():
		if edges[message_index].is_empty():
			terminal_indices.append(message_index)
	var can_reach_end := {}
	for terminal_index in terminal_indices:
		for index in _walk_graph(reverse_edges, terminal_index):
			can_reach_end[index] = true
	for message_index in reachable:
		if not can_reach_end.has(message_index):
			_add(diagnostics, "error", "消息 #%d" % (int(message_index) + 1), "消息路径进入无出口循环。")


static func _walk_graph(edges: Array[Array], start_index: int) -> Dictionary:
	var visited := {}
	var pending: Array[int] = [start_index]
	while not pending.is_empty():
		var current := pending.pop_front()
		if current < 0 or current >= edges.size() or visited.has(current):
			continue
		visited[current] = true
		for target in edges[current]:
			pending.append(int(target))
	return visited


static func _validate_completion_events(events_value: Variant, catalogs: Dictionary, diagnostics: Array[Dictionary]) -> void:
	if not events_value is Array:
		_add(diagnostics, "error", "完成动作", "on_complete_events 必须是数组。")
		return
	for event_index in (events_value as Array).size():
		var location := "完成动作 #%d" % (event_index + 1)
		var event_value: Variant = (events_value as Array)[event_index]
		if not event_value is Dictionary:
			_add(diagnostics, "error", location, "完成动作必须是对象。")
			continue
		var event := event_value as Dictionary
		var event_type := str(event.get("type", ""))
		if not COMPLETION_EVENT_TYPES.has(event_type):
			_add(diagnostics, "error", location, "未知完成动作类型：%s" % event_type)
		elif event_type == "activate_goal":
			var goal_id := str(event.get("goal_id", "")).strip_edges()
			if goal_id.is_empty():
				_add(diagnostics, "error", location, "activate_goal 缺少 goal_id。")
			elif catalogs.has("goal_ids") and not (catalogs.get("goal_ids", []) as Array).has(goal_id):
				_add(diagnostics, "error", location, "目标不存在：%s" % goal_id)
		elif event_type == "activate_main_chat_topic":
			for required_field in ["character_id", "event_id", "topic_text", "topic_prompt_hint"]:
				if str(event.get(required_field, "")).strip_edges().is_empty():
					_add(diagnostics, "error", location, "主聊天话题缺少 %s。" % required_field)
			var story_script_path := str(event.get("story_script_path", "")).strip_edges()
			if story_script_path != "" and not FileAccess.file_exists(story_script_path):
				_add(diagnostics, "warning", location, "后续主线不存在，将回退到话题 AI：%s" % story_script_path)


static func _add(diagnostics: Array[Dictionary], severity: String, location: String, message: String) -> void:
	diagnostics.append({"severity": severity, "location": location, "message": message})