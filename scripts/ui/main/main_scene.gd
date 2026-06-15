extends Control

const PhotoMemoryManagerScript = preload("res://scripts/data/photo_memory_manager.gd")
const DEBUG_PANEL_SCENE = preload("res://scenes/ui/story/debug_panel.tscn")
const AffectionPanelScene = preload("res://scenes/ui/mobile/affection_panel.tscn")
const BackgroundSettingPanelScene = preload("res://scenes/ui/main/background_setting_panel.tscn")
const EVENT_REGISTRY_PATH := "res://assets/data/events/event_registry.json"
const MAP_DATA_PATH := "res://assets/data/map/core/map_data.json"
const MAIN_BACKGROUND_DATA_PATH := "res://assets/data/main_backgrounds.json"
const MAIN_SCENE_IDLE_CHAT_MIN_SECONDS := 55.0
const MAIN_SCENE_IDLE_CHAT_MAX_SECONDS := 95.0
const MAIN_SCENE_IDLE_CHAT_RETRY_SECONDS := 12.0

@onready var ui_panel: Panel = $UIPanel
@onready var rest_button: Button = $UIPanel/BottomBarHBox/ActionHBox/RestButton
@onready var skill_button: Button = $UIPanel/BottomBarHBox/BtnHBox/SkillButton
@onready var hide_ui_button: Button = $UIPanel/SystemButton/ToolBarMargin/HBox/HideUIButton
@onready var camera_button: Button = $UIPanel/SystemButton/ToolBarMargin/HBox/CameraButton
@onready var phone_button: Button = $UIPanel/SystemButton/ToolBarMargin/HBox/PhoneButton
@onready var affection_button: Button = $UIPanel/AffectionButton
@onready var affection_stage_level_label: Label = $UIPanel/AffectionButton/ContentHBox/HeartWrap/HeartLevelLabel
@onready var affection_stage_title_label: Label = $UIPanel/AffectionButton/ContentHBox/StageVBox/StageTitleLabel
@onready var goal_value_label: Label = $UIPanel/GoalPanel/GoalMargin/GoalVBox/GoalValue
@onready var mood_panel: Control = $UIPanel/MoodPanel
@onready var mood_name_container: Control = $UIPanel/MoodNamelContainer
@onready var mood_title_label: Label = $UIPanel/MoodPanel/MoodMargin/MoodVBox/MoodTopHBox/MoodTitle
@onready var mood_panel_value_label: Label = $UIPanel/MoodPanel/MoodMargin/MoodVBox/MoodBarTrack/MoodBar/MoodValueLabel
@onready var mood_panel_hint_label: Label = $UIPanel/MoodPanel/MoodMargin/MoodVBox/MoodHintLabel
@onready var mood_bar: ProgressBar = $UIPanel/MoodPanel/MoodMargin/MoodVBox/MoodBarTrack/MoodBar
@onready var mood_name_container_emoji_label: Label = $UIPanel/MoodNamelContainer/MoodNamelMargin/MoodHeadHBox/MoodEmojiLabel
@onready var mood_name_container_name_label: Label = $UIPanel/MoodNamelContainer/MoodNamelMargin/MoodHeadHBox/MoodNameLabel
@onready var affection_overlay: Control = $UIPanel/AffectionOverlay
@onready var affection_dismiss_button: Button = $UIPanel/AffectionOverlay/DismissButton
@onready var affection_popup_frame: Control = $UIPanel/AffectionOverlay/PopupCenter/AffectionPopupFrame
@onready var wardrobe_button: Button = $UIPanel/BottomBarHBox/BtnHBox/WardrobeButton
@onready var bg_switch_button: Button = $BgSwitchButton
@onready var bg_transition_fade: ColorRect = $BgTransitionFade

@onready var diary_button: Button = $UIPanel/BottomBarHBox/BtnHBox/DiaryButton
@onready var wechat_button: Button = $UIPanel/BottomBarHBox/BtnHBox/WeChatButton
@onready var wechat_unread_badge: Label = $UIPanel/BottomBarHBox/BtnHBox/WeChatButton/UnreadBadge
@onready var main_action_button: Button = $UIPanel/BottomBarHBox/ActionHBox/MainActionButton

var _photo_manager = PhotoMemoryManagerScript.new()
@onready var stats_panel = $UIPanel/StatsPanelAnchor/StatsPanel
@onready var top_status_panel = $UIPanel/TopStatusPanel
@onready var bgm: AudioStreamPlayer = $BGM
@onready var music_player: Control = $UIPanel/BottomBarHBox/MusicPlayer
@onready var diary_panel: Control = $UIPanel/DiaryPanel
@onready var diary_notification: PanelContainer = $UIPanel/DiaryNotification
@onready var wardrobe_panel: Control = $WardrobePanel
@onready var dialogue_panel: Control = $DialoguePanel
@onready var dialogue_name_label: Label = $DialoguePanel/DialogueLayer/VBox/NameLabel
@onready var dialogue_text: RichTextLabel = $DialoguePanel/DialogueLayer/VBox/RichTextLabel
@onready var quick_option_layer: Control = $DialoguePanel/QuickOptionLayer
@onready var input_layer: Panel = $DialoguePanel/InputLayer
@onready var input_field: TextEdit = $DialoguePanel/InputLayer/HBoxContainer/InputField
@onready var send_btn: Button = $DialoguePanel/InputLayer/HBoxContainer/SendButton
@onready var dialogue_toolbar_container: Control = $DialoguePanel/ToolBarContainer
@onready var end_chat_btn: Button = $DialoguePanel/ToolBarContainer/ToolBarMargin/HBox/EndChatButton
@onready var history_btn: Button = $DialoguePanel/ToolBarContainer/ToolBarMargin/HBox/HistoryButton
@onready var quick_options_container = $DialoguePanel/QuickOptionLayer/ScrollContainer/QuickOptions

@onready var deepseek_client = $DeepSeekClient

@onready var interact_group: VBoxContainer = $UIPanel/InteractGroup
@onready var chat_button: Button = $UIPanel/InteractGroup/ChatButton
@onready var gift_button: Button = $UIPanel/InteractGroup/GiftButton
@onready var date_button: Button = $UIPanel/InteractGroup/DateButton
@onready var interactive_button: Button = $UIPanel/InteractGroup/InteractiveButton
@onready var interactive_sub_menu: Control = $UIPanel/InteractiveSubMenu
@onready var co_create_button: Button = $UIPanel/InteractiveSubMenu/Margin/VBox/CoCreateButton

var activity_panel_instance = null
var drawing_board_instance = null

var _chat_tween: Tween = null
var _typewriter_tween: Tween = null
var stream_live_buffer: String = ""
var stream_live_active: bool = false

var _accumulated_stats: Dictionary = {
	"intimacy": 0.0,
	"trust": 0.0,
	"openness": 0.0,
	"conscientiousness": 0.0,
	"extraversion": 0.0,
	"agreeableness": 0.0,
	"neuroticism": 0.0
}

var settings_panel_instance = null
var desktop_pet_instance: Window = null
var chat_scene_instance = null
var archive_panel_instance = null
var mobile_interface_instance = null
var incoming_call_notification_instance = null
var history_panel_instance = null
var schedule_panel_instance = null

var _story_mode_active: bool = false
var _main_action_mode: String = "schedule"
var _interaction_ui_locked_by_dialogue: bool = false

var _window_detector: Node = null
var _is_afk: bool = false
var _afk_timer: Timer = null
var _ui_tween: Tween = null
var _mood_hover_tween: Tween = null
var audio_player: AudioStreamPlayer = null
var _proactive_bubble_request_in_flight: bool = false
var _main_scene_idle_chat_elapsed: float = 0.0
var _main_scene_idle_chat_interval: float = MAIN_SCENE_IDLE_CHAT_MIN_SECONDS

var map_scene_instance = null

const TOPIC_LIST = [
	"最近在忙些什么呢？",
	"今天天气真不错，对吧？",
	"有什么心事想和我聊聊吗？",
	"推荐一本你喜欢的书或电影吧。",
	"聊聊你的兴趣爱好吧！",
	"最近有遇到什么有趣的事吗？",
	"周末通常是怎么过的呢？"
]

var stream_live_queue: Array = []
var stream_live_worker_running: bool = false
var stream_live_done: bool = false

var is_proactive_greeting: bool = false
var proactive_greeting_step: int = 0
var is_memory_revisit_active: bool = false
var _generated_image_panel: Panel = null

var _waiting_for_chat_click: bool = false
signal _chat_click_proceed

var pending_options_data = []
var _rendered_quick_options: Array = []
var is_text_playback_finished = true
var _awaiting_topic_selection: bool = false
var _topic_greeting_playing: bool = false
var _pending_topic_options: Array = []
const DAILY_HISTORY_MODULE := "daily"
const MAIN_CHAT_SUBTYPE_DAILY := "daily_chat"
const MAIN_CHAT_SUBTYPE_TOPIC := "daily_topic_chat"
const MAIN_CHAT_SUBTYPE_CONCERN := "daily_concern_chat"
const MAIN_CHAT_SUBTYPE_MEMORY := "daily_memory_revisit"
const MAIN_CHAT_SUBTYPE_PROACTIVE := "daily_proactive"
var _current_main_chat_subtype: String = MAIN_CHAT_SUBTYPE_DAILY
var _current_main_chat_topic: String = ""

func _set_main_chat_context(subtype: String, topic: String = "") -> void:
	_current_main_chat_subtype = subtype
	_current_main_chat_topic = topic

func _reset_main_chat_context() -> void:
	_set_main_chat_context(MAIN_CHAT_SUBTYPE_DAILY)

func _resolve_topic_chat_subtype(topic: String) -> String:
	var normalized = topic.strip_edges()
	var concern_keywords = ["心事", "烦恼", "难过", "委屈", "伤心", "不开心"]
	for keyword in concern_keywords:
		if normalized.find(keyword) != -1:
			return MAIN_CHAT_SUBTYPE_CONCERN
	return MAIN_CHAT_SUBTYPE_TOPIC

func _build_main_chat_meta(extra_data: Dictionary = {}) -> Dictionary:
	var meta = {
		"module": DAILY_HISTORY_MODULE,
		"subtype": _current_main_chat_subtype
	}
	if _current_main_chat_topic != "":
		meta["topic"] = _current_main_chat_topic
	if not extra_data.is_empty():
		meta.merge(extra_data, true)
	return meta

func _update_affection_button_ui() -> void:
	if not is_instance_valid(affection_button) or not GameDataManager.profile:
		return
	var stage_conf: Dictionary = GameDataManager.profile.get_current_stage_config()
	if is_instance_valid(affection_stage_level_label):
		affection_stage_level_label.text = str(GameDataManager.profile.current_stage)
	if is_instance_valid(affection_stage_title_label):
		affection_stage_title_label.text = str(stage_conf.get("stageTitle", "未命名阶段"))
	_update_goal_panel_ui()
	_update_mood_panel_ui()
	if is_instance_valid(affection_panel_instance) and affection_panel_instance.visible and affection_panel_instance.has_method("update_ui"):
		affection_panel_instance.update_ui(GameDataManager.profile)

func _bind_profile_signals() -> void:
	if not GameDataManager.profile:
		return
	if not GameDataManager.profile.profile_updated.is_connected(_on_profile_updated):
		GameDataManager.profile.profile_updated.connect(_on_profile_updated)

func _on_profile_updated() -> void:
	_update_affection_button_ui()
	if stats_panel and stats_panel.has_method("_update_ui"):
		stats_panel._update_ui()
	if top_status_panel and top_status_panel.has_method("_update_ui"):
		top_status_panel._update_ui()

func _update_mood_panel_ui() -> void:
	if not is_instance_valid(mood_name_container_name_label) or not is_instance_valid(mood_panel_value_label):
		return

	if not GameDataManager.profile or not GameDataManager.mood_system:
		mood_name_container_emoji_label.text = ""
		mood_name_container_name_label.text = "未知"
		mood_panel_value_label.text = "-- / 100"
		mood_panel_hint_label.text = "当前暂无心情数据"
		if is_instance_valid(mood_bar):
			mood_bar.value = 0.0
		return

	var mood_value := int(round(GameDataManager.profile.mood_value))
	var mood_info: Dictionary = GameDataManager.mood_system.get_macro_mood(mood_value)
	var mood_id := str(mood_info.get("id", "calm"))
	var mood_name := str(mood_info.get("name", "平静"))
	var mood_emoji := str(mood_info.get("emoji", ""))
	var palette := _get_mood_panel_palette(mood_id)

	mood_name_container_emoji_label.text = mood_emoji
	mood_name_container_name_label.text = mood_name
	mood_panel_value_label.text = "%d / 100" % mood_value
	mood_panel_hint_label.text = _build_mood_panel_hint(mood_id)
	if is_instance_valid(mood_bar):
		mood_bar.value = mood_value
		var fill_style = mood_bar.get("theme_override_styles/fill") as StyleBoxFlat
		if fill_style:
			fill_style.bg_color = palette.get("bar_color", Color(0.55, 0.79, 0.76, 1.0))

	if is_instance_valid(mood_title_label):
		mood_title_label.add_theme_color_override("font_color", palette.get("accent_color", Color(0.13, 0.76, 0.70, 1.0)))
	mood_name_container_name_label.add_theme_color_override("font_color", palette.get("name_color", Color(1, 1, 1, 1)))
	mood_panel_value_label.add_theme_color_override("font_color", palette.get("value_color", Color(0.85, 0.94, 0.92, 1.0)))
	mood_panel_hint_label.add_theme_color_override("font_color", palette.get("hint_color", Color(0.92, 0.92, 0.92, 1.0)))

func _build_mood_panel_hint(mood_id: String) -> String:
	match mood_id:
		"broken":
			return "当前更需要被接住、恢复状态，先别硬推节奏。"
		"low":
			return "当前偏向回稳与安抚，适合慢慢找回状态。"
		"pleasant":
			return "当前适合主动尝试，也更容易自然拉近关系。"
		"ecstatic":
			return "当前适合表现、突破和推进关系，但别用力过猛。"
		_:
			return "当前节奏平稳，适合常规推进和日常互动。"

func _get_mood_panel_palette(mood_id: String) -> Dictionary:
	match mood_id:
		"broken":
			return {
				"accent_color": Color(0.93, 0.47, 0.60, 1.0),
				"name_color": Color(1.0, 0.86, 0.90, 1.0),
				"value_color": Color(1.0, 0.78, 0.84, 1.0),
				"hint_color": Color(0.98, 0.84, 0.88, 1.0),
				"bar_color": Color(0.92, 0.36, 0.56, 1.0)
			}
		"low":
			return {
				"accent_color": Color(0.97, 0.67, 0.42, 1.0),
				"name_color": Color(1.0, 0.90, 0.80, 1.0),
				"value_color": Color(1.0, 0.84, 0.70, 1.0),
				"hint_color": Color(0.98, 0.88, 0.78, 1.0),
				"bar_color": Color(0.95, 0.60, 0.30, 1.0)
			}
		"pleasant":
			return {
				"accent_color": Color(0.37, 0.84, 0.64, 1.0),
				"name_color": Color(0.90, 1.0, 0.94, 1.0),
				"value_color": Color(0.82, 0.98, 0.88, 1.0),
				"hint_color": Color(0.86, 0.97, 0.90, 1.0),
				"bar_color": Color(0.31, 0.82, 0.58, 1.0)
			}
		"ecstatic":
			return {
				"accent_color": Color(0.42, 0.74, 1.0, 1.0),
				"name_color": Color(0.87, 0.94, 1.0, 1.0),
				"value_color": Color(0.78, 0.89, 1.0, 1.0),
				"hint_color": Color(0.84, 0.92, 1.0, 1.0),
				"bar_color": Color(0.29, 0.63, 1.0, 1.0)
			}
		_:
			return {
				"accent_color": Color(0.68, 0.84, 0.94, 1.0),
				"name_color": Color(0.96, 0.98, 1.0, 1.0),
				"value_color": Color(0.84, 0.92, 0.97, 1.0),
				"hint_color": Color(0.88, 0.93, 0.96, 1.0),
				"bar_color": Color(0.58, 0.76, 0.86, 1.0)
			}

