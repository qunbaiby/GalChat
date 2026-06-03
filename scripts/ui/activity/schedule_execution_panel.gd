extends Control

signal course_completed(index: int)
signal all_courses_completed
signal schedule_finished

@export var slot_scene: PackedScene

const ScheduleEventPanelScene = preload("res://scenes/ui/activity/schedule_event_panel.tscn")
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
	"mood": "心情",
	"stress": "压力"
}
const EVENT_CHANCE_BY_CATEGORY := {
	"physical_health": 0.28,
	"creation_design": 0.24,
	"music_dance_performance": 0.26,
	"social_etiquette": 0.22,
	"rest": 0.14
}
const LOCAL_EVENT_POOL := {
	"physical_health": [
		{
			"event_title": "训练节奏变化",
			"event_desc": "训练做到一半，老师临时要求你尝试更高强度的一组动作，大家都在看你的反应。",
			"options": [
				{"text": "咬牙跟上", "style": "冒险", "effects_hint": "偏向体能提升", "result_desc": "你硬撑着完成了整组动作，虽然有些吃力，但体能和反应都被逼了出来。", "attr_changes": {"体能": 6, "反应": 3, "压力": 2}},
				{"text": "稳住节奏", "style": "稳妥", "effects_hint": "偏向稳定发挥", "result_desc": "你选择按自己的节奏完成训练，过程更稳定，身体负担也轻一些。", "attr_changes": {"体能": 3, "心情": 1, "压力": -1}}
			]
		}
	],
	"creation_design": [
		{
			"event_title": "灵感偏航",
			"event_desc": "做到一半时，你忽然冒出一个完全不同的视觉方案，如果改动，今天的进度就得重来一部分。",
			"options": [
				{"text": "直接重做", "style": "冒险", "effects_hint": "偏向审美爆发", "result_desc": "你果断推翻原稿重新构图，虽然累，但最终画面的完成度明显更高。", "attr_changes": {"审美": 5, "感知": 3, "压力": 2}},
				{"text": "局部微调", "style": "稳妥", "effects_hint": "偏向稳定推进", "result_desc": "你保留主体结构，只对关键细节做优化，整体推进更稳。", "attr_changes": {"学识": 2, "表达": 3, "压力": -1}}
			]
		}
	],
	"music_dance_performance": [
		{
			"event_title": "临场点名",
			"event_desc": "老师突然点你单独示范一段关键动作，全班的目光一下集中到了你身上。",
			"options": [
				{"text": "主动上前", "style": "表现", "effects_hint": "偏向表达提升", "result_desc": "你主动站到最前面完成示范，虽然紧张，但台风和表现力都更亮眼了。", "attr_changes": {"表达": 5, "气质": 3, "压力": 2}},
				{"text": "先观察下", "style": "保守", "effects_hint": "偏向减少失误", "result_desc": "你先看了别人一轮再调整动作，整体更稳，也避免了明显失误。", "attr_changes": {"反应": 2, "心情": 1, "压力": -1}}
			]
		}
	],
	"social_etiquette": [
		{
			"event_title": "即兴应对",
			"event_desc": "课堂模拟环节里，对方忽然抛出计划外的问题，现场气氛一下变得微妙起来。",
			"options": [
				{"text": "顺势接话", "style": "社交", "effects_hint": "偏向礼仪表达", "result_desc": "你顺势把话题接住，还自然化解了尴尬，礼仪与表达都加分不少。", "attr_changes": {"礼仪": 4, "表达": 3, "心情": 1}},
				{"text": "谨慎回应", "style": "稳妥", "effects_hint": "偏向稳定发挥", "result_desc": "你没有急着抢答，而是稳稳给出回应，虽然不算惊艳，但相当得体。", "attr_changes": {"礼仪": 3, "气质": 2, "压力": -1}}
			]
		}
	],
	"rest": [
		{
			"event_title": "短暂放空",
			"event_desc": "难得的休息时间里，窗外的风和阳光都很舒服，你忽然有点想把手机也一起放下。",
			"options": [
				{"text": "彻底发呆", "style": "放松", "effects_hint": "偏向减压恢复", "result_desc": "你让自己彻底放空了一会儿，压力和疲惫都松下来不少。", "attr_changes": {"心情": 4, "压力": -4}},
				{"text": "顺手记录", "style": "细腻", "effects_hint": "偏向感知审美", "result_desc": "你顺手把眼前的光影和情绪记了下来，心情变好，观察力也被调动起来。", "attr_changes": {"审美": 2, "感知": 2, "心情": 2}}
			]
		}
	]
}

