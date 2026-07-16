@tool
extends Window

const Service = preload("res://addons/story_editor/core/mobile_ai_workbench_service.gd")
const DeepSeekRequester = preload("res://addons/story_editor/core/mobile_ai_deepseek_requester.gd")
const WINDOW_LAYOUT_PATH := "res://addons/story_editor/core/editor_window_layout.gd"

var last_preview: Dictionary = {}
var generation_requester: Node
var active_job_id := ""
var job_sequence := 0


func _ready() -> void:
	close_requested.connect(hide)
	%PreviewButton.pressed.connect(build_preview)
	%RealRequestButton.pressed.connect(start_real_request)
	%CancelRequestButton.pressed.connect(cancel_real_request)
	%CharacterSelect.item_selected.connect(_on_character_selected)
	%ResultTabs.set_tab_title(%ResultTabs.get_tab_idx_from_control(%最终Prompt), "最终 Prompt")
	%ResultTabs.set_tab_title(%ResultTabs.get_tab_idx_from_control(%请求Messages), "请求 Messages")
	%ResultTabs.set_tab_title(%ResultTabs.get_tab_idx_from_control(%请求元数据), "请求元数据")
	_setup_characters()
	_setup_diagnostics()


func open_workbench() -> void:
	(load(WINDOW_LAYOUT_PATH) as GDScript).new().open_window(self, Vector2i(1360, 820), Vector2i(1040, 650))


func set_generation_requester(requester: Node) -> void:
	if generation_requester != null:
		_disconnect_requester()
		if generation_requester.get_parent() == self:
			generation_requester.queue_free()
	generation_requester = requester
	if generation_requester.get_parent() == null:
		add_child(generation_requester)
	generation_requester.completed.connect(_on_request_completed)
	generation_requester.failed.connect(_on_request_failed)


func start_real_request() -> void:
	if not active_job_id.is_empty():
		return
	if not build_preview():
		return
	if generation_requester == null:
		set_generation_requester(DeepSeekRequester.new())
	job_sequence += 1
	active_job_id = "mobile_ai_job_%d" % job_sequence
	_set_request_running(true)
	%请求元数据.text = JSON.stringify({"status": "running", "job_id": active_job_id}, "    ")
	%StatusLabel.text = "正在执行真实 API 请求 · 不写角色存档"
	var request := last_preview.get("request", {}) as Dictionary
	generation_requester.request(active_job_id, {"messages": (request.get("messages", []) as Array).duplicate(true)})


func cancel_real_request() -> void:
	if active_job_id.is_empty():
		return
	var cancelled_job_id := active_job_id
	generation_requester.cancel(cancelled_job_id)
	active_job_id = ""
	_set_request_running(false)
	%请求元数据.text = JSON.stringify({"status": "cancelled", "job_id": cancelled_job_id}, "    ")
	%StatusLabel.text = "真实请求已取消 · 未写入角色存档"


func build_preview() -> bool:
	var history_value: Variant = JSON.parse_string(%HistoryEdit.text)
	if not history_value is Array:
		_show_input_error("内存历史必须是 JSON 数组。")
		return false
	var response_value: Variant = JSON.parse_string(%ResponseEdit.text)
	if not response_value is Dictionary:
		_show_input_error("原始响应必须是 JSON 对象。")
		return false
	var mode := str(%ModeSelect.get_item_metadata(%ModeSelect.selected))
	last_preview = Service.preview(mode, _collect_overrides(), history_value as Array, %PlayerTextEdit.text, response_value)
	var request := last_preview.get("request", {}) as Dictionary
	var response := last_preview.get("response", {}) as Dictionary
	var messages := request.get("messages", []) as Array
	%最终Prompt.text = str((messages[0] as Dictionary).get("content", "")) if not messages.is_empty() else ""
	%请求Messages.text = JSON.stringify(messages, "    ")
	%清洗结果.text = JSON.stringify({"parts": response.get("parts", []), "history_records": response.get("history_records", []), "raw_content": response.get("raw_content", "")}, "    ")
	_show_diagnostics(response.get("diagnostics", []) as Array)
	%StatusLabel.text = "已构建 %d 条请求消息 · 清洗为 %d 段 · 无网络与存档写入" % [messages.size(), (response.get("parts", []) as Array).size()]
	return true


