extends Control

signal stage_changed(new_stage: int)

const PERIOD_OPTIONS := ["上午", "下午", "傍晚", "夜晚"]
const WEATHER_OPTIONS := [
	{"id": "sunny", "label": "晴天"},
	{"id": "cloudy", "label": "多云"},
	{"id": "overcast", "label": "阴天"},
	{"id": "foggy", "label": "有雾"},
	{"id": "rainy", "label": "雨天"},
	{"id": "thunder", "label": "雷雨"},
	{"id": "snow", "label": "雪天"}
]
const SUB_STAT_CONFIG := [
	{"id": "stat_stamina", "label": "体能"},
	{"id": "stat_rhythm", "label": "反应"},
	{"id": "stat_knowledge", "label": "学识"},
	{"id": "stat_expression", "label": "表达"},
	{"id": "stat_temperament", "label": "气质"},
	{"id": "stat_etiquette", "label": "礼仪"},
	{"id": "stat_aesthetics", "label": "审美"},
	{"id": "stat_perception", "label": "感知"}
]
const MAIN_FEATURE_DEBUG_CONFIG := [
	{"id": "main.gift", "label": "礼物"},
	{"id": "main.creation", "label": "创作"},
	{"id": "main.wechat", "label": "微聊"},
	{"id": "main.wardrobe", "label": "换装"},
	{"id": "main.date", "label": "约会"},
	{"id": "main.schedule", "label": "行程安排"},
	{"id": "main.outing", "label": "外出"}
]
const STORY_SCAN_DIRS := [
	"res://assets/data/story/scripts/main",
	"res://assets/data/story/scripts/events"
]
const STORY_SCENE_PATH := "res://scenes/ui/story/story_scene.tscn"
const QUICK_LOCATION_SCENE_PATH := "res://scenes/ui/map/core/quick_location_scene.tscn"
const COLOR_TEXT := Color(0.23, 0.22, 0.2, 1)
const COLOR_MUTED := Color(0.42, 0.49, 0.56, 1)
const COLOR_SOFT := Color(0.56, 0.62, 0.68, 1)
const COLOR_PRIMARY := Color(0.57, 0.82, 0.76, 1)
const COLOR_PRIMARY_DARK := Color(0.43, 0.71, 0.64, 1)
const COLOR_SURFACE := Color(1, 1, 1, 0.98)
const COLOR_SURFACE_ALT := Color(0.965, 0.975, 0.985, 1)
const COLOR_BORDER := Color(0.86, 0.89, 0.93, 1)

@onready var close_btn: Button = $CenterContainer/Panel/RootVBox/FooterVBox/CloseButton
@onready var refresh_all_btn: Button = $CenterContainer/Panel/RootVBox/HeaderHBox/HeaderActions/RefreshAllButton
@onready var status_label: Label = $CenterContainer/Panel/RootVBox/FooterVBox/StatusLabel
@onready var tab_container: TabContainer = $CenterContainer/Panel/RootVBox/TabContainer
@onready var overview_content: VBoxContainer = $CenterContainer/Panel/RootVBox/TabContainer/总览/ScrollContainer/OverviewContent
@onready var stats_content: VBoxContainer = $CenterContainer/Panel/RootVBox/TabContainer/关系属性/ScrollContainer/StatsContent
@onready var story_content: VBoxContainer = $CenterContainer/Panel/RootVBox/TabContainer/剧情测试/ScrollContainer/StoryContent
@onready var personality_text: RichTextLabel = $CenterContainer/Panel/RootVBox/TabContainer/大五人格/ScrollContainer/PersonalityText
@onready var trait_option: OptionButton = $CenterContainer/Panel/RootVBox/TabContainer/大五人格/ModifyHBox/TraitOption
@onready var trait_value_input: SpinBox = $CenterContainer/Panel/RootVBox/TabContainer/大五人格/ModifyHBox/TraitValueInput
@onready var set_trait_btn: Button = $CenterContainer/Panel/RootVBox/TabContainer/大五人格/ModifyHBox/SetTraitBtn
@onready var refresh_personality_btn: Button = $CenterContainer/Panel/RootVBox/TabContainer/大五人格/PersonalityHeaderHBox/RefreshPersonalityBtn
@onready var snapshot_personality_btn: Button = $CenterContainer/Panel/RootVBox/TabContainer/大五人格/PersonalityHeaderHBox/SnapshotPersonalityBtn
@onready var settle_personality_btn: Button = $CenterContainer/Panel/RootVBox/TabContainer/大五人格/PersonalityHeaderHBox/SettlePersonalityBtn

var is_from_title: bool = false

var time_summary_label: Label
var relation_summary_label: Label
var overview_story_summary_label: Label
var story_progress_summary_label: Label
var event_summary_label: Label
var core_stats_label: Label
var feature_unlock_summary_label: Label

var day_spin: SpinBox
var period_option: OptionButton
var hour_spin: SpinBox
var minute_spin: SpinBox
var weather_option: OptionButton
var temperature_spin: SpinBox

var stage_option: OptionButton
var macro_mood_option: OptionButton
var intimacy_spin: SpinBox
var trust_spin: SpinBox
var mood_value_spin: SpinBox
var expression_option: OptionButton
var energy_spin: SpinBox
var max_energy_spin: SpinBox
var gold_spin: SpinBox

var switch_char_btn: Button
var test_call_btn: Button
var generate_diary_btn: Button
var free_chat_toggle: CheckButton
var test_fixed_chat_btn: Button
var clear_fixed_chat_btn: Button
var send_moment_btn: Button
var ai_generate_moment_btn: Button
var moment_author_input: LineEdit
var moment_mode_option: OptionButton
var moment_content_input: TextEdit
var feature_toggle_buttons: Dictionary = {}

var finished_story_input: LineEdit
var finished_story_list: ItemList
var triggered_event_input: LineEdit
var event_list: ItemList
var story_play_option: OptionButton
var story_filter_input: LineEdit
var story_play_input: LineEdit
var story_play_summary_label: Label
var entry_location_option: OptionButton
var entry_npc_input: LineEdit
var entry_story_summary_label: Label

var sub_stat_spins: Dictionary = {}
var expression_ids: Array[String] = []
var available_story_ids: Array[String] = []
var available_event_ids: Array[String] = []
var available_location_ids: Array[String] = []
var story_path_map: Dictionary = {}
var filtered_story_ids: Array[String] = []

func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	refresh_all_btn.pressed.connect(_on_refresh_all_pressed)
	set_trait_btn.pressed.connect(_on_set_trait_pressed)
	refresh_personality_btn.pressed.connect(_on_refresh_personality_pressed)
	snapshot_personality_btn.pressed.connect(_on_snapshot_personality_pressed)
	settle_personality_btn.pressed.connect(_on_settle_personality_pressed)

	_build_dynamic_ui()
	_apply_static_styles()
	_connect_llm_signals()
	_reload_reference_ids()
	_refresh_all_views()

func show_panel() -> void:
	_ensure_profile_ready()
	if is_from_title:
		tab_container.set_tab_hidden(2, true)
		if tab_container.current_tab == 2:
			tab_container.current_tab = 0
	else:
		tab_container.set_tab_hidden(2, false)
	_refresh_all_views()
	show()

func _build_dynamic_ui() -> void:
	_build_overview_tab()
	_build_stats_tab()
	_build_story_tab()

func _build_overview_tab() -> void:
	var time_card := _create_card(overview_content, "时间与天气", "调试剧情时间、时段与当天天气覆盖。天气覆盖仅写入当前角色调试存档，不会改动原始 story_time.json。")
	time_summary_label = _create_info_label(time_card)

	var time_row_1 := _create_row(time_card)
	_create_field_label(time_row_1, "第几天")
	day_spin = _create_spin_box(time_row_1, 0, 999, 1, 0, false)
	_create_field_label(time_row_1, "时段")
	period_option = _create_option_button(time_row_1)
	for period_text in PERIOD_OPTIONS:
		period_option.add_item(period_text)

	var time_row_2 := _create_row(time_card)
	_create_field_label(time_row_2, "小时")
	hour_spin = _create_spin_box(time_row_2, 0, 23, 1, 8, false)
	_create_field_label(time_row_2, "分钟")
	minute_spin = _create_spin_box(time_row_2, 0, 59, 1, 0, false)
	_create_field_label(time_row_2, "天气")
	weather_option = _create_option_button(time_row_2)
	for weather_data in WEATHER_OPTIONS:
		weather_option.add_item(str(weather_data.get("label", "")))
	_create_field_label(time_row_2, "气温")
	temperature_spin = _create_spin_box(time_row_2, -30, 50, 1, 20, false)

	var time_actions := _create_flow_row(time_card)
	var apply_time_btn := _create_button(time_actions, "应用时间天气", true)
	apply_time_btn.pressed.connect(_on_apply_time_weather_pressed)
	var next_period_btn := _create_button(time_actions, "下一时段")
	next_period_btn.pressed.connect(_on_advance_period_pressed)
	var next_day_btn := _create_button(time_actions, "推进一天")
	next_day_btn.pressed.connect(_on_advance_day_pressed)
	var clear_weather_btn := _create_button(time_actions, "清除天气覆盖")
	clear_weather_btn.pressed.connect(_on_clear_weather_override_pressed)

	var quick_card := _create_card(overview_content, "当前概览", "便于快速确认当前角色、关系、属性与剧情进度是否已经生效。")
	relation_summary_label = _create_info_label(quick_card)
	overview_story_summary_label = _create_info_label(quick_card)