@onready var top_image_rect: TextureRect = $MainPanel/TopImageRect
@onready var title_label: Label = $MainPanel/TopImageRect/TitleContainer/TitleLabel
@onready var desc_label: Label = $MainPanel/DescLabel
@onready var bonus_hbox: HBoxContainer = $MainPanel/BonusHBox
@onready var track_container: HBoxContainer = $MainPanel/TrackContainer
@onready var character_icon: Node2D = $MainPanel/TrackContainer/CharacterIcon
@onready var click_area: Button = $ClickArea

@onready var result_popup: Control = $ResultPopup
@onready var result_content_vbox: VBoxContainer = $ResultPopup/VBox/Content/Margin/VBox
@onready var stats_vbox: GridContainer = $ResultPopup/VBox/Content/Margin/VBox/StatsVBox
@onready var close_button: Button = $ResultPopup/CloseButton

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

@onready var footer_stress_val: Label = $ResultPopup/VBox/Footer/Margin/HBox/StressHBox/Val
@onready var footer_stress_diff: Label = $ResultPopup/VBox/Footer/Margin/HBox/StressHBox/Diff

@onready var footer_gold_val: Label = $ResultPopup/VBox/Footer/Margin/HBox/GoldHBox/Val
@onready var footer_gold_diff: Label = $ResultPopup/VBox/Footer/Margin/HBox/GoldHBox/Diff

@onready var auto_button: Button = $MainPanel/ControlButtons/AutoButton
@onready var skip_button: Button = $MainPanel/ControlButtons/SkipButton
@onready var loading_overlay: Control = $LoadingOverlay
@onready var loading_text: Label = $LoadingOverlay/VBox/LoadingText

var _is_auto_playing: bool = false
var _is_skipping: bool = false
var _result_anim_tween: Tween = null

var _courses_data: Array
var _start_attrs: Dictionary
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
var _weekly_key_events: Array[Dictionary] = []

func _ready() -> void:
	click_area.pressed.connect(_on_click_area_pressed)
	close_button.pressed.connect(_on_end_button_pressed)
	
	if auto_button: auto_button.pressed.connect(_on_auto_pressed)
	if skip_button: skip_button.pressed.connect(_on_skip_pressed)
	if loading_overlay: loading_overlay.hide()
	
	# 初始状态
	result_popup.hide()
	close_button.hide()

func setup(courses_data: Array, start_attrs: Dictionary, end_attrs: Dictionary) -> void:
	_courses_data = courses_data
	_start_attrs = start_attrs
	_end_attrs = end_attrs
	_last_processed_course_index = -1
	_current_event_course_index = -1
	_current_event_selected_option = ""
	_current_event_data.clear()
	_current_event_options.clear()
	_weekly_key_events.clear()
	
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
	if _is_auto_playing and not _is_moving and can_continue and not result_popup.visible and (loading_overlay == null or not loading_overlay.visible) and _current_event_panel == null:
		_on_click_area_pressed()

func _update_course_info(index: int) -> void:
	if index < 0 or index >= _courses_data.size(): return
	
	var current_course = _courses_data[index]
	
	# 1. 顶部配图
	if current_course.has("image_path") and not current_course["image_path"].is_empty():
		var img_path = current_course["image_path"]
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
	var c_name = current_course.get("name", "未知课程")
	title_label.text = tr(c_name)
	
	desc_label.text = current_course.get("desc", "缺少课程描述...")
	
	# 3. 属性加成展示
	update_bonus(current_course.get("bonus_list", []))

func update_bonus(bonus_list: Array) -> void:
	for child in bonus_hbox.get_children():
		child.queue_free()
		
	for bonus in bonus_list:
		var hbox = HBoxContainer.new()
		
		if bonus.has("icon"):
			var icon = TextureRect.new()
			icon.texture = load(bonus["icon"])
			icon.custom_minimum_size = Vector2(24, 24)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hbox.add_child(icon)
			
		var name_lbl = Label.new()
		name_lbl.text = tr(bonus.get("name", ""))
		name_lbl.add_theme_color_override("font_color", Color(0.4, 0.3, 0.2))
		hbox.add_child(name_lbl)
		
		var val_lbl = Label.new()
		val_lbl.text = "+" + str(bonus.get("value", 0))
		val_lbl.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2))
		hbox.add_child(val_lbl)
		
		bonus_hbox.add_child(hbox)

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
		slot.setup(str(i + 1))
		slot.set_completed(false)
		_slots.append(slot)
	
	_current_slot_index = 0
	_slots[0].set_completed(false)
	
	# 重置小人的显示状态（修复“两个我”的问题）
	character_icon.show()
	character_icon.modulate.a = 1.0

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
	if GameDataManager.story_time_manager:
		var absolute_day = GameDataManager.story_time_manager.current_day_offset + course_index
		return weekdays[posmod(absolute_day, weekdays.size())]
	return "本日"

func _build_bonus_summary(course_data: Dictionary) -> String:
	var parts: Array[String] = []
	for bonus in course_data.get("bonus_list", []):
		parts.append("%s+%s" % [str(bonus.get("name", "")), str(bonus.get("value", 0))])
	return "、".join(parts) if not parts.is_empty() else "无明显加成"