func _setup_mood_hover_ui() -> void:
	if is_instance_valid(mood_panel):
		mood_panel.visible = false
		mood_panel.modulate.a = 0.0
		if not mood_panel.mouse_entered.is_connected(_on_mood_ui_mouse_entered):
			mood_panel.mouse_entered.connect(_on_mood_ui_mouse_entered)
		if not mood_panel.mouse_exited.is_connected(_on_mood_ui_mouse_exited):
			mood_panel.mouse_exited.connect(_on_mood_ui_mouse_exited)
	if is_instance_valid(mood_name_container):
		mood_name_container.self_modulate.a = 1.0
		if not mood_name_container.mouse_entered.is_connected(_on_mood_ui_mouse_entered):
			mood_name_container.mouse_entered.connect(_on_mood_ui_mouse_entered)
		if not mood_name_container.mouse_exited.is_connected(_on_mood_ui_mouse_exited):
			mood_name_container.mouse_exited.connect(_on_mood_ui_mouse_exited)

func _on_mood_ui_mouse_entered() -> void:
	_show_mood_panel()

func _on_mood_ui_mouse_exited() -> void:
	call_deferred("_sync_mood_hover_state")

func _sync_mood_hover_state() -> void:
	if _is_mouse_over_mood_ui():
		_show_mood_panel()
	else:
		_hide_mood_panel()

func _is_mouse_over_mood_ui() -> bool:
	var mouse_pos := get_viewport().get_mouse_position()
	if is_instance_valid(mood_name_container) and mood_name_container.get_global_rect().has_point(mouse_pos):
		return true
	if is_instance_valid(mood_panel) and mood_panel.visible and mood_panel.get_global_rect().has_point(mouse_pos):
		return true
	return false

func _show_mood_panel() -> void:
	if not is_instance_valid(mood_panel) or not is_instance_valid(mood_name_container):
		return
	if _mood_hover_tween:
		_mood_hover_tween.kill()
	mood_panel.visible = true
	_mood_hover_tween = create_tween()
	_mood_hover_tween.set_parallel(true)
	_mood_hover_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_mood_hover_tween.tween_property(mood_panel, "modulate:a", 1.0, 0.18)
	_mood_hover_tween.tween_property(mood_name_container, "self_modulate:a", 0.0, 0.18)

func _hide_mood_panel() -> void:
	if not is_instance_valid(mood_panel) or not is_instance_valid(mood_name_container):
		return
	if _mood_hover_tween:
		_mood_hover_tween.kill()
	_mood_hover_tween = create_tween()
	_mood_hover_tween.set_parallel(true)
	_mood_hover_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_mood_hover_tween.tween_property(mood_panel, "modulate:a", 0.0, 0.18)
	_mood_hover_tween.tween_property(mood_name_container, "self_modulate:a", 1.0, 0.18)
	_mood_hover_tween.chain().tween_callback(func():
		if is_instance_valid(mood_panel):
			mood_panel.visible = false
	)

func _update_goal_panel_ui() -> void:
	if not is_instance_valid(goal_value_label):
		return
	goal_value_label.text = ""

func _build_goal_panel_text(profile) -> String:
	var current_conf: Dictionary = profile.get_current_stage_config()
	if current_conf.is_empty():
		return "当前阶段配置缺失。"

	var next_conf: Dictionary = profile.get_stage_config(int(profile.current_stage) + 1)
	var current_resonance: float = float(profile.intimacy) + float(profile.trust)
	var resonance_threshold: float = float(current_conf.get("resonance_threshold", 9999.0))
	var lines: Array[String] = []

	if next_conf.is_empty() or resonance_threshold >= 9999.0:
		lines.append("当前已达最高阶段")
		lines.append("继续推进日常互动与关键剧情")
		return "\n".join(lines)

	lines.append("下一阶段：%s" % str(next_conf.get("stageTitle", "未命名阶段")))
	lines.append("共感进度：%.0f / %.0f" % [current_resonance, resonance_threshold])

	var milestone_story := str(current_conf.get("milestone_story", "")).strip_edges()
	if milestone_story != "":
		var event_manager = get_tree().root.get_node_or_null("EventManager")
		var milestone_done := false
		if event_manager and event_manager.has_method("is_event_triggered"):
			milestone_done = event_manager.is_event_triggered(milestone_story)
		lines.append("里程碑：%s%s" % [
			_describe_goal_milestone(milestone_story),
			"（已完成）" if milestone_done else "（待触发）"
		])
	else:
		lines.append("里程碑：继续提升亲密与信任")

	return "\n".join(lines)

func _ensure_goal_reference_cache() -> void:
	if _goal_event_registry_cache.is_empty() and FileAccess.file_exists(EVENT_REGISTRY_PATH):
		var event_file = FileAccess.open(EVENT_REGISTRY_PATH, FileAccess.READ)
		if event_file:
			var event_json = JSON.new()
			if event_json.parse(event_file.get_as_text()) == OK:
				var event_data = event_json.get_data()
				for event_item in event_data.get("events", []):
					var event_id := str(event_item.get("event_id", "")).strip_edges()
					if event_id != "":
						_goal_event_registry_cache[event_id] = event_item
			event_file.close()

	if _goal_map_name_cache.is_empty() and FileAccess.file_exists(MAP_DATA_PATH):
		var map_file = FileAccess.open(MAP_DATA_PATH, FileAccess.READ)
		if map_file:
			var map_json = JSON.new()
			if map_json.parse(map_file.get_as_text()) == OK:
				var map_data = map_json.get_data()
				var locations: Dictionary = map_data.get("locations", {})
				for location_id in locations.keys():
					var location_info = locations[location_id]
					if location_info is Dictionary:
						_goal_map_name_cache[str(location_id)] = str(location_info.get("name", location_id))
			map_file.close()

func _describe_goal_milestone(event_id: String) -> String:
	if event_id == "":
		return "继续推进关键剧情"

	_ensure_goal_reference_cache()
	if not _goal_event_registry_cache.has(event_id):
		return "完成关键事件【%s】" % event_id

	var event_info: Dictionary = _goal_event_registry_cache[event_id]
	var parts: Array[String] = []
	for condition in event_info.get("conditions", []):
		if not (condition is Dictionary):
			continue
		match str(condition.get("type", "")):
			"location":
				var location_id := str(condition.get("value", ""))
				parts.append("前往【%s】" % _goal_map_name_cache.get(location_id, location_id))
			"time_period":
				parts.append("时段为【%s】" % str(condition.get("value", "")))
			"weather":
				parts.append("天气为【%s】" % str(condition.get("value", "")))
			"npc_stage":
				parts.append("相关角色阶段达到 %s" % str(condition.get("min_stage", "")))

	if parts.is_empty():
		return "完成关键事件【%s】" % event_id
	return "，".join(parts)

func _ensure_affection_panel_popup() -> void:
	if is_instance_valid(affection_panel_instance):
		return
	affection_panel_instance = AffectionPanelScene.instantiate()
	affection_popup_frame.add_child(affection_panel_instance)
	if affection_panel_instance is Control:
		var panel_control := affection_panel_instance as Control
		var target_size := panel_control.custom_minimum_size
		if target_size == Vector2.ZERO:
			target_size = panel_control.get_combined_minimum_size()
		if target_size != Vector2.ZERO:
			affection_popup_frame.custom_minimum_size = target_size
	affection_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if affection_panel_instance.has_signal("back_requested"):
		affection_panel_instance.back_requested.connect(_hide_affection_popup)

func _show_affection_popup() -> void:
	_ensure_affection_panel_popup()
	if not is_instance_valid(affection_panel_instance):
		return
	affection_panel_instance.show_panel(GameDataManager.profile)
	affection_overlay.show()
	affection_overlay.modulate.a = 0.0
	affection_popup_frame.scale = Vector2(0.94, 0.94)
	affection_popup_frame.pivot_offset = affection_popup_frame.custom_minimum_size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(affection_overlay, "modulate:a", 1.0, 0.2)
	tween.tween_property(affection_popup_frame, "scale", Vector2.ONE, 0.2)

func _hide_affection_popup() -> void:
	if not is_instance_valid(affection_overlay) or not affection_overlay.visible:
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(affection_overlay, "modulate:a", 0.0, 0.18)
	tween.tween_property(affection_popup_frame, "scale", Vector2(0.94, 0.94), 0.18)
	tween.chain().tween_callback(func():
		if is_instance_valid(affection_panel_instance) and affection_panel_instance.has_method("hide_panel"):
			affection_panel_instance.hide_panel()
		affection_overlay.hide()
	)

func _is_ui_blocked() -> bool:
	if is_proactive_greeting or proactive_greeting_step > 0:
		return true
	if _interaction_ui_locked_by_dialogue:
		return true
	if _ui_tween and _ui_tween.is_running():
		return true
	return false

func _on_main_chat_pressed() -> void:
	if _is_ui_blocked(): return
	_animate_button(chat_button)
	
	if _ui_tween:
		_ui_tween.kill()
	_ui_tween = create_tween()
	_ui_tween.tween_property(ui_panel, "modulate:a", 0.0, 0.3)
	_ui_tween.tween_callback(func(): ui_panel.visible = false)
	
	if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
		current_bg_scene.set_ui_hidden(true)

	_begin_topic_selection_flow()

func _begin_topic_selection_flow() -> void:
	_awaiting_topic_selection = true
	_topic_greeting_playing = true
	_pending_topic_options.clear()
	_show_dialogue_topic_selection()
	_populate_topics()
	_request_topic_greeting()

func _show_dialogue_topic_selection() -> void:
	_set_interaction_ui_hidden_for_dialogue(true)
	dialogue_panel.visible = true
	dialogue_panel.visible = true
	dialogue_panel.modulate.a = 0.0
	var d_tween = create_tween()
	d_tween.tween_property(dialogue_panel, "modulate:a", 1.0, 0.3)

	dialogue_name_label.text = GameDataManager.profile.char_name
	dialogue_text.bbcode_enabled = true
	dialogue_text.visible_ratio = 1.0
	dialogue_text.visible_characters = -1

	_set_dialogue_input_waiting(GameDataManager.profile.char_name)
	_set_dialogue_toolbar_visible(true, true, true)
	if quick_option_layer:
		quick_option_layer.hide()

func _populate_topics() -> void:
	_clear_topic_options()
	
	# 请求 AI 动态生成话题
	var profile = GameDataManager.profile
	var stage_conf = profile.get_current_stage_config()
	var stage_title = stage_conf.get("stageTitle", "陌生人")
	var world_bg = profile.description.replace("{char_name}", profile.char_name)
	
	var prompt = "【系统指令】\n当前世界观与角色设定：%s\n\n请基于当前玩家作为少女【%s】的“指导人”身份，以及你们当前的情感阶段（当前阶段：%s），分别生成 3 个固定类别的话题选项：1 个学习话题、1 个生活话题、1 个情感话题。\n要求：\n1. 话题必须严格符合上述世界观设定，绝对禁止凭空捏造不符合设定的元素。\n2. 三个话题都要符合指导人身份，可以体现教导、关心、日常询问、鼓励或情感陪伴。\n3. 每个话题 20 字以内，自然简短，且必须是可以直接点击发送的玩家台词。\n4. 只输出 JSON，不要输出任何解释文字。\n5. JSON 格式必须严格如下：{\"study_topic\":\"...\",\"life_topic\":\"...\",\"emotion_topic\":\"...\"}" % [world_bg, profile.char_name, stage_title]
	
	deepseek_client.generate_dynamic_topics(prompt, func(text: String):
		if not _awaiting_topic_selection:
			return
		if text.is_empty():
			_render_dynamic_topics("最近在忙些什么呢？\n今天天气真不错，对吧？\n有什么心事想和我聊聊吗？")
		else:
			_render_dynamic_topics(text)
	)

func _render_dynamic_topics(raw_text: String) -> void:
	var topic_map := _parse_topic_topic_map(raw_text)
	_pending_topic_options = [
		QuickOptionListHelper.build_topic_option_item(str(topic_map.get("study", "最近学习进度还顺利吗？")), "study"),
		QuickOptionListHelper.build_topic_option_item(str(topic_map.get("life", "今天过得怎么样？")), "life"),
		QuickOptionListHelper.build_topic_option_item(str(topic_map.get("emotion", "最近有没有什么心事想和我说？")), "emotion")
	]
	if _awaiting_topic_selection and not _topic_greeting_playing:
		_show_topic_options()

func _parse_topic_topic_map(raw_text: String) -> Dictionary:
	var fallback := {
		"study": "最近学习进度还顺利吗？",
		"life": "今天过得怎么样？",
		"emotion": "最近有没有什么心事想和我说？"
	}
	var json_text := raw_text.strip_edges()
	var regex := RegEx.new()
	regex.compile("```(?:json)?\\s*(\\{[\\s\\S]*?\\})\\s*```")
	var match = regex.search(raw_text)
	if match:
		json_text = match.get_string(1).strip_edges()
	else:
		var start_idx := raw_text.find("{")
		var end_idx := raw_text.rfind("}")
		if start_idx != -1 and end_idx != -1 and end_idx > start_idx:
			json_text = raw_text.substr(start_idx, end_idx - start_idx + 1).strip_edges()

	var json := JSON.new()
	if json_text != "" and json.parse(json_text) == OK and json.data is Dictionary:
		var data := json.data as Dictionary
		return {
			"study": str(data.get("study_topic", fallback["study"])).strip_edges(),
			"life": str(data.get("life_topic", fallback["life"])).strip_edges(),
			"emotion": str(data.get("emotion_topic", fallback["emotion"])).strip_edges()
		}

	var topics := QuickOptionListHelper.parse_topic_lines(
		raw_text,
		[fallback["study"], fallback["life"], fallback["emotion"]],
		3
	)
	return {
		"study": str(topics[0] if topics.size() > 0 else fallback["study"]),
		"life": str(topics[1] if topics.size() > 1 else fallback["life"]),
		"emotion": str(topics[2] if topics.size() > 2 else fallback["emotion"])
	}

func _clear_topic_options() -> void:
	for child in quick_options_container.get_children():
		child.queue_free()

func _show_topic_options() -> void:
	_clear_topic_options()
	if quick_option_layer:
		quick_option_layer.show()
	if _pending_topic_options.is_empty():
		QuickOptionListHelper.show_loading_item(quick_options_container)
		return
	QuickOptionListHelper.populate_option_items(quick_options_container, _pending_topic_options, _on_topic_selected, 74.0)

func _request_topic_greeting() -> void:
	if deepseek_client.is_connected("npc_event_dialogue_completed", _on_topic_greeting_generated):
		deepseek_client.npc_event_dialogue_completed.disconnect(_on_topic_greeting_generated)
	if deepseek_client.is_connected("npc_event_dialogue_failed", _on_topic_greeting_failed):
		deepseek_client.npc_event_dialogue_failed.disconnect(_on_topic_greeting_failed)

	deepseek_client.npc_event_dialogue_completed.connect(_on_topic_greeting_generated, CONNECT_ONE_SHOT)
	deepseek_client.npc_event_dialogue_failed.connect(_on_topic_greeting_failed, CONNECT_ONE_SHOT)

	var profile = GameDataManager.profile
	var stage_conf = profile.get_current_stage_config()
	var player_name = profile.player_title
	if player_name.is_empty():
		player_name = "指导人"
	var greeting_prompt = "请生成一句聊天开场问候，核心意思是“要聊点什么呢？”。要求：1. 结合你当前对%s的情感阶段与语气，当前阶段是%s。2. 必须符合你当前角色设定，用第一人称自然开口。3. 只输出一句简短台词，20字以内。4. 可以带一个简短括号动作描写。5. 不要输出多个选项，不要展开成长对话。" % [player_name, stage_conf.get("stageTitle", "陌生人")]
	deepseek_client.generate_npc_event_dialogue("luna", greeting_prompt)

func _on_topic_greeting_generated(greeting_text: String) -> void:
	if not _awaiting_topic_selection:
		return
	if dialogue_panel.has_method("cancel_single_line"):
		dialogue_panel.cancel_single_line(false)
	if dialogue_panel.has_signal("single_line_finished"):
		dialogue_panel.single_line_finished.connect(_on_topic_greeting_finished, CONNECT_ONE_SHOT)
	dialogue_panel.play_single_line("luna", GameDataManager.profile.char_name, greeting_text, true, true, true)

func _on_topic_greeting_failed(_error_msg: String) -> void:
	if not _awaiting_topic_selection:
		return
	_on_topic_greeting_generated("（轻轻看向你）这次想聊点什么呢？")

func _on_topic_greeting_finished() -> void:
	if not _awaiting_topic_selection:
		return
	_topic_greeting_playing = false
	_set_dialogue_toolbar_visible(true, true, true)
	_show_topic_options()

