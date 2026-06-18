extends Control

signal course_completed(index: int)
signal all_courses_completed
signal schedule_finished

@export var slot_scene: PackedScene

const ScheduleEventPanelScene = preload("res://scenes/ui/activity/schedule_event_panel.tscn")
const DeepSeekClientLocator = preload("res://scripts/api/utils/deepseek_client_locator.gd")
const STAT_KEY_ALIASES := {
	"stat_stamina": "体能",
	"stat_rhythm": "反应",
	"stat_knowledge": "学识",
	"stat_expression": "表达",
	"stat_temperament": "气质",
	"stat_etiquette": "礼仪",
	"stat_aesthetics": "审美",
	"stat_perception": "感知",
	"vitality": "体能",
	"knowledge": "学识",
	"social": "表达",
	"gold": "金币",
	"mood": "心情"
}
const EVENT_CHANCE_BY_CATEGORY := {
	"physical_health": 0.28,
	"creation_design": 0.24,
	"music_dance_performance": 0.26,
	"social_etiquette": 0.22,
	"rest": 0.14
}
const MAX_SCHEDULE_RANDOM_EVENTS := 1
const LOCAL_EVENT_POOL_PATH := "res://assets/data/interaction/activity/local_schedule_events.json"

@onready var info_panel: Panel = $InfoPanel
@onready var top_image_rect: TextureRect = $InfoPanel/TopImageRect
@onready var title_label: Label = $InfoPanel/TitleContainer/TitleLabel
@onready var desc_label: Label = $InfoPanel/DescLabel
@onready var control_toolbar: PanelContainer = $ControlToolbar
@onready var track_panel: Panel = $TrackPanel
@onready var track_container: HBoxContainer = $TrackPanel/TrackMargin/TrackContainer
@onready var character_icon: Node2D = $TrackPanel/TrackMargin/TrackContainer/CharacterIcon
@onready var click_area: Button = $ClickArea

@onready var result_popup: Control = $ResultPopup
@onready var result_content_vbox: VBoxContainer = $ResultPopup/VBox/Content/Margin/VBox
@onready var stats_vbox: GridContainer = $ResultPopup/VBox/Content/Margin/VBox/StatsVBox
@onready var close_button: Button = $ResultPopup/CloseButton
@onready var result_panel_close_button: Button = $ResultPopup/PanelCloseButton

# Core stat UI nodes
@onready var core_phys_old: Label = $ResultPopup/VBox/Content/Margin/VBox/CoreStatsGrid/CorePhysical/Margin/HBox/OldVal
@onready var core_phys_new: Label = $ResultPopup/VBox/Content/Margin/VBox/CoreStatsGrid/CorePhysical/Margin/HBox/NewVal
@onready var core_phys_grade: Label = $ResultPopup/VBox/Content/Margin/VBox/CoreStatsGrid/CorePhysical/Margin/HBox/GradePanel/Margin/GradeLabel

@onready var core_int_old: Label = $ResultPopup/VBox/Content/Margin/VBox/CoreStatsGrid/CoreIntelligence/Margin/HBox/OldVal
@onready var core_int_new: Label = $ResultPopup/VBox/Content/Margin/VBox/CoreStatsGrid/CoreIntelligence/Margin/HBox/NewVal
@onready var core_int_grade: Label = $ResultPopup/VBox/Content/Margin/VBox/CoreStatsGrid/CoreIntelligence/Margin/HBox/GradePanel/Margin/GradeLabel

@onready var core_charm_old: Label = $ResultPopup/VBox/Content/Margin/VBox/CoreStatsGrid/CoreCharm/Margin/HBox/OldVal
@onready var core_charm_new: Label = $ResultPopup/VBox/Content/Margin/VBox/CoreStatsGrid/CoreCharm/Margin/HBox/NewVal
@onready var core_charm_grade: Label = $ResultPopup/VBox/Content/Margin/VBox/CoreStatsGrid/CoreCharm/Margin/HBox/GradePanel/Margin/GradeLabel

@onready var core_sens_old: Label = $ResultPopup/VBox/Content/Margin/VBox/CoreStatsGrid/CoreSensibility/Margin/HBox/OldVal
@onready var core_sens_new: Label = $ResultPopup/VBox/Content/Margin/VBox/CoreStatsGrid/CoreSensibility/Margin/HBox/NewVal
@onready var core_sens_grade: Label = $ResultPopup/VBox/Content/Margin/VBox/CoreStatsGrid/CoreSensibility/Margin/HBox/GradePanel/Margin/GradeLabel

# Footer UI nodes
@onready var footer_mood_val: Label = $ResultPopup/VBox/Footer/Margin/HBox/MoodHBox/Val
@onready var footer_mood_diff: Label = $ResultPopup/VBox/Footer/Margin/HBox/MoodHBox/Diff

@onready var footer_gold_val: Label = $ResultPopup/VBox/Footer/Margin/HBox/GoldHBox/Val
@onready var footer_gold_diff: Label = $ResultPopup/VBox/Footer/Margin/HBox/GoldHBox/Diff

@onready var auto_button: Button = $ControlToolbar/Margin/ControlButtons/AutoButton
@onready var skip_button: Button = $ControlToolbar/Margin/ControlButtons/SkipButton
@onready var loading_overlay: Control = $LoadingOverlay
@onready var loading_text: Label = $LoadingOverlay/VBox/LoadingText

var _is_auto_playing: bool = false
var _is_skipping: bool = false
var _result_anim_tween: Tween = null

var _courses_data: Array
var _start_attrs: Dictionary
var _base_end_attrs: Dictionary
var _end_attrs: Dictionary

var _current_slot_index: int = 0
var _is_moving: bool = false
var _slots: Array = []

var _current_event_panel: Node = null
var _current_event_desc: String = ""
var _current_event_options: Array = []
var _current_event_data: Dictionary = {}
var _current_event_course_index: int = -1
var _current_event_selected_option: String = ""
var _last_processed_course_index: int = -1
var _last_time_synced_course_index: int = -1
var _weekly_key_events: Array[Dictionary] = []
var _pending_event_attr_changes: Dictionary = {}
var _schedule_start_day_offset: int = 0
var _local_event_pool: Dictionary = {}
var _has_started_execution: bool = false
var _schedule_random_event_count: int = 0

func _ready() -> void:
	_local_event_pool = _load_local_event_pool()
	click_area.pressed.connect(_on_click_area_pressed)
	if info_panel and not info_panel.gui_input.is_connected(_on_info_panel_gui_input):
		info_panel.gui_input.connect(_on_info_panel_gui_input)
	if track_panel and not track_panel.gui_input.is_connected(_on_track_panel_gui_input):
		track_panel.gui_input.connect(_on_track_panel_gui_input)
	close_button.pressed.connect(_on_end_button_pressed)
	if result_panel_close_button and not result_panel_close_button.pressed.is_connected(_on_end_button_pressed):
		result_panel_close_button.pressed.connect(_on_end_button_pressed)
	
	if auto_button: auto_button.pressed.connect(_on_auto_pressed)
	if skip_button: skip_button.pressed.connect(_on_skip_pressed)
	if loading_overlay:
		loading_overlay.hide()
	
	# 初始状态
	result_popup.hide()
	close_button.hide()
	if is_instance_valid(result_panel_close_button):
		result_panel_close_button.hide()
	var guide_manager = get_node_or_null("/root/GuideManager")
	if guide_manager and guide_manager.has_method("on_schedule_execution_panel_ready"):
		guide_manager.on_schedule_execution_panel_ready(self)