func _build_schedule_event_context(course_index: int) -> Dictionary:
	var course_data = _courses_data[course_index]
	return {
		"course_index": course_index,
		"course_name": course_data.get("name", "未知课程"),
		"course_desc": course_data.get("desc", ""),
		"category_id": course_data.get("category_id", "rest"),
		"category_name": course_data.get("category_name", "综合课程"),
		"day_label": _get_day_label(course_index),
		"bonus_summary": _build_bonus_summary(course_data),
		"mood": int(_end_attrs.get("心情", _start_attrs.get("心情", 50))),
		"stress": int(_end_attrs.get("压力", _start_attrs.get("压力", 0)))
	}

func _build_attr_changes_summary(raw_changes: Dictionary) -> String:
	var normalized = _normalize_attr_changes(raw_changes)
	var ordered_keys = ["体能", "反应", "学识", "表达", "气质", "礼仪", "审美", "感知", "心情", "压力", "金币"]
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
	separator.theme_override_constants.separation = 10
	result_content_vbox.add_child(separator)

	var section = VBoxContainer.new()
	section.name = "WeeklyEventSection"
	section.theme_override_constants.separation = 10
	result_content_vbox.add_child(section)

	var title = Label.new()
	title.text = "本周关键事件"
	title.add_theme_color_override("font_color", Color(0.25, 0.23, 0.2, 1))
	title.add_theme_font_size_override("font_size", 18)
	section.add_child(title)

	for event_info in _weekly_key_events:
		var card = PanelContainer.new()
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color(0.985, 0.988, 0.995, 1)
		card_style.border_width_left = 1
		card_style.border_width_top = 1
		card_style.border_width_right = 1
		card_style.border_width_bottom = 1
		card_style.border_color = Color(0.9, 0.92, 0.95, 1)
		card_style.corner_radius_top_left = 10
		card_style.corner_radius_top_right = 10
		card_style.corner_radius_bottom_right = 10
		card_style.corner_radius_bottom_left = 10
		card.theme_override_styles.panel = card_style
		section.add_child(card)

		var margin = MarginContainer.new()
		margin.theme_override_constants.margin_left = 14
		margin.theme_override_constants.margin_top = 10
		margin.theme_override_constants.margin_right = 14
		margin.theme_override_constants.margin_bottom = 10
		card.add_child(margin)

		var card_vbox = VBoxContainer.new()
		card_vbox.theme_override_constants.separation = 6
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
	var category_id = str(context.get("category_id", "rest"))
	var pool = LOCAL_EVENT_POOL.get(category_id, LOCAL_EVENT_POOL.get("rest", []))
	if pool.is_empty():
		return {}
	var idx = randi() % pool.size()
	var event_data = (pool[idx] as Dictionary).duplicate(true)
	if not event_data.has("event_title"):
		event_data["event_title"] = "%s事件" % str(context.get("category_name", "课程"))
	return event_data

func _normalize_attr_changes(raw_changes: Dictionary) -> Dictionary:
	var normalized := {}
	for raw_key in raw_changes.keys():
		var final_key = STAT_KEY_ALIASES.get(str(raw_key), str(raw_key))
		normalized[final_key] = int(raw_changes[raw_key])
	return normalized

func _apply_attr_changes(raw_changes: Dictionary) -> void:
	var changes = _normalize_attr_changes(raw_changes)
	for attr in changes.keys():
		var val = int(changes[attr])
		if _end_attrs.has(attr):
			_end_attrs[attr] += val
		else:
			_end_attrs[attr] = _start_attrs.get(attr, 0) + val
	_end_attrs["压力"] = clamp(int(_end_attrs.get("压力", 0)), 0, GameDataManager.profile.max_stress)
	_end_attrs["心情"] = clamp(int(_end_attrs.get("心情", 0)), 0, 100)
	_end_attrs["金币"] = max(0, int(_end_attrs.get("金币", 0)))

func _should_trigger_schedule_event(course_index: int, course_data: Dictionary) -> bool:
	if course_data.get("is_event", false):
		return false
	var category_id = str(course_data.get("category_id", "rest"))
	var chance = float(EVENT_CHANCE_BY_CATEGORY.get(category_id, 0.2))
	var stress_bonus = max(0.0, float(_end_attrs.get("压力", 0) - 50) * 0.002)
	var course_repeat_penalty = 0.0
	if course_index > 0 and _courses_data[course_index - 1].get("id", "") == course_data.get("id", ""):
		course_repeat_penalty = 0.03
	return randf() < clamp(chance + stress_bonus - course_repeat_penalty, 0.05, 0.45)

func _process_course_at_index(course_index: int) -> void:
	if course_index < 0 or course_index >= _courses_data.size():
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
	if _is_moving:
		return
		
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

