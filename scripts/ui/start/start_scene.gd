extends Control

const DEBUG_PANEL_SCENE = preload("res://scenes/ui/story/debug_panel.tscn")
const BUG_FEEDBACK_PANEL_SCENE = preload("res://scenes/ui/start/bug_feedback_panel.tscn")
const ConfirmDialogScene = preload("res://scenes/ui/common/confirm_dialog.tscn")
const GUIDE_STATE_KEY := "guide_state_v1"

@onready var start_button: Button = $ContentRoot/MenuGroup/MenuButtons/StartButton
@onready var desktop_pet_button: Button = $ContentRoot/MenuGroup/MenuButtons/DesktopPetButton
@onready var settings_button: Button = $ContentRoot/ActionGroup/TopRightBar/SettingsButton
@onready var bug_feedback_button: Button = $ContentRoot/ActionGroup/TopRightBar/BugFeedbackButton

var settings_panel_instance = null
var archive_select_panel_instance = null
var debug_panel_instance = null
var bug_feedback_panel_instance = null
var desktop_pet_instance: Window = null
var _pending_new_archive_slot_id: String = ""
var _pending_previous_archive_slot_id: String = ""

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
    
    # 动画：按钮点击弹性反馈
    start_button.pivot_offset = start_button.size / 2
    if desktop_pet_button:
        desktop_pet_button.pivot_offset = desktop_pet_button.size / 2
    settings_button.pivot_offset = settings_button.size / 2
    bug_feedback_button.pivot_offset = bug_feedback_button.size / 2

func _on_close_requested() -> void:
    _cleanup_pending_new_archive()
    get_tree().quit()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        _cleanup_pending_new_archive()
        get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_F12:
            _open_debug_panel()

func _on_start_pressed() -> void:
    _animate_button(start_button)
    _show_archive_select_panel()

func _show_archive_select_panel() -> void:
    if archive_select_panel_instance == null:
        var panel_scene = load("res://scenes/ui/save_load/save_load_panel.tscn")
        archive_select_panel_instance = panel_scene.instantiate()
        add_child(archive_select_panel_instance)
        archive_select_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        archive_select_panel_instance.archive_slot_selected.connect(_on_archive_slot_selected)
    archive_select_panel_instance.show_panel()

func _on_archive_slot_selected(slot_id: String, is_empty: bool) -> void:
    if is_empty:
        await _create_new_archive(slot_id)
        return
    if not GameDataManager.save_manager.load_archive(slot_id):
        return
    archive_select_panel_instance.hide_panel()
    await _enter_game_for_current_archive(false)

func _create_new_archive(slot_id: String) -> void:
    var previous_slot_id: String = GameDataManager.get_active_archive_id()
    if not GameDataManager.save_manager.prepare_empty_archive(slot_id):
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
    var saved_ok: bool = GameDataManager.save_manager.auto_save()
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
    var window = get_window()
    GameDataManager.set_meta("last_window_pos", window.position)
    if ensure_guide_prompt:
        await _ensure_guide_opt_in_choice()
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