func _on_topic_selected(topic: String) -> void:
	# 执行互动开销（行动力、金币、经验、心情、时间等）
	if GameDataManager.interaction_manager:
		if not GameDataManager.interaction_manager.execute_interaction("chat_luna_topic"):
			return
	else:
		if not GameDataManager.profile.consume_energy(5):
			ToastManager.show_system_toast("行动力不足，需要5点行动力", Color.RED)
			return
		
	if top_status_panel and top_status_panel.has_method("_update_ui"):
		top_status_panel._update_ui()

	_awaiting_topic_selection = false
	_set_main_chat_context(_resolve_topic_chat_subtype(topic), topic)
	dialogue_name_label.text = GameDataManager.profile.char_name
	dialogue_text.text = "..."
	_set_dialogue_input_waiting(GameDataManager.profile.char_name)

	if input_layer:
		input_layer.show()
	_set_dialogue_toolbar_visible(true, true, true)

	for child in quick_options_container.get_children():
		child.queue_free()
	if quick_option_layer:
		quick_option_layer.hide()
		
	var stage_conf = GameDataManager.profile.get_current_stage_config()
	var stage_desc = stage_conf.get("stageDesc", "")
	var player_name = GameDataManager.profile.player_title
	if player_name.is_empty():
		player_name = "指导人"
	var user_msg = "【系统提示】玩家主动选择了话题：“" + topic + "” 与你聊天。玩家当前的身份是你的指导人，且你对玩家的称呼是“" + player_name + "”。当前你们的情感阶段是：" + stage_desc + "。请你结合当前的身份、情感阶段和心情，以第一人称主动向玩家打招呼并展开这个话题。不要复述系统提示，直接给出纯台词回复（必须包含括号动作描写）。"
	deepseek_client.send_chat_message_stream(user_msg, "main_chat")

func _cancel_topic_selection() -> void:
	_awaiting_topic_selection = false
	_topic_greeting_playing = false
	_pending_topic_options.clear()
	_clear_topic_options()
	if dialogue_panel.has_method("cancel_single_line"):
		dialogue_panel.cancel_single_line(false)
	if quick_option_layer:
		quick_option_layer.hide()
	if input_layer:
		input_layer.hide()
	if history_btn:
		history_btn.hide()

	var d_tween = create_tween()
	d_tween.tween_property(dialogue_panel, "modulate:a", 0.0, 0.3)
	d_tween.tween_callback(func(): dialogue_panel.visible = false)

	ui_panel.visible = true
	ui_panel.modulate.a = 0.0
	if _ui_tween:
		_ui_tween.kill()
	_ui_tween = create_tween()
	_ui_tween.tween_property(ui_panel, "modulate:a", 1.0, 0.3)

	if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
		current_bg_scene.set_ui_hidden(false)
	_set_interaction_ui_hidden_for_dialogue(false)

var is_ending_chat: bool = false

func _on_date_pressed() -> void:
	if _is_ui_blocked(): return
	if is_instance_valid(date_button):
		_animate_button(date_button)
		
	var date_scene_path = "res://scenes/ui/date/date_scene.tscn"
	if FileAccess.file_exists(date_scene_path):
		var date_scene_res = load(date_scene_path)
		if date_scene_res:
			var date_scene = date_scene_res.instantiate()
			ui_panel.add_child(date_scene)
			date_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _on_gift_pressed() -> void:
	if _is_ui_blocked(): return
	if is_instance_valid(gift_button):
		_animate_button(gift_button)
	
	var gift_popup_path = "res://scenes/ui/gift/gift_panel.tscn"
	if FileAccess.file_exists(gift_popup_path):
		var gift_popup_scene = load(gift_popup_path)
		if gift_popup_scene:
			var popup = gift_popup_scene.instantiate()
			ui_panel.add_child(popup)
			
			if popup.has_signal("gift_sent"):
				popup.gift_sent.connect(_on_gift_sent)
				
			if popup.has_method("show_panel"):
				popup.show_panel()

func _on_gift_sent(gift_data: Dictionary) -> void:
	var gift_id = gift_data.get("id", "")
	if gift_id == "":
		return
		
	# 委托 GiftManager 处理，它内部会调用 interaction_manager 扣除行动力/时间等，并处理亲密和信任加成
	var res = GameDataManager.gift_manager.send_gift(GameDataManager.profile, gift_id)
	if not res.success:
		ToastManager.show_system_toast(res.msg, Color.RED)
		return
		
	# 显示Toast
	ToastManager.show_toast("送出了 [%s]" % gift_data.get("name", "礼物"), Color(0.6, 0.4, 0.8, 0.9))
	if res.gained_intimacy > 0:
		ToastManager.show_stat_toast("intimacy", "亲密 +%.1f" % res.gained_intimacy)
	if res.gained_trust > 0:
		ToastManager.show_stat_toast("trust", "信任 +%.1f" % res.gained_trust)
		
	if top_status_panel and top_status_panel.has_method("_update_ui"):
		top_status_panel._update_ui()
		
	# 送礼后触发对话面板和特定话题
	if _ui_tween:
		_ui_tween.kill()
	_ui_tween = create_tween()
	_ui_tween.tween_property(ui_panel, "modulate:a", 0.0, 0.3)
	_ui_tween.tween_callback(func(): ui_panel.visible = false)
	
	if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
		current_bg_scene.set_ui_hidden(true)
	
	dialogue_panel.visible = true
	dialogue_panel.modulate.a = 0.0
	var d_tween = create_tween()
	d_tween.tween_property(dialogue_panel, "modulate:a", 1.0, 0.3)
	
	dialogue_name_label.text = GameDataManager.profile.char_name
	dialogue_text.text = "..."
	_set_dialogue_input_waiting(GameDataManager.profile.char_name)
	
	if end_chat_btn:
		end_chat_btn.show()
	if history_btn:
		history_btn.show()
	
	for child in quick_options_container.get_children():
		child.queue_free()
		
	var gift_name = gift_data.get("name", "礼物")
	var stage_conf = GameDataManager.profile.get_current_stage_config()
	var stage_desc = stage_conf.get("stageDesc", "")
	var player_name = GameDataManager.profile.player_title
	if player_name.is_empty():
		player_name = "指导人"
		
	var user_msg = "【系统提示】玩家（当前身份：" + player_name + "）刚刚送给你一份礼物：【" + gift_name + "】。当前情感阶段是：" + stage_desc + "。请结合你的性格、心情和这份礼物的特点，主动对玩家说出你的感谢和反应（必须包含动作描写）。不要复述系统提示，直接给出台词。"
	deepseek_client.send_chat_message_stream(user_msg, "main_chat")

func _on_rest_pressed() -> void:
	if _is_ui_blocked(): return
	_animate_button(rest_button)
	
	# 检查行动力
	var energy_val = GameDataManager.profile.current_energy
	var energy_warning = energy_val > 0
	
	# 检查时间
	var time_warning = false
	if GameDataManager.story_time_manager:
		var current_time = GameDataManager.story_time_manager.current_hour * 60 + GameDataManager.story_time_manager.current_minute
		# 假设 24:00 是 1440 分钟，如果小于这个值，说明时间还早
		if current_time < 1440:
			time_warning = true
	
	if energy_warning or time_warning:
		var warning_text = ""
		if energy_warning and time_warning:
			warning_text = "还有未消耗的行动力，且时间还早，确定要休息了吗？"
		elif energy_warning:
			warning_text = "还有未消耗的行动力，确定要休息了吗？"
		else:
			warning_text = "时间还早，确定要休息了吗？"
			
		var ConfirmDialogObj = load("res://scenes/ui/common/confirm_dialog.tscn")
		var confirm_dialog = ConfirmDialogObj.instantiate()
		add_child(confirm_dialog)
		confirm_dialog.setup(warning_text)
		confirm_dialog.confirmed.connect(_execute_rest_transition.bind(confirm_dialog))
		confirm_dialog.canceled.connect(func(): confirm_dialog.queue_free())
	else:
		_execute_rest_transition(null)

func _execute_rest_transition(dialog: Node) -> void:
	if is_instance_valid(dialog):
		dialog.queue_free()
		
	# 屏蔽交互
	ui_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 创建黑屏遮罩
	var black_screen = ColorRect.new()
	black_screen.color = Color.BLACK
	black_screen.modulate.a = 0.0
	black_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 确保盖在最上面
	add_child(black_screen)
	move_child(black_screen, get_child_count() - 1)
	
	var tween = create_tween()
	# 1. 黑屏淡入
	tween.tween_property(black_screen, "modulate:a", 1.0, 1.0)
	
	# 2. 执行跳过逻辑
	tween.tween_callback(func():
		if GameDataManager.story_time_manager:
			# 跳到下一天
			GameDataManager.story_time_manager.advance_day(1)
			# 确保时间设置为早上6点
			GameDataManager.story_time_manager.current_hour = 6
			GameDataManager.story_time_manager.current_minute = 0
			GameDataManager.story_time_manager.current_period = GameDataManager.story_time_manager.PERIOD_MORNING
			GameDataManager.story_time_manager.time_advanced.emit(0, GameDataManager.story_time_manager.current_period)
			
			# 恢复行动力等日常重置逻辑可以在这里或者时间管理器的跨天信号里处理
			GameDataManager.profile.current_energy = GameDataManager.profile.max_energy
			
			GameDataManager.profile.save_profile()
			GameDataManager.story_time_manager.save_data()
			GameDataManager.save_manager.auto_save()
	)

	# 3. 停留一会
	tween.tween_interval(1.0)
	
	# 4. 黑屏淡出
	tween.tween_property(black_screen, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func():
		black_screen.queue_free()
		ui_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	)
	print("[MainScene] 休息按钮被点击，预留接口")

func _on_interactive_pressed() -> void:
	if _is_ui_blocked(): return
	_animate_button(interactive_button)
	interactive_sub_menu.visible = not interactive_sub_menu.visible

func _on_co_create_pressed() -> void:
	if _is_ui_blocked(): return
	_animate_button(co_create_button)
	interactive_sub_menu.visible = false
	if drawing_board_instance == null:
		var DrawingBoardObj = load("res://scenes/ui/activity/drawing_board_panel.tscn")
		drawing_board_instance = DrawingBoardObj.instantiate()
		ui_panel.add_child(drawing_board_instance)
		drawing_board_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if drawing_board_instance.has_signal("creation_completed"):
			drawing_board_instance.creation_completed.connect(_on_drawing_creation_completed)
		if drawing_board_instance.has_signal("creation_failed"):
			drawing_board_instance.creation_failed.connect(_on_drawing_creation_failed)
		if drawing_board_instance.has_signal("close_requested"):
			drawing_board_instance.close_requested.connect(func(): drawing_board_instance.hide())
	drawing_board_instance.show()

func _on_drawing_creation_completed(image_path: String, prompt: String) -> void:
	if drawing_board_instance:
		drawing_board_instance.hide()

	if image_path.strip_edges() != "":
		var photo_manager = PhotoMemoryManagerScript.new()
		var memory_context = GameDataManager.memory_manager.build_story_memory_context() if GameDataManager.memory_manager else {}
		photo_manager.register_photo(image_path, "drawing_image", {
			"album_category": "drawing",
			"memory_context": memory_context,
			"preferred_layers": ["bond", "emotion", "habit"],
			"source_title": "一起完成的画",
			"source_text": prompt,
			"source_id": str(Time.get_unix_time_from_system()),
			"prompt": prompt,
			"source_char_id": str(GameDataManager.profile.current_character_id) if GameDataManager.profile else ""
		})
	
	# 执行互动开销
	if GameDataManager.interaction_manager:
		GameDataManager.interaction_manager.execute_interaction("co_create_board")
	
	# 显示图片和对话
	_show_generated_image_and_dialogue(image_path)

func _on_drawing_creation_failed(error_msg: String) -> void:
	ToastManager.show_system_toast(error_msg, Color.RED)

func _show_generated_image_and_dialogue(image_path: String) -> void:
	if is_instance_valid(_generated_image_panel):
		_generated_image_panel.queue_free()
	_generated_image_panel = null

	# 利用系统的图库面板或者创建临时的面板显示图片
	var tex = ImageTexture.create_from_image(Image.load_from_file(image_path))
	if tex == null:
		ToastManager.show_system_toast("无法加载生成的图片", Color.RED)
		return
		
	var tex_rect = TextureRect.new()
	tex_rect.texture = tex
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var panel = Panel.new()
	_generated_image_panel = panel
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	panel.add_theme_stylebox_override("panel", style)
	
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(tex_rect)
	
	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(20, 20)
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.pressed.connect(func(): panel.queue_free())
	panel.add_child(close_btn)
	
	add_child(panel)
	move_child(panel, dialogue_panel.get_index())
	
	# 显示对话
	if _ui_tween:
		_ui_tween.kill()
	_ui_tween = create_tween()
	_ui_tween.tween_property(ui_panel, "modulate:a", 0.0, 0.3)
	_ui_tween.tween_callback(func(): ui_panel.visible = false)
	
	if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
		current_bg_scene.set_ui_hidden(true)
	
	dialogue_panel.visible = true
	dialogue_panel.modulate.a = 0.0
	var d_tween = create_tween()
	d_tween.tween_property(dialogue_panel, "modulate:a", 1.0, 0.3)
	
	dialogue_name_label.text = GameDataManager.profile.char_name
	dialogue_text.text = "哥哥，我根据你画的草图，丰富了一下细节，你看好看吗？"
	dialogue_text.visible_ratio = 0.0
	
	if _typewriter_tween:
		_typewriter_tween.kill()
	_typewriter_tween = create_tween()
	_typewriter_tween.tween_property(dialogue_text, "visible_ratio", 1.0, 1.5)
	_typewriter_tween.finished.connect(func(): _set_dialogue_input_ready(), CONNECT_ONE_SHOT)
	
	_set_dialogue_input_waiting(GameDataManager.profile.char_name)
	
	if end_chat_btn:
		end_chat_btn.show()
	if history_btn:
		history_btn.show()
	
	for child in quick_options_container.get_children():
		child.queue_free()

func _on_end_chat_pressed() -> void:
	if _story_mode_active:
		return
	if _awaiting_topic_selection:
		_cancel_topic_selection()
		return
	var event_manager = get_node_or_null("/root/EventManager")
	if event_manager and event_manager.has_method("execute_event"):
		event_manager.execute_event("farewell")

func _close_chat_panel(show_stats_toast: bool = true) -> void:
	if is_instance_valid(_generated_image_panel):
		_generated_image_panel.queue_free()
	_generated_image_panel = null
	is_memory_revisit_active = false
	_reset_main_chat_context()

	if show_stats_toast:
		_show_accumulated_stats()
	
	var d_tween = create_tween()
	d_tween.tween_property(dialogue_panel, "modulate:a", 0.0, 0.3)
	d_tween.tween_callback(func(): dialogue_panel.visible = false)

	if quick_option_layer:
		quick_option_layer.hide()
	
	ui_panel.visible = true
	ui_panel.modulate.a = 0.0
	if _ui_tween:
		_ui_tween.kill()
	_ui_tween = create_tween()
	_ui_tween.tween_property(ui_panel, "modulate:a", 1.0, 0.3)
	
	if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
		current_bg_scene.set_ui_hidden(false)

	_set_interaction_ui_hidden_for_dialogue(false)

func _set_dialogue_input_waiting(char_name: String = "") -> void:
	if dialogue_panel and dialogue_panel.has_method("set_input_waiting_state"):
		dialogue_panel.set_input_waiting_state(char_name)
		return
	if input_layer:
		input_layer.show()
	if input_field:
		var final_name := char_name.strip_edges()
		if final_name == "":
			final_name = "角色"
		input_field.text = "【%s】正在讲话中，请等待…" % final_name
		input_field.editable = false
	if send_btn:
		send_btn.disabled = true

func _set_dialogue_toolbar_visible(visible: bool, show_end: bool = true, show_history: bool = true) -> void:
	if dialogue_toolbar_container:
		dialogue_toolbar_container.visible = visible
	if not visible:
		return
	if end_chat_btn:
		end_chat_btn.visible = show_end
	if history_btn:
		history_btn.visible = show_history

func _set_dialogue_input_ready(clear_text: bool = true) -> void:
	if dialogue_panel and dialogue_panel.has_method("set_input_ready_state"):
		dialogue_panel.set_input_ready_state(clear_text)
		return
	if input_layer:
		input_layer.show()
	if input_field:
		if clear_text:
			input_field.text = ""
		input_field.editable = true
	if send_btn:
		send_btn.disabled = false

