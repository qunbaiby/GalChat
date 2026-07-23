extends Control

const DEBUG_PANEL_SCENE = preload("res://scenes/ui/story/debug_panel.tscn")
const BUG_FEEDBACK_PANEL_SCENE = preload("res://scenes/ui/start/bug_feedback_panel.tscn")
const ACCOUNT_AUTH_PANEL_SCENE = preload("res://scenes/ui/start/account_auth_panel.tscn")
const ACCOUNT_CENTER_PANEL_SCENE = preload("res://scenes/ui/start/account_center_panel.tscn")
const ConfirmDialogScene = preload("res://scenes/ui/common/confirm_dialog.tscn")
const GUIDE_STATE_KEY := "guide_state_v1"

@onready var start_button: Button = $ContentRoot/MenuGroup/MenuButtons/StartButton
@onready var desktop_pet_button: Button = $ContentRoot/MenuGroup/MenuButtons/DesktopPetButton
@onready var login_button: Button = $ContentRoot/MenuGroup/MenuButtons/LoginButton
@onready var settings_button: Button = $ContentRoot/ActionGroup/TopRightBar/SettingsButton
@onready var bug_feedback_button: Button = $ContentRoot/ActionGroup/TopRightBar/BugFeedbackButton
@onready var account_button: Button = $ContentRoot/ActionGroup/TopRightBar/AccountButton
@onready var account_status_label: Label = $ContentRoot/MenuGroup/MenuButtons/LoginStatusLabel
@onready var menu_group: Control = $ContentRoot/MenuGroup
@onready var menu_buttons: VBoxContainer = $ContentRoot/MenuGroup/MenuButtons

var settings_panel_instance = null
var archive_select_panel_instance = null
var debug_panel_instance = null
var bug_feedback_panel_instance = null
var desktop_pet_instance: Window = null
var account_auth_panel_instance: Control = null
var account_center_panel_instance: Control = null
var _pending_authenticated_action: Callable
var _pending_new_archive_slot_id: String = ""
var _pending_previous_archive_slot_id: String = ""
var _opening_archive_panel: bool = false