func _build_stats_tab() -> void:
	var relation_card := _create_card(stats_content, "关系与状态", "阶段、亲密、信任、宏观心情和当前表情会在这里统一处理。")
	var stage_row := _create_row(relation_card)
	_create_field_label(stage_row, "阶段")
	stage_option = _create_option_button(stage_row)
	stage_option.item_selected.connect(_on_stage_option_preview_selected)
	_create_field_label(stage_row, "表情")
	expression_option = _create_option_button(stage_row)

	var relation_row := _create_row(relation_card)
	_create_field_label(relation_row, "亲密")
	intimacy_spin = _create_spin_box(relation_row, 0, 9999, 1, 0, true)
	_create_field_label(relation_row, "信任")
	trust_spin = _create_spin_box(relation_row, 0, 9999, 1, 0, true)
	_create_field_label(relation_row, "心情值")
	mood_value_spin = _create_spin_box(relation_row, 0, 100, 1, 50, true)

	var mood_row := _create_row(relation_card)
	_create_field_label(mood_row, "宏观心情")
	macro_mood_option = _create_option_button(mood_row)
	macro_mood_option.item_selected.connect(_on_macro_mood_selected)
	var apply_relation_row := _create_flow_row(relation_card)
	var apply_relation_btn := _create_button(apply_relation_row, "应用关系状态", true)
	apply_relation_btn.pressed.connect(_on_apply_relation_pressed)

	var resource_card := _create_card(stats_content, "资源数值", "金币、当前行动力与行动力上限会立即写入角色存档。")
	var resource_row := _create_row(resource_card)
	_create_field_label(resource_row, "当前行动力")
	energy_spin = _create_spin_box(resource_row, 0, 999, 1, 20, false)
	_create_field_label(resource_row, "行动力上限")
	max_energy_spin = _create_spin_box(resource_row, 1, 999, 1, 50, false)
	_create_field_label(resource_row, "金币")
	gold_spin = _create_spin_box(resource_row, 0, 999999, 10, 500, false)
	var apply_resource_btn := _create_button(resource_row, "应用资源", true)
	apply_resource_btn.pressed.connect(_on_apply_resources_pressed)

	var stats_card := _create_card(stats_content, "四基八维", "直接修改 Luna 的八维属性，并实时查看四基合计。")
	var stat_grid := GridContainer.new()
	stat_grid.columns = 4
	stat_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_grid.add_theme_constant_override("h_separation", 12)
	stat_grid.add_theme_constant_override("v_separation", 10)
	stats_card.add_child(stat_grid)
	for stat_data in SUB_STAT_CONFIG:
		var stat_id := str(stat_data.get("id", ""))
		var stat_label := Label.new()
		stat_label.text = str(stat_data.get("label", stat_id))
		stat_label.add_theme_color_override("font_color", COLOR_TEXT)
		stat_grid.add_child(stat_label)
		var stat_spin := SpinBox.new()
		stat_spin.min_value = 0.0
		stat_spin.max_value = 2000.0
		stat_spin.step = 1.0
		stat_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_spin_box(stat_spin)
		stat_grid.add_child(stat_spin)
		sub_stat_spins[stat_id] = stat_spin

	core_stats_label = _create_info_label(stats_card)
	var apply_stats_row := _create_flow_row(stats_card)
	var apply_stats_btn := _create_button(apply_stats_row, "应用八维属性", true)
	apply_stats_btn.pressed.connect(_on_apply_sub_stats_pressed)

func _build_story_tab() -> void:
	var story_play_card := _create_card(story_content, "剧情直达播放", "支持直接输入 story id 或完整脚本路径，快速跳进 story_scene 测试单段剧情。")
	story_play_summary_label = _create_info_label(story_play_card)
	var story_filter_row := _create_row(story_play_card)
	_create_field_label(story_filter_row, "筛选")
	story_filter_input = _create_line_edit(story_filter_row, "输入关键字过滤 story id")
	story_filter_input.text_changed.connect(_on_story_filter_changed)
	var story_play_row := _create_row(story_play_card)
	_create_field_label(story_play_row, "剧情")
	story_play_option = _create_option_button(story_play_row)
	story_play_option.item_selected.connect(func(_index: int) -> void:
		_refresh_story_debug_summary()
	)
	var story_path_row := _create_row(story_play_card)
	_create_field_label(story_path_row, "输入")
	story_play_input = _create_line_edit(story_path_row, "story id 或 res://.../xxx.json")
	var story_play_actions := _create_flow_row(story_play_card)
	var play_selected_btn := _create_button(story_play_actions, "播放剧情", true)
	play_selected_btn.pressed.connect(_on_play_story_pressed)
	var refresh_story_resolver_btn := _create_button(story_play_actions, "刷新解析")
	refresh_story_resolver_btn.pressed.connect(_on_refresh_story_debug_info_pressed)

	var entry_story_card := _create_card(story_content, "地点入口剧情模拟", "按当前时间、天气、阶段解析某个地点的入口剧情，并可完整模拟“入口剧情 -> 地点场景”流程。")
	entry_story_summary_label = _create_info_label(entry_story_card)
	var entry_row := _create_row(entry_story_card)
	_create_field_label(entry_row, "地点")
	entry_location_option = _create_option_button(entry_row)
	entry_location_option.item_selected.connect(func(_index: int) -> void:
		_refresh_story_debug_summary()
	)
	_create_field_label(entry_row, "NPC")
	entry_npc_input = _create_line_edit(entry_row, "留空则自动选择")
	var entry_actions := _create_flow_row(entry_story_card)
	var resolve_entry_btn := _create_button(entry_actions, "检查入口剧情")
	resolve_entry_btn.pressed.connect(_on_refresh_story_debug_info_pressed)
	var full_entry_btn := _create_button(entry_actions, "完整模拟", true)
	full_entry_btn.pressed.connect(_on_simulate_location_entry_pressed)
	var play_entry_only_btn := _create_button(entry_actions, "只播入口剧情")
	play_entry_only_btn.pressed.connect(_on_play_entry_story_only_pressed)

	var story_progress_card := _create_card(story_content, "剧情进度", "手动标记剧情已完成/未完成，用于测试入口剧情、里程碑与回放屏蔽逻辑。")
	story_progress_summary_label = _create_info_label(story_progress_card)
	var story_input_row := _create_row(story_progress_card)
	_create_field_label(story_input_row, "剧情 ID")
	finished_story_input = _create_line_edit(story_input_row, "例如：jing_library_guidance")
	var story_actions := _create_flow_row(story_progress_card)
	var mark_story_btn := _create_button(story_actions, "标记完成", true)
	mark_story_btn.pressed.connect(_on_mark_story_finished_pressed)
	var unmark_story_btn := _create_button(story_actions, "移除完成")
	unmark_story_btn.pressed.connect(_on_unmark_story_finished_pressed)
	var clear_story_btn := _create_button(story_actions, "清空全部")
	clear_story_btn.pressed.connect(_on_clear_finished_stories_pressed)
	finished_story_list = ItemList.new()
	finished_story_list.custom_minimum_size = Vector2(0, 160)
	finished_story_list.select_mode = ItemList.SELECT_SINGLE
	finished_story_list.item_selected.connect(_on_finished_story_selected)
	_style_item_list(finished_story_list)
	story_progress_card.add_child(finished_story_list)

	var event_progress_card := _create_card(story_content, "事件进度", "触发事件列表来自 EventManager 注册表，可直接标记或撤销事件已触发状态。")
	event_summary_label = _create_info_label(event_progress_card)
	var event_input_row := _create_row(event_progress_card)
	_create_field_label(event_input_row, "事件 ID")
	triggered_event_input = _create_line_edit(event_input_row, "例如：ya_cafe_first_visit")
	var event_actions := _create_flow_row(event_progress_card)
	var mark_event_btn := _create_button(event_actions, "标记触发", true)
	mark_event_btn.pressed.connect(_on_mark_event_triggered_pressed)
	var unmark_event_btn := _create_button(event_actions, "移除触发")
	unmark_event_btn.pressed.connect(_on_unmark_event_triggered_pressed)
	var clear_event_btn := _create_button(event_actions, "清空全部")
	clear_event_btn.pressed.connect(_on_clear_triggered_events_pressed)
	event_list = ItemList.new()
	event_list.custom_minimum_size = Vector2(0, 160)
	event_list.select_mode = ItemList.SELECT_SINGLE
	event_list.item_selected.connect(_on_event_selected)
	_style_item_list(event_list)
	event_progress_card.add_child(event_list)

	var tools_card := _create_card(story_content, "常用测试工具", "保留原有切角色、模拟来电、固定聊天、日记与朋友圈调试入口。")
	var tool_row := _create_flow_row(tools_card)
	switch_char_btn = _create_button(tool_row, "切换角色")
	switch_char_btn.pressed.connect(_on_switch_char_pressed)
	test_call_btn = _create_button(tool_row, "模拟来电")
	test_call_btn.pressed.connect(_on_test_call_pressed)
	generate_diary_btn = _create_button(tool_row, "生成日记")
	generate_diary_btn.pressed.connect(_on_generate_diary_pressed)

	var chat_row := _create_flow_row(tools_card)
	free_chat_toggle = CheckButton.new()
	free_chat_toggle.text = "启用自由 AI 聊天"
	_style_check_button(free_chat_toggle)
	free_chat_toggle.toggled.connect(_on_free_chat_toggled)
	chat_row.add_child(free_chat_toggle)
	test_fixed_chat_btn = _create_button(chat_row, "测试静固定剧本")
	test_fixed_chat_btn.pressed.connect(_on_test_fixed_chat_pressed)
	clear_fixed_chat_btn = _create_button(chat_row, "清除固定聊天")
	clear_fixed_chat_btn.pressed.connect(_on_clear_fixed_chat_pressed)

	var feature_card := _create_card(story_content, "主场景功能解锁", "直接测试礼物、创作、微聊、换装、约会、行程安排与外出按钮的锁定状态。")
	feature_unlock_summary_label = _create_info_label(feature_card)
	var feature_actions := _create_flow_row(feature_card)
	for feature_config in MAIN_FEATURE_DEBUG_CONFIG:
		var feature_id := str(feature_config.get("id", "")).strip_edges()
		var label_text := str(feature_config.get("label", feature_id))
		var toggle_btn := _create_button(feature_actions, "%s：已解锁" % label_text)
		var target_feature_id := feature_id
		toggle_btn.pressed.connect(func() -> void:
			_on_toggle_main_feature_pressed(target_feature_id)
		)
		feature_toggle_buttons[feature_id] = toggle_btn
	var feature_batch_actions := _create_flow_row(feature_card)
	var unlock_all_btn := _create_button(feature_batch_actions, "全部解锁", true)
	unlock_all_btn.pressed.connect(_on_unlock_all_main_features_pressed)
	var lock_all_btn := _create_button(feature_batch_actions, "全部锁定")
	lock_all_btn.pressed.connect(_on_lock_all_main_features_pressed)
	var refresh_feature_btn := _create_button(feature_batch_actions, "刷新功能状态")
	refresh_feature_btn.pressed.connect(_on_refresh_main_feature_unlocks_pressed)

	var moments_card := _create_card(story_content, "朋友圈测试", "支持手动插入测试动态，或直接触发 AI 自动生成朋友圈。")
	var author_row := _create_row(moments_card)
	_create_field_label(author_row, "发送者")
	moment_author_input = _create_line_edit(author_row, "AI")
	moment_author_input.text = "AI"
	_create_field_label(author_row, "模式")
	moment_mode_option = _create_option_button(author_row)
	moment_mode_option.add_item("图文并茂")
	moment_mode_option.add_item("纯文字")

	var content_row := _create_row(moments_card)
	_create_field_label(content_row, "内容")
	moment_content_input = _create_text_edit(content_row, "这是一条测试朋友圈。", 96)
	moment_content_input.text = "这是一条测试朋友圈。"

	var moment_actions := _create_flow_row(moments_card)
	send_moment_btn = _create_button(moment_actions, "手动发送", true)
	send_moment_btn.pressed.connect(_on_send_moment_pressed)
	ai_generate_moment_btn = _create_button(moment_actions, "AI 生成")
	ai_generate_moment_btn.pressed.connect(_on_ai_generate_moment_pressed)