func _on_send_pressed() -> void:
	if _story_mode_active:
		return
	var text = input_field.text.strip_edges()
	if text.is_empty():
		return
	if _awaiting_topic_selection:
		_on_topic_selected(text)
		return
	if _current_main_chat_subtype == MAIN_CHAT_SUBTYPE_MEMORY or _current_main_chat_subtype == MAIN_CHAT_SUBTYPE_PROACTIVE:
		_set_main_chat_context(MAIN_CHAT_SUBTYPE_DAILY)
		
	_set_dialogue_input_waiting(GameDataManager.profile.char_name)
	
	for child in quick_options_container.get_children():
		child.queue_free()
	if quick_option_layer:
		quick_option_layer.hide()
		
	GameDataManager.history.add_message("player", text, "", "main_chat", _build_main_chat_meta())
	
	dialogue_name_label.text = "我"
	
	var display_text = text
	var color_regex_zh = RegEx.new()
	color_regex_zh.compile("（(.*?)）")
	display_text = color_regex_zh.sub(display_text, "[color=green]（$1）[/color]", true)
	var color_regex_en = RegEx.new()
	color_regex_en.compile("\\((.*?)\\)")
	display_text = color_regex_en.sub(display_text, "[color=green]($1)[/color]", true)
	
	dialogue_text.bbcode_enabled = true
	dialogue_text.text = display_text
	dialogue_text.visible_ratio = 0.0
	
	if _typewriter_tween:
		_typewriter_tween.kill()
	_typewriter_tween = create_tween()
	var dur = max(0.5, text.length() * 0.05)
	_typewriter_tween.tween_property(dialogue_text, "visible_ratio", 1.0, dur)
	
	if is_inside_tree():
		while _typewriter_tween and _typewriter_tween.is_valid() and _typewriter_tween.is_running():
			await get_tree().process_frame
			
	dialogue_text.visible_ratio = 1.0
	dialogue_text.visible_characters = -1
	
	if is_proactive_greeting:
		is_proactive_greeting = false
		
	deepseek_client.send_chat_message_stream(text, "main_chat")

func _on_chat_stream_started() -> void:
	stream_live_active = true
	stream_live_done = false
	stream_live_buffer = ""
	stream_live_queue.clear()
	is_text_playback_finished = false
	pending_options_data.clear()
	
	if _waiting_for_chat_click:
		_waiting_for_chat_click = false
		_chat_click_proceed.emit()
		
	_try_start_stream_worker()

func _on_chat_stream_delta(delta_text: String) -> void:
	if not stream_live_active:
		return
	stream_live_buffer += delta_text
	_extract_stream_segments(false)
	_try_start_stream_worker()

func _on_chat_response(response: Dictionary) -> void:
	if stream_live_active:
		stream_live_done = true
		_extract_stream_segments(true)
		_try_start_stream_worker()
		
		# 我们不再在这里直接保存全量内容，因为 _stream_worker_loop 会逐句保存并附带语音缓存
		# GameDataManager.history.add_message("char", deepseek_client._chat_stream_full_text, "", "main_chat")
		deepseek_client.send_options_generation(deepseek_client._chat_stream_full_text, "", "main_chat")
		deepseek_client.send_emotion_generation(deepseek_client._chat_stream_full_text)
		return
		
	if response.has("choices") and response["choices"].size() > 0:
		var reply = response["choices"][0]["message"]["content"]
		# 我们不再在这里直接保存全量内容，因为 _stream_worker_loop 会逐句保存并附带语音缓存
		# GameDataManager.history.add_message("char", reply, "", "main_chat")
		deepseek_client.send_options_generation(reply, "", "main_chat")
		deepseek_client.send_emotion_generation(reply)
			
		dialogue_name_label.text = GameDataManager.profile.char_name
		
		var display_text = reply
		var color_regex_zh = RegEx.new()
		color_regex_zh.compile("（(.*?)）")
		display_text = color_regex_zh.sub(display_text, "[color=green]（$1）[/color]", true)
		var color_regex_en = RegEx.new()
		color_regex_en.compile("\\((.*?)\\)")
		display_text = color_regex_en.sub(display_text, "[color=green]($1)[/color]", true)
		
		dialogue_text.bbcode_enabled = true
		dialogue_text.text = display_text
		dialogue_text.visible_ratio = 1.0
		_set_dialogue_input_ready()
	else:
		dialogue_name_label.text = GameDataManager.profile.char_name
		dialogue_text.text = "似乎走神了..."
		_set_dialogue_input_ready()

func _extract_stream_segments(force_flush: bool) -> void:
	var delim = "[SPLIT]"
	while true:
		var idx = stream_live_buffer.find(delim)
		if idx == -1:
			break
		var part = stream_live_buffer.substr(0, idx).strip_edges()
		stream_live_buffer = stream_live_buffer.substr(idx + delim.length())
		if part != "":
			stream_live_queue.append(part)
			
	if force_flush:
		var last_part = stream_live_buffer.strip_edges()
		stream_live_buffer = ""
		if last_part != "":
			var parts = _auto_split_message(last_part)
			for p in parts:
				if typeof(p) == TYPE_STRING:
					var tp = p.strip_edges()
					if tp != "":
						stream_live_queue.append(tp)

func _auto_split_message(text: String) -> Array:
	if "[SPLIT]" in text:
		return text.split("[SPLIT]", false)
		
	var mood_tag = ""
	var pure_text = text
	var mood_regex = RegEx.new()
	mood_regex.compile("(?i)(?:<|\\<|《|\\[|【)\\s*(mood|心情)\\s*[:：]\\s*([^>\\>》\\]】]+)\\s*(?:>|\\>|》|\\]|】)")
	var mood_match = mood_regex.search(text)
	if mood_match:
		mood_tag = mood_match.get_string()
		pure_text = text.replace(mood_tag, "")
		
	var modified_text = pure_text
	
	# 新增策略0：优先将大模型输出的换行符视为消息分隔符
	# 很多时候AI会用换行来排版不同的动作和对话
	modified_text = modified_text.replace("\r\n", "\n")
	var nl_regex = RegEx.new()
	nl_regex.compile("\\n+")
	modified_text = nl_regex.sub(modified_text, "[SPLIT]", true)
	
	# 修复：确保连续的 [SPLIT] 被合并为一个
	modified_text = modified_text.replace("[SPLIT][SPLIT]", "[SPLIT]")
	modified_text = modified_text.replace("[SPLIT] [SPLIT]", "[SPLIT]")
	
	if not "[SPLIT]" in modified_text:
		var endings = ["。", "！", "？", "……", "”", "」", "~", "～"]
		var brackets = ["（", "("]
		
		# 策略1：根据“标点+动作括号”完美切分，这样刚好能保证切分后下一句以动作开头，带着后续的对话
		for end_char in endings:
			for bracket in brackets:
				modified_text = modified_text.replace(end_char + bracket, end_char + "[SPLIT]" + bracket)
				modified_text = modified_text.replace(end_char + " " + bracket, end_char + "[SPLIT]" + bracket)
				
		# 策略2：如果文本仍未切分且过长（>80字），强行按标点切分
		if not "[SPLIT]" in modified_text and modified_text.length() > 80:
			modified_text = modified_text.replace("。", "。[SPLIT]")
			modified_text = modified_text.replace("！", "！[SPLIT]")
			modified_text = modified_text.replace("？", "？[SPLIT]")
			# 避免把连续的标点切碎
			modified_text = modified_text.replace("[SPLIT][SPLIT]", "[SPLIT]")
		
	var parts = modified_text.split("[SPLIT]", false)
	var merged_parts = []
	var temp_str = ""
	
	for p in parts:
		var tp = p.strip_edges()
		if tp == "": continue
		
		if temp_str == "":
			temp_str = tp
		else:
			# 优化：判断当前片段(tp)或者暂存片段(temp_str)是否*仅仅*包含动作描写（没有实质对话内容）
			var tp_clean = tp
			var temp_clean = temp_str
			var action_regex = RegEx.new()
			action_regex.compile("（.*?）|\\(.*?\\)")
			tp_clean = action_regex.sub(tp_clean, "", true).strip_edges()
			temp_clean = action_regex.sub(temp_clean, "", true).strip_edges()
			
			# 如果其中一个片段仅仅只有动作描写（去掉括号后无内容），则必须合并
			if tp_clean == "" or temp_clean == "":
				temp_str += " " + tp
			else:
				merged_parts.append(temp_str)
				temp_str = tp
				
	if temp_str != "":
		merged_parts.append(temp_str)

	merged_parts = ChatSplitHelper.merge_incomplete_parentheses(merged_parts)
		
	# 新增限制：如果某一条消息长度超过 60，强制进行二次切分
	var final_split_parts = []
	for part in merged_parts:
		if part.length() > 60:
			var split_part = part
			var endings = ["。", "！", "？", "……", "”", "」", "~", "～"]
			var brackets = ["（", "("]
			# 尝试在动作前切分
			for end_char in endings:
				for bracket in brackets:
					split_part = split_part.replace(end_char + bracket, end_char + "[FORCE_SPLIT]" + bracket)
					split_part = split_part.replace(end_char + " " + bracket, end_char + "[FORCE_SPLIT]" + bracket)
			
			# 如果依然没有切分开，强行按标点切分
			if not "[FORCE_SPLIT]" in split_part:
				split_part = split_part.replace("。", "。[FORCE_SPLIT]")
				split_part = split_part.replace("！", "！[FORCE_SPLIT]")
				split_part = split_part.replace("？", "？[FORCE_SPLIT]")
				split_part = split_part.replace("[FORCE_SPLIT][FORCE_SPLIT]", "[FORCE_SPLIT]")
				
			var sub_parts = split_part.split("[FORCE_SPLIT]", false)
			for sp in sub_parts:
				if sp.strip_edges() != "":
					final_split_parts.append(sp.strip_edges())
		else:
			final_split_parts.append(part)
			
	merged_parts = final_split_parts
	merged_parts = ChatSplitHelper.merge_incomplete_parentheses(merged_parts)
		
	# 限制最多3条
	if merged_parts.size() > 3:
		# 只保留前3条，或者把后面的内容全部合并到第3条里
		var truncated_parts = []
		truncated_parts.append(merged_parts[0])
		truncated_parts.append(merged_parts[1])
		truncated_parts.append(merged_parts[2])
		merged_parts = truncated_parts
		
	if merged_parts.size() > 0 and mood_tag != "":
		merged_parts[merged_parts.size() - 1] += mood_tag
		
	if merged_parts.size() == 0:
		return [text]
		
	return merged_parts

func _try_start_stream_worker() -> void:
	if stream_live_worker_running:
		return
	stream_live_worker_running = true
	_stream_worker_loop()

func _stream_worker_loop() -> void:
	while stream_live_queue.size() > 0 or (stream_live_active and not stream_live_done):
		if not stream_live_active and stream_live_queue.size() == 0:
			break
			
		if stream_live_queue.size() > 0:
			var text = stream_live_queue.pop_front()
			
			# 清理情绪标签等
			var mood_regex = RegEx.new()
			mood_regex.compile("(?i)(?:<|\\<|《|\\[|【)\\s*(mood|心情)\\s*[:：]\\s*([^>\\>》\\]】]+)\\s*(?:>|\\>|》|\\]|】)")
			var pure_text = mood_regex.sub(text, "", true).strip_edges()
			
			if pure_text == "":
				continue
				
			dialogue_name_label.text = GameDataManager.profile.char_name
			
			# 强制清理：只保留最开头的一个动作描述，移除其余所有动作描述
			var extract_regex = RegEx.new()
			extract_regex.compile("（.*?）|\\(.*?\\)")
			var matches = extract_regex.search_all(pure_text)
			if matches.size() > 0:
				var first_action = matches[0].get_string()
				var no_action_text = extract_regex.sub(pure_text, "", true).strip_edges()
				pure_text = first_action + " " + no_action_text
			
			var display_text = pure_text
			var color_regex_zh = RegEx.new()
			color_regex_zh.compile("（(.*?)）")
			display_text = color_regex_zh.sub(display_text, "[color=green]（$1）[/color]", true)
			var color_regex_en = RegEx.new()
			color_regex_en.compile("\\((.*?)\\)")
			display_text = color_regex_en.sub(display_text, "[color=green]($1)[/color]", true)
			
			dialogue_text.bbcode_enabled = true
			dialogue_text.text = display_text
			dialogue_text.visible_ratio = 0.0
			
			var current_cache_key = ""
			
			if _typewriter_tween:
				_typewriter_tween.kill()
			_typewriter_tween = create_tween()
			var dur = max(0.5, pure_text.length() * 0.05)
			_typewriter_tween.tween_property(dialogue_text, "visible_ratio", 1.0, dur)
			
			var is_tts_started = false
			var tts_text = pure_text
			var action_regex = RegEx.new()
			action_regex.compile("（.*?）|\\(.*?\\)")
			tts_text = action_regex.sub(tts_text, "", true).strip_edges()
			
			if GameDataManager.config.voice_enabled:
				var regex_tts = RegEx.new()
				regex_tts.compile("[a-zA-Z0-9\u4e00-\u9fa5]")
				if regex_tts.search(tts_text) != null:
					is_tts_started = true
					var options = {}
					# 通过 TTSManager 统一生成缓存键，确保与实际缓存文件命名一致
					current_cache_key = TTSManager.get_cache_key(tts_text, options)
					TTSManager.synthesize(tts_text, options)
			
			# 这里必须等待一帧，确保 TTS 组件内部有机会触发 success 信号
			await get_tree().process_frame
			
			# 将该条切分后的消息存入历史记录中
			GameDataManager.history.add_message("char", pure_text, current_cache_key, "main_chat", _build_main_chat_meta())
			
			if is_inside_tree():
				while _typewriter_tween and _typewriter_tween.is_valid() and _typewriter_tween.is_running():
					if not stream_live_active:
						break
					await get_tree().process_frame
					
			if not stream_live_active:
				break
				
			dialogue_text.visible_ratio = 1.0
			dialogue_text.visible_characters = -1
			
			_waiting_for_chat_click = false
				
			if is_tts_started and is_inside_tree() and audio_player:
				var wait_count = 0
				while not audio_player.playing and wait_count < 10:
					if not stream_live_active:
						break
					await get_tree().create_timer(0.05).timeout
					wait_count += 1
					
				wait_count = 0
				while audio_player.playing and is_inside_tree() and wait_count < 1200:
					if not stream_live_active:
						if audio_player: audio_player.stop()
						break
					await get_tree().create_timer(0.05).timeout
					wait_count += 1
					
			if not is_ending_chat and not is_proactive_greeting and not is_memory_revisit_active and is_inside_tree():
				await get_tree().create_timer(1.0).timeout
				
			if audio_player and audio_player.playing:
				audio_player.stop()
				
			if not stream_live_active:
				break
		else:
			if is_inside_tree():
				await get_tree().create_timer(0.1).timeout

	stream_live_worker_running = false
	stream_live_active = false
	
	is_text_playback_finished = true
	
	if is_ending_chat or is_proactive_greeting:
		if audio_player and audio_player.playing:
			await audio_player.finished
		if is_ending_chat:
			_show_accumulated_stats()
		_close_chat_panel(false)
		if input_layer:
			input_layer.show()
		is_ending_chat = false
		is_proactive_greeting = false
		is_memory_revisit_active = false
		return
		
	_try_show_options()
	
	_set_dialogue_input_ready()

func _on_chat_click_proceed_handler() -> void:
	pass

func _on_tts_success(audio_stream: AudioStream, text: String) -> void:
	if _story_mode_active:
		return
	if audio_player:
		audio_player.stream = audio_stream
		audio_player.play()

func _on_tts_failed(error_msg: String, text: String) -> void:
	if _story_mode_active:
		return
	print("MainScene TTS 失败: ", error_msg)

func _on_dialogue_panel_gui_input(event: InputEvent) -> void:
	if _story_mode_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if dialogue_text.visible_ratio < 1.0:
			if _typewriter_tween:
				_typewriter_tween.kill()
			dialogue_text.visible_ratio = 1.0
			dialogue_text.visible_characters = -1
		elif _waiting_for_chat_click:
			_waiting_for_chat_click = false
			_chat_click_proceed.emit()

func _show_accumulated_stats() -> void:
	var display_keys = {
		"intimacy": "亲密",
		"trust": "信任"
	}
	
	for key in _accumulated_stats.keys():
		var val = _accumulated_stats[key]
		if abs(val) > 0.01: # Avoid floating point inaccuracies
			if display_keys.has(key):
				var sign_str = "+" if val > 0 else ""
				var formatted_val = sign_str + ("%.1f" % val)
				ToastManager.show_stat_toast(key, display_keys[key] + " " + formatted_val)
		_accumulated_stats[key] = 0.0 # reset for next time