func _finish_slot_move(skip_ui_update: bool = false) -> void:
	_is_moving = false
	
	# 走到下一个槽位时，立刻刷新顶部的当前课程图文信息
	if not skip_ui_update:
		_update_course_info(_current_slot_index)
	
	# 前 4 节课完成后推进到下一天；最后一节课在结果结算时停留到当晚
	if _current_slot_index > 0 and _current_slot_index < 4:
		if GameDataManager.story_time_manager:
			GameDataManager.story_time_manager.advance_day(1)
		
	if _current_slot_index == 4 and _last_processed_course_index >= 4:
		# 走到最后一个槽位时，立刻将最后一个也标为完成
		set_slot_status(_current_slot_index, true)
		course_completed.emit(_current_slot_index)
		all_courses_completed.emit()
		
		# 第5个课程完成，不跨天，时间设定为周五晚上 20:00
		if GameDataManager.story_time_manager:
			GameDataManager.story_time_manager.current_hour = 20
			GameDataManager.story_time_manager.current_minute = 0
			GameDataManager.story_time_manager.current_period = GameDataManager.story_time_manager.PERIOD_NIGHT
			GameDataManager.story_time_manager.time_advanced.emit(0, GameDataManager.story_time_manager.current_period)
			
		_show_result_popup()
	elif _is_auto_playing:
		if not _is_skipping:
			await get_tree().create_timer(0.3).timeout
			if not is_inside_tree(): return
		_try_auto_next()

func _get_deepseek_client() -> Node:
	if get_tree().current_scene and get_tree().current_scene.has_node("DeepSeekClient"):
		return get_tree().current_scene.get_node("DeepSeekClient")
	if get_node_or_null("/root/DeepSeekClient"):
		return get_node("/root/DeepSeekClient")
	if get_tree().root.has_node("MainScene/DeepSeekClient"):
		return get_node("/root/MainScene/DeepSeekClient")
	return null

func _trigger_story_script(course_data: Dictionary, course_index: int) -> void:
	var script_path = course_data.get("script_path", "")
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
		"event_title": course_data.get("name", "剧情事件"),
		"result_desc": course_data.get("desc", "触发了一段关键剧情。")
	})
	_last_processed_course_index = max(_last_processed_course_index, course_index)
	_finish_slot_move(true)

func _show_loading(text: String) -> void:
	if loading_overlay:
		loading_text.text = text
		loading_overlay.modulate.a = 0.0
		loading_overlay.show()
		var t = create_tween()
		t.tween_property(loading_overlay, "modulate:a", 1.0, 0.2)

func _hide_loading() -> void:
	if loading_overlay and loading_overlay.visible:
		var t = create_tween()
		t.tween_property(loading_overlay, "modulate:a", 0.0, 0.2)
		t.finished.connect(func(): loading_overlay.hide())

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
	
	_show_loading("突发事件生成中...")
	
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
	_show_loading("事件结算中...")
	
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
	_apply_attr_changes(changes)
	if _current_event_panel and is_instance_valid(_current_event_panel):
		_current_event_panel.show_result(desc, _normalize_attr_changes(changes))
		if _is_auto_playing or _is_skipping:
			await get_tree().create_timer(1.0 if _is_skipping else 1.8).timeout
			if is_instance_valid(_current_event_panel):
				_on_event_result_confirmed()
	else:
		_last_processed_course_index = max(_last_processed_course_index, _current_event_course_index)
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
		_slots[index].set_completed(completed)

func _show_result_popup() -> void:
	result_popup.modulate.a = 0
	result_popup.show()
	click_area.hide()
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
	
	var start_stress = _start_attrs.get("压力", GameDataManager.profile.stress)
	var end_stress = _end_attrs.get("压力", start_stress)
	footer_stress_val.text = str(end_stress)
	var diff_stress = end_stress - start_stress
	footer_stress_diff.text = ("+%d" % diff_stress) if diff_stress >= 0 else str(diff_stress)
	footer_stress_diff.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4) if diff_stress > 0 else Color(0.26, 0.71, 0.97))
	
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

func _on_end_button_pressed() -> void:
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
	profile.stress = clamp(_end_attrs.get("压力", profile.stress), 0, profile.max_stress)
	profile.mood_value = clamp(_end_attrs.get("心情", profile.mood_value), 0, 100)

	profile.save_profile()
	if GameDataManager.story_time_manager:
		GameDataManager.story_time_manager.save_data()
	GameDataManager.save_manager.auto_save()

	# 使用现有的全局黑屏过渡管理器过渡回主场景
	SceneTransitionManager.transition_to_scene("res://scenes/ui/main/main_scene.tscn")
	schedule_finished.emit()
	queue_free()

func _on_close_pressed() -> void:
	_on_end_button_pressed()