func _load_local_event_pool() -> Dictionary:
	if not FileAccess.file_exists(LOCAL_EVENT_POOL_PATH):
		push_warning("本地课程事件配置不存在: %s" % LOCAL_EVENT_POOL_PATH)
		return {}

	var file = FileAccess.open(LOCAL_EVENT_POOL_PATH, FileAccess.READ)
	if file == null:
		push_warning("无法打开本地课程事件配置: %s" % LOCAL_EVENT_POOL_PATH)
		return {}

	var content = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(content) != OK:
		push_warning("本地课程事件配置解析失败: %s" % LOCAL_EVENT_POOL_PATH)
		return {}

	var data = json.get_data()
	if not data is Dictionary:
		push_warning("本地课程事件配置格式错误: %s" % LOCAL_EVENT_POOL_PATH)
		return {}

	return (data as Dictionary).duplicate(true)

func setup(courses_data: Array, start_attrs: Dictionary, end_attrs: Dictionary) -> void:
	_courses_data = courses_data
	_start_attrs = start_attrs.duplicate(true)
	_base_end_attrs = end_attrs.duplicate(true)
	_end_attrs = _base_end_attrs.duplicate(true)
	_last_processed_course_index = -1
	_last_time_synced_course_index = -1
	_current_event_course_index = -1
	_current_event_selected_option = ""
	_current_event_data.clear()
	_current_event_options.clear()
	_weekly_key_events.clear()
	_pending_event_attr_changes.clear()
	_has_started_execution = false
	_schedule_random_event_count = 0
	if GameDataManager.story_time_manager:
		_schedule_start_day_offset = GameDataManager.story_time_manager.current_day_offset
	else:
		_schedule_start_day_offset = 0
	
	_init_slots()
	
	# 初始展示第 1 个课程的内容
	_update_course_info(0)
	
	# 5. 角色小人初始位置
	character_icon.modulate.a = 0.0 # 先隐藏，避免闪烁
	
	await get_tree().process_frame
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_inside_tree(): return
	
	_reset_character_position()
	
	var t = create_tween()
	t.tween_property(character_icon, "modulate:a", 1.0, 0.2)


func _on_auto_pressed() -> void:
	_is_auto_playing = not _is_auto_playing
	if _is_auto_playing:
		auto_button.text = "停止"
		auto_button.add_theme_color_override("font_color", Color(0.26, 0.71, 0.97))
		_try_auto_next()
	else:
		auto_button.text = "自动"
		auto_button.remove_theme_color_override("font_color")

func _on_skip_pressed() -> void:
	_is_skipping = true
	_is_auto_playing = true
	auto_button.text = "自动"
	auto_button.remove_theme_color_override("font_color")
	_try_auto_next()

func _try_auto_next() -> void:
	if not is_inside_tree(): return
	var can_continue = _current_slot_index < 4 or (_current_slot_index == 4 and _last_processed_course_index < 4)
	if _is_auto_playing and not _is_moving and can_continue and not result_popup.visible and not _is_loading_visible() and _current_event_panel == null:
		_on_click_area_pressed()

func _is_loading_visible() -> bool:
	return loading_overlay != null and loading_overlay.visible

func _update_course_info(index: int) -> void:
	if index < 0 or index >= _courses_data.size(): return
	
	var current_course = _courses_data[index]
	var display_course: Dictionary = current_course
	if current_course.get("is_event", false):
		var pending_story_entry = _get_pending_story_entry(current_course)
		if pending_story_entry.is_empty():
			pending_story_entry = _get_first_story_entry(current_course)
		if not pending_story_entry.is_empty():
			display_course = current_course.duplicate(true)
			display_course["image_path"] = pending_story_entry.get("image_path", current_course.get("image_path", ""))
			display_course["desc"] = pending_story_entry.get("summary", current_course.get("desc", "缺少课程描述..."))
			display_course["period"] = pending_story_entry.get("period", current_course.get("period", ""))
	
	# 1. 顶部配图
	if display_course.has("image_path") and not display_course["image_path"].is_empty():
		var img_path = display_course["image_path"]
		var bg_path = ImageManager.get_image_path(img_path)
		if bg_path != "":
			img_path = bg_path
		if ResourceLoader.exists(img_path):
			top_image_rect.texture = load(img_path)
		else:
			top_image_rect.texture = null
	else:
		top_image_rect.texture = null
		
	# 2. 标题与描述
	var c_name = display_course.get("name", "未知课程")
	title_label.text = tr(c_name)
	
	desc_label.text = display_course.get("desc", "缺少课程描述...")

func _init_slots() -> void:
	for child in track_container.get_children():
		if child != character_icon:
			child.queue_free()
	_slots.clear()
	
	for i in range(5):
		var slot = slot_scene.instantiate()
		track_container.add_child(slot)
		# 让所有槽位都在小人节点之前
		track_container.move_child(slot, i)
		var course_data: Dictionary = {}
		if i < _courses_data.size():
			course_data = _courses_data[i]
		slot.setup(str(i + 1), course_data)
		_slots.append(slot)
	
	_current_slot_index = 0
	_refresh_slot_states()
	
	# 重置小人的显示状态（修复“两个我”的问题）
	character_icon.show()
	character_icon.modulate.a = 1.0

func _refresh_slot_states() -> void:
	for i in range(_slots.size()):
		var slot = _slots[i]
		if slot == null:
			continue
		if _current_slot_index == 4 and _last_processed_course_index >= 4:
			slot.set_state("completed")
		elif i < _current_slot_index:
			slot.set_state("completed")
		elif i == _current_slot_index:
			slot.set_state("current")
		else:
			slot.set_state("pending")

func _reset_character_position() -> void:
	if _slots.is_empty(): return
	var current_slot = _slots[_current_slot_index]
	# 需要在 yield 之后调用，确保 global_position 计算准确
	var char_size = Vector2(50, 50)
	if character_icon is AnimatedSprite2D:
		char_size = Vector2(0, 0) # AnimatedSprite2D 的中心通常在坐标原点
	character_icon.global_position = current_slot.global_position + (current_slot.size - char_size) / 2.0

func _get_day_label(course_index: int) -> String:
	var weekdays = ["周六", "周日", "周一", "周二", "周三", "周四", "周五"]
	var absolute_day = _schedule_start_day_offset + course_index
	return weekdays[posmod(absolute_day, weekdays.size())]
	return "本日"

func _build_bonus_summary(course_data: Dictionary) -> String:
	var parts: Array[String] = []
	for bonus in course_data.get("bonus_list", []):
		parts.append("%s+%s" % [str(bonus.get("name", "")), str(bonus.get("value", 0))])
	return "、".join(parts) if not parts.is_empty() else "无明显加成"