func _on_emotion_response(response: Dictionary) -> void:
	if response.has("choices") and response["choices"].size() > 0:
		var reply = response["choices"][0]["message"]["content"]
		var regex = RegEx.new()
		regex.compile("(?i)(?:<|\\<|《|\\[|【)\\s*(intimacy|trust|亲密度|亲密变化|信任度|信任值|信任变化|openness|conscientiousness|extraversion|agreeableness|neuroticism)\\s*[:：]\\s*([^>\\>》\\]】]+)\\s*(?:>|\\>|》|\\]|】)")
		var matches = regex.search_all(reply)
		var has_changes = false
		var relationship_feedback: Dictionary = {}
		var personality_feedback: Dictionary = {}
		
		for m in matches:
			var tag = m.get_string(1).to_lower()
			var val = m.get_string(2).strip_edges()
			var f_val = val.to_float()
			
			if tag == "intimacy" or tag.begins_with("亲密"):
				relationship_feedback["intimacy"] = float(relationship_feedback.get("intimacy", 0.0)) + f_val
			elif tag == "trust" or tag.begins_with("信任"):
				relationship_feedback["trust"] = float(relationship_feedback.get("trust", 0.0)) + f_val
			elif tag in ["openness", "conscientiousness", "extraversion", "agreeableness", "neuroticism"]:
				if f_val != 0.0:
					has_changes = true
					personality_feedback[tag] = float(personality_feedback.get(tag, 0.0)) + f_val
					_accumulated_stats[tag] += f_val
		if not relationship_feedback.is_empty():
			var sanitized_relationships = GameDataManager.personality_system.sanitize_llm_relationship_deltas(relationship_feedback)
			var intimacy_delta = float(sanitized_relationships.get("intimacy", 0.0))
			var trust_delta = float(sanitized_relationships.get("trust", 0.0))
			if abs(intimacy_delta) > 0.001:
				GameDataManager.profile.update_intimacy(intimacy_delta)
				has_changes = true
				_accumulated_stats["intimacy"] += intimacy_delta
			if abs(trust_delta) > 0.001:
				GameDataManager.profile.update_trust(trust_delta)
				has_changes = true
				_accumulated_stats["trust"] += trust_delta
		if not personality_feedback.is_empty():
			GameDataManager.personality_system.apply_personality_feedback(
				GameDataManager.profile,
				personality_feedback,
				"main_scene_emotion",
				{
					"force_log": true
				}
			)
					
		if has_changes:
			GameDataManager.profile.save_profile()
			if stats_panel and stats_panel.has_method("_update_ui"):
				stats_panel._update_ui()
			if top_status_panel and top_status_panel.has_method("_update_ui"):
				top_status_panel._update_ui()
			_update_affection_button_ui()

func _on_options_response(response: Dictionary) -> void:
	if response.has("choices") and response["choices"].size() > 0:
		var reply = response["choices"][0]["message"]["content"]
		var json = JSON.new()
		
		# 提取可能的 JSON 代码块
		var json_str = reply
		var regex = RegEx.new()
		regex.compile("```(?:json)?\\s*(\\{[\\s\\S]*?\\})\\s*```")
		var match = regex.search(reply)
		if match:
			json_str = match.get_string(1).strip_edges()
		else:
			var start_idx = reply.find("{")
			var end_idx = reply.rfind("}")
			if start_idx != -1 and end_idx != -1 and end_idx > start_idx:
				json_str = reply.substr(start_idx, end_idx - start_idx + 1)
				
		if json.parse(json_str.strip_edges()) == OK:
			var data = json.get_data()
			if data is Dictionary and data.has("options") and data["options"] is Array:
				pending_options_data = data["options"]
				_try_show_options()
				return

func _try_show_options() -> void:
	if is_text_playback_finished and pending_options_data.size() > 0:
		if quick_option_layer:
			quick_option_layer.show()
		_rendered_quick_options = QuickOptionListHelper.normalize_dialogue_choice_options(pending_options_data)
		QuickOptionListHelper.populate_option_items_with_index(
			quick_options_container,
			_rendered_quick_options,
			_on_quick_option_selected,
			74.0
		)
		pending_options_data.clear()

func _on_quick_option_selected(text: String, index: int = -1) -> void:
	if index >= 0 and index < _rendered_quick_options.size():
		var option_data := _rendered_quick_options[index] as Dictionary
		var kind := str(option_data.get("kind", "")).strip_edges()
		if kind == "trust":
			GameDataManager.profile.update_intimacy(2)
			GameDataManager.profile.update_trust(6)
		else:
			GameDataManager.profile.update_intimacy(6)
			GameDataManager.profile.update_trust(2)
		
	input_field.text = text
	_on_send_pressed()

@onready var bg_container: Control = $BackgroundContainer
var current_bg_scene: Node = null
var bg_setting_panel_instance = null
var _main_bg_catalog: Array = []
var _main_bg_catalog_by_id: Dictionary = {}
var _phone_mode_active: bool = false
var _bg_transition_active: bool = false

func _load_main_bg_catalog() -> void:
	_main_bg_catalog.clear()
	_main_bg_catalog_by_id.clear()
	if not FileAccess.file_exists(MAIN_BACKGROUND_DATA_PATH):
		return
	var file = FileAccess.open(MAIN_BACKGROUND_DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data = json.get_data()
		for entry in data.get("backgrounds", []):
			if entry is Dictionary:
				var final_entry: Dictionary = entry.duplicate(true)
				var bg_id := str(final_entry.get("id", "")).strip_edges()
				if bg_id == "":
					continue
				_main_bg_catalog.append(final_entry)
				_main_bg_catalog_by_id[bg_id] = final_entry
	file.close()

func _match_main_bg_id_from_path(path: String) -> String:
	var target_path := path.strip_edges()
	if target_path == "":
		return ""
	for entry in _main_bg_catalog:
		if str(entry.get("path", "")).strip_edges() == target_path:
			return str(entry.get("id", ""))
	return ""

func _ensure_main_bg_unlock_state() -> void:
	if not GameDataManager.config or _main_bg_catalog.is_empty():
		return

	var dirty := false
	if GameDataManager.config.unlocked_main_bg_ids.is_empty():
		var default_ids: Array = []
		for entry in _main_bg_catalog:
			if bool(entry.get("default_unlocked", false)):
				default_ids.append(str(entry.get("id", "")))
		if default_ids.is_empty():
			default_ids.append(str(_main_bg_catalog[0].get("id", "")))
		GameDataManager.config.unlocked_main_bg_ids = default_ids
		dirty = true

	var current_bg_id := str(GameDataManager.config.current_main_bg_id).strip_edges()
	if current_bg_id == "" or not _main_bg_catalog_by_id.has(current_bg_id):
		current_bg_id = _match_main_bg_id_from_path(ImageManager.get_image_path("main_bg_scene"))
		if current_bg_id == "" and not GameDataManager.config.unlocked_main_bg_ids.is_empty():
			current_bg_id = str(GameDataManager.config.unlocked_main_bg_ids[0])
		if current_bg_id == "" and not _main_bg_catalog.is_empty():
			current_bg_id = str(_main_bg_catalog[0].get("id", ""))
		GameDataManager.config.current_main_bg_id = current_bg_id
		dirty = true

	if dirty:
		GameDataManager.config.save_config()

func _get_current_main_bg_id() -> String:
	if GameDataManager.config:
		var config_bg_id := str(GameDataManager.config.current_main_bg_id).strip_edges()
		if config_bg_id != "":
			return config_bg_id
	return _match_main_bg_id_from_path(ImageManager.get_image_path("main_bg_scene"))

func _resolve_current_main_bg_path() -> String:
	var bg_id := _get_current_main_bg_id()
	if bg_id != "" and _main_bg_catalog_by_id.has(bg_id):
		var scene_path := str(_main_bg_catalog_by_id[bg_id].get("path", "")).strip_edges()
		if scene_path != "" and ResourceLoader.exists(scene_path):
			return scene_path

	var main_bg_path = ImageManager.get_image_path("main_bg_scene")
	if main_bg_path != "" and ResourceLoader.exists(main_bg_path):
		return main_bg_path
	return "res://scenes/ui/main/backgrounds/locations/default_room_bg.tscn"

func _get_unlocked_main_bg_entries() -> Array:
	if _main_bg_catalog.is_empty():
		return []
	var unlocked_id_map: Dictionary = {}
	if GameDataManager.config:
		for bg_id in GameDataManager.config.unlocked_main_bg_ids:
			var final_id: String = str(bg_id).strip_edges()
			if final_id != "":
				unlocked_id_map[final_id] = true

	var display_entries: Array = []
	for entry in _main_bg_catalog:
		var final_entry: Dictionary = (entry as Dictionary).duplicate(true)
		var final_id: String = str(final_entry.get("id", "")).strip_edges()
		final_entry["unlocked"] = unlocked_id_map.has(final_id)
		display_entries.append(final_entry)

	return display_entries

func _ensure_bg_setting_panel() -> void:
	if is_instance_valid(bg_setting_panel_instance):
		return
	bg_setting_panel_instance = BackgroundSettingPanelScene.instantiate()
	add_child(bg_setting_panel_instance)
	bg_setting_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_setting_panel_instance.apply_requested.connect(_on_main_bg_apply_requested)

func _update_bg_switch_button_visibility() -> void:
	if not is_instance_valid(bg_switch_button):
		return
	var should_show = _phone_mode_active and is_instance_valid(mobile_interface_instance) and mobile_interface_instance.visible
	bg_switch_button.visible = should_show
	if should_show:
		move_child(bg_switch_button, -1)
		if is_instance_valid(bg_transition_fade):
			move_child(bg_transition_fade, -1)
		if is_instance_valid(bg_setting_panel_instance):
			move_child(bg_setting_panel_instance, -1)

func _hide_bg_setting_panel_immediately() -> void:
	if is_instance_valid(bg_setting_panel_instance):
		bg_setting_panel_instance.visible = false

func _on_bg_switch_pressed() -> void:
	if _bg_transition_active:
		return
	_animate_button(bg_switch_button)
	_ensure_bg_setting_panel()
	if bg_setting_panel_instance.visible:
		bg_setting_panel_instance.hide_panel()
		return
	bg_setting_panel_instance.show_panel(_get_unlocked_main_bg_entries(), _get_current_main_bg_id())

func _on_main_bg_apply_requested(bg_id: String) -> void:
	await _apply_main_background(bg_id)

func _apply_main_background(bg_id: String) -> void:
	var final_id := bg_id.strip_edges()
	if _bg_transition_active or final_id == "" or not _main_bg_catalog_by_id.has(final_id):
		return

	var target_entry: Dictionary = _main_bg_catalog_by_id[final_id]
	var target_path := str(target_entry.get("path", "")).strip_edges()
	if target_path == "" or not ResourceLoader.exists(target_path):
		return

	_bg_transition_active = true
	_hide_bg_setting_panel_immediately()
	bg_transition_fade.visible = true
	bg_transition_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	bg_transition_fade.modulate.a = 0.0
	var fade_in := create_tween()
	fade_in.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade_in.tween_property(bg_transition_fade, "modulate:a", 1.0, 0.38)
	await fade_in.finished
	await get_tree().create_timer(0.22).timeout

	_load_bg_scene(target_path)
	if GameDataManager.config:
		GameDataManager.config.current_main_bg_id = final_id
		if not GameDataManager.config.unlocked_main_bg_ids.has(final_id):
			GameDataManager.config.unlocked_main_bg_ids.append(final_id)
		GameDataManager.config.save_config()

	var fade_out := create_tween()
	fade_out.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade_out.tween_property(bg_transition_fade, "modulate:a", 0.0, 0.42)
	await fade_out.finished
	bg_transition_fade.visible = false
	bg_transition_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_transition_active = false

func _ready() -> void:
	# 动态加载主界面背景场景
	_load_main_bg_catalog()
	_ensure_main_bg_unlock_state()
	var main_bg_path = _resolve_current_main_bg_path()
	_load_bg_scene(main_bg_path)
			
	if GameDataManager.config:
		GameDataManager.config.apply_settings()
		
	var window = get_window()
	window.close_requested.connect(_on_close_requested)
	
	hide_ui_button.pressed.connect(_on_hide_ui_pressed)
	camera_button.pressed.connect(_on_camera_pressed)
	phone_button.pressed.connect(_on_phone_pressed)
	if bg_switch_button:
		bg_switch_button.pressed.connect(_on_bg_switch_pressed)
		bg_switch_button.visible = false
	if bg_transition_fade:
		bg_transition_fade.visible = false
		bg_transition_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg_transition_fade.modulate.a = 0.0
	affection_button.pressed.connect(_on_affection_pressed)
	affection_dismiss_button.pressed.connect(_hide_affection_popup)
	rest_button.pressed.connect(_on_rest_pressed)
	main_action_button.pressed.connect(_on_main_action_pressed)
	skill_button.pressed.connect(_on_skill_placeholder_pressed)
	diary_button.pressed.connect(_on_diary_pressed)
	if wechat_button:
		wechat_button.pressed.connect(_on_wechat_pressed)
	if wechat_unread_badge:
		var badge_style = StyleBoxFlat.new()
		badge_style.bg_color = Color("eb4545")
		badge_style.corner_radius_top_left = 11
		badge_style.corner_radius_top_right = 11
		badge_style.corner_radius_bottom_right = 11
		badge_style.corner_radius_bottom_left = 11
		wechat_unread_badge.add_theme_stylebox_override("normal", badge_style)
		var badge_bg = wechat_unread_badge.get_node_or_null("BadgeBg")
		if badge_bg:
			badge_bg.queue_free()
			
	if MobileFixedChatManager.has_signal("unread_count_changed"):
		MobileFixedChatManager.unread_count_changed.connect(_on_wechat_unread_changed)
	_on_wechat_unread_changed()
	
	if wardrobe_button:
		wardrobe_button.pressed.connect(_on_wardrobe_pressed)
	if wardrobe_panel:
		wardrobe_panel.outfit_changed.connect(_on_outfit_changed)
		
	if GameDataManager.profile and GameDataManager.profile.current_outfit != "default":
		call_deferred("_apply_saved_outfit")
	
	chat_button.pressed.connect(_on_main_chat_pressed)
	gift_button.pressed.connect(_on_gift_pressed)
	date_button.pressed.connect(_on_date_pressed)
	interactive_button.pressed.connect(_on_interactive_pressed)
	co_create_button.pressed.connect(_on_co_create_pressed)
	if end_chat_btn:
		end_chat_btn.pressed.connect(_on_end_chat_pressed)
	if history_btn:
		history_btn.pressed.connect(_on_history_pressed)
	if send_btn:
		send_btn.pressed.connect(_on_send_pressed)
	
	deepseek_client.chat_stream_started.connect(_on_chat_stream_started)
	deepseek_client.chat_stream_delta.connect(_on_chat_stream_delta)
	deepseek_client.chat_request_completed.connect(_on_chat_response)
	deepseek_client.options_request_completed.connect(_on_options_response)
	deepseek_client.emotion_request_completed.connect(_on_emotion_response)
	
	dialogue_panel.visible = false
	dialogue_panel.modulate.a = 0.0
	if quick_option_layer:
		quick_option_layer.hide()
	if dialogue_panel.has_signal("panel_clicked"):
		dialogue_panel.panel_clicked.connect(_on_dialogue_panel_gui_input)
	
	diary_notification.modulate.a = 0.0
	diary_notification.position.x = 1300 # Initial off-screen position
	
	audio_player = AudioStreamPlayer.new()
	audio_player.name = "MainTTSPlayer"
	add_child(audio_player)
	
	TTSManager.tts_success.connect(_on_tts_success)
	TTSManager.tts_failed.connect(_on_tts_failed)
			
	GameDataManager.character_switched.connect(_on_character_switched)
	_bind_profile_signals()
	
	if chat_button and GameDataManager.profile:
		chat_button.text = "与 " + GameDataManager.profile.char_name + " 聊天"
	
	_update_affection_button_ui()
	_setup_mood_hover_ui()
		
	# 动画：按钮点击弹性反馈 - 这些现在可以通过检查是否有 size 动态计算 pivot_offset
	# 或者我们在 inspector 中设置好的也会生效。这里保留以防有些按钮大小动态变化
	# 注意：已经在 _animate_button 里加了 btn.pivot_offset = btn.size / 2.0
	# 所以下面这些其实可以移除，但保留也没坏处
	camera_button.pivot_offset = camera_button.size / 2
	phone_button.pivot_offset = phone_button.size / 2
	rest_button.pivot_offset = rest_button.size / 2
	skill_button.pivot_offset = skill_button.size / 2
	hide_ui_button.pivot_offset = hide_ui_button.size / 2
	affection_button.pivot_offset = affection_button.size / 2
	if is_instance_valid(main_action_button):
		main_action_button.pivot_offset = main_action_button.size / 2
		
	# 恢复整个主窗口的鼠标输入响应，清除可能因为之前透明测试遗留的 passthrough 多边形
	if not is_queued_for_deletion():
		DisplayServer.window_set_mouse_passthrough(PackedVector2Array(), get_window().get_window_id())
	
	# Update StatsPanel explicitly when returning to main scene
	if stats_panel and stats_panel.has_method("_update_ui"):
		stats_panel._update_ui()
		
	if top_status_panel and top_status_panel.has_method("_update_ui"):
		top_status_panel._update_ui()
		
	# 尝试找回已存在的桌宠实例
	if get_tree().root.has_node("DesktopPet"):
		desktop_pet_instance = get_tree().root.get_node("DesktopPet")
		
	# 关联音乐播放器
	if is_instance_valid(music_player) and is_instance_valid(bgm):
		music_player.set_audio_player(bgm)
		
	# 初始化挂机检测
	var window_detector_path = "res://scripts/csharp/WindowDetector.cs"
	if FileAccess.file_exists(window_detector_path):
		var WindowDetectorObj = load(window_detector_path)
		if WindowDetectorObj:
			_window_detector = WindowDetectorObj.new()
			add_child(_window_detector)
			# 把当前主窗口的真实 HWND 传给 C# 层，用于精准判断
			var win_id = get_window().get_window_id()
			var hwnd = DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, win_id)
			if hwnd:
				_window_detector.call("SetMainHwnd", hwnd)
			
	_afk_timer = Timer.new()
	_afk_timer.wait_time = 1.0
	_afk_timer.autostart = true
	_afk_timer.timeout.connect(_check_afk_status)
	add_child(_afk_timer)
	_reset_idle_chatter_timer()

	# 先同步主按钮状态，避免下面的延迟逻辑执行期间仍保留旧文案和旧行为。
	_update_button_states_by_time()
	
	# 进入主场景后仍会先弹一次主动问候气泡；开场剧情标记只用于清理一次性状态。
	var should_try_memory_revisit: bool = GameDataManager.history and GameDataManager.history.messages.size() > 0
	if GameDataManager.get_meta("just_finished_intro_story", false):
		GameDataManager.set_meta("just_finished_intro_story", false)
	await get_tree().create_timer(1.0).timeout
	if is_inside_tree():
		_trigger_proactive_greeting()
		_reset_idle_chatter_timer()
	if should_try_memory_revisit:
		await get_tree().create_timer(2.8).timeout
		if is_inside_tree() and not _proactive_bubble_request_in_flight:
			if not (is_instance_valid(current_bg_scene) and current_bg_scene.has_method("is_idle_quote_playing") and current_bg_scene.is_idle_quote_playing()):
				_try_trigger_memory_revisit()

	if GameDataManager.story_time_manager:
		GameDataManager.story_time_manager.time_advanced.connect(_on_story_time_advanced)