func _collect_overrides() -> Dictionary:
	return {
		"character_id": str(%CharacterSelect.get_item_metadata(%CharacterSelect.selected)),
		"player_name": %PlayerEdit.text,
		"relationship_stage": int(%StageSpin.value),
		"intimacy": float(%IntimacySpin.value),
		"trust": float(%TrustSpin.value),
		"flavor": %FlavorEdit.text,
		"story_time": %TimeEdit.text,
		"mood_desc": "【角色当前整体心情】：\n%s" % %MoodEdit.text,
		"memory_desc": %MemoryEdit.text,
		"location_context": %LocationEdit.text,
		"dynamic_style": Service.SINGLE_STYLE if %StyleSelect.selected == 0 else Service.DOUBLE_STYLE
	}


func _setup_characters() -> void:
	%CharacterSelect.clear()
	for entry in Service.scan_characters():
		%CharacterSelect.add_item("%s · %s" % [str(entry.get("label", "")), str(entry.get("id", ""))])
		%CharacterSelect.set_item_metadata(%CharacterSelect.item_count - 1, str(entry.get("id", "")))
		if str(entry.get("id", "")) == "luna":
			%CharacterSelect.select(%CharacterSelect.item_count - 1)


func _on_character_selected(_index: int) -> void:
	var context := Service.build_context({"character_id": str(%CharacterSelect.get_item_metadata(%CharacterSelect.selected)), "relationship_stage": int(%StageSpin.value)})
	%PlayerEdit.text = str(context.get("player_name", "老师"))


func _setup_diagnostics() -> void:
	%审核诊断.set_column_title(0, "级别")
	%审核诊断.set_column_title(1, "说明")
	%审核诊断.set_column_expand(0, false)
	%审核诊断.set_column_custom_minimum_width(0, 80)


func _show_diagnostics(diagnostics: Array) -> void:
	%审核诊断.clear()
	var root: TreeItem = %审核诊断.create_item()
	if diagnostics.is_empty():
		var item: TreeItem = %审核诊断.create_item(root)
		item.set_text(0, "OK")
		item.set_text(1, "响应结构、分段和纯台词清洗有效。")
		return
	for diagnostic_value in diagnostics:
		if diagnostic_value is Dictionary:
			var diagnostic := diagnostic_value as Dictionary
			var item: TreeItem = %审核诊断.create_item(root)
			item.set_text(0, str(diagnostic.get("severity", "warning")).to_upper())
			item.set_text(1, str(diagnostic.get("message", "")))


func _show_input_error(message: String) -> void:
	%StatusLabel.text = message
	_show_diagnostics([{"severity": "error", "message": message}])


func _on_request_completed(job_id: String, raw_response: Dictionary, metadata: Dictionary) -> void:
	if job_id != active_job_id:
		return
	active_job_id = ""
	_set_request_running(false)
	%ResponseEdit.text = JSON.stringify(raw_response, "    ")
	build_preview()
	%请求元数据.text = JSON.stringify({"status": "completed", "job_id": job_id, "metadata": metadata}, "    ")
	%StatusLabel.text = "真实请求完成 · 已按生产规则清洗 · 未写入角色存档"
	%ResultTabs.current_tab = %ResultTabs.get_tab_idx_from_control(%清洗结果)


func _on_request_failed(job_id: String, error_message: String, metadata: Dictionary) -> void:
	if job_id != active_job_id:
		return
	active_job_id = ""
	_set_request_running(false)
	%请求元数据.text = JSON.stringify({"status": "failed", "job_id": job_id, "error": error_message, "metadata": metadata}, "    ")
	_show_input_error("真实请求失败：%s" % error_message)
	%ResultTabs.current_tab = %ResultTabs.get_tab_idx_from_control(%请求元数据)


func _set_request_running(running: bool) -> void:
	%RealRequestButton.disabled = running
	%CancelRequestButton.disabled = not running
	%PreviewButton.disabled = running


func _disconnect_requester() -> void:
	if generation_requester.completed.is_connected(_on_request_completed):
		generation_requester.completed.disconnect(_on_request_completed)
	if generation_requester.failed.is_connected(_on_request_failed):
		generation_requester.failed.disconnect(_on_request_failed)