func _build_schedule_event_context(course_index: int) -> Dictionary:
	var course_data = _courses_data[course_index]
	var mood_value = int(_end_attrs.get("心情", _start_attrs.get("心情", 50)))
	var mood_data = GameDataManager.mood_system.get_macro_mood(mood_value)
	return {
		"course_index": course_index,
		"course_name": course_data.get("name", "未知课程"),
		"course_desc": course_data.get("desc", ""),
		"category_id": course_data.get("category_id", "rest"),
		"category_name": course_data.get("category_name", "综合课程"),
		"day_label": _get_day_label(course_index),
		"bonus_summary": _build_bonus_summary(course_data),
		"mood": mood_value,
		"mood_name": str(mood_data.get("name", "平静")),
		"mood_tag": str(mood_data.get("id", "calm"))
	}


func _build_attr_changes_summary(raw_changes: Dictionary) -> String:
	var normalized = _normalize_attr_changes(raw_changes)
	var ordered_keys = ["体能", "反应", "学识", "表达", "气质", "礼仪", "审美", "感知", "心情", "金币"]
	var parts: Array[String] = []
	for key in ordered_keys:
		if not normalized.has(key):
			continue
		var value = int(normalized[key])
		if value == 0:
			continue
		parts.append("%s%s%d" % [key, "+" if value > 0 else "", value])
	return "、".join(parts)

func _record_weekly_key_event(event_info: Dictionary) -> void:
	if event_info.is_empty():
		return
	_weekly_key_events.append(event_info.duplicate(true))

func _clear_weekly_event_summary_ui() -> void:
	if not is_instance_valid(result_content_vbox):
		return
	var old_separator = result_content_vbox.get_node_or_null("WeeklyEventSeparator")
	if old_separator:
		result_content_vbox.remove_child(old_separator)
		old_separator.queue_free()
	var old_section = result_content_vbox.get_node_or_null("WeeklyEventSection")
	if old_section:
		result_content_vbox.remove_child(old_section)
		old_section.queue_free()

func _render_weekly_event_summary() -> void:
	_clear_weekly_event_summary_ui()
	if _weekly_key_events.is_empty() or not is_instance_valid(result_content_vbox):
		return

	var separator = HSeparator.new()
	separator.name = "WeeklyEventSeparator"
	separator.add_theme_constant_override("separation", 10)
	result_content_vbox.add_child(separator)

	var section = VBoxContainer.new()
	section.name = "WeeklyEventSection"
	section.add_theme_constant_override("separation", 10)
	result_content_vbox.add_child(section)

	var title = Label.new()
	title.text = "本周关键事件"
	title.add_theme_color_override("font_color", Color(0.25, 0.23, 0.2, 1))
	title.add_theme_font_size_override("font_size", 18)
	section.add_child(title)

	for event_info in _weekly_key_events:
		var card = PanelContainer.new()
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color(0.9607843, 0.98039216, 0.96862745, 0.92)
		card_style.border_width_left = 1
		card_style.border_width_top = 1
		card_style.border_width_right = 1
		card_style.border_width_bottom = 1
		card_style.border_color = Color(0.82, 0.9, 0.88, 0.95)
		card_style.corner_radius_top_left = 12
		card_style.corner_radius_top_right = 12
		card_style.corner_radius_bottom_right = 12
		card_style.corner_radius_bottom_left = 12
		card.add_theme_stylebox_override("panel", card_style)
		section.add_child(card)

		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_bottom", 10)
		card.add_child(margin)

		var card_vbox = VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 6)
		margin.add_child(card_vbox)

		var header = Label.new()
		header.text = "%s | %s" % [
			str(event_info.get("day_label", "本周")),
			str(event_info.get("event_title", event_info.get("course_name", "关键事件")))
		]
		header.add_theme_color_override("font_color", Color(0.19, 0.47, 0.44, 1))
		header.add_theme_font_size_override("font_size", 16)
		card_vbox.add_child(header)

		var course_name = str(event_info.get("course_name", ""))
		var chosen_option = str(event_info.get("chosen_option", ""))
		var result_desc = str(event_info.get("result_desc", event_info.get("summary", "")))
		var attr_summary = str(event_info.get("attr_summary", ""))

		var detail_parts: Array[String] = []
		if course_name != "":
			detail_parts.append("课程：%s" % course_name)
		if chosen_option != "":
			detail_parts.append("选择：%s" % chosen_option)
		if result_desc != "":
			detail_parts.append(result_desc)
		if attr_summary != "":
			detail_parts.append("变化：%s" % attr_summary)

		var detail = Label.new()
		detail.text = "\n".join(detail_parts)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_theme_color_override("font_color", Color(0.38, 0.34, 0.3, 1))
		detail.add_theme_font_size_override("font_size", 14)
		card_vbox.add_child(detail)

func _get_local_schedule_event(context: Dictionary) -> Dictionary:
	if _local_event_pool.is_empty():
		_local_event_pool = _load_local_event_pool()
	var category_id = str(context.get("category_id", "rest"))
	var pool = _local_event_pool.get(category_id, _local_event_pool.get("rest", []))
	if pool.is_empty():
		return {}
	var mood_tag = str(context.get("mood_tag", "calm"))
	var weighted_pool: Array[int] = []
	for i in range(pool.size()):
		var event_entry = pool[i] as Dictionary
		var weight = 1
		var tags = event_entry.get("mood_tags", [])
		if tags is Array and not tags.is_empty():
			weight = _get_mood_match_weight(mood_tag, tags)
		for _j in range(weight):
			weighted_pool.append(i)
	var idx = weighted_pool[randi() % weighted_pool.size()] if not weighted_pool.is_empty() else randi() % pool.size()
	var event_data = (pool[idx] as Dictionary).duplicate(true)
	if not event_data.has("event_title"):
		event_data["event_title"] = "%s事件" % str(context.get("category_name", "课程"))
	return event_data

func _get_mood_match_weight(current_mood: String, tags: Array) -> int:
	var best_weight := 1
	for tag in tags:
		var target_mood = str(tag)
		var distance = _get_mood_distance(current_mood, target_mood)
		var weight = 1
		match distance:
			0:
				weight = 8
			1:
				weight = 4
			2:
				weight = 2
			_:
				weight = 1
		best_weight = max(best_weight, weight)
	return best_weight

func _get_mood_distance(from_mood: String, to_mood: String) -> int:
	var mood_order := {
		"broken": 0,
		"low": 1,
		"calm": 2,
		"pleasant": 3,
		"ecstatic": 4
	}
	var from_index = int(mood_order.get(from_mood, 2))
	var to_index = int(mood_order.get(to_mood, 2))
	return absi(from_index - to_index)

func _normalize_attr_changes(raw_changes: Dictionary) -> Dictionary:
	var normalized := {}
	for raw_key in raw_changes.keys():
		var final_key = STAT_KEY_ALIASES.get(str(raw_key), str(raw_key))
		normalized[final_key] = int(raw_changes[raw_key])
	return normalized

func _apply_attr_changes_to_target(raw_changes: Dictionary, target_attrs: Dictionary) -> void:
	var changes = _normalize_attr_changes(raw_changes)
	for attr in changes.keys():
		var val = int(changes[attr])
		if target_attrs.has(attr):
			target_attrs[attr] += val
		else:
			target_attrs[attr] = _start_attrs.get(attr, 0) + val
	target_attrs["心情"] = clamp(int(target_attrs.get("心情", 0)), 0, 100)
	target_attrs["金币"] = max(0, int(target_attrs.get("金币", 0)))