func _process(delta: float) -> void:
	_update_main_scene_idle_chatter(delta)

func _input(event: InputEvent) -> void:
	if _is_idle_activity_event(event):
		_note_main_scene_activity()

func _is_idle_activity_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventScreenTouch:
		return event.pressed
	return false

func _reset_idle_chatter_timer(min_interval: float = MAIN_SCENE_IDLE_CHAT_MIN_SECONDS) -> void:
	_main_scene_idle_chat_elapsed = 0.0
	var clamped_min: float = clampf(min_interval, 1.0, MAIN_SCENE_IDLE_CHAT_MAX_SECONDS)
	_main_scene_idle_chat_interval = randf_range(clamped_min, MAIN_SCENE_IDLE_CHAT_MAX_SECONDS)

func _note_main_scene_activity() -> void:
	_reset_idle_chatter_timer()

func _can_trigger_idle_chatter() -> bool:
	if _is_afk or _story_mode_active or _bg_transition_active:
		return false
	if _phone_mode_active or (is_instance_valid(mobile_interface_instance) and mobile_interface_instance.visible):
		return false
	if is_instance_valid(camera_panel_instance) and camera_panel_instance.visible:
		return false
	if is_instance_valid(dialogue_panel) and dialogue_panel.visible:
		return false
	if _interaction_ui_locked_by_dialogue:
		return false
	if is_instance_valid(chat_scene_instance) and chat_scene_instance.visible:
		return false
	if is_instance_valid(schedule_panel_instance) and schedule_panel_instance.visible:
		return false
	if is_instance_valid(activity_panel_instance) and activity_panel_instance.visible:
		return false
	if is_instance_valid(history_panel_instance) and history_panel_instance.visible:
		return false
	if is_instance_valid(archive_panel_instance) and archive_panel_instance.visible:
		return false
	if is_instance_valid(wardrobe_panel) and wardrobe_panel.visible:
		return false
	if is_instance_valid(diary_panel) and diary_panel.visible:
		return false
	if is_instance_valid(affection_popup_frame) and affection_popup_frame.visible:
		return false
	if not is_instance_valid(current_bg_scene):
		return false
	if not current_bg_scene.has_method("request_idle_quote"):
		return false
	if current_bg_scene.has_method("is_idle_quote_playing") and current_bg_scene.is_idle_quote_playing():
		return false
	return true

func _trigger_main_scene_idle_chatter() -> bool:
	if not _can_trigger_idle_chatter():
		return false
	if current_bg_scene.has_method("request_idle_quote"):
		return bool(current_bg_scene.request_idle_quote())
	return false

func _update_main_scene_idle_chatter(delta: float) -> void:
	if not _can_trigger_idle_chatter():
		_main_scene_idle_chat_elapsed = 0.0
		return
	_main_scene_idle_chat_elapsed += delta
	if _main_scene_idle_chat_elapsed < _main_scene_idle_chat_interval:
		return
	if _trigger_main_scene_idle_chatter():
		_reset_idle_chatter_timer()
	else:
		_reset_idle_chatter_timer(MAIN_SCENE_IDLE_CHAT_RETRY_SECONDS)

func _get_interact_trigger_button() -> Button:
	if not is_instance_valid(current_bg_scene):
		return null
	return current_bg_scene.get_node_or_null("InteractTriggerButton") as Button

func _sync_interaction_entry_mutual_exclusion() -> void:
	var interact_trigger_btn := _get_interact_trigger_button()
	if interact_group and (_phone_mode_active or (is_instance_valid(mobile_interface_instance) and mobile_interface_instance.visible)):
		interact_group.visible = false
		interact_group.modulate.a = 0.0
	if interact_trigger_btn and (_phone_mode_active or (is_instance_valid(mobile_interface_instance) and mobile_interface_instance.visible)):
		interact_trigger_btn.visible = false
		interact_trigger_btn.modulate.a = 0.0
		return
	if not interact_trigger_btn or not interact_group:
		return

	if interact_trigger_btn.visible and interact_trigger_btn.modulate.a > 0.0:
		interact_group.visible = false
		interact_group.modulate.a = 0.0

func _update_button_states_by_time() -> void:
	if not GameDataManager.story_time_manager: return
	var date_dict = GameDataManager.story_time_manager.get_current_date_dict()
	var weekday = date_dict.weekday
	var current_hour = GameDataManager.story_time_manager.current_hour
	
	var interact_trigger_btn := _get_interact_trigger_button()

	if _interaction_ui_locked_by_dialogue or _phone_mode_active or (is_instance_valid(mobile_interface_instance) and mobile_interface_instance.visible):
		if interact_group:
			interact_group.visible = false
			interact_group.modulate.a = 0.0
		if interact_trigger_btn:
			interact_trigger_btn.visible = false
			interact_trigger_btn.modulate.a = 0.0
		return
	
	# 1. 休息到周六或周日：外出解禁，课程安排禁用，显示互动触发按钮
	if weekday == 0 or weekday == 6:
		if main_action_button:
			main_action_button.disabled = false
			main_action_button.text = "外出"
		_main_action_mode = "map"
		if interact_group: interact_group.visible = false
		if interact_trigger_btn:
			interact_trigger_btn.visible = true
			interact_trigger_btn.modulate.a = 1.0
		if rest_button:
			rest_button.show()
			rest_button.disabled = false
	else:
		# 周一到周五
		# 3. 到了周五晚上八点（20:00 及之后）：课程安排和外出都禁用，显示互动触发按钮
		if weekday == 5 and current_hour >= 20:
			if main_action_button:
				main_action_button.disabled = true
				main_action_button.text = "行程安排"
			_main_action_mode = "disabled"
			if interact_group: interact_group.visible = false
			if interact_trigger_btn:
				interact_trigger_btn.visible = true
				interact_trigger_btn.modulate.a = 1.0
			if rest_button:
				rest_button.show()
				rest_button.disabled = false
		else:
			# 2. 周内（周一至周五 20:00前）：外出禁用，隐藏互动触发按钮和互动组，只能进行课程安排
			if main_action_button:
				main_action_button.disabled = false
				main_action_button.text = "行程安排"
			_main_action_mode = "schedule"
			if interact_group: interact_group.visible = false
			if interact_trigger_btn: interact_trigger_btn.visible = false
			if rest_button:
				rest_button.hide()
				rest_button.disabled = true

func _set_interaction_ui_hidden_for_dialogue(hidden: bool) -> void:
	_interaction_ui_locked_by_dialogue = hidden

	if interact_group:
		interact_group.visible = false
		interact_group.modulate.a = 0.0

	var interact_trigger_btn := _get_interact_trigger_button()
	if not interact_trigger_btn:
		return

	if hidden:
		interact_trigger_btn.visible = false
		interact_trigger_btn.modulate.a = 0.0
	else:
		_update_button_states_by_time()

func _on_story_time_advanced(_days: int, _current_period: String) -> void:
	_update_button_states_by_time()

func _trigger_proactive_greeting() -> void:
	var event_manager = get_node_or_null("/root/EventManager")
	if event_manager and event_manager.has_method("execute_event"):
		event_manager.execute_event("proactive_greeting")

func _build_proactive_bubble_prompt(prompt_type: String) -> String:
	if GameDataManager.profile == null:
		return "只输出一句自然问候，不要括号动作，不要旁白。"

	var profile = GameDataManager.profile
	var stage_conf = profile.get_current_stage_config()
	var stage_title := str(stage_conf.get("stageTitle", "陌生人"))
	var stage_desc := str(stage_conf.get("stageDesc", ""))
	var player_name := str(profile.player_title).strip_edges()
	if player_name == "":
		player_name = "指导人"

	var type_desc := "玩家刚进入主场景，请你自然地主动打个招呼。"
	if prompt_type == "course":
		type_desc = "今天是新一周的开始，请你自然地主动聊一句和课程、安排或打起精神有关的话。"
	elif prompt_type == "daily":
		type_desc = "今天是周末，请你自然地主动聊一句和放松、休息或一起度过今天有关的话。"

	return "【系统指令】\n你是%s。\n玩家刚进入主场景，你想先主动和%s说一句话。\n%s\n当前关系阶段：%s。\n当前关系描述：%s。\n要求：\n1. 只输出一句成品台词。\n2. 字数控制在12到28字。\n3. 只保留说话内容，不要括号动作，不要旁白，不要解释，不要换行。\n4. 语气必须符合当前关系阶段与角色人设。\n5. 内容要像主场景里飘出的主动问候气泡。" % [
		profile.char_name,
		player_name,
		type_desc,
		stage_title,
		stage_desc
	]

func _show_proactive_greeting_bubble(raw_text: String) -> void:
	var final_text := raw_text.strip_edges()
	if final_text == "":
		final_text = "今天也一起慢慢来吧。"
	if not is_instance_valid(current_bg_scene):
		return
	if current_bg_scene.has_method("show_idle_quote_text"):
		current_bg_scene.show_idle_quote_text(final_text, true, 1.8, true)

func _on_proactive_greeting_generated(greeting_text: String) -> void:
	if not _proactive_bubble_request_in_flight:
		return
	_proactive_bubble_request_in_flight = false
	_show_proactive_greeting_bubble(greeting_text)

func _on_proactive_greeting_failed(_error_msg: String) -> void:
	if not _proactive_bubble_request_in_flight:
		return
	_proactive_bubble_request_in_flight = false
	var fallback := "今天也要陪在你身边。"
	if GameDataManager.story_time_manager:
		var weekday := int(GameDataManager.story_time_manager.get_current_date_dict().get("weekday", -1))
		if weekday == 1:
			fallback = "新的一周，也一起加油吧。"
		elif weekday == 0 or weekday == 6:
			fallback = "周末终于到了，想怎么放松呢？"
	_show_proactive_greeting_bubble(fallback)

func _try_trigger_memory_revisit() -> void:
	if dialogue_panel.visible or is_memory_revisit_active:
		return
	if GameDataManager.memory_manager == null:
		return
	var trigger_context = GameDataManager.memory_manager.build_story_memory_context()
	var revisit_data = GameDataManager.memory_manager.get_revisit_event_candidate(trigger_context)
	if revisit_data.is_empty():
		return
	GameDataManager.memory_manager.mark_memory_revisited(revisit_data.get("memory_id", ""), trigger_context)
	var event_manager = get_node_or_null("/root/EventManager")
	if event_manager and event_manager.has_method("execute_event"):
		event_manager.execute_event("memory_revisit", revisit_data)

func start_memory_revisit(revisit_data: Dictionary) -> void:
	if revisit_data.is_empty():
		return
	is_memory_revisit_active = true
	_set_main_chat_context(MAIN_CHAT_SUBTYPE_MEMORY)
	
	if _ui_tween:
		_ui_tween.kill()
	_ui_tween = create_tween()
	_ui_tween.tween_property(ui_panel, "modulate:a", 0.0, 0.3)
	_ui_tween.tween_callback(func(): ui_panel.visible = false)
	
	if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
		current_bg_scene.set_ui_hidden(true)
		
	# 如果通过对话点击事件，隐藏互动的气泡按钮等
	if is_instance_valid(current_bg_scene) and current_bg_scene.has_node("StoryButton"):
		var btn = current_bg_scene.get_node("StoryButton")
		var b_tween = create_tween()
		b_tween.tween_property(btn, "modulate:a", 0.0, 0.3)
		b_tween.tween_callback(func(): btn.visible = false)
		
	_set_interaction_ui_hidden_for_dialogue(true)
	
	dialogue_panel.visible = true
	dialogue_panel.modulate.a = 0.0
	var d_tween = create_tween()
	d_tween.tween_property(dialogue_panel, "modulate:a", 1.0, 0.3)
	
	dialogue_name_label.text = GameDataManager.profile.char_name
	dialogue_text.text = "..."
	_set_dialogue_input_waiting(GameDataManager.profile.char_name)
	
	if end_chat_btn:
		end_chat_btn.show()
	if history_btn:
		history_btn.show()
	if input_layer:
		input_layer.show()
	
	for child in quick_options_container.get_children():
		child.queue_free()
	if quick_option_layer:
		quick_option_layer.hide()
	
	var user_msg = GameDataManager.prompt_manager.build_memory_revisit_prompt(GameDataManager.profile, revisit_data, revisit_data.get("trigger_context", {}))
	deepseek_client.send_chat_message_stream(user_msg, "main_chat")

func start_proactive_greeting(prompt_type: String) -> void:
	if _proactive_bubble_request_in_flight:
		return
	if not is_instance_valid(current_bg_scene) or not current_bg_scene.has_method("show_idle_quote_text"):
		return

	_proactive_bubble_request_in_flight = true
	_set_main_chat_context(MAIN_CHAT_SUBTYPE_PROACTIVE)

	if deepseek_client.is_connected("npc_event_dialogue_completed", _on_proactive_greeting_generated):
		deepseek_client.npc_event_dialogue_completed.disconnect(_on_proactive_greeting_generated)
	if deepseek_client.is_connected("npc_event_dialogue_failed", _on_proactive_greeting_failed):
		deepseek_client.npc_event_dialogue_failed.disconnect(_on_proactive_greeting_failed)

	deepseek_client.npc_event_dialogue_completed.connect(_on_proactive_greeting_generated, CONNECT_ONE_SHOT)
	deepseek_client.npc_event_dialogue_failed.connect(_on_proactive_greeting_failed, CONNECT_ONE_SHOT)

	var npc_id := "luna"
	if GameDataManager.profile:
		var current_character_id := str(GameDataManager.profile.current_character_id).strip_edges()
		if current_character_id != "":
			npc_id = current_character_id

	deepseek_client.generate_npc_event_dialogue(npc_id, _build_proactive_bubble_prompt(prompt_type))