func _create_card(parent: VBoxContainer, title: String, desc: String = "") -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _create_card_stylebox())
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.25, 0.23, 0.2, 1))
	content.add_child(title_label)

	if desc != "":
		var desc_label := Label.new()
		desc_label.text = desc
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_color_override("font_color", Color(0.45, 0.51, 0.58, 1))
		content.add_child(desc_label)

	return content

func _create_card_stylebox() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.96)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = COLOR_BORDER
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = Color(0.5, 0.74, 0.7, 0.08)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	return style

func _create_row(parent: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	return row

func _create_flow_row(parent: VBoxContainer) -> FlowContainer:
	var row := FlowContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	parent.add_child(row)
	return row

func _create_field_label(parent: HBoxContainer, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(72, 38)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", COLOR_TEXT)
	parent.add_child(label)
	return label

func _create_info_label(parent: VBoxContainer) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(0, 40)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", COLOR_MUTED)
	parent.add_child(label)
	return label

func _create_spin_box(parent: HBoxContainer, min_value: float, max_value: float, step: float, value: float, rounded: bool) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if rounded:
		spin.rounded = true
	_style_spin_box(spin)
	parent.add_child(spin)
	return spin

func _create_option_button(parent: HBoxContainer) -> OptionButton:
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(140, 40)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_option_button(option)
	parent.add_child(option)
	return option

func _create_button(parent: Control, text: String, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(124, 40)
	_style_button(button, primary)
	parent.add_child(button)
	return button

func _create_line_edit(parent: HBoxContainer, placeholder: String) -> LineEdit:
	var line_edit := LineEdit.new()
	line_edit.placeholder_text = placeholder
	line_edit.custom_minimum_size = Vector2(0, 40)
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_line_edit(line_edit)
	parent.add_child(line_edit)
	return line_edit

func _create_text_edit(parent: HBoxContainer, text: String = "", min_height: float = 88.0) -> TextEdit:
	var text_edit := TextEdit.new()
	text_edit.custom_minimum_size = Vector2(0, min_height)
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.text = text
	_style_text_edit(text_edit)
	parent.add_child(text_edit)
	return text_edit

func _apply_static_styles() -> void:
	tab_container.add_theme_color_override("font_selected_color", COLOR_TEXT)
	tab_container.add_theme_color_override("font_unselected_color", COLOR_MUTED)
	tab_container.add_theme_color_override("font_hovered_color", COLOR_TEXT)
	tab_container.add_theme_color_override("font_disabled_color", COLOR_SOFT)
	status_label.add_theme_color_override("font_color", COLOR_MUTED)
	personality_text.add_theme_color_override("default_color", COLOR_TEXT)
	_style_button(refresh_all_btn, false)
	_style_button(close_btn, true)
	_style_button(refresh_personality_btn, false)
	_style_button(snapshot_personality_btn, false)
	_style_button(settle_personality_btn, true)
	_style_button(set_trait_btn, true)
	_style_option_button(trait_option)
	_style_spin_box(trait_value_input)
	var personality_label: Label = $CenterContainer/Panel/RootVBox/TabContainer/大五人格/PersonalityHeaderHBox/PersonalityLabel
	personality_label.add_theme_color_override("font_color", COLOR_TEXT)
	personality_label.add_theme_font_size_override("font_size", 16)

func _create_input_stylebox(is_focus: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SURFACE
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = COLOR_PRIMARY_DARK if is_focus else COLOR_BORDER
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	return style

func _create_button_stylebox(primary: bool, hovered: bool = false, pressed: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PRIMARY if primary else (Color(0.94, 0.97, 0.99, 1) if hovered or pressed else COLOR_SURFACE_ALT)
	if primary and hovered:
		style.bg_color = Color(0.53, 0.79, 0.73, 1)
	elif primary and pressed:
		style.bg_color = Color(0.48, 0.74, 0.68, 1)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = COLOR_PRIMARY_DARK if primary else COLOR_BORDER
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 14
	style.content_margin_top = 8
	style.content_margin_right = 14
	style.content_margin_bottom = 8
	return style

func _style_button(button: Button, primary: bool) -> void:
	button.add_theme_color_override("font_color", Color(1, 1, 1, 1) if primary else COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1) if primary else COLOR_TEXT)
	button.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1) if primary else COLOR_TEXT)
	button.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1) if primary else COLOR_TEXT)
	button.add_theme_stylebox_override("normal", _create_button_stylebox(primary))
	button.add_theme_stylebox_override("hover", _create_button_stylebox(primary, true))
	button.add_theme_stylebox_override("pressed", _create_button_stylebox(primary, false, true))
	button.add_theme_stylebox_override("focus", _create_button_stylebox(primary))