func _accumulate_pending_event_attr_changes(raw_changes: Dictionary) -> void:
	var changes = _normalize_attr_changes(raw_changes)
	for attr in changes.keys():
		_pending_event_attr_changes[attr] = int(_pending_event_attr_changes.get(attr, 0)) + int(changes[attr])

func _rebuild_final_end_attrs() -> void:
	_end_attrs = _base_end_attrs.duplicate(true)
	if not _pending_event_attr_changes.is_empty():
		_apply_attr_changes_to_target(_pending_event_attr_changes, _end_attrs)

func _set_story_time(day_offset: int, period: String, hour: int, minute: int) -> void:
	var time_manager = GameDataManager.story_time_manager
	if not time_manager:
		return

	var day_delta = day_offset - time_manager.current_day_offset
	if day_delta > 0:
		time_manager.advance_day(day_delta)
	else:
		time_manager.current_day_offset = day_offset

	var needs_manual_emit = day_delta <= 0
	if time_manager.current_period != period or time_manager.current_hour != hour or time_manager.current_minute != minute:
		time_manager.current_period = period
		time_manager.current_hour = hour
		time_manager.current_minute = minute
		needs_manual_emit = true

	if needs_manual_emit:
		time_manager.time_advanced.emit(0, time_manager.current_period)

func _sync_story_time_after_course(course_index: int) -> void:
	if course_index < 0:
		return
	var time_manager = GameDataManager.story_time_manager
	if not time_manager:
		return
	if course_index < 4:
		_set_story_time(_schedule_start_day_offset + course_index + 1, time_manager.PERIOD_MORNING, 8, 0)
	elif course_index == 4:
		_set_story_time(_schedule_start_day_offset + 4, time_manager.PERIOD_NIGHT, 20, 0)

func _has_remaining_schedule_random_event_quota() -> bool:
	return _schedule_random_event_count < MAX_SCHEDULE_RANDOM_EVENTS

func _consume_schedule_random_event_quota() -> void:
	_schedule_random_event_count = mini(MAX_SCHEDULE_RANDOM_EVENTS, _schedule_random_event_count + 1)

func _should_trigger_schedule_event(course_index: int, course_data: Dictionary) -> bool:
	if course_data.get("is_event", false):
		return false
	if str(course_data.get("script_path", "")).strip_edges() != "":
		return false
	if not _has_remaining_schedule_random_event_quota():
		return false
	var category_id = str(course_data.get("category_id", "rest"))
	var chance = float(EVENT_CHANCE_BY_CATEGORY.get(category_id, 0.2))
	var mood_value = float(_end_attrs.get("心情", 50))
	var low_mood_bonus = max(0.0, (50.0 - mood_value) * 0.002)
	var course_repeat_penalty = 0.0
	if course_index > 0 and _courses_data[course_index - 1].get("id", "") == course_data.get("id", ""):
		course_repeat_penalty = 0.03
	return randf() < clamp(chance + low_mood_bonus - course_repeat_penalty, 0.05, 0.45)

func _has_pending_story_event_at(course_index: int) -> bool:
	if course_index < 0 or course_index >= _courses_data.size():
		return false
	if course_index <= _last_processed_course_index:
		return false
	var course_data = _courses_data[course_index]
	if not bool(course_data.get("is_event", false)):
		return false
	return not _get_pending_story_entry(course_data).is_empty()

func _get_story_event_entries(course_data: Dictionary) -> Array:
	var entries = course_data.get("event_entries", [])
	if entries is Array and entries.size() > 0:
		return entries
	var fallback_script_path := str(course_data.get("script_path", "")).strip_edges()
	if fallback_script_path == "":
		return []
	return [{
		"event_id": fallback_script_path.get_file().get_basename(),
		"period": str(course_data.get("period", "")).strip_edges(),
		"script_path": fallback_script_path,
		"image_path": str(course_data.get("image_path", "")).strip_edges(),
		"summary": str(course_data.get("desc", "")).strip_edges()
	}]

func _get_first_story_entry(course_data: Dictionary) -> Dictionary:
	var entries = _get_story_event_entries(course_data)
	if entries.is_empty():
		return {}
	var first_entry = entries[0]
	return first_entry if first_entry is Dictionary else {}

func _get_pending_story_entry(course_data: Dictionary) -> Dictionary:
	var profile = GameDataManager.profile
	for raw_entry in _get_story_event_entries(course_data):
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		var event_id := str(entry.get("event_id", "")).strip_edges()
		if event_id == "":
			event_id = str(entry.get("script_path", "")).get_file().get_basename()
		if profile and event_id != "" and profile.has_finished_story(event_id):
			continue
		return entry
	return {}

func _try_trigger_immediate_story_event_for_current_slot() -> bool:
	if _is_moving or result_popup.visible:
		return false
	if _is_loading_visible():
		return false
	if _current_event_panel != null:
		return false
	if not _has_pending_story_event_at(_current_slot_index):
		return false
	var course_data = _courses_data[_current_slot_index]
	_trigger_story_script(course_data, _current_slot_index)
	return true

func _process_course_at_index(course_index: int) -> void:
	if course_index < 0 or course_index >= _courses_data.size():
		_finish_slot_move()
		return
	if course_index <= _last_processed_course_index:
		_finish_slot_move()
		return
	var course_data = _courses_data[course_index]
	if course_data.get("is_event", false):
		_trigger_story_script(course_data, course_index)
	elif _should_trigger_schedule_event(course_index, course_data):
		_trigger_schedule_event(course_index)
	else:
		_last_processed_course_index = max(_last_processed_course_index, course_index)
		_finish_slot_move()
	
func _on_click_area_pressed() -> void:
	var guide_manager = get_node_or_null("/root/GuideManager")
	if guide_manager and guide_manager.has_method("get_current_step_id"):
		var current_step_id := str(guide_manager.get_current_step_id())
		match current_step_id:
			"explain_execution_info_panel":
				if _is_mouse_inside_control(info_panel) and guide_manager.has_method("report_action"):
					guide_manager.report_action("schedule_execution_click_info_panel")
				return
			"explain_execution_track_panel":
				if guide_manager.has_method("report_action"):
					guide_manager.report_action("schedule_execution_finish_intro")
			"finish_execution_intro":
				if guide_manager.has_method("report_action"):
					guide_manager.report_action("schedule_execution_finish_intro")
			"explain_execution_panel":
				if guide_manager.has_method("report_action"):
					guide_manager.report_action("schedule_execution_click_area")
				return
	_advance_execution_progress(guide_manager)

func _advance_execution_progress(guide_manager: Node = null) -> void:
	if _is_moving:
		return
	if not _has_started_execution:
		_has_started_execution = true
		if guide_manager and guide_manager.has_method("report_action"):
			guide_manager.report_action("schedule_execution_advance")
		
	if _current_slot_index >= 4:
		if _last_processed_course_index < 4:
			_process_course_at_index(4)
		else:
			_show_result_popup()
		return
		
	_is_moving = true
	
	# 立即标记当前所在槽位为完成
	set_slot_status(_current_slot_index, true)
	course_completed.emit(_current_slot_index)
	
	var next_index = _current_slot_index + 1
	var target_slot = _slots[next_index]
	var char_size = Vector2(50, 50)
	if character_icon is AnimatedSprite2D:
		char_size = Vector2(0, 0)
	var target_pos = target_slot.global_position + (target_slot.size - char_size) / 2.0
	
	var duration = 0.05 if _is_skipping else 0.35
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(character_icon, "global_position", target_pos, duration)
	
	tween.finished.connect(func():
		_current_slot_index = next_index
		_process_course_at_index(next_index - 1)
	)

func _on_info_panel_gui_input(event: InputEvent) -> void:
	if not _is_left_click_press(event):
		return
	var guide_manager = get_node_or_null("/root/GuideManager")
	if guide_manager and guide_manager.has_method("get_current_step_id"):
		if str(guide_manager.get_current_step_id()) == "explain_execution_info_panel" and guide_manager.has_method("report_action"):
			guide_manager.report_action("schedule_execution_click_info_panel")
			accept_event()

func _on_track_panel_gui_input(event: InputEvent) -> void:
	if not _is_left_click_press(event):
		return
	var guide_manager = get_node_or_null("/root/GuideManager")
	if guide_manager and guide_manager.has_method("get_current_step_id"):
		if str(guide_manager.get_current_step_id()) == "explain_execution_track_panel" and guide_manager.has_method("report_action"):
			guide_manager.report_action("schedule_execution_finish_intro")
			_advance_execution_progress(guide_manager)
			accept_event()

func _is_left_click_press(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton):
		return false
	var mouse_event := event as InputEventMouseButton
	return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT

func _finish_slot_move(skip_ui_update: bool = false) -> void:
	_is_moving = false
	_refresh_slot_states()
	
	# 走到下一个槽位时，立刻刷新顶部的当前课程图文信息
	if not skip_ui_update:
		_update_course_info(_current_slot_index)
		if _try_trigger_immediate_story_event_for_current_slot():
			return
	
	# 每完成一节课后，精确同步到下一天上午；最后一节课结束后同步到周五夜晚
	if _last_processed_course_index >= 0 and _last_processed_course_index != _last_time_synced_course_index:
		_sync_story_time_after_course(_last_processed_course_index)
		_last_time_synced_course_index = _last_processed_course_index
		
	if _current_slot_index == 4 and _last_processed_course_index >= 4:
		# 走到最后一个槽位时，立刻将最后一个也标为完成
		set_slot_status(_current_slot_index, true)
		course_completed.emit(_current_slot_index)
		all_courses_completed.emit()
		_show_result_popup()
	elif _is_auto_playing:
		if not _is_skipping:
			await get_tree().create_timer(0.3).timeout
			if not is_inside_tree(): return
		_try_auto_next()

func _get_deepseek_client() -> Node:
	return DeepSeekClientLocator.find(self)

func _get_control_focus_rect(control: Control) -> Rect2:
	if not is_instance_valid(control):
		return Rect2()
	if not control.is_visible_in_tree():
		return Rect2()
	var rect := Rect2(Vector2.ZERO, control.size)
	var panel_origin: Vector2 = get_global_transform_with_canvas().origin
	var current: Node = control
	while current != null and current != self:
		if current is Control:
			rect.position += (current as Control).position
		current = current.get_parent()
	rect.position += panel_origin
	return rect

func _build_rounded_rect_polygon(rect: Rect2, radius: float, segments_per_corner: int = 6) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return polygon
	var final_radius := minf(radius, minf(rect.size.x * 0.5, rect.size.y * 0.5))
	if final_radius <= 0.5:
		return PackedVector2Array([
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		])
	_append_arc_points(
		polygon,
		Vector2(rect.end.x - final_radius, rect.position.y + final_radius),
		final_radius,
		-PI * 0.5,
		0.0,
		segments_per_corner
	)
	_append_arc_points(
		polygon,
		Vector2(rect.end.x - final_radius, rect.end.y - final_radius),
		final_radius,
		0.0,
		PI * 0.5,
		segments_per_corner
	)
	_append_arc_points(
		polygon,
		Vector2(rect.position.x + final_radius, rect.end.y - final_radius),
		final_radius,
		PI * 0.5,
		PI,
		segments_per_corner
	)
	_append_arc_points(
		polygon,
		Vector2(rect.position.x + final_radius, rect.position.y + final_radius),
		final_radius,
		PI,
		PI * 1.5,
		segments_per_corner
	)
	return polygon

func _append_arc_points(target: PackedVector2Array, center: Vector2, radius: float, start_angle: float, end_angle: float, segments: int) -> void:
	for index in range(segments + 1):
		var t := float(index) / float(maxi(1, segments))
		var angle := lerpf(start_angle, end_angle, t)
		var point := center + Vector2(cos(angle), sin(angle)) * radius
		if target.is_empty() or target[target.size() - 1].distance_to(point) > 0.25:
			target.append(point)

func _make_focus_entry(rect: Rect2, radius: float) -> Dictionary:
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return {}
	return {
		"rect": rect,
		"shape": "rect",
		"shape_params": {
			"corner_radius": radius
		},
		"cutout_polygon": _build_rounded_rect_polygon(rect, radius)
	}

func _is_mouse_inside_control(control: Control) -> bool:
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		return false
	var mouse_position := get_viewport().get_mouse_position()
	return _get_control_focus_rect(control).has_point(mouse_position)

func get_info_panel_focus_data() -> Variant:
	return _make_focus_entry(_get_control_focus_rect(info_panel), 22.0)

func get_track_panel_focus_data() -> Variant:
	return _make_focus_entry(_get_control_focus_rect(track_panel), 18.0)

func get_info_panel_target() -> Control:
	return info_panel

func get_track_panel_target() -> Control:
	return track_panel

func get_click_area_focus_data() -> Array:
	var focus_data: Array = []
	var info_rect: Rect2 = _get_control_focus_rect(info_panel)
	if info_rect.size.x > 1.0 and info_rect.size.y > 1.0:
		focus_data.append(_make_focus_entry(info_rect, 22.0))
	var track_rect: Rect2 = _get_control_focus_rect(track_panel)
	if track_rect.size.x > 1.0 and track_rect.size.y > 1.0:
		focus_data.append(_make_focus_entry(track_rect, 18.0))
	if is_instance_valid(control_toolbar) and control_toolbar.visible:
		var toolbar_rect: Rect2 = _get_control_focus_rect(control_toolbar)
		if toolbar_rect.size.x > 1.0 and toolbar_rect.size.y > 1.0:
			focus_data.append(_make_focus_entry(toolbar_rect, 14.0))
	return focus_data

func get_click_area_target() -> Control:
	return click_area

func get_result_close_button_focus_data() -> Variant:
	if is_instance_valid(close_button) and close_button.visible:
		return _make_focus_entry(_get_control_focus_rect(close_button), 14.0)
	if is_instance_valid(result_panel_close_button) and result_panel_close_button.visible:
		return _make_focus_entry(_get_control_focus_rect(result_panel_close_button), 8.0)
	return Rect2()

func get_result_close_button_target() -> Control:
	if is_instance_valid(close_button) and close_button.visible:
		return close_button
	if is_instance_valid(result_panel_close_button) and result_panel_close_button.visible:
		return result_panel_close_button
	return null

func is_result_close_button_ready_for_guide() -> bool:
	if not is_instance_valid(result_popup) or not result_popup.visible:
		return false
	if is_instance_valid(close_button) and close_button.is_visible_in_tree():
		return true
	if is_instance_valid(result_panel_close_button) and result_panel_close_button.is_visible_in_tree():
		return true
	return false