func _ready() -> void:
	if GameDataManager.config:
		GameDataManager.config.apply_settings()

	if start_button == null or settings_button == null or bug_feedback_button == null:
		push_error("StartScene 按钮节点缺失，无法初始化开始界面交互。")
		return
		
	# 开始界面需要占据全屏，取消鼠标穿透（恢复系统默认的全屏接受鼠标输入，同时确保画面渲染）
	DisplayServer.window_set_mouse_passthrough(PackedVector2Array(), get_tree().root.get_window_id())
		
	var window = get_window()
	if GameDataManager.has_meta("last_window_pos"):
		var last_pos = GameDataManager.get_meta("last_window_pos")
		if typeof(last_pos) == TYPE_VECTOR2I or typeof(last_pos) == TYPE_VECTOR2:
			window.position = last_pos
		else:
			window.move_to_center()
	else:
		window.move_to_center()
			
	window.close_requested.connect(_on_close_requested)
	start_button.pressed.connect(_on_start_pressed)
	if desktop_pet_button:
		desktop_pet_button.pressed.connect(_on_desktop_pet_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	bug_feedback_button.pressed.connect(_on_bug_feedback_pressed)
	account_button.pressed.connect(_on_account_pressed)
	login_button.pressed.connect(_on_account_pressed)
	OfficialAuthManager.auth_state_changed.connect(_on_auth_state_changed)
	OfficialAuthManager.session_state_changed.connect(_on_session_state_changed)
	OfficialAuthManager.profile_updated.connect(_on_profile_updated)
	_update_session_state(OfficialAuthManager.get_session_state())
	# 动画：按钮点击弹性反馈
	start_button.pivot_offset = start_button.size / 2
	if desktop_pet_button:
		desktop_pet_button.pivot_offset = desktop_pet_button.size / 2
	settings_button.pivot_offset = settings_button.size / 2
	bug_feedback_button.pivot_offset = bug_feedback_button.size / 2
	account_button.pivot_offset = account_button.size / 2
	login_button.pivot_offset = login_button.size / 2

func _on_close_requested() -> void:
	_cleanup_pending_new_archive()
	if GameDataManager.save_manager:
		GameDataManager.save_manager.save_before_exit()
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_cleanup_pending_new_archive()
		if GameDataManager.save_manager:
			GameDataManager.save_manager.save_before_exit()
		get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F12:
			_open_debug_panel()

func _on_start_pressed() -> void:
	if not _require_authentication(_on_start_pressed):
		return
	if not _require_local_chat_api():
		return
	if _opening_archive_panel:
		return
	_opening_archive_panel = true
	start_button.disabled = true
	_animate_button(start_button)
	await get_tree().process_frame
	_show_archive_select_panel()
	start_button.disabled = false
	_opening_archive_panel = false

func _show_archive_select_panel() -> void:
	if GameDataManager.save_manager == null:
		push_error("StartScene 无法打开存档界面：SaveManager 未初始化。")
		return
	if archive_select_panel_instance == null:
		var panel_scene = load("res://scenes/ui/save_load/save_load_panel.tscn")
		if panel_scene == null:
			push_error("StartScene 无法加载存档界面场景。")
			return
		archive_select_panel_instance = panel_scene.instantiate()
		add_child(archive_select_panel_instance)
		archive_select_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		archive_select_panel_instance.archive_slot_selected.connect(_on_archive_slot_selected)
		if archive_select_panel_instance.has_signal("new_archive_requested"):
			archive_select_panel_instance.new_archive_requested.connect(_on_new_archive_requested)
	archive_select_panel_instance.show_panel()

func _on_archive_slot_selected(slot_id: String, is_empty: bool) -> void:
	if is_empty:
		await _create_new_archive(slot_id, "新的记忆")
		return
	if not GameDataManager.save_manager.load_archive(slot_id):
		return
	archive_select_panel_instance.hide_panel()
	await _enter_game_for_current_archive(false)

func _on_new_archive_requested() -> void:
	var popup_scene = load("res://scenes/ui/save_load/archive_name_popup.tscn")
	if popup_scene == null:
		return
	var popup = popup_scene.instantiate()
	add_child(popup)
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.name_submitted.connect(func(archive_name: String) -> void:
		var final_name := archive_name.strip_edges()
		if is_instance_valid(popup):
			popup.queue_free()
		if final_name == "":
			return
		await _create_new_archive(GameDataManager.save_manager.generate_archive_id(), final_name)
	)

func _create_new_archive(slot_id: String, archive_name: String = "") -> void:
	var previous_slot_id: String = GameDataManager.get_active_archive_id()
	if not GameDataManager.save_manager.prepare_empty_archive(slot_id, archive_name):
		return
	_pending_new_archive_slot_id = slot_id
	_pending_previous_archive_slot_id = previous_slot_id
	var popup_scene = load("res://scenes/ui/story/player_info_popup.tscn")
	if popup_scene == null:
		_cleanup_pending_new_archive()
		return
	var popup = popup_scene.instantiate()
	add_child(popup)
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await popup.info_submitted
	if not is_instance_valid(popup):
		_cleanup_pending_new_archive()
		return
	_apply_player_info_from_popup(popup.player_info)
	popup.queue_free()
	await _ensure_guide_opt_in_choice(true)
	var saved_ok: bool = GameDataManager.save_manager.auto_save("archive_initialized", GameDataManager.get_active_archive_id())
	if not saved_ok:
		push_error("StartScene 新建档案后自动存档失败。")
		_cleanup_pending_new_archive()
		return
	_clear_pending_new_archive_state()
	if archive_select_panel_instance:
		archive_select_panel_instance.hide_panel()
	await _enter_game_for_current_archive(true, false)

func _cleanup_pending_new_archive() -> void:
	if _pending_new_archive_slot_id == "":
		return
	var pending_slot_id: String = _pending_new_archive_slot_id
	var previous_slot_id: String = _pending_previous_archive_slot_id
	_clear_pending_new_archive_state()
	if GameDataManager.save_manager:
		GameDataManager.save_manager.delete_save(pending_slot_id)
	if previous_slot_id != "" and GameDataManager.save_manager:
		GameDataManager.save_manager.load_archive(previous_slot_id)
	elif GameDataManager.config:
		GameDataManager.set_active_archive_id("", true)

func _clear_pending_new_archive_state() -> void:
	_pending_new_archive_slot_id = ""
	_pending_previous_archive_slot_id = ""

func _apply_player_info_from_popup(player_info: Dictionary) -> void:
	if GameDataManager.profile == null:
		return
	if player_info.has("name"):
		GameDataManager.profile.player_name = player_info["name"]
	if player_info.has("gender"):
		GameDataManager.profile.player_gender = player_info["gender"]
	if player_info.has("birthday"):
		GameDataManager.profile.player_birthday = player_info["birthday"]
	if player_info.has("zodiac"):
		GameDataManager.profile.player_zodiac = player_info["zodiac"]
	if player_info.has("mbti"):
		GameDataManager.profile.player_mbti = player_info["mbti"]
	if player_info.has("profession"):
		GameDataManager.profile.player_profession = player_info["profession"]
	if player_info.has("avatar_path"):
		GameDataManager.profile.player_avatar_path = player_info["avatar_path"]
	GameDataManager.sync_profile_to_config()
	if GameDataManager.config:
		GameDataManager.config.save_config()
	GameDataManager.profile.save_profile()

func _enter_game_for_current_archive(force_play_intro: bool, ensure_guide_prompt: bool = true) -> void:
	if _uses_official_ai() and not OfficialAuthManager.is_authenticated():
		_pending_authenticated_action = func() -> void: await _enter_game_for_current_archive(force_play_intro, ensure_guide_prompt)
		_open_account_panel()
		return
	if not _require_local_chat_api():
		return
	var window = get_window()
	GameDataManager.set_meta("last_window_pos", window.position)
	if ensure_guide_prompt:
		await _ensure_guide_opt_in_choice()
	if force_play_intro:
		GameDataManager.save_active_story_checkpoint({})
	var story_checkpoint := GameDataManager.load_active_story_checkpoint()
	var checkpoint_script_path := str(story_checkpoint.get("script_path", "")).strip_edges()
	var checkpoint_script_data: Variant = story_checkpoint.get("script_data", {})
	var has_file_checkpoint: bool = not checkpoint_script_path.is_empty() and FileAccess.file_exists(checkpoint_script_path)
	var has_runtime_checkpoint: bool = checkpoint_script_data is Dictionary and not checkpoint_script_data.is_empty()
	if not story_checkpoint.is_empty() and not has_file_checkpoint and not has_runtime_checkpoint:
		GameDataManager.save_active_story_checkpoint({})
	var need_play_intro := force_play_intro
	if not need_play_intro and GameDataManager.profile and not GameDataManager.profile.has_finished_story("intro_story"):
		need_play_intro = true

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var tween = create_tween()
	tween.tween_property(overlay, "color:a", 1.0, 1.0)
	await tween.finished

	if not force_play_intro and has_file_checkpoint:
		GameDataManager.set_meta("play_specific_story", checkpoint_script_path)
		_transition_to_scene("res://scenes/ui/story/story_scene.tscn")
		return
	if not force_play_intro and has_runtime_checkpoint:
		GameDataManager.set_meta("play_runtime_story_data", checkpoint_script_data)
		_transition_to_scene("res://scenes/ui/story/story_scene.tscn")
		return
	if need_play_intro:
		if GameDataManager.history:
			GameDataManager.history.clear_history()
		GameDataManager.set_meta("play_intro_story", true)
		_transition_to_scene("res://scenes/ui/story/story_scene.tscn")
		return
	_transition_to_scene("res://scenes/ui/main/main_scene.tscn")

func _ensure_guide_opt_in_choice(force_prompt_when_unknown: bool = false) -> void:
	var guide_manager = get_node_or_null("/root/GuideManager")
	if guide_manager == null:
		return
	if guide_manager.has_method("reload_for_current_archive"):
		guide_manager.reload_for_current_archive()
	var raw_guide_state = GameDataManager.get_archive_custom_config(GUIDE_STATE_KEY, null)
	var should_force_prompt := force_prompt_when_unknown and raw_guide_state == null
	var should_prompt := should_force_prompt
	if not should_prompt:
		if not guide_manager.has_method("should_prompt_for_guide_opt_in") or not bool(guide_manager.should_prompt_for_guide_opt_in()):
			return
		should_prompt = true
	if not should_prompt:
		return
	if ConfirmDialogScene == null:
		return
	var dialog = ConfirmDialogScene.instantiate()
	get_tree().root.add_child(dialog)
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if dialog.has_method("setup_advanced"):
		dialog.setup_advanced(
			"开启新手引导",
			"是否为这个存档开启新手引导？\n开启后会在开场剧情结束后，继续引导你完成行程安排与课程执行的基础教学。",
			"",
			"选择只会影响当前存档，之后也可以再手动开启其他演示引导。",
			"开启引导",
			"暂不需要"
		)
	var guide_opt_in_choice := {
		"decided": false,
		"enabled": false
	}
	if dialog.has_signal("confirmed"):
		dialog.confirmed.connect(func() -> void:
			guide_opt_in_choice["enabled"] = true
			guide_opt_in_choice["decided"] = true
		)
	if dialog.has_signal("canceled"):
		dialog.canceled.connect(func() -> void:
			guide_opt_in_choice["enabled"] = false
			guide_opt_in_choice["decided"] = true
		)
	while not bool(guide_opt_in_choice.get("decided", false)) and is_instance_valid(dialog):
		await get_tree().process_frame
	var enabled := bool(guide_opt_in_choice.get("enabled", false))
	if guide_manager.has_method("set_guide_opt_in"):
		guide_manager.set_guide_opt_in(enabled)

func _transition_to_scene(scene_path: String) -> void:
	if get_tree().root.has_node("SceneTransitionManager"):
		get_tree().root.get_node("SceneTransitionManager").transition_to_scene(scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)

func _on_desktop_pet_pressed() -> void:
	if not _require_authentication(_on_desktop_pet_pressed):
		return
	_animate_button(desktop_pet_button)
	
	# 初始化 GameDataManager 的必要组件（如果没有的话）
	if GameDataManager.profile == null:
		GameDataManager.profile = CharacterProfile.new()
		GameDataManager.profile.load_profile()
		
	if desktop_pet_instance == null:
		var DesktopPetObj = load("res://scenes/ui/desktop_pet/desktop_pet.tscn")
		desktop_pet_instance = DesktopPetObj.instantiate()
		desktop_pet_instance.is_standalone_mode = true
		get_tree().root.add_child(desktop_pet_instance)
		
		# 监听桌宠的关闭事件，清理引用
		desktop_pet_instance.tree_exited.connect(func():
			desktop_pet_instance = null
		)

func _on_settings_pressed() -> void:
	_animate_button(settings_button)
	if settings_panel_instance == null:
		var SettingsPanelObj = load("res://scenes/ui/settings/settings_scene.tscn")
		settings_panel_instance = SettingsPanelObj.instantiate()
		add_child(settings_panel_instance)
		settings_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_panel_instance.show_panel()


func _on_bug_feedback_pressed() -> void:
	_animate_button(bug_feedback_button)
	if bug_feedback_panel_instance == null:
		if BUG_FEEDBACK_PANEL_SCENE == null:
			push_error("[StartScene] 无法加载 BUG 反馈面板场景。")
			return
		bug_feedback_panel_instance = BUG_FEEDBACK_PANEL_SCENE.instantiate()
		add_child(bug_feedback_panel_instance)
		bug_feedback_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bug_feedback_panel_instance.show_panel()

func _on_account_pressed() -> void:
	if OfficialAuthManager.is_authenticated():
		_open_account_center()
		return
	_open_account_panel()

func _on_logout_pressed() -> void:
	_pending_authenticated_action = Callable()
	OfficialAuthManager.logout()

func _on_logout_all_pressed() -> void:
	_pending_authenticated_action = Callable()
	OfficialAuthManager.logout_all()

func _open_account_center() -> void:
	if is_instance_valid(account_center_panel_instance):
		return
	account_center_panel_instance = ACCOUNT_CENTER_PANEL_SCENE.instantiate()
	add_child(account_center_panel_instance)
	account_center_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	account_center_panel_instance.closed.connect(func() -> void: account_center_panel_instance = null)
	account_center_panel_instance.logged_out.connect(func() -> void: _pending_authenticated_action = Callable())

func _open_account_panel(register_mode: bool = false) -> void:
	if is_instance_valid(account_auth_panel_instance):
		return
	account_auth_panel_instance = ACCOUNT_AUTH_PANEL_SCENE.instantiate()
	add_child(account_auth_panel_instance)
	account_auth_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	account_auth_panel_instance.authenticated.connect(_on_account_authenticated)
	account_auth_panel_instance.local_mode_requested.connect(_on_local_mode_requested)
	account_auth_panel_instance.closed.connect(func() -> void: account_auth_panel_instance = null)
	if register_mode:
		account_auth_panel_instance.call_deferred("show_register")

func _require_authentication(action: Callable) -> bool:
	if not _uses_official_ai() or OfficialAuthManager.is_authenticated():
		return true
	_pending_authenticated_action = action
	_open_account_panel()
	return false

func _on_local_mode_requested() -> void:
	if GameDataManager.config == null:
		return
	GameDataManager.config.ai_service_mode = GameDataManager.config.AI_SERVICE_PERSONAL
	GameDataManager.config.save_config()
	_pending_authenticated_action = Callable()
	if is_instance_valid(account_auth_panel_instance):
		account_auth_panel_instance.queue_free()
		account_auth_panel_instance = null
	_update_account_status(OfficialAuthManager.is_authenticated())

func _uses_official_ai() -> bool:
	return GameDataManager.config == null or GameDataManager.config.ai_service_mode == GameDataManager.config.AI_SERVICE_OFFICIAL

func _require_local_chat_api() -> bool:
	if _uses_official_ai() or (GameDataManager.config and not GameDataManager.config.api_key.strip_edges().is_empty()):
		return true
	var dialog = ConfirmDialogScene.instantiate()
	get_tree().root.add_child(dialog)
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.setup_advanced(
		"需要配置对话模型",
		"本地模式需要先配置对话模型 API Key，才能开始陪伴。其他语音、视觉和图像能力均为可选配置。",
		"",
		"配置保存在本机。",
		"前往设置",
		"取消"
	)
	dialog.confirmed.connect(_on_settings_pressed)
	return false

func _on_account_authenticated() -> void:
	_update_account_status(true)
	if _pending_authenticated_action.is_valid():
		var action := _pending_authenticated_action
		_pending_authenticated_action = Callable()
		action.call_deferred()

func _on_auth_state_changed(authenticated_state: bool, _message: String) -> void:
	if not authenticated_state and GameDataManager.save_manager:
		GameDataManager.save_manager.current_slot_id = ""
	_update_account_status(authenticated_state)

func _update_account_status(authenticated_state: bool) -> void:
	var local_mode := not _uses_official_ai()
	var can_enter := local_mode or authenticated_state
	menu_group.visible = true
	menu_buttons.position.y = 473.0
	start_button.visible = can_enter
	desktop_pet_button.visible = can_enter
	login_button.visible = not can_enter
	account_button.visible = authenticated_state and not local_mode
	settings_button.visible = can_enter
	bug_feedback_button.visible = can_enter
	account_status_label.text = "本地模式" if local_mode else ("云端身份已连接" if authenticated_state else "登录后开始陪伴")

func _on_session_state_changed(state: int, _message: String) -> void:
	_update_session_state(state)

func _update_session_state(state: int) -> void:
	var restoring := state == OfficialAuthManager.SessionState.RESTORING
	var local_mode := not _uses_official_ai()
	var signed_in := state == OfficialAuthManager.SessionState.SIGNED_IN
	var can_enter := local_mode or signed_in
	menu_group.visible = true
	menu_buttons.position.y = 473.0
	start_button.visible = can_enter
	desktop_pet_button.visible = can_enter
	login_button.visible = not can_enter and state == OfficialAuthManager.SessionState.SIGNED_OUT
	account_button.visible = signed_in and not local_mode
	settings_button.visible = can_enter
	bug_feedback_button.visible = can_enter
	account_status_label.text = "本地模式" if local_mode else ("正在验证账号..." if restoring else ("云端身份已连接" if signed_in else "登录后开始陪伴"))

func _on_profile_updated(profile: Dictionary) -> void:
	var username := str(profile.get("username", "")).strip_edges()
	if not username.is_empty():
		account_button.tooltip_text = "用户中心：%s" % username

func _open_debug_panel() -> void:
	if debug_panel_instance == null:
		if DEBUG_PANEL_SCENE == null:
			push_error("[StartScene] 无法加载调试面板场景：res://scenes/ui/story/debug_panel.tscn")
			return
		debug_panel_instance = DEBUG_PANEL_SCENE.instantiate()
		add_child(debug_panel_instance)
		debug_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		debug_panel_instance.is_from_title = true
	
	if debug_panel_instance.visible:
		debug_panel_instance.hide()
	else:
		debug_panel_instance.show_panel()

func _animate_button(btn: Button) -> void:
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(0.9, 0.9), 0.05)
	tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.05)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.05)