func _style_line_edit(line_edit: LineEdit) -> void:
	line_edit.add_theme_color_override("font_color", COLOR_TEXT)
	line_edit.add_theme_color_override("font_placeholder_color", COLOR_SOFT)
	line_edit.add_theme_color_override("font_selected_color", COLOR_TEXT)
	line_edit.add_theme_color_override("caret_color", COLOR_TEXT)
	line_edit.add_theme_color_override("selection_color", Color(0.8, 0.92, 0.89, 1))
	line_edit.add_theme_stylebox_override("normal", _create_input_stylebox())
	line_edit.add_theme_stylebox_override("focus", _create_input_stylebox(true))
	line_edit.add_theme_stylebox_override("read_only", _create_input_stylebox())

func _style_text_edit(text_edit: TextEdit) -> void:
	text_edit.add_theme_color_override("font_color", COLOR_TEXT)
	text_edit.add_theme_color_override("font_placeholder_color", COLOR_SOFT)
	text_edit.add_theme_color_override("caret_color", COLOR_TEXT)
	text_edit.add_theme_color_override("selection_color", Color(0.8, 0.92, 0.89, 1))
	text_edit.add_theme_stylebox_override("normal", _create_input_stylebox())
	text_edit.add_theme_stylebox_override("focus", _create_input_stylebox(true))
	text_edit.add_theme_stylebox_override("read_only", _create_input_stylebox())

func _style_option_button(option: OptionButton) -> void:
	option.add_theme_color_override("font_color", COLOR_TEXT)
	option.add_theme_color_override("font_hover_color", COLOR_TEXT)
	option.add_theme_color_override("font_pressed_color", COLOR_TEXT)
	option.add_theme_color_override("font_focus_color", COLOR_TEXT)
	option.add_theme_stylebox_override("normal", _create_input_stylebox())
	option.add_theme_stylebox_override("hover", _create_input_stylebox(true))
	option.add_theme_stylebox_override("pressed", _create_input_stylebox(true))
	option.add_theme_stylebox_override("focus", _create_input_stylebox(true))

func _style_spin_box(spin: SpinBox) -> void:
	spin.custom_minimum_size = Vector2(120, 40)
	spin.add_theme_color_override("font_color", COLOR_TEXT)
	spin.add_theme_color_override("font_hover_color", COLOR_TEXT)
	spin.add_theme_color_override("font_focus_color", COLOR_TEXT)
	spin.add_theme_stylebox_override("normal", _create_input_stylebox())
	spin.add_theme_stylebox_override("hover", _create_input_stylebox(true))
	spin.add_theme_stylebox_override("pressed", _create_input_stylebox(true))
	spin.add_theme_stylebox_override("focus", _create_input_stylebox(true))
	var spin_line_edit: LineEdit = spin.get_line_edit()
	if spin_line_edit:
		_style_line_edit(spin_line_edit)

func _style_check_button(check_button: CheckButton) -> void:
	check_button.custom_minimum_size = Vector2(180, 40)
	check_button.add_theme_color_override("font_color", COLOR_TEXT)
	check_button.add_theme_color_override("font_hover_color", COLOR_TEXT)
	check_button.add_theme_color_override("font_pressed_color", COLOR_TEXT)
	check_button.add_theme_color_override("font_focus_color", COLOR_TEXT)

func _style_item_list(list: ItemList) -> void:
	list.add_theme_color_override("font_color", COLOR_TEXT)
	list.add_theme_color_override("font_selected_color", COLOR_TEXT)
	list.add_theme_color_override("guide_color", COLOR_BORDER)
	list.add_theme_color_override("selection_rect_color", Color(0.84, 0.93, 0.91, 1))
	list.add_theme_stylebox_override("panel", _create_input_stylebox())
	list.add_theme_stylebox_override("focus", _create_input_stylebox(true))

func _ensure_profile_ready() -> void:
	if GameDataManager.profile == null:
		GameDataManager.profile = CharacterProfile.new()
		GameDataManager.profile.load_profile()

func _connect_llm_signals() -> void:
	var client = DeepSeekClientLocator.find(self)

	if client:
		if not client.is_connected("diary_generated", _on_diary_generated):
			client.diary_generated.connect(_on_diary_generated)
		if not client.is_connected("diary_error", _on_diary_error):
			client.diary_error.connect(_on_diary_error)

func _reload_reference_ids() -> void:
	available_story_ids.clear()
	story_path_map.clear()
	for dir_path in STORY_SCAN_DIRS:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				var story_id := file_name.get_basename()
				if not available_story_ids.has(story_id):
					available_story_ids.append(story_id)
				if not story_path_map.has(story_id):
					story_path_map[story_id] = "%s/%s" % [dir_path, file_name]
			file_name = dir.get_next()
		dir.list_dir_end()
	available_story_ids.sort()

	available_event_ids.clear()
	var event_manager = get_node_or_null("/root/EventManager")
	if event_manager:
		for raw_event in event_manager.event_registry:
			if not (raw_event is Dictionary):
				continue
			var event_id := str(raw_event.get("event_id", "")).strip_edges()
			if event_id != "" and not available_event_ids.has(event_id):
				available_event_ids.append(event_id)
	available_event_ids.sort()

	available_location_ids.clear()
	if MapDataManager:
		for raw_location_id in MapDataManager.locations.keys():
			var location_id := str(raw_location_id).strip_edges()
			if location_id != "":
				available_location_ids.append(location_id)
	available_location_ids.sort()

func _refresh_all_views() -> void:
	_ensure_profile_ready()
	_init_stage_options()
	_init_macro_mood_options()
	_init_expression_options()
	_sync_time_controls()
	_sync_profile_controls()
	_refresh_story_event_lists()
	_refresh_story_debug_controls()
	_refresh_summary_labels()
	_refresh_main_feature_unlock_controls()
	_update_personality_display(GameDataManager.profile)
	_update_status("已同步当前调试状态")

func _refresh_story_debug_controls() -> void:
	if story_play_option:
		_apply_story_filter_to_option()

	if entry_location_option:
		var previous_location := _get_selected_location_id()
		entry_location_option.clear()
		for location_id in available_location_ids:
			var loc_data: Dictionary = MapDataManager.get_location(location_id)
			var loc_name := str(loc_data.get("name", location_id))
			entry_location_option.add_item("%s | %s" % [location_id, loc_name])
		if entry_location_option.item_count > 0:
			var selected_location_index := 0
			if previous_location != "":
				var location_match_index := available_location_ids.find(previous_location)
				if location_match_index >= 0:
					selected_location_index = location_match_index
			entry_location_option.select(selected_location_index)

	_refresh_story_debug_summary()

func _init_stage_options() -> void:
	stage_option.clear()
	var profile = GameDataManager.profile
	if profile == null:
		return
	for i in range(profile.stages_config.size()):
		var config = profile.stages_config[i]
		var stage_num := int(config.get("stage", i + 1))
		var title := str(config.get("stageTitle", "未知阶段"))
		var title_parts := title.split(" ")
		var display_title: String = title_parts[1] if title_parts.size() > 1 else title
		stage_option.add_item("Stage %d: %s" % [stage_num, display_title], stage_num)

func _init_macro_mood_options() -> void:
	macro_mood_option.clear()
	if GameDataManager.mood_system == null:
		return
	for i in range(GameDataManager.mood_system.macro_mood_configs.size()):
		var config = GameDataManager.mood_system.macro_mood_configs[i]
		var name := str(config.get("name", "未知"))
		var min_val := int(config.get("min_value", 0))
		var max_val := int(config.get("max_value", 100))
		macro_mood_option.add_item("%s (%d-%d)" % [name, min_val, max_val], i)

func _init_expression_options() -> void:
	expression_option.clear()
	expression_ids.clear()
	if GameDataManager.expression_system == null:
		return
	for raw_id in GameDataManager.expression_system.all_expression_ids:
		var expression_id := str(raw_id)
		var config: Dictionary = GameDataManager.expression_system.expression_configs.get(expression_id, {})
		var expression_name := str(config.get("name", config.get("expression_name", expression_id)))
		expression_option.add_item(expression_name)
		expression_ids.append(expression_id)

func _sync_time_controls() -> void:
	var story_time_manager = GameDataManager.story_time_manager
	if story_time_manager == null:
		return
	day_spin.value = story_time_manager.current_day_offset
	hour_spin.value = story_time_manager.current_hour
	minute_spin.value = story_time_manager.current_minute
	var period_index := PERIOD_OPTIONS.find(story_time_manager.current_period)
	period_option.select(max(period_index, 0))
	var weather_id: String = story_time_manager.get_story_weather_id()
	var weather_index := _get_weather_index(weather_id)
	weather_option.select(weather_index)
	var current_day_cfg: Dictionary = story_time_manager.get_current_day_config()
	temperature_spin.value = int(current_day_cfg.get("temperature", 20))