func has_started_execution() -> bool:
	return _has_started_execution

func _trigger_story_script(course_data: Dictionary, course_index: int) -> void:
	var story_entry = _get_pending_story_entry(course_data)
	var script_path = str(story_entry.get("script_path", course_data.get("script_path", ""))).strip_edges()
	if script_path == "" or not FileAccess.file_exists(script_path):
		_last_processed_course_index = max(_last_processed_course_index, course_index)
		_finish_slot_move()
		return
		
	# 实例化故事场景作为子节点
	# 黑屏过渡
	var transition_overlay = ColorRect.new()
	transition_overlay.color = Color.BLACK
	transition_overlay.modulate.a = 0.0
	transition_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_overlay.z_index = 100
	add_child(transition_overlay)
	
	var tween = create_tween()
	tween.tween_property(transition_overlay, "modulate:a", 1.0, 0.5)
	await tween.finished
	if not is_inside_tree(): return
	
	var story_scene = load("res://scenes/ui/story/story_scene.tscn").instantiate()
	GameDataManager.set_meta("play_specific_story", script_path)
	add_child(story_scene)
	story_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	story_scene.z_index = 50
	
	# 因为 story_scene 刚被 add_child，它可能会在 transition_overlay 之上
	# 确保 transition_overlay 在最上层
	move_child(transition_overlay, -1)
	
	# 【修复时序问题】：等待场景内部的 _ready 执行完毕，并让引擎完成第一帧渲染
	# 稍微加一点点延迟，确保剧情的背景和立绘都已经挂载完毕再淡出黑屏
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_inside_tree(): return
	
	# 淡出黑屏
	var tween2 = create_tween()
	tween2.tween_property(transition_overlay, "modulate:a", 0.0, 0.5)
	await tween2.finished
	if not is_inside_tree(): return
	transition_overlay.queue_free()
	
	# 等待故事结束
	await story_scene.chat_closed
	if not is_inside_tree(): return
	
	# 故事结束后，恢复黑屏过渡效果
	var out_overlay = ColorRect.new()
	out_overlay.color = Color.BLACK
	out_overlay.modulate.a = 0.0
	out_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	out_overlay.z_index = 100
	add_child(out_overlay)
	
	var tween3 = create_tween()
	tween3.tween_property(out_overlay, "modulate:a", 1.0, 0.5)
	await tween3.finished
	if not is_inside_tree(): return
	
	# 在黑屏完全遮挡住的时候，销毁故事场景，这样就不会有弹出关闭的突兀感
	if is_instance_valid(story_scene):
		story_scene.queue_free()
		
	# 【修复延迟问题】：在黑屏结束前，提前让底层的逻辑往下走，更新下一个日程界面的 UI 元素
	# 这里只调用纯 UI 的更新逻辑（如果是执行下一次移动），但是我们不直接触发动画，
	# 让底下的课程封面图、标题先变过去，并在黑屏中完成加载
	_update_course_info(_current_slot_index)
		
	# 确保在黑屏期间，底下的日常界面（如新的课程封面图等）能完成加载并渲染出一帧
	await get_tree().create_timer(0.3).timeout
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_inside_tree(): return
	
	# 然后再把黑屏淡出，展示底下的日常界面
	var tween4 = create_tween()
	tween4.tween_property(out_overlay, "modulate:a", 0.0, 0.5)
	await tween4.finished
	if not is_inside_tree(): return
	out_overlay.queue_free()
	
	# 由于前面已经提前更新了 UI，这里我们跳过 _update_course_info() 的二次调用，
	# 直接执行属性结算等后续动作
	_record_weekly_key_event({
		"type": "story",
		"day_label": _get_day_label(course_index),
		"course_name": course_data.get("name", "剧情事件"),
		"event_title": str(story_entry.get("event_id", course_data.get("name", "剧情事件"))).strip_edges(),
		"result_desc": str(story_entry.get("summary", course_data.get("desc", "触发了一段关键剧情。"))).strip_edges()
	})
	if _has_pending_story_event_at(course_index):
		_update_course_info(course_index)
		await get_tree().process_frame
		if not is_inside_tree(): return
		_trigger_story_script(course_data, course_index)
		return
	_last_processed_course_index = max(_last_processed_course_index, course_index)
	_finish_slot_move(true)

func _show_loading(text: String = "") -> void:
	if loading_overlay:
		var has_text = text.strip_edges() != ""
		if loading_text:
			loading_text.visible = has_text
			if has_text:
				loading_text.text = text
		loading_overlay.modulate.a = 0.0
		loading_overlay.show()
		var t = create_tween()
		t.tween_property(loading_overlay, "modulate:a", 1.0, 0.2)

func _hide_loading() -> void:
	if loading_overlay and loading_overlay.visible:
		var t = create_tween()
		t.tween_property(loading_overlay, "modulate:a", 0.0, 0.2)
		t.finished.connect(func():
			loading_overlay.hide()
			if loading_text:
				loading_text.visible = false
		)

func _trigger_schedule_event(course_index: int) -> void:
	var client = _get_deepseek_client()
	_current_event_course_index = course_index
	var context = _build_schedule_event_context(course_index)
	_current_event_data.clear()
	_current_event_options.clear()
	if not client:
		_on_schedule_event_generated(_get_local_schedule_event(context))
		return
		
	var course_data = _courses_data[course_index]
	var course_name = course_data.get("name", "未知课程")
	var course_desc = course_data.get("desc", "")
	
	_show_loading("课堂气氛忽然有些变化...")
	
	if not client.is_connected("schedule_event_generated", _on_schedule_event_generated):
		client.schedule_event_generated.connect(_on_schedule_event_generated)
	if not client.is_connected("schedule_event_error", _on_schedule_event_error):
		client.schedule_event_error.connect(_on_schedule_event_error)
		
	client.generate_schedule_event(course_name, course_desc, context)

func _on_schedule_event_generated(event_data: Dictionary) -> void:
	_hide_loading()
	
	var client = _get_deepseek_client()
	if client:
		if client.is_connected("schedule_event_generated", _on_schedule_event_generated):
			client.schedule_event_generated.disconnect(_on_schedule_event_generated)
		if client.is_connected("schedule_event_error", _on_schedule_event_error):
			client.schedule_event_error.disconnect(_on_schedule_event_error)
			
	_current_event_data = event_data.duplicate(true)
	if _current_event_data.is_empty():
		_current_event_data = _get_local_schedule_event(_build_schedule_event_context(_current_event_course_index))
	if _current_event_data.is_empty():
		_last_processed_course_index = max(_last_processed_course_index, _current_event_course_index)
		_finish_slot_move()
		return
	_consume_schedule_random_event_quota()
	
	_current_event_panel = ScheduleEventPanelScene.instantiate()
	add_child(_current_event_panel)
	
	_current_event_desc = _current_event_data.get("event_desc", "发生了一个随机事件。")
	var options = _current_event_data.get("options", [])
	_current_event_options.clear()
	
	var opt1 = "选项 1"
	var opt2 = "选项 2"
	if options.size() > 0:
		opt1 = options[0].get("text", "选项 1")
		_current_event_options.append(opt1)
	if options.size() > 1:
		opt2 = options[1].get("text", "选项 2")
		_current_event_options.append(opt2)
		
	_current_event_panel.setup(_current_event_desc, opt1, opt2, _current_event_data.get("event_title", "突发事件！"))
	_current_event_panel.option_selected.connect(_on_event_option_selected)
	if not _current_event_panel.result_confirmed.is_connected(_on_event_result_confirmed):
		_current_event_panel.result_confirmed.connect(_on_event_result_confirmed)

func _on_schedule_event_error(_error_msg: String) -> void:
	_hide_loading()
	
	var client = _get_deepseek_client()
	if client:
		if client.is_connected("schedule_event_generated", _on_schedule_event_generated):
			client.schedule_event_generated.disconnect(_on_schedule_event_generated)
		if client.is_connected("schedule_event_error", _on_schedule_event_error):
			client.schedule_event_error.disconnect(_on_schedule_event_error)
	
	_on_schedule_event_generated(_get_local_schedule_event(_build_schedule_event_context(_current_event_course_index)))

func _on_event_option_selected(idx: int) -> void:
	_show_loading("你的选择让事情有了新的走向...")
	
	var client = _get_deepseek_client()
	var course_data = _courses_data[_current_event_course_index]
	var course_name = course_data.get("name", "未知课程")
	var context = _build_schedule_event_context(_current_event_course_index)
	
	var chosen_option = "未知选项"
	if idx >= 0 and idx < _current_event_options.size():
		chosen_option = _current_event_options[idx]
	_current_event_selected_option = chosen_option
	
	var options = _current_event_data.get("options", [])
	if idx >= 0 and idx < options.size():
		var selected_option = options[idx]
		if selected_option is Dictionary and selected_option.has("attr_changes"):
			_on_schedule_event_resolved({
				"result_desc": selected_option.get("result_desc", "事件已处理。"),
				"attr_changes": selected_option.get("attr_changes", {})
			})
			return
		
	if not client.is_connected("schedule_event_resolved", _on_schedule_event_resolved):
		client.schedule_event_resolved.connect(_on_schedule_event_resolved)
	if not client.is_connected("schedule_event_resolve_error", _on_schedule_event_resolve_error):
		client.schedule_event_resolve_error.connect(_on_schedule_event_resolve_error)
		
	client.resolve_schedule_event(course_name, _current_event_desc, chosen_option, context)

func _cleanup_resolve_state() -> void:
	_hide_loading()
	
	if _current_event_panel:
		if _current_event_panel.option_selected.is_connected(_on_event_option_selected):
			_current_event_panel.option_selected.disconnect(_on_event_option_selected)
		if _current_event_panel.result_confirmed.is_connected(_on_event_result_confirmed):
			_current_event_panel.result_confirmed.disconnect(_on_event_result_confirmed)
		_current_event_panel.queue_free()
		_current_event_panel = null
	_current_event_data.clear()
	_current_event_course_index = -1
	_current_event_selected_option = ""
		
	var client = _get_deepseek_client()
	if client:
		if client.is_connected("schedule_event_resolved", _on_schedule_event_resolved):
			client.schedule_event_resolved.disconnect(_on_schedule_event_resolved)
		if client.is_connected("schedule_event_resolve_error", _on_schedule_event_resolve_error):
			client.schedule_event_resolve_error.disconnect(_on_schedule_event_resolve_error)


func _on_schedule_event_resolved(result_data: Dictionary) -> void:
	_hide_loading()
	var desc = result_data.get("result_desc", "事件已处理。")
	var changes = result_data.get("attr_changes", result_data.get("rewards", result_data.get("stat_changes", {})))
	var resolved_course_index = _current_event_course_index
	if resolved_course_index >= 0 and resolved_course_index < _courses_data.size():
		var course_data = _courses_data[resolved_course_index]
		_record_weekly_key_event({
			"type": "schedule_event",
			"day_label": _get_day_label(resolved_course_index),
			"course_name": course_data.get("name", "未知课程"),
			"event_title": _current_event_data.get("event_title", "突发事件"),
			"chosen_option": _current_event_selected_option,
			"result_desc": desc,
			"attr_summary": _build_attr_changes_summary(changes)
		})
	_accumulate_pending_event_attr_changes(changes)
	if _current_event_panel and is_instance_valid(_current_event_panel):
		_current_event_panel.show_result(desc, _normalize_attr_changes(changes))
		if _is_auto_playing or _is_skipping:
			await get_tree().create_timer(0.9 if _is_skipping else 1.6).timeout
			if _current_event_panel and is_instance_valid(_current_event_panel):
				_on_event_result_confirmed()
	else:
		_cleanup_resolve_state()
		_last_processed_course_index = max(_last_processed_course_index, resolved_course_index)
		_finish_slot_move()
	
func _on_schedule_event_resolve_error(_error_msg: String) -> void:
	_on_schedule_event_resolved({
		"result_desc": "你谨慎地处理了这次状况，课程顺利继续，没有额外波动。",
		"attr_changes": {}
	})

func _on_event_result_confirmed() -> void:
	var resolved_course_index = _current_event_course_index
	_cleanup_resolve_state()
	_last_processed_course_index = max(_last_processed_course_index, resolved_course_index)
	_finish_slot_move()

func _show_event_result_toast(msg: String) -> void:
	var toast = Label.new()
	toast.text = msg
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	toast.add_theme_font_size_override("font_size", 24)
	toast.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	toast.add_theme_color_override("font_outline_color", Color(1, 1, 1))
	toast.add_theme_constant_override("outline_size", 4)
	add_child(toast)
	
	var t = create_tween().set_parallel(true)
	t.tween_property(toast, "position:y", toast.position.y - 50, 2.0)
	t.tween_property(toast, "modulate:a", 0.0, 2.0)
	t.chain().tween_callback(func():
		toast.queue_free()
		_finish_slot_move()
	)

func set_slot_status(index: int, completed: bool) -> void:
	if index >= 0 and index < _slots.size():
		_slots[index].set_state("completed" if completed else "pending")