func start_farewell() -> void:
	if is_ending_chat:
		return
		
	if deepseek_client._chat_stream_active:
		deepseek_client._stop_chat_stream()
		
	stream_live_active = false
	stream_live_worker_running = false
	stream_live_queue.clear()
	
	if audio_player and audio_player.playing:
		audio_player.stop()
		
	if _typewriter_tween:
		_typewriter_tween.kill()
		
	is_ending_chat = true
	
	input_field.editable = false
	send_btn.disabled = true
	
	if end_chat_btn:
		end_chat_btn.hide()
	if history_btn:
		history_btn.hide()
	if input_layer:
		input_layer.hide()
		
	for child in quick_options_container.get_children():
		child.queue_free()
	if quick_option_layer:
		quick_option_layer.hide()
		
	var prompt = "【系统提示：玩家想要结束对话。请结合你当前的身份、心情和性格，说一句简短的结束语作为告别（必须包含括号动作描写）。绝对不要提到你是AI。】"
	deepseek_client.send_chat_message_stream(prompt, "main_chat")

func _add_neon_effect_to_button(btn: Button) -> void:
	if btn.has_meta("neon_style"):
		btn.remove_meta("neon_style")
	if btn.has_meta("neon_mat"):
		btn.remove_meta("neon_mat")

	if btn.name == "RestButton":
		var base_style = btn.get_theme_stylebox("normal")
		var style := (base_style.duplicate() as StyleBoxFlat) if base_style is StyleBoxFlat else StyleBoxFlat.new()
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_stylebox_override("focus", style)
		style.border_color = Color(0, 0, 0, 0)
		style.shadow_color = Color(0, 0, 0, 0)
		style.shadow_size = 0
		btn.set_meta("neon_style", style)
	elif btn.name == "MainActionButton":
		var style = btn.get_theme_stylebox("normal")
		var bg_color = Color(0.15, 0.16, 0.18, 0.7) # 默认的半透明灰色
		if style is StyleBoxFlat:
			bg_color = style.bg_color

		var source_material = btn.material as ShaderMaterial
		if source_material == null:
			# 无材质时退回普通 StyleBox 方案，保留当前按钮的斜切外观。
			var fallback_style := (style.duplicate() as StyleBoxFlat) if style is StyleBoxFlat else StyleBoxFlat.new()
			fallback_style.bg_color = bg_color
			fallback_style.border_color = Color(0, 0, 0, 0)
			fallback_style.shadow_color = Color(0, 0, 0, 0)
			fallback_style.shadow_size = 0
			btn.add_theme_stylebox_override("normal", fallback_style)
			btn.add_theme_stylebox_override("hover", fallback_style)
			btn.add_theme_stylebox_override("pressed", fallback_style)
			btn.add_theme_stylebox_override("focus", fallback_style)
			btn.set_meta("neon_style", fallback_style)
		else:
			var mat = source_material.duplicate() as ShaderMaterial
			btn.material = null

			var empty_style = StyleBoxEmpty.new()
			btn.add_theme_stylebox_override("normal", empty_style)
			btn.add_theme_stylebox_override("hover", empty_style)
			btn.add_theme_stylebox_override("pressed", empty_style)
			btn.add_theme_stylebox_override("focus", empty_style)

			var bg_rect = ColorRect.new()
			bg_rect.color = bg_color # 恢复半透明底色，让 Shader 去裁剪它

			var pad = 0.15
			var h = btn.size.y / (1.0 - 2.0 * pad)
			var w = btn.size.x + h * 2.0 * pad
			bg_rect.size = Vector2(w, h)
			bg_rect.position = Vector2(-h * pad, -h * pad)
			bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bg_rect.show_behind_parent = true

			mat.set_shader_parameter("padding", pad)
			mat.set_shader_parameter("aspect_ratio", w / h)
			mat.set_shader_parameter("border_width", 0.0)
			mat.set_shader_parameter("border_color", Color(0, 0, 0, 0))
			mat.set_shader_parameter("glow_size", 0.0)
			mat.set_shader_parameter("glow_color", Color(0, 0, 0, 0))

			# 关键修复：把原本的纯色背景色通过 shader parameter 传给 shader，让 shader 自己去画内部的半透明底色！
			if mat.get_shader().get_code().find("uniform vec4 bg_color") != -1:
				mat.set_shader_parameter("bg_color", bg_color)

			bg_rect.material = mat
			btn.add_child(bg_rect)
			btn.set_meta("neon_mat", mat)
		
	btn.mouse_entered.connect(_on_neon_btn_hover.bind(btn, true))
	btn.mouse_exited.connect(_on_neon_btn_hover.bind(btn, false))
	btn.button_down.connect(_on_neon_btn_press.bind(btn, true))
	btn.button_up.connect(_on_neon_btn_press.bind(btn, false))

func _on_neon_btn_hover(btn: Button, is_hover: bool) -> void:
	if btn.has_meta("neon_tween"):
		var tween = btn.get_meta("neon_tween") as Tween
		if tween: tween.kill()
	if btn.has_meta("neon_loop"):
		var loop = btn.get_meta("neon_loop") as Tween
		if loop: loop.kill()
		
	if btn.button_pressed: return
	
	var tween = create_tween().set_parallel(true)
	btn.set_meta("neon_tween", tween)
	
	var target_color = Color(0.0, 0.8, 1.0, 0.8) # 青蓝色
	var target_border = 1
	var target_shadow = 2
	var target_shader_border = 0.008
	var target_shader_glow = 0.015
	
	if not is_hover:
		target_color = Color(0, 0, 0, 0)
		target_border = 0
		target_shadow = 0
		target_shader_border = 0.0
		target_shader_glow = 0.0
		
	if btn.has_meta("neon_style"):
		var style = btn.get_meta("neon_style") as StyleBoxFlat
		tween.tween_property(style, "border_color", target_color, 0.3)
		tween.tween_property(style, "shadow_color", target_color, 0.3)
		tween.tween_property(style, "border_width_left", target_border, 0.3)
		tween.tween_property(style, "border_width_top", target_border, 0.3)
		tween.tween_property(style, "border_width_right", target_border, 0.3)
		tween.tween_property(style, "border_width_bottom", target_border, 0.3)
		tween.tween_property(style, "shadow_size", target_shadow, 0.3)
	elif btn.has_meta("neon_mat"):
		var mat = btn.get_meta("neon_mat") as ShaderMaterial
		tween.tween_method(func(v): mat.set_shader_parameter("border_color", v), mat.get_shader_parameter("border_color"), target_color, 0.3)
		tween.tween_method(func(v): mat.set_shader_parameter("glow_color", v), mat.get_shader_parameter("glow_color"), target_color, 0.3)
		tween.tween_method(func(v): mat.set_shader_parameter("border_width", v), mat.get_shader_parameter("border_width"), target_shader_border, 0.3)
		tween.tween_method(func(v): mat.set_shader_parameter("glow_size", v), mat.get_shader_parameter("glow_size"), target_shader_glow, 0.3)
		
	if is_hover:
		tween.chain().tween_callback(_start_neon_loop.bind(btn, Color(0.0, 0.8, 1.0, 0.8), Color(1.0, 0.0, 0.5, 0.8), 1.0))

func _on_neon_btn_press(btn: Button, is_pressed: bool) -> void:
	if btn.has_meta("neon_tween"):
		var tween = btn.get_meta("neon_tween") as Tween
		if tween: tween.kill()
	if btn.has_meta("neon_loop"):
		var loop = btn.get_meta("neon_loop") as Tween
		if loop: loop.kill()
		
	var tween = create_tween().set_parallel(true)
	btn.set_meta("neon_tween", tween)
	
	if is_pressed:
		var target_color = Color(1.0, 0.9, 0.2, 1.0) # 黄色/爆亮
		if btn.has_meta("neon_style"):
			var style = btn.get_meta("neon_style") as StyleBoxFlat
			tween.tween_property(style, "border_color", target_color, 0.1)
			tween.tween_property(style, "shadow_color", target_color, 0.1)
			tween.tween_property(style, "border_width_left", 1, 0.1)
			tween.tween_property(style, "border_width_top", 1, 0.1)
			tween.tween_property(style, "border_width_right", 1, 0.1)
			tween.tween_property(style, "border_width_bottom", 1, 0.1)
			tween.tween_property(style, "shadow_size", 2, 0.1)
		elif btn.has_meta("neon_mat"):
			var mat = btn.get_meta("neon_mat") as ShaderMaterial
			tween.tween_method(func(v): mat.set_shader_parameter("border_color", v), mat.get_shader_parameter("border_color"), target_color, 0.1)
			tween.tween_method(func(v): mat.set_shader_parameter("glow_color", v), mat.get_shader_parameter("glow_color"), target_color, 0.1)
			tween.tween_method(func(v): mat.set_shader_parameter("border_width", v), mat.get_shader_parameter("border_width"), 0.008, 0.1)
			tween.tween_method(func(v): mat.set_shader_parameter("glow_size", v), mat.get_shader_parameter("glow_size"), 0.015, 0.1)
			
		tween.chain().tween_callback(_start_neon_loop.bind(btn, Color(1.0, 0.9, 0.2, 1.0), Color(1.0, 0.2, 0.2, 1.0), 0.2))
	else:
		_on_neon_btn_hover(btn, btn.is_hovered())

func _start_neon_loop(btn: Button, color1: Color, color2: Color, duration: float) -> void:
	var loop = create_tween().set_loops()
	btn.set_meta("neon_loop", loop)
	
	if btn.has_meta("neon_style"):
		var style = btn.get_meta("neon_style") as StyleBoxFlat
		loop.tween_property(style, "border_color", color2, duration)
		loop.parallel().tween_property(style, "shadow_color", color2, duration)
		loop.tween_property(style, "border_color", color1, duration)
		loop.parallel().tween_property(style, "shadow_color", color1, duration)
	elif btn.has_meta("neon_mat"):
		var mat = btn.get_meta("neon_mat") as ShaderMaterial
		loop.tween_method(func(v): mat.set_shader_parameter("border_color", v), color1, color2, duration)
		loop.parallel().tween_method(func(v): mat.set_shader_parameter("glow_color", v), color1, color2, duration)
		loop.tween_method(func(v): mat.set_shader_parameter("border_color", v), color2, color1, duration)
		loop.parallel().tween_method(func(v): mat.set_shader_parameter("glow_color", v), color2, color1, duration)

func _check_afk_status() -> void:
	var window = get_window()
	var is_minimized = window.mode == Window.MODE_MINIMIZED
	
	var is_covered_fullscreen = false
	if is_instance_valid(_window_detector):
		is_covered_fullscreen = _window_detector.call("IsAnyFullScreenWindowCovering")
		
	var should_be_afk = is_minimized or is_covered_fullscreen
	
	if should_be_afk != _is_afk:
		_is_afk = should_be_afk
		if _is_afk:
			_on_enter_afk()
		else:
			_on_exit_afk()

func _on_enter_afk() -> void:
	print("[MainScene] 视为主场景后台挂机，暂停音乐与进度")
	if bgm:
		bgm.stream_paused = true
		
func _on_exit_afk() -> void:
	print("[MainScene] 退出后台挂机模式，恢复音乐与进度")
	if bgm:
		bgm.stream_paused = false
	_reset_idle_chatter_timer()

func _on_desktop_pet_pressed() -> void:
	if _is_ui_blocked(): return
	_toggle_desktop_pet()

func _toggle_desktop_pet() -> void:
	if is_instance_valid(desktop_pet_instance):
		# 桌宠已存在，关闭它。先隐藏以防止输入系统报错
		desktop_pet_instance.hide()
		desktop_pet_instance.queue_free()
		desktop_pet_instance = null
	else:
		# 创建桌宠，直接挂载在 root 下，这样切换场景也不会被销毁
		var DesktopPetObj = load("res://scenes/ui/desktop_pet/desktop_pet.tscn")
		desktop_pet_instance = DesktopPetObj.instantiate()
		get_tree().root.add_child(desktop_pet_instance)

func _on_skill_placeholder_pressed() -> void:
	if _is_ui_blocked(): return
	_animate_button(skill_button)
	ToastManager.show_system_toast("技能系统入口预留中", Color(0.57, 0.82, 0.76, 1))

func _on_incoming_call_accepted(char_id: String, is_video: bool, is_fixed: bool = false) -> void:
	# 接听电话：打开手机面板
	if mobile_interface_instance == null or not mobile_interface_instance.visible:
		_on_phone_pressed()
		
	# 告诉手机面板直接跳转到通话界面
	mobile_interface_instance.open_call_directly(char_id, is_video, is_fixed)

func _on_wechat_pressed() -> void:
	if wechat_unread_badge:
		wechat_unread_badge.hide()
	_stop_wechat_shake()

	if _is_ui_blocked(): return
	_animate_button(wechat_button)
	_ensure_mobile_interface()
	if mobile_interface_instance and mobile_interface_instance.has_method("open_wechat_directly"):
		await get_tree().process_frame
		mobile_interface_instance.open_wechat_directly(true)

var _wechat_shake_tween: Tween = null

func _on_wechat_unread_changed(char_id: String = "", unread_count: int = 0) -> void:
	var total_unread = MobileFixedChatManager.get_total_unread_count()
	if wechat_unread_badge:
		if total_unread > 0:
			wechat_unread_badge.text = str(total_unread)
			wechat_unread_badge.show()
			_start_wechat_shake()
		else:
			wechat_unread_badge.hide()
			_stop_wechat_shake()

func _start_wechat_shake() -> void:
	if not is_instance_valid(wechat_button):
		return
	if _wechat_shake_tween and _wechat_shake_tween.is_valid():
		return
		
	wechat_button.pivot_offset = wechat_button.size / 2.0
	_wechat_shake_tween = create_tween().set_loops()
	_wechat_shake_tween.tween_property(wechat_button, "rotation_degrees", 5.0, 0.1)
	_wechat_shake_tween.tween_property(wechat_button, "rotation_degrees", -5.0, 0.1)
	_wechat_shake_tween.tween_property(wechat_button, "rotation_degrees", 5.0, 0.1)
	_wechat_shake_tween.tween_property(wechat_button, "rotation_degrees", -5.0, 0.1)
	_wechat_shake_tween.tween_property(wechat_button, "rotation_degrees", 0.0, 0.1)
	_wechat_shake_tween.tween_interval(1.5)

func _stop_wechat_shake() -> void:
	if _wechat_shake_tween and _wechat_shake_tween.is_valid():
		_wechat_shake_tween.kill()
		_wechat_shake_tween = null
	if is_instance_valid(wechat_button):
		wechat_button.rotation_degrees = 0.0

func _ensure_mobile_interface() -> void:
	if mobile_interface_instance == null:
		var MobileInterfaceObj = load("res://scenes/ui/mobile/mobile_interface.tscn")
		mobile_interface_instance = MobileInterfaceObj.instantiate()
		add_child(mobile_interface_instance)
		mobile_interface_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mobile_interface_instance.app_opened.connect(_on_mobile_app_opened)
		mobile_interface_instance.phone_closing.connect(_on_phone_closing)
	
	if is_instance_valid(chat_scene_instance) and chat_scene_instance.visible:
		mobile_interface_instance.get_parent().remove_child(mobile_interface_instance)
		add_child(mobile_interface_instance)
		move_child(mobile_interface_instance, -1)

func _on_phone_pressed() -> void:
	if _is_ui_blocked(): return
	_animate_button(phone_button)
	_ensure_mobile_interface()
	_phone_mode_active = true
	if interact_group:
		interact_group.visible = false
		interact_group.modulate.a = 0.0
	
	if _ui_tween:
		_ui_tween.kill()
	_ui_tween = create_tween()
	_ui_tween.set_parallel(true)
	_ui_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_ui_tween.tween_property(ui_panel, "modulate:a", 0.0, 0.4)
	_ui_tween.tween_property(bg_container, "position:x", -245.0, 0.4)
	_ui_tween.chain().tween_callback(func(): ui_panel.visible = false)
	
	if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
		current_bg_scene.set_ui_hidden(true)
	_sync_interaction_entry_mutual_exclusion()
		
	mobile_interface_instance.show_phone()
	_update_bg_switch_button_visibility()

func _on_phone_closing() -> void:
	_phone_mode_active = false
	_update_bg_switch_button_visibility()
	_hide_bg_setting_panel_immediately()
	if _ui_tween:
		_ui_tween.kill()
	ui_panel.visible = true
	_ui_tween = create_tween()
	_ui_tween.set_parallel(true)
	_ui_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_ui_tween.tween_property(ui_panel, "modulate:a", 1.0, 0.4)
	_ui_tween.tween_property(bg_container, "position:x", 0.0, 0.4)
	
	if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
		current_bg_scene.set_ui_hidden(false)