func _sync_profile_controls() -> void:
	var profile = GameDataManager.profile
	if profile == null:
		return
	var stage_idx := 0
	for i in range(stage_option.item_count):
		if stage_option.get_item_id(i) == profile.current_stage:
			stage_idx = i
			break
	stage_option.select(stage_idx)
	intimacy_spin.value = profile.intimacy
	trust_spin.value = profile.trust
	mood_value_spin.value = profile.mood_value
	energy_spin.value = profile.current_energy
	max_energy_spin.value = profile.max_energy
	gold_spin.value = profile.gold
	for stat_data in SUB_STAT_CONFIG:
		var stat_id := str(stat_data.get("id", ""))
		if sub_stat_spins.has(stat_id):
			var spin: SpinBox = sub_stat_spins[stat_id]
			spin.value = float(profile.get(stat_id))

	var expression_idx := expression_ids.find(profile.current_expression)
	expression_option.select(max(expression_idx, 0))

	var mood_idx := 0
	if GameDataManager.mood_system:
		for i in range(GameDataManager.mood_system.macro_mood_configs.size()):
			var config = GameDataManager.mood_system.macro_mood_configs[i]
			var min_val := float(config.get("min_value", 0))
			var max_val := float(config.get("max_value", 100))
			if profile.mood_value >= min_val and profile.mood_value <= max_val:
				mood_idx = i
				break
	macro_mood_option.select(mood_idx)

	if GameDataManager.config:
		free_chat_toggle.button_pressed = GameDataManager.config.get_custom_config("free_chat_enabled", false)

	_refresh_core_stats_label()

func _refresh_summary_labels() -> void:
	var profile = GameDataManager.profile
	var story_time_manager = GameDataManager.story_time_manager
	if profile == null or story_time_manager == null:
		return

	time_summary_label.text = "当前剧情时间：%s" % story_time_manager.get_story_time_string()

	var flavor_label := "未知"
	if GameDataManager.personality_system:
		flavor_label = GameDataManager.personality_system.get_relationship_flavor_label(profile)
	relation_summary_label.text = "角色：%s | 阶段：%d | 亲密 %.0f | 信任 %.0f | 心情 %.0f | 表情 %s | 关系风味 %s" % [
		profile.current_character_id,
		profile.current_stage,
		profile.intimacy,
		profile.trust,
		profile.mood_value,
		profile.current_expression,
		flavor_label
	]

	var triggered_count := 0
	var event_manager = get_node_or_null("/root/EventManager")
	if event_manager:
		triggered_count = event_manager.triggered_events.size()
	overview_story_summary_label.text = "已完成剧情 %d 项 | 已触发事件 %d 项 | 金币 %d | 行动力 %d/%d" % [
		profile.finished_stories.size(),
		triggered_count,
		profile.gold,
		profile.current_energy,
		profile.max_energy
	]
	if story_progress_summary_label:
		story_progress_summary_label.text = "当前角色共有 %d 条已完成剧情，列表中 [x] 表示已完成，[ ] 表示未完成或尚未记录。" % [
			profile.finished_stories.size()
		]

	if event_summary_label:
		event_summary_label.text = "事件注册数：%d | 当前角色已触发：%d" % [available_event_ids.size(), triggered_count]

func _get_main_scene_debug_target() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene
	return get_node_or_null("/root/MainScene")

func _get_guide_manager() -> Node:
	return get_node_or_null("/root/GuideManager")

func _resolve_main_feature_unlock_state(feature_id: String) -> bool:
	var main_scene := _get_main_scene_debug_target()
	if main_scene and main_scene.has_method("is_main_feature_unlocked"):
		return bool(main_scene.is_main_feature_unlocked(feature_id))
	var guide_manager := _get_guide_manager()
	if guide_manager == null or not guide_manager.has_method("is_feature_unlocked"):
		return true
	return bool(guide_manager.is_feature_unlocked(feature_id, true))

func _refresh_main_feature_unlock_controls() -> void:
	if feature_unlock_summary_label == null:
		return
	var summary_parts: Array[String] = []
	for feature_config in MAIN_FEATURE_DEBUG_CONFIG:
		var feature_id := str(feature_config.get("id", "")).strip_edges()
		var label_text := str(feature_config.get("label", feature_id))
		var unlocked := _resolve_main_feature_unlock_state(feature_id)
		summary_parts.append("%s:%s" % [label_text, "已解锁" if unlocked else "已锁定"])
		var toggle_btn := feature_toggle_buttons.get(feature_id) as Button
		if toggle_btn:
			toggle_btn.text = "%s：%s" % [label_text, "锁定" if unlocked else "解锁"]
			_style_button(toggle_btn, not unlocked)
	feature_unlock_summary_label.text = "当前状态：%s" % " | ".join(summary_parts)

func _apply_main_feature_unlock_updates(updates: Dictionary, status_text: String) -> void:
	var guide_manager := _get_guide_manager()
	if guide_manager == null or not guide_manager.has_method("set_feature_unlocks"):
		_update_status("未找到 GuideManager，无法修改功能锁定状态")
		return
	var main_scene := _get_main_scene_debug_target()
	guide_manager.set_feature_unlocks(updates, main_scene)
	_trigger_global_auto_save()
	_refresh_main_feature_unlock_controls()
	_update_status(status_text)

func _refresh_core_stats_label() -> void:
	var profile = GameDataManager.profile
	if profile == null or GameDataManager.stats_system == null or core_stats_label == null:
		return
	core_stats_label.text = "四基合计：体 %d / 智 %d / 魅 %d / 感 %d" % [
		GameDataManager.stats_system.get_core_physical(profile),
		GameDataManager.stats_system.get_core_intelligence(profile),
		GameDataManager.stats_system.get_core_charm(profile),
		GameDataManager.stats_system.get_core_sensibility(profile)
	]

func _refresh_story_event_lists() -> void:
	var profile = GameDataManager.profile
	var event_manager = get_node_or_null("/root/EventManager")
	if profile == null or event_manager == null:
		return

	finished_story_list.clear()
	var story_source: Array[String] = available_story_ids.duplicate()
	for finished_id in profile.finished_stories:
		var normalized_id := str(finished_id)
		if not story_source.has(normalized_id):
			story_source.append(normalized_id)
	story_source.sort()
	for story_id in story_source:
		var prefix := "[x]" if profile.finished_stories.has(story_id) else "[ ]"
		finished_story_list.add_item("%s %s" % [prefix, story_id])

	event_list.clear()
	var event_source: Array[String] = available_event_ids.duplicate()
	for triggered_id in event_manager.triggered_events:
		var normalized_event_id := str(triggered_id)
		if not event_source.has(normalized_event_id):
			event_source.append(normalized_event_id)
	event_source.sort()
	for event_id in event_source:
		var prefix := "[x]" if event_manager.triggered_events.has(event_id) else "[ ]"
		event_list.add_item("%s %s" % [prefix, event_id])

func _refresh_story_debug_summary() -> void:
	if story_play_summary_label:
		var manual_input: String = story_play_input.text.strip_edges() if story_play_input else ""
		var selected_story_id: String = manual_input if manual_input != "" else _get_selected_story_id()
		var resolved_story_path: String = _resolve_story_path(selected_story_id)
		var filter_text: String = story_filter_input.text.strip_edges() if story_filter_input else ""
		story_play_summary_label.text = "筛选：%s | 命中 %d / %d\n选中剧情：%s\n解析路径：%s" % [
			filter_text if filter_text != "" else "全部",
			filtered_story_ids.size(),
			available_story_ids.size(),
			selected_story_id if selected_story_id != "" else "未选择",
			resolved_story_path if resolved_story_path != "" else "未解析到脚本"
		]

	if entry_story_summary_label:
		var location_id: String = _get_selected_location_id()
		if location_id == "":
			entry_story_summary_label.text = "未选择地点"
			return
		var analysis: Dictionary = MapDataManager.analyze_location_entry_stories(location_id) if MapDataManager.has_method("analyze_location_entry_stories") else {}
		var entry_story: Dictionary = analysis.get("current_story", MapDataManager.get_location_entry_story(location_id))
		var preview_npc_id: String = _get_debug_entry_npc_id(location_id)
		var context: Dictionary = analysis.get("context", {})
		var context_text: String = "day=%s | period=%s | weather=%s | events=%s | stage=%s" % [
			str(context.get("day_offset", "-")),
			str(context.get("period", "-")),
			str(context.get("weather", "-")),
			str(context.get("active_events", [])),
			str(context.get("stage", "-"))
		]
		if entry_story.is_empty():
			var reason_lines: Array[String] = []
			for entry_data in analysis.get("entries", []):
				if not (entry_data is Dictionary):
					continue
				var story_data: Dictionary = entry_data.get("story", {})
				var resolved_id := str(story_data.get("resolved_id", story_data.get("id", ""))).strip_edges()
				var reasons: Array = entry_data.get("failure_reasons", [])
				var reason_text: String = "；".join(reasons) if not reasons.is_empty() else "未命中，但没有返回详细原因"
				reason_lines.append("- %s: %s" % [resolved_id if resolved_id != "" else "未命名剧情", reason_text])
			var suffix: String = "\n失败原因：\n%s" % "\n".join(reason_lines) if not reason_lines.is_empty() else ""
			entry_story_summary_label.text = "地点 %s 当前没有可触发的入口剧情；将直接进入 quick_location_scene。默认 NPC：%s\n上下文：%s%s" % [
				location_id,
				preview_npc_id if preview_npc_id != "" else "无",
				context_text,
				suffix
			]
			return
		var story_id: String = str(entry_story.get("id", "")).strip_edges()
		var script_path: String = str(entry_story.get("trigger_script", "")).strip_edges()
		var badge_text: String = str(entry_story.get("badge_text", "主线")).strip_edges()
		entry_story_summary_label.text = "地点 %s 当前入口剧情：%s\n脚本：%s\n标识：%s | 进入 NPC：%s\n上下文：%s" % [
			location_id,
			story_id if story_id != "" else script_path.get_file().get_basename(),
			script_path,
			badge_text if badge_text != "" else "主线",
			preview_npc_id if preview_npc_id != "" else "无",
			context_text
		]

func _commit_profile_changes(status_text: String) -> void:
	var profile = GameDataManager.profile
	if profile == null:
		return
	profile.save_profile()
	profile.profile_updated.emit()
	if GameDataManager.save_manager:
		GameDataManager.save_manager.call_deferred("auto_save")
	_refresh_all_views()
	_update_status(status_text)

func _trigger_global_auto_save() -> void:
	if GameDataManager.save_manager:
		GameDataManager.save_manager.call_deferred("auto_save")

func _update_personality_display(profile: CharacterProfile) -> void:
	if profile == null or not is_instance_valid(personality_text):
		return

	var base_o := float(profile.base_personality.get("openness", 50.0))
	var base_c := float(profile.base_personality.get("conscientiousness", 50.0))
	var base_e := float(profile.base_personality.get("extraversion", 50.0))
	var base_a := float(profile.base_personality.get("agreeableness", 50.0))
	var base_n := float(profile.base_personality.get("neuroticism", 50.0))

	var text := "[b]基础分值 -> 实时分值[/b]\n\n"
	text += "经验开放性 (O): %.1f -> [color=#4a90e2]%.1f[/color]\n" % [base_o, profile.openness]
	text += "尽责严谨性 (C): %.1f -> [color=#4a90e2]%.1f[/color]\n" % [base_c, profile.conscientiousness]
	text += "外向活跃性 (E): %.1f -> [color=#4a90e2]%.1f[/color]\n" % [base_e, profile.extraversion]
	text += "亲和共情性 (A): %.1f -> [color=#4a90e2]%.1f[/color]\n" % [base_a, profile.agreeableness]
	text += "神经敏感性 (N): %.1f -> [color=#4a90e2]%.1f[/color]\n" % [base_n, profile.neuroticism]

	if GameDataManager.personality_system:
		text += "\n[b]人格状态:[/b]\n"
		text += GameDataManager.personality_system.get_personality_state_summary(profile) + "\n"
		text += GameDataManager.personality_system.get_recent_event_summary(profile) + "\n"
		text += GameDataManager.personality_system.get_tension_summary(profile) + "\n"
		text += GameDataManager.personality_system.get_mood_summary(profile) + "\n"
		text += GameDataManager.personality_system.get_pattern_summary(profile) + "\n"
		text += GameDataManager.personality_system.get_last_settlement_summary(profile) + "\n"
		text += "\n[b]动态特征描述:[/b]\n"
		text += GameDataManager.personality_system.get_dynamic_traits(profile)

	personality_text.text = text

func _update_status(text: String) -> void:
	if status_label:
		status_label.text = text

func _get_weather_index(weather_id: String) -> int:
	for i in range(WEATHER_OPTIONS.size()):
		if str(WEATHER_OPTIONS[i].get("id", "")) == weather_id:
			return i
	return 0

func _get_selected_weather_id() -> String:
	if weather_option == null or weather_option.selected < 0 or weather_option.selected >= WEATHER_OPTIONS.size():
		return "sunny"
	return str(WEATHER_OPTIONS[weather_option.selected].get("id", "sunny"))

func _get_selected_stage() -> int:
	if stage_option == null or stage_option.selected < 0:
		return 1
	return int(stage_option.get_item_id(stage_option.selected))

func _get_selected_expression_id() -> String:
	if expression_option == null or expression_option.selected < 0 or expression_option.selected >= expression_ids.size():
		return "calm"
	return expression_ids[expression_option.selected]

func _get_selected_story_id() -> String:
	if story_play_option == null or story_play_option.item_count <= 0 or story_play_option.selected < 0:
		return ""
	return story_play_option.get_item_text(story_play_option.selected).strip_edges()

func _get_selected_location_id() -> String:
	if entry_location_option == null or entry_location_option.item_count <= 0 or entry_location_option.selected < 0:
		return ""
	var raw_text := entry_location_option.get_item_text(entry_location_option.selected)
	return raw_text.get_slice(" | ", 0).strip_edges()

func _extract_marked_item_id(text: String) -> String:
	if text.length() <= 4:
		return text.strip_edges()
	return text.substr(4).strip_edges()

func _resolve_story_path(raw_value: String) -> String:
	var normalized_value := raw_value.strip_edges()
	if normalized_value == "":
		return ""
	if normalized_value.begins_with("res://") or normalized_value.begins_with("user://"):
		if ResourceLoader.exists(normalized_value) or FileAccess.file_exists(normalized_value):
			return normalized_value
		return ""
	if story_path_map.has(normalized_value):
		return str(story_path_map[normalized_value])
	for dir_path in STORY_SCAN_DIRS:
		var candidate_path := "%s/%s.json" % [dir_path, normalized_value]
		if ResourceLoader.exists(candidate_path) or FileAccess.file_exists(candidate_path):
			return candidate_path
	return ""

func _apply_story_filter_to_option() -> void:
	if story_play_option == null:
		return
	var previous_story: String = story_play_option.get_item_text(story_play_option.selected) if story_play_option.item_count > 0 and story_play_option.selected >= 0 else ""
	var filter_text: String = story_filter_input.text.strip_edges().to_lower() if story_filter_input else ""
	filtered_story_ids.clear()
	story_play_option.clear()
	for story_id in available_story_ids:
		if filter_text != "" and story_id.to_lower().find(filter_text) == -1:
			continue
		filtered_story_ids.append(story_id)
		story_play_option.add_item(story_id)
	if story_play_option.item_count > 0:
		var selected_index := 0
		if previous_story != "":
			var match_index := filtered_story_ids.find(previous_story)
			if match_index >= 0:
				selected_index = match_index
		story_play_option.select(selected_index)

func _on_story_filter_changed(_new_text: String) -> void:
	_apply_story_filter_to_option()
	_refresh_story_debug_summary()

func _get_debug_entry_npc_id(location_id: String) -> String:
	var manual_npc_id: String = entry_npc_input.text.strip_edges() if entry_npc_input else ""
	if manual_npc_id != "":
		return manual_npc_id
	var npcs: Array = MapDataManager.generate_location_npcs(location_id)
	if not npcs.is_empty():
		return str(npcs[0]).strip_edges()
	return ""

func _open_quick_location_debug(location_id: String, npc_id: String, duration: float = 0.4) -> void:
	var quick_scene_res = load(QUICK_LOCATION_SCENE_PATH)
	if quick_scene_res == null:
		_update_status("QuickLocation 场景加载失败")
		return
	var instance = quick_scene_res.instantiate()
	instance.location_id = location_id
	instance.initial_npc_id = npc_id
	hide()
	var transition_manager = get_node_or_null("/root/SceneTransitionManager")
	if transition_manager:
		transition_manager.transition_to_scene_instance(instance, duration)
	else:
		get_tree().root.add_child(instance)
		get_tree().current_scene = instance

func _play_story_via_transition(script_path: String, status_text: String) -> void:
	if script_path == "":
		_update_status("未找到可播放的剧情脚本")
		return
	GameDataManager.set_meta("play_specific_story", script_path)
	hide()
	var transition_manager = get_node_or_null("/root/SceneTransitionManager")
	if transition_manager:
		transition_manager.transition_to_scene(STORY_SCENE_PATH)
	else:
		get_tree().change_scene_to_file(STORY_SCENE_PATH)
	_update_status(status_text)