func _show_result_popup() -> void:
	_rebuild_final_end_attrs()
	result_popup.modulate.a = 0
	result_popup.show()
	click_area.hide()
	if is_instance_valid(result_panel_close_button):
		result_panel_close_button.hide()
	_render_weekly_event_summary()
	
	var tween = create_tween()
	tween.tween_property(result_popup, "modulate:a", 1.0, 0.3)
	
	var phys_keys = ["体能", "反应"]
	var int_keys = ["学识", "表达"]
	var charm_keys = ["气质", "礼仪"]
	var sens_keys = ["审美", "感知"]
	
	var get_core = func(attrs: Dictionary, keys: Array) -> int:
		var total = 0
		for k in keys:
			total += attrs.get(k, 0)
		return int(floor(total))
	
	var get_grade = func(val: float) -> String:
		var levels = [0, 800, 1400, 2000, 2800, 3600, 4400, 5200, 6000, 7200, 8000]
		var grades = ["E-", "E", "D", "D+", "C", "C+", "B", "B+", "A", "S"]
		var grade = "S+"
		for i in range(1, levels.size()):
			if val < levels[i]:
				grade = grades[i-1]
				break
		return grade
	
	var start_phys = get_core.call(_start_attrs, phys_keys)
	var end_phys = get_core.call(_end_attrs, phys_keys)
	core_phys_old.text = str(start_phys)
	core_phys_new.text = str(end_phys)
	core_phys_grade.text = " %s " % get_grade.call(end_phys)
	
	var start_int = get_core.call(_start_attrs, int_keys)
	var end_int = get_core.call(_end_attrs, int_keys)
	core_int_old.text = str(start_int)
	core_int_new.text = str(end_int)
	core_int_grade.text = " %s " % get_grade.call(end_int)
	
	var start_charm = get_core.call(_start_attrs, charm_keys)
	var end_charm = get_core.call(_end_attrs, charm_keys)
	core_charm_old.text = str(start_charm)
	core_charm_new.text = str(end_charm)
	core_charm_grade.text = " %s " % get_grade.call(end_charm)
	
	var start_sens = get_core.call(_start_attrs, sens_keys)
	var end_sens = get_core.call(_end_attrs, sens_keys)
	core_sens_old.text = str(start_sens)
	core_sens_new.text = str(end_sens)
	core_sens_grade.text = " %s " % get_grade.call(end_sens)
	
	# Footer variables
	var start_mood = _start_attrs.get("心情", GameDataManager.profile.mood_value)
	var end_mood = _end_attrs.get("心情", start_mood)
	footer_mood_val.text = str(end_mood)
	var diff_mood = end_mood - start_mood
	footer_mood_diff.text = ("+%d" % diff_mood) if diff_mood >= 0 else str(diff_mood)
	footer_mood_diff.add_theme_color_override("font_color", Color(0.26, 0.71, 0.97) if diff_mood >= 0 else Color(0.9, 0.4, 0.4))
	
	var start_gold = _start_attrs.get("金币", GameDataManager.profile.gold)
	var end_gold = _end_attrs.get("金币", start_gold)
	footer_gold_val.text = str(end_gold)
	var diff_gold = end_gold - start_gold
	footer_gold_diff.text = ("+%d" % diff_gold) if diff_gold >= 0 else str(diff_gold)
	footer_gold_diff.add_theme_color_override("font_color", Color(0.26, 0.71, 0.97) if diff_gold >= 0 else Color(0.9, 0.4, 0.4))
	
	for child in stats_vbox.get_children():
		child.queue_free()
		
	var sub_keys = [
		"体能", "反应",
		"学识", "表达",
		"气质", "礼仪",
		"审美", "感知"
	]
	
	for attr in sub_keys:
		var old_val = _start_attrs.get(attr, 0)
		var new_val = _end_attrs.get(attr, old_val)
		
		var hbox = HBoxContainer.new()
		hbox.custom_minimum_size = Vector2(160, 24)
		
		var name_lbl = Label.new()
		name_lbl.text = tr(attr)
		name_lbl.custom_minimum_size = Vector2(50, 0)
		name_lbl.add_theme_color_override("font_color", Color(0.4, 0.3, 0.2))
		hbox.add_child(name_lbl)
		
		var val_lbl = Label.new()
		val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		
		if new_val > old_val:
			var diff = new_val - old_val
			val_lbl.text = "%d (+%d)" % [old_val, diff]
			val_lbl.add_theme_color_override("font_color", Color(0.26, 0.71, 0.97))
			
			# 动画逻辑移出循环外统一处理
			pass
		else:
			val_lbl.text = str(old_val)
			val_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			
		hbox.add_child(val_lbl)
		stats_vbox.add_child(hbox)
		
	_result_anim_tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	_result_anim_tween.tween_method(func(v: float):
		for child in stats_vbox.get_children():
			var name_lbl = child.get_child(0)
			var val_lbl = child.get_child(1)
			var attr = name_lbl.text
			
			var old_v = _start_attrs.get(attr, 0)
			var new_v = _end_attrs.get(attr, old_v)
			if new_v > old_v:
				var diff = new_v - old_v
				var curr_v = lerp(float(old_v), float(new_v), v)
				val_lbl.text = "%d (+%d)" % [int(curr_v), diff]
	, 0.0, 1.0, 1.2)
	
	_result_anim_tween.finished.connect(func():
		_set_result_to_final()
	)

func _set_result_to_final() -> void:
	for child in stats_vbox.get_children():
		var name_lbl = child.get_child(0)
		var val_lbl = child.get_child(1)
		var attr = name_lbl.text
		var old_v = _start_attrs.get(attr, 0)
		var new_v = _end_attrs.get(attr, old_v)
		if new_v > old_v:
			val_lbl.text = "%d (+%d)" % [new_v, new_v - old_v]
			
	close_button.show()
	if is_instance_valid(result_panel_close_button):
		result_panel_close_button.show()

func _prepare_result_panel_for_scene_exit() -> void:
	if result_popup:
		result_popup.hide()
	if is_instance_valid(result_panel_close_button):
		result_panel_close_button.hide()
	if close_button:
		close_button.hide()
	if loading_overlay:
		loading_overlay.hide()

func _on_end_button_pressed() -> void:
	var guide_manager = get_node_or_null("/root/GuideManager")
	if guide_manager and guide_manager.has_method("report_action"):
		guide_manager.report_action("close_schedule_result_popup")
	var profile = GameDataManager.profile
	
	# Save course progress
	for course in _courses_data:
		var c_id = course.get("id", "")
		if c_id != "":
			var max_prog = course.get("max_progress", 0)
			if max_prog > 0:
				var increment = course.get("progress_increment", 0)
				var cur_prog = profile.course_progress.get(c_id, 0)
				profile.course_progress[c_id] = min(cur_prog + increment, max_prog)
	
	# Save attrs back to profile
	profile.stat_stamina = _end_attrs.get("体能", profile.stat_stamina)
	profile.stat_rhythm = _end_attrs.get("反应", profile.stat_rhythm)
	profile.stat_knowledge = _end_attrs.get("学识", profile.stat_knowledge)
	profile.stat_expression = _end_attrs.get("表达", profile.stat_expression)
	profile.stat_temperament = _end_attrs.get("气质", profile.stat_temperament)
	profile.stat_etiquette = _end_attrs.get("礼仪", profile.stat_etiquette)
	profile.stat_aesthetics = _end_attrs.get("审美", profile.stat_aesthetics)
	profile.stat_perception = _end_attrs.get("感知", profile.stat_perception)
	profile.gold = max(0, _end_attrs.get("金币", profile.gold))
	profile.mood_value = clamp(_end_attrs.get("心情", profile.mood_value), 0, 100)

	profile.save_profile()
	if GameDataManager.story_time_manager:
		GameDataManager.story_time_manager.save_data()
	GameDataManager.save_manager.auto_save()

	schedule_finished.emit()
	if SceneTransitionManager and SceneTransitionManager.has_method("transition_to_scene_with_mid_callback"):
		await SceneTransitionManager.transition_to_scene_with_mid_callback(
			"res://scenes/ui/main/main_scene.tscn",
			Callable(self, "_prepare_result_panel_for_scene_exit"),
			1.6
		)
		return
	_prepare_result_panel_for_scene_exit()
	if SceneTransitionManager and SceneTransitionManager.has_method("transition_to_scene"):
		await SceneTransitionManager.transition_to_scene("res://scenes/ui/main/main_scene.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/ui/main/main_scene.tscn")

func _on_close_pressed() -> void:
	_on_end_button_pressed()