func _on_mobile_app_opened(app_name: String) -> void:
	match app_name:
		"desktop_pet":
			_toggle_desktop_pet()

func _on_main_action_pressed() -> void:
	if _is_ui_blocked(): return
	_animate_button(main_action_button)
	if _main_action_mode == "map":
		print("[MainScene] Map button pressed")
		if GameDataManager.profile:
			if GameDataManager.profile.neuroticism >= 80.0:
				var ConfirmDialogObj = load("res://scenes/ui/common/confirm_dialog.tscn")
				var confirm_dialog = ConfirmDialogObj.instantiate()
				add_child(confirm_dialog)
				confirm_dialog.setup("她现在的状态不太好，把自己锁在房间\n里不愿意出门...\n(需要通过聊天或互动安抚情绪)")
				if confirm_dialog.cancel_button:
					confirm_dialog.cancel_button.hide()
				return
		SceneTransitionManager.transition_to_scene("res://scenes/ui/map/core/world_map_scene.tscn")
	elif _main_action_mode == "schedule":
		if activity_panel_instance == null:
			var ActivityPanelObj = load("res://scenes/ui/activity/activity_panel.tscn")
			activity_panel_instance = ActivityPanelObj.instantiate()
			add_child(activity_panel_instance)
			activity_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		activity_panel_instance.show_panel()

func _sync_background_weather_layer() -> void:
	var weather_bridge = get_tree().root.get_node_or_null("GameDataManager/WeatherBridge")
	if weather_bridge == null or not weather_bridge.has_method("set_weather_overlay_target"):
		return
	var weather_layer: Control = null
	if is_instance_valid(current_bg_scene):
		weather_layer = current_bg_scene.get_node_or_null("WeatherLayer") as Control
	weather_bridge.set_weather_overlay_target(weather_layer)

func _clear_background_weather_layer() -> void:
	var weather_bridge = get_tree().root.get_node_or_null("GameDataManager/WeatherBridge")
	if weather_bridge and weather_bridge.has_method("set_weather_overlay_target"):
		weather_bridge.set_weather_overlay_target(null)

func _load_bg_scene(path: String) -> void:
	if current_bg_scene != null:
		_clear_background_weather_layer()
		current_bg_scene.queue_free()
		current_bg_scene = null
		
	var bg_packed = load(path)
	if bg_packed:
		current_bg_scene = bg_packed.instantiate()
		bg_container.add_child(current_bg_scene)
		if current_bg_scene.has_signal("background_ready"):
			current_bg_scene.background_ready.connect(func(): print("[MainScene] Background Scene Ready: ", path))
			
		var story_btn = current_bg_scene.get_node_or_null("StoryButton")
		if story_btn:
			story_btn.pressed.connect(_on_galchat_pressed)
			story_btn.pivot_offset = story_btn.size / 2
			
		var interact_trigger_btn = current_bg_scene.get_node_or_null("InteractTriggerButton")
		if interact_trigger_btn:
			interact_trigger_btn.pressed.connect(_on_interact_trigger_pressed)
			interact_trigger_btn.pivot_offset = interact_trigger_btn.size / 2
		if _phone_mode_active and current_bg_scene.has_method("set_ui_hidden"):
			current_bg_scene.set_ui_hidden(true)
		_sync_background_weather_layer()
		_update_button_states_by_time()
	else:
		_sync_background_weather_layer()

func _on_interact_trigger_pressed() -> void:
	if _is_ui_blocked(): return
	var btn := _get_interact_trigger_button()
	if btn:
		_animate_button(btn)
		var tween = create_tween()
		tween.tween_property(btn, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func(): btn.visible = false)
		
	if interact_group:
		interact_group.modulate.a = 0.0
		interact_group.visible = true
		var g_tween = create_tween()
		g_tween.tween_property(interact_group, "modulate:a", 1.0, 0.3)
		g_tween.finished.connect(_sync_interaction_entry_mutual_exclusion, CONNECT_ONE_SHOT)

func _on_galchat_pressed() -> void:
	if _is_ui_blocked(): return
	if is_instance_valid(current_bg_scene) and current_bg_scene.has_node("StoryButton"):
		_animate_button(current_bg_scene.get_node("StoryButton"))
	
	_story_mode_active = true
	
	if _awaiting_topic_selection:
		_awaiting_topic_selection = false
		for child in quick_options_container.get_children():
			child.queue_free()
		if quick_option_layer:
			quick_option_layer.hide()
	
	if _ui_tween:
		_ui_tween.kill()
	_ui_tween = create_tween()
	_ui_tween.tween_property(ui_panel, "modulate:a", 0.0, 0.3)
	_ui_tween.tween_callback(func(): ui_panel.visible = false)
	
	if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
		current_bg_scene.set_ui_hidden(true)
		
	if is_instance_valid(current_bg_scene) and current_bg_scene.has_node("StoryButton"):
		var btn = current_bg_scene.get_node("StoryButton")
		var b_tween = create_tween()
		b_tween.tween_property(btn, "modulate:a", 0.0, 0.3)
		b_tween.tween_callback(func(): btn.visible = false)
		
	_set_interaction_ui_hidden_for_dialogue(true)
	
	if chat_scene_instance == null:
		chat_scene_instance = Control.new()
		chat_scene_instance.name = "EmbeddedDialogueManager"
		chat_scene_instance.visible = false
		chat_scene_instance.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chat_scene_instance.set_script(load("res://scripts/dialogue/dialogue_manager.gd"))
		chat_scene_instance.ui_panel_path = NodePath("../DialoguePanel")
		chat_scene_instance.dialogue_panel_path = NodePath("../DialoguePanel")
		chat_scene_instance.audio_player_path = NodePath("../MainTTSPlayer")
		chat_scene_instance.click_blocker_path = NodePath("")
		chat_scene_instance.character_layer_path = NodePath("")
		chat_scene_instance.free_chat_info_layer_path = NodePath("")
		add_child(chat_scene_instance)
		move_child(chat_scene_instance, -1)
		chat_scene_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		chat_scene_instance.chat_closed.connect(_on_chat_closed)
		
	chat_scene_instance.show_panel()
	if bgm.playing:
		bgm.stop()

func _on_chat_closed() -> void:
	_story_mode_active = false
	
	if dialogue_panel and dialogue_panel.visible:
		var d_tween = create_tween()
		d_tween.tween_property(dialogue_panel, "modulate:a", 0.0, 0.2)
		d_tween.tween_callback(func(): dialogue_panel.visible = false)
	
	if _ui_tween:
		_ui_tween.kill()
	ui_panel.visible = true
	ui_panel.modulate.a = 0.0
	_ui_tween = create_tween()
	_ui_tween.tween_property(ui_panel, "modulate:a", 1.0, 0.3)
	
	if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
		current_bg_scene.set_ui_hidden(false)
	
	if not bgm.playing:
		bgm.play()

func _on_history_pressed() -> void:
	if _is_ui_blocked(): return
	if _story_mode_active:
		return
	if history_panel_instance == null:
		var HistoryPanelObj = load("res://scenes/ui/history/history_panel.tscn")
		history_panel_instance = HistoryPanelObj.instantiate()
		add_child(history_panel_instance)
		history_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if history_panel_instance.has_signal("play_voice_requested"):
			history_panel_instance.play_voice_requested.connect(_play_cached_voice)
	
	if history_panel_instance.has_method("show_module"):
		history_panel_instance.show_module(DAILY_HISTORY_MODULE)
	else:
		history_panel_instance.show()

func _play_cached_voice(cache_key: String) -> void:
	var stream = TTSManager.load_cached_audio_by_key(cache_key)
	if stream and audio_player:
		audio_player.stream = stream
		audio_player.play()
		return

	var history_text := ""
	for msg in GameDataManager.history.messages:
		if str(msg.get("voice_cache_key", "")) == cache_key:
			history_text = str(msg.get("text", ""))
			break

	if history_text != "":
		var bbcode_regex = RegEx.new()
		bbcode_regex.compile("\\[/?[^\\]]+\\]")
		var clean_text = bbcode_regex.sub(history_text, "", true).strip_edges()
		clean_text = ChatSplitHelper.strip_parentheses(clean_text).strip_edges()
		if clean_text != "":
			TTSManager.synthesize(clean_text, {})
			return

	print("未找到语音缓存: ", cache_key)

func _on_close_requested() -> void:
	pass

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var desktop_pet = get_tree().root.get_node_or_null("DesktopPet")
		if is_instance_valid(desktop_pet) and desktop_pet.visible:
			# Godot 4 中，主场景是 Control 时，我们应该隐藏对应的 Window
			get_tree().root.hide()
		else:
			get_tree().quit()

var camera_panel_instance = null
var affection_panel_instance = null
var _goal_event_registry_cache: Dictionary = {}
var _goal_map_name_cache: Dictionary = {}

func _on_camera_pressed() -> void:
	if _is_ui_blocked(): return
	_animate_button(camera_button)
	if camera_panel_instance == null:
		var CameraPanelObj = load("res://scenes/ui/mobile/camera_panel.tscn")
		camera_panel_instance = CameraPanelObj.instantiate()
		get_tree().get_root().add_child(camera_panel_instance)
		camera_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		get_tree().get_root().move_child(camera_panel_instance, -1)
		
	camera_panel_instance.show_panel()
	
	if _ui_tween:
		_ui_tween.kill()
	_ui_tween = create_tween()
	_ui_tween.tween_property(ui_panel, "modulate:a", 0.0, 0.3)
	_ui_tween.tween_callback(func(): ui_panel.visible = false)
	
	if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
		current_bg_scene.set_ui_hidden(true)
		
	if camera_panel_instance.has_signal("camera_closed") and not camera_panel_instance.camera_closed.is_connected(_on_camera_closed):
		camera_panel_instance.camera_closed.connect(_on_camera_closed)

func _on_camera_closed() -> void:
	if _ui_tween:
		_ui_tween.kill()
	ui_panel.visible = true
	_ui_tween = create_tween()
	_ui_tween.tween_property(ui_panel, "modulate:a", 1.0, 0.3)
	
	if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
		current_bg_scene.set_ui_hidden(false)

func _on_affection_pressed() -> void:
	if _is_ui_blocked(): return
	_animate_button(affection_button)
	_show_affection_popup()

func _on_diary_pressed() -> void:
	if _is_ui_blocked(): return
	_animate_button(diary_button)
	diary_panel.show_diary()

func _on_wardrobe_pressed() -> void:
	if _is_ui_blocked(): return
	if is_instance_valid(wardrobe_button):
		_animate_button(wardrobe_button)
	if is_instance_valid(wardrobe_panel):
		wardrobe_panel.show()

func _apply_saved_outfit() -> void:
	if is_instance_valid(wardrobe_panel):
		if wardrobe_panel.outfits_data.is_empty():
			wardrobe_panel._load_data()
		_on_outfit_changed(GameDataManager.profile.current_outfit)

func _on_outfit_changed(new_id: String) -> void:
	print("[MainScene] 换装完成，当前服装 ID: ", new_id)
	# 替换背景里的立绘
	var bg_container = $BackgroundContainer
	if bg_container.get_child_count() > 0:
		var bg = bg_container.get_child(0)
		if bg and bg.has_node("LunaAni"):
			var luna_ani = bg.get_node("LunaAni")
			if is_instance_valid(luna_ani) and is_instance_valid(wardrobe_panel):
				# 从 wardrobe_panel 的数据中寻找新衣服的 sprite
				for outfit in wardrobe_panel.outfits_data:
					if outfit.get("id") == new_id:
						var sprite_path = outfit.get("sprite", "")
						if sprite_path != "" and ResourceLoader.exists(sprite_path):
							var res = load(sprite_path)
							if res is SpriteFrames:
								luna_ani.sprite_frames = res
								luna_ani.play("default")
							elif res is Texture2D:
								var frames = SpriteFrames.new()
								frames.add_animation("default")
								frames.add_frame("default", res)
								luna_ani.sprite_frames = frames
								luna_ani.play("default")
						break



func _on_location_selected(location_id: String):
	print("[MainScene] Transitioning to location: ", location_id)
	# The actual transition is currently handled inside world_map_scene.gd
	# But we can also handle hiding main UI here if needed

func show_diary_notification() -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(diary_notification, "position:x", 1280 - 300, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(diary_notification, "modulate:a", 1.0, 0.5)
	
	var out_tween = create_tween()
	out_tween.tween_interval(3.0)
	out_tween.tween_property(diary_notification, "position:x", 1300, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	out_tween.parallel().tween_property(diary_notification, "modulate:a", 0.0, 0.5)

func _on_hide_ui_pressed() -> void:
	if _is_ui_blocked(): return
	_animate_button(hide_ui_button)
	if _ui_tween:
		_ui_tween.kill()
	_ui_tween = create_tween()
	_ui_tween.tween_property(ui_panel, "modulate:a", 0.0, 0.3)
	_ui_tween.tween_callback(func(): ui_panel.visible = false)
	
	if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
		current_bg_scene.set_ui_hidden(true)

func _unhandled_input(event: InputEvent) -> void:
	if _story_mode_active:
		if not (event is InputEventKey and event.pressed and event.keycode == KEY_F12):
			return
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		var root = get_tree().root
		var debug_panel = root.get_node_or_null("GlobalDebugPanel")
		if debug_panel == null:
			if DEBUG_PANEL_SCENE == null:
				push_error("[MainScene] 无法加载调试面板场景：res://scenes/ui/story/debug_panel.tscn")
				get_viewport().set_input_as_handled()
				return
			debug_panel = DEBUG_PANEL_SCENE.instantiate()
			debug_panel.name = "GlobalDebugPanel"
			root.add_child(debug_panel)
			debug_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			
			# 如果当前是主场景，连上信号
			debug_panel.stage_changed.connect(func(stage: int):
				GameDataManager.history.messages.clear()
				GameDataManager.history.save_history()
				print("【Debug】强制切换情感阶段至：" + str(stage))
			)
			debug_panel.show_panel() # Instantiate and show directly
		elif debug_panel.visible:
			debug_panel.hide()
		else:
			debug_panel.show_panel()
		get_viewport().set_input_as_handled()
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# 如果手机界面存在且正在显示相机，不要显示UI
		if camera_panel_instance and camera_panel_instance.visible:
			return
			
		# 如果手机界面正在显示，不要因为点击而恢复UI
		if mobile_interface_instance and mobile_interface_instance.visible:
			return
			
		# 对话期间锁定互动入口，避免被点击空白等逻辑重新显示
		if _interaction_ui_locked_by_dialogue:
			return

		# 检查是否需要收起互动组
		if interact_group and interact_group.visible and interact_group.modulate.a > 0.99:
			var tween = create_tween()
			tween.tween_property(interact_group, "modulate:a", 0.0, 0.2)
			tween.tween_callback(func(): interact_group.visible = false)
			
			var btn := _get_interact_trigger_button()
			if btn:
				if not _story_mode_active and not (chat_scene_instance and chat_scene_instance.visible):
					btn.visible = true
					var b_tween = create_tween()
					b_tween.tween_property(btn, "modulate:a", 1.0, 0.3)
					b_tween.finished.connect(_sync_interaction_entry_mutual_exclusion, CONNECT_ONE_SHOT)
			
			get_viewport().set_input_as_handled()
			return
			
		if not ui_panel.visible or ui_panel.modulate.a < 0.99:
			get_viewport().set_input_as_handled()
			if _ui_tween:
				_ui_tween.kill()
			ui_panel.visible = true
			_ui_tween = create_tween()
			_ui_tween.tween_property(ui_panel, "modulate:a", 1.0, 0.3)
			
			if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
				current_bg_scene.set_ui_hidden(false)
			
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _awaiting_topic_selection:
			get_viewport().set_input_as_handled()
			_cancel_topic_selection()
func _on_character_switched(char_id: String) -> void:
	# 角色切换后更新主界面的面板（特别是数值显示）
	_bind_profile_signals()
	if stats_panel and stats_panel.has_method("_update_ui"):
		stats_panel._update_ui()
		
	if top_status_panel and top_status_panel.has_method("_update_ui"):
		top_status_panel._update_ui()
	
	if chat_button and GameDataManager.profile:
		chat_button.text = "与 " + GameDataManager.profile.char_name + " 聊天"
	
	_update_affection_button_ui()
		
	# 注意：ChatScene 的更新由它自己内部监听信号处理

func _animate_button(btn: Button) -> void:
	if btn == null:
		return
	btn.pivot_offset = btn.size / 2.0
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(0.9, 0.9), 0.05)
	tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.05)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.05)