func _simulate_location_entry_story_flow(location_id: String, npc_id: String, story_config: Dictionary) -> void:
	var script_path := str(story_config.get("trigger_script", "")).strip_edges()
	if script_path == "":
		_open_quick_location_debug(location_id, npc_id)
		return
	if not (ResourceLoader.exists(script_path) or FileAccess.file_exists(script_path)):
		_update_status("入口剧情脚本不存在，已改为直接进入地点")
		_open_quick_location_debug(location_id, npc_id)
		return

	var host_scene: Node = get_tree().current_scene if get_tree().current_scene != null else self
	hide()
	var transition_overlay := ColorRect.new()
	transition_overlay.color = Color.BLACK
	transition_overlay.modulate.a = 0.0
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_overlay.z_index = 300
	host_scene.add_child(transition_overlay)

	var fade_in := create_tween()
	fade_in.tween_property(transition_overlay, "modulate:a", 1.0, 0.35)
	await fade_in.finished
	if not is_inside_tree():
		return

	GameDataManager.set_meta("play_specific_story", script_path)
	var story_scene_res = load(STORY_SCENE_PATH)
	if story_scene_res == null:
		if is_instance_valid(transition_overlay):
			transition_overlay.queue_free()
		_update_status("StoryScene 加载失败")
		return
	var story_scene = story_scene_res.instantiate()
	host_scene.add_child(story_scene)
	if story_scene is Control:
		story_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		story_scene.z_index = 240
	host_scene.move_child(transition_overlay, host_scene.get_child_count() - 1)

	await get_tree().process_frame
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return

	var fade_out := create_tween()
	fade_out.tween_property(transition_overlay, "modulate:a", 0.0, 0.35)
	await fade_out.finished
	if not is_inside_tree():
		return

	await story_scene.chat_closed
	if not is_inside_tree():
		return

	var fade_back := create_tween()
	fade_back.tween_property(transition_overlay, "modulate:a", 1.0, 0.35)
	await fade_back.finished
	if not is_inside_tree():
		return

	if is_instance_valid(story_scene):
		story_scene.queue_free()
	if is_instance_valid(transition_overlay):
		transition_overlay.queue_free()

	_open_quick_location_debug(location_id, npc_id, 0.2)

func _on_refresh_all_pressed() -> void:
	_reload_reference_ids()
	_refresh_all_views()

func _on_refresh_story_debug_info_pressed() -> void:
	_refresh_story_debug_summary()
	_update_status("已刷新剧情解析信息")

func _on_close_pressed() -> void:
	hide()

func _on_apply_time_weather_pressed() -> void:
	var story_time_manager = GameDataManager.story_time_manager
	if story_time_manager == null:
		_update_status("时间系统未就绪")
		return
	story_time_manager.set_debug_time(int(day_spin.value), period_option.get_item_text(period_option.selected), int(hour_spin.value), int(minute_spin.value))
	story_time_manager.set_debug_weather(_get_selected_weather_id(), int(temperature_spin.value), int(day_spin.value))
	_trigger_global_auto_save()
	_refresh_all_views()
	_update_status("已应用时间与天气覆盖")

func _on_advance_period_pressed() -> void:
	var story_time_manager = GameDataManager.story_time_manager
	if story_time_manager == null:
		return
	story_time_manager.advance_period()
	story_time_manager.save_data()
	_trigger_global_auto_save()
	_refresh_all_views()
	_update_status("已推进到下一时段")

func _on_advance_day_pressed() -> void:
	var story_time_manager = GameDataManager.story_time_manager
	if story_time_manager == null:
		return
	story_time_manager.advance_day(1)
	story_time_manager.save_data()
	_trigger_global_auto_save()
	_refresh_all_views()
	_update_status("已推进一天")

func _on_clear_weather_override_pressed() -> void:
	var story_time_manager = GameDataManager.story_time_manager
	if story_time_manager == null:
		return
	story_time_manager.clear_debug_weather(int(day_spin.value))
	_trigger_global_auto_save()
	_refresh_all_views()
	_update_status("已清除该天的天气覆盖")

func _on_stage_option_preview_selected(_index: int) -> void:
	_update_status("阶段选项已切换，点击“应用关系状态”后生效")

func _on_macro_mood_selected(index: int) -> void:
	if GameDataManager.mood_system == null:
		return
	if index < 0 or index >= GameDataManager.mood_system.macro_mood_configs.size():
		return
	var config = GameDataManager.mood_system.macro_mood_configs[index]
	var min_val := float(config.get("min_value", 0))
	var max_val := float(config.get("max_value", 100))
	mood_value_spin.value = (min_val + max_val) / 2.0

func _on_apply_relation_pressed() -> void:
	var profile = GameDataManager.profile
	if profile == null:
		return
	profile.current_stage = _get_selected_stage()
	profile.intimacy = intimacy_spin.value
	profile.trust = trust_spin.value
	profile.mood_value = mood_value_spin.value
	profile.update_expression(_get_selected_expression_id())
	stage_changed.emit(profile.current_stage)
	_commit_profile_changes("已应用关系、阶段、心情与表情")

func _on_apply_resources_pressed() -> void:
	var profile = GameDataManager.profile
	if profile == null:
		return
	profile.max_energy = max(1, int(max_energy_spin.value))
	profile.current_energy = clamp(int(energy_spin.value), 0, profile.max_energy)
	profile.gold = int(gold_spin.value)
	_commit_profile_changes("已应用金币与行动力")

func _on_apply_sub_stats_pressed() -> void:
	var profile = GameDataManager.profile
	if profile == null:
		return
	for stat_id in sub_stat_spins.keys():
		var spin: SpinBox = sub_stat_spins[stat_id]
		profile.set(str(stat_id), spin.value)
	_commit_profile_changes("已应用八维属性")

func _on_mark_story_finished_pressed() -> void:
	var profile = GameDataManager.profile
	var story_id := finished_story_input.text.strip_edges()
	if profile == null or story_id == "":
		_update_status("请输入要标记的剧情 ID")
		return
	profile.mark_story_finished(story_id)
	_refresh_all_views()
	_update_status("已标记剧情完成：%s" % story_id)

func _on_unmark_story_finished_pressed() -> void:
	var profile = GameDataManager.profile
	var story_id := finished_story_input.text.strip_edges()
	if profile == null or story_id == "":
		_update_status("请输入要移除的剧情 ID")
		return
	if profile.has_method("unmark_story_finished"):
		profile.unmark_story_finished(story_id)
	_refresh_all_views()
	_update_status("已移除剧情完成标记：%s" % story_id)

func _on_clear_finished_stories_pressed() -> void:
	var profile = GameDataManager.profile
	if profile == null:
		return
	if profile.has_method("clear_finished_stories"):
		profile.clear_finished_stories()
	_refresh_all_views()
	_update_status("已清空所有剧情完成记录")

func _on_mark_event_triggered_pressed() -> void:
	var event_manager = get_node_or_null("/root/EventManager")
	var event_id := triggered_event_input.text.strip_edges()
	if event_manager == null or event_id == "":
		_update_status("请输入要标记的事件 ID")
		return
	event_manager.mark_event_triggered(event_id)
	_trigger_global_auto_save()
	_refresh_all_views()
	_update_status("已标记事件触发：%s" % event_id)

func _on_unmark_event_triggered_pressed() -> void:
	var event_manager = get_node_or_null("/root/EventManager")
	var event_id := triggered_event_input.text.strip_edges()
	if event_manager == null or event_id == "":
		_update_status("请输入要移除的事件 ID")
		return
	if event_manager.has_method("unmark_event_triggered"):
		event_manager.unmark_event_triggered(event_id)
	_trigger_global_auto_save()
	_refresh_all_views()
	_update_status("已移除事件触发：%s" % event_id)

func _on_clear_triggered_events_pressed() -> void:
	var event_manager = get_node_or_null("/root/EventManager")
	if event_manager == null:
		return
	if event_manager.has_method("clear_triggered_events"):
		event_manager.clear_triggered_events()
	_trigger_global_auto_save()
	_refresh_all_views()
	_update_status("已清空所有事件触发记录")

func _on_finished_story_selected(index: int) -> void:
	finished_story_input.text = _extract_marked_item_id(finished_story_list.get_item_text(index))

func _on_event_selected(index: int) -> void:
	triggered_event_input.text = _extract_marked_item_id(event_list.get_item_text(index))

func _on_play_story_pressed() -> void:
	var raw_input: String = story_play_input.text.strip_edges() if story_play_input else ""
	var story_key: String = raw_input if raw_input != "" else _get_selected_story_id()
	var script_path: String = _resolve_story_path(story_key)
	if script_path == "":
		_update_status("未解析到剧情脚本：%s" % story_key)
		return
	_play_story_via_transition(script_path, "正在播放剧情：%s" % story_key)

func _on_simulate_location_entry_pressed() -> void:
	var location_id := _get_selected_location_id()
	if location_id == "":
		_update_status("请先选择地点")
		return
	var npc_id := _get_debug_entry_npc_id(location_id)
	var entry_story: Dictionary = MapDataManager.get_location_entry_story(location_id)
	if entry_story.is_empty():
		_update_status("当前无入口剧情，直接进入地点：%s" % location_id)
		_open_quick_location_debug(location_id, npc_id)
		return
	await _simulate_location_entry_story_flow(location_id, npc_id, entry_story)
	_update_status("已执行地点入口剧情模拟：%s" % location_id)

func _on_play_entry_story_only_pressed() -> void:
	var location_id := _get_selected_location_id()
	if location_id == "":
		_update_status("请先选择地点")
		return
	var entry_story: Dictionary = MapDataManager.get_location_entry_story(location_id)
	if entry_story.is_empty():
		_update_status("该地点当前没有可播放的入口剧情")
		return
	var script_path := str(entry_story.get("trigger_script", "")).strip_edges()
	if script_path == "":
		_update_status("入口剧情未配置脚本")
		return
	_play_story_via_transition(script_path, "正在播放入口剧情：%s" % location_id)

func _on_switch_char_pressed() -> void:
	var profiles := _get_available_character_ids()
	var current_id := ""
	if GameDataManager.config:
		current_id = GameDataManager.config.current_character_id
	if current_id == "" and GameDataManager.profile:
		current_id = GameDataManager.profile.current_character_id

	if profiles.size() <= 1:
		_update_status("当前只有一个角色，无需切换")
		return

	var idx := profiles.find(current_id)
	var next_idx := (idx + 1) % profiles.size()
	var next_id: String = str(profiles[next_idx])
	GameDataManager.switch_character(next_id)
	_reload_reference_ids()
	show_panel()
	_update_status("已切换角色：%s" % next_id)

func _get_available_character_ids() -> Array:
	var ids: Array = []
	var dir = DirAccess.open("res://assets/data/characters")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json") and not file_name.ends_with("_stages.json"):
				ids.append(file_name.replace(".json", ""))
			file_name = dir.get_next()
		dir.list_dir_end()
	return ids

func _on_test_call_pressed() -> void:
	var fixed_calls_path := "res://assets/data/story/scripts/calls/fixed_calls.json"
	if not FileAccess.file_exists(fixed_calls_path):
		_update_status("未找到通话数据文件")
		return

	var file = FileAccess.open(fixed_calls_path, FileAccess.READ)
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	if err != OK:
		_update_status("通话数据解析失败")
		return

	var calls_data = json.data
	if not (calls_data is Dictionary) or calls_data.keys().is_empty():
		_update_status("通话数据为空")
		return

	var first_call_id = calls_data.keys()[0]
	var call_event = {
		"type": "video_call",
		"call_id": first_call_id
	}

	var call_system = get_node_or_null("/root/CallEventSystem")
	if call_system:
		call_system.trigger_call_event(call_event)
		_update_status("已触发测试来电：%s" % first_call_id)
		return

	var main_scene = get_tree().current_scene
	if main_scene == null:
		_update_status("当前场景不可用，无法模拟来电")
		return
	var chat_scene = preload("res://scenes/ui/mobile/chat/mobile_chat_panel.tscn").instantiate()
	main_scene.add_child(chat_scene)
	chat_scene.hide_panel(false)
	await get_tree().process_frame
	if chat_scene.has_method("start_video_call"):
		chat_scene.start_video_call(true, false)
	_update_status("已通过聊天面板模拟来电")

func _on_generate_diary_pressed() -> void:
	generate_diary_btn.disabled = true
	generate_diary_btn.text = "生成中..."

	var client = DeepSeekClientLocator.find(self)

	if client and client.has_method("send_diary_generation"):
		if not client.diary_generated.is_connected(_on_diary_generated):
			client.diary_generated.connect(_on_diary_generated)
		if not client.diary_error.is_connected(_on_diary_error):
			client.diary_error.connect(_on_diary_error)
		client.send_diary_generation()
		_update_status("正在请求生成日记")
		return

	await get_tree().create_timer(1.0).timeout
	var mock_diary := {
		"date": Time.get_date_string_from_system(),
		"weather": "晴",
		"content": "今天天气不错，调试面板已经成功触发了一次模拟日记生成。"
	}
	_on_diary_generated(mock_diary)

func _on_diary_generated(diary_entry: Dictionary) -> void:
	generate_diary_btn.disabled = false
	generate_diary_btn.text = "生成日记"
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("show_diary_notification"):
		main_scene.show_diary_notification()
	var image_error := str(diary_entry.get("image_generation_error", "")).strip_edges()
	if image_error != "":
		_update_status("日记文字生成成功，插图使用占位图：%s" % image_error)
	else:
		_update_status("日记生成成功")

func _on_diary_error(error_msg: String) -> void:
	generate_diary_btn.disabled = false
	generate_diary_btn.text = "生成日记"
	_update_status("日记生成失败：%s" % error_msg)

func _on_send_moment_pressed() -> void:
	var author := moment_author_input.text.strip_edges()
	var content := moment_content_input.text.strip_edges()
	if author == "":
		author = "AI"
	if content == "":
		content = "这是一条测试内容"

	var images: Array = []
	if moment_mode_option.selected == 0:
		images.append("res://icon.svg")

	var moments_manager = get_node_or_null("/root/MomentsManager")
	if moments_manager:
		moments_manager.add_moment(author, Time.get_date_string_from_system(), content, images)
		_update_status("已手动插入测试朋友圈")
	else:
		_update_status("MomentsManager 未找到")

func _on_ai_generate_moment_pressed() -> void:
	var event_manager = get_node_or_null("/root/EventManager")
	if event_manager and event_manager.has_method("execute_event"):
		event_manager.execute_event("post_moment")
		_update_status("已触发 AI 自动生成朋友圈")
	else:
		_update_status("EventManager 未找到")

func _on_set_trait_pressed() -> void:
	var trait_map := ["openness", "conscientiousness", "extraversion", "agreeableness", "neuroticism"]
	var selected_idx := trait_option.selected
	if selected_idx < 0 or selected_idx >= trait_map.size():
		return
	var profile = GameDataManager.profile
	if profile == null:
		return
	var trait_name: String = str(trait_map[selected_idx])
	profile.set(trait_name, trait_value_input.value)
	profile.refresh_personality_state()
	_commit_profile_changes("已强制设置人格维度：%s" % trait_name)

func _on_refresh_personality_pressed() -> void:
	if GameDataManager.profile:
		_update_personality_display(GameDataManager.profile)
		_update_status("已刷新人格显示")

func _on_snapshot_personality_pressed() -> void:
	var profile = GameDataManager.profile
	if profile == null:
		return
	profile.record_personality_snapshot("debug_manual", true)
	profile.profile_updated.emit()
	_trigger_global_auto_save()
	_refresh_all_views()
	_update_status("已记录人格快照")

func _on_settle_personality_pressed() -> void:
	var profile = GameDataManager.profile
	if profile == null or GameDataManager.personality_system == null:
		return
	GameDataManager.personality_system.settle_personality_tension(profile, "debug_manual", {
		"short_settle_scale": 1.0,
		"long_settle_scale": 0.35,
		"force_log": true,
		"force_snapshot": true
	})
	profile.profile_updated.emit()
	_trigger_global_auto_save()
	_refresh_all_views()
	_update_status("已执行一次人格张力沉降")

func _on_free_chat_toggled(toggled_on: bool) -> void:
	if GameDataManager.config:
		GameDataManager.config.set_custom_config("free_chat_enabled", toggled_on)
		GameDataManager.config.save_config()
	_update_status("自由聊天已%s" % ("开启" if toggled_on else "关闭"))

func _on_test_fixed_chat_pressed() -> void:
	var manager = get_node_or_null("/root/MobileFixedChatManager")
	if manager:
		manager.trigger_script("jing_piano_practice_invite")
		_update_status("已触发静的固定聊天剧本")
		_on_close_pressed()

func _on_clear_fixed_chat_pressed() -> void:
	var manager = get_node_or_null("/root/MobileFixedChatManager")
	if manager:
		manager.clear_all_records()
		_update_status("已清除所有固定对话记录")

func _on_toggle_main_feature_pressed(feature_id: String) -> void:
	var current_unlocked := _resolve_main_feature_unlock_state(feature_id)
	var target_unlocked := not current_unlocked
	_apply_main_feature_unlock_updates(
		{feature_id: target_unlocked},
		"已将 %s 调整为%s" % [feature_id, "解锁" if target_unlocked else "锁定"]
	)

func _on_unlock_all_main_features_pressed() -> void:
	var updates: Dictionary = {}
	for feature_config in MAIN_FEATURE_DEBUG_CONFIG:
		var feature_id := str(feature_config.get("id", "")).strip_edges()
		if feature_id != "":
			updates[feature_id] = true
	_apply_main_feature_unlock_updates(updates, "已解锁全部主场景测试功能")

func _on_lock_all_main_features_pressed() -> void:
	var updates: Dictionary = {}
	for feature_config in MAIN_FEATURE_DEBUG_CONFIG:
		var feature_id := str(feature_config.get("id", "")).strip_edges()
		if feature_id != "":
			updates[feature_id] = false
	_apply_main_feature_unlock_updates(updates, "已锁定全部主场景测试功能")

func _on_refresh_main_feature_unlocks_pressed() -> void:
	_refresh_main_feature_unlock_controls()
	_update_status("已刷新主场景功能锁定状态")
