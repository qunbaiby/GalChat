extends Node

const AccountAuthPanelScene = preload("res://scenes/ui/start/account_auth_panel.tscn")
const SettingsScene = preload("res://scenes/ui/settings/settings_scene.tscn")
const StartScene = preload("res://scenes/ui/start/start_scene.tscn")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var config = GameDataManager.config
	var original_mode: String = config.ai_service_mode
	var original_api_key: String = config.api_key

	await _test_version_click_threshold()
	await _test_settings_tabs(config)
	await _test_local_api_preflight(config)

	config.ai_service_mode = original_mode
	config.api_key = original_api_key
	if failures.is_empty():
		print("START_LOCAL_MODE_SMOKE_OK")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error("START_LOCAL_MODE_SMOKE: %s" % failure)
	get_tree().quit(1)


func _test_version_click_threshold() -> void:
	var panel := AccountAuthPanelScene.instantiate()
	get_tree().root.add_child(panel)
	await get_tree().process_frame
	var signal_state := {"count": 0}
	panel.local_mode_requested.connect(func() -> void: signal_state["count"] += 1)
	var version_button := panel.get_node("VersionButton") as Button
	for _click_index in 6:
		version_button.pressed.emit()
	_expect(signal_state.count == 0, "版本号在第 7 次点击前提前进入本地模式。")
	_expect(not version_button.disabled, "版本号在第 7 次点击前被禁用。")
	version_button.pressed.emit()
	_expect(signal_state.count == 1, "版本号第 7 次点击没有发出本地模式信号。")
	_expect(version_button.disabled, "版本号第 7 次点击后没有禁用重复触发。")
	panel.queue_free()
	await get_tree().process_frame


func _test_settings_tabs(config) -> void:
	config.ai_service_mode = ConfigResource.AI_SERVICE_OFFICIAL
	var official_settings := SettingsScene.instantiate()
	get_tree().root.add_child(official_settings)
	await get_tree().process_frame
	official_settings.show_panel()
	var official_tabs := official_settings.tab_container as TabContainer
	_expect(official_tabs.is_tab_hidden(0), "官方模式没有隐藏 AI 配置标签。")
	_expect(not official_settings.ai_tab_button.visible, "官方模式没有隐藏 AI 配置侧栏按钮。")
	_expect(official_tabs.current_tab == 1, "官方模式没有默认选中画面设置。")
	official_settings.queue_free()
	await get_tree().process_frame

	config.ai_service_mode = ConfigResource.AI_SERVICE_PERSONAL
	var local_settings := SettingsScene.instantiate()
	get_tree().root.add_child(local_settings)
	await get_tree().process_frame
	local_settings.show_panel()
	var local_tabs := local_settings.tab_container as TabContainer
	_expect(not local_tabs.is_tab_hidden(0), "本地模式没有显示 AI 配置标签。")
	_expect(local_settings.ai_tab_button.visible, "本地模式没有显示 AI 配置侧栏按钮。")
	_expect(local_tabs.current_tab == 0, "本地模式没有默认选中 AI 配置。")
	local_settings.queue_free()
	await get_tree().process_frame


func _test_local_api_preflight(config) -> void:
	var start_scene := StartScene.instantiate()
	get_tree().root.add_child(start_scene)
	await get_tree().process_frame

	config.ai_service_mode = ConfigResource.AI_SERVICE_PERSONAL
	config.api_key = ""
	_expect(not start_scene.call("_require_local_chat_api"), "本地模式缺少对话 API Key 时仍允许开始陪伴。")
	await get_tree().process_frame
	var missing_key_dialog: Node = get_tree().root.get_node_or_null("ConfirmDialog")
	_expect(missing_key_dialog != null, "本地模式缺少对话 API Key 时没有显示配置提示。")
	if missing_key_dialog:
		missing_key_dialog.queue_free()
	await get_tree().process_frame

	config.api_key = "   "
	_expect(not start_scene.call("_require_local_chat_api"), "本地模式空白对话 API Key 没有被拒绝。")
	await get_tree().process_frame
	var blank_key_dialog: Node = get_tree().root.get_node_or_null("ConfirmDialog")
	if blank_key_dialog:
		blank_key_dialog.queue_free()
	await get_tree().process_frame

	config.api_key = "test-local-key"
	_expect(start_scene.call("_require_local_chat_api"), "本地模式已配置对话 API Key 时仍被阻断。")
	config.ai_service_mode = ConfigResource.AI_SERVICE_OFFICIAL
	config.api_key = ""
	_expect(start_scene.call("_require_local_chat_api"), "官方模式错误地要求本地对话 API Key。")
	start_scene.queue_free()
	await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)