@tool
extends Control

const WINDOW_LAYOUT_PATH := "res://addons/story_editor/core/editor_window_layout.gd"


const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")
const StoryScanner = preload("res://addons/story_editor/core/story_scanner.gd")
const MobileChatScanner = preload("res://addons/story_editor/core/mobile_fixed_chat_scanner.gd")
const FixedCallScanner = preload("res://addons/story_editor/core/fixed_voice_call_scanner.gd")
const ContentCreationService = preload("res://addons/story_editor/core/story_content_creation_service.gd")
const StoryValidator = preload("res://addons/story_editor/core/story_validator.gd")
const StoryResourceCatalog = preload("res://addons/story_editor/core/story_resource_catalog.gd")
const StoryBranchSimulator = preload("res://addons/story_editor/core/story_branch_simulator.gd")
const EventTemplateService = preload("res://addons/story_editor/core/story_event_template_service.gd")
const NodeTemplateInstantiator = preload("res://addons/story_editor/core/story_node_template_instantiator.gd")
const EventNodeScene = preload("res://addons/story_editor/ui/story_event_node.tscn")
const ChapterEntryNodeScene = preload("res://addons/story_editor/ui/story_chapter_entry_node.tscn")

const CREATE_EVENT_TYPES := [
	"dialogue", "background", "audio", "bgm", "show_character",
	"move_character", "hide_character", "period_card", "choice", "jump",
	"set_variable", "ai_chat", "guided_ai_chat", "start_free_chat", "voice_call",
	"show_player_call_name_popup"
]

const EVENT_TYPE_LABELS := {
	"dialogue": "对白",
	"background": "切换背景",
	"audio": "音效",
	"bgm": "背景音乐",
	"show_character": "显示角色",
	"move_character": "移动角色",
	"hide_character": "隐藏角色",
	"period_card": "时段卡片",
	"choice": "玩家选项",
	"jump": "跳转章节",
	"set_variable": "设置变量",
	"ai_chat": "AI 对话",
	"guided_ai_chat": "引导式 AI 主线对话",
	"start_free_chat": "自由聊天",
	"voice_call": "语音通话",
	"show_player_call_name_popup": "称呼设置弹窗"
}

const EVENT_DEFAULTS := {
	"dialogue": {"type": "dialogue", "speaker": "旁白", "content": "新对白"},
	"background": {"type": "background", "bg_id": "", "transition_type": "fade", "duration": 0.5},
	"audio": {"type": "audio", "audio_id": "", "audio_type": "se", "action": "play", "fade_time": 0.0, "loop": false},
	"bgm": {"type": "bgm", "audio_id": "", "action": "play", "fade_time": 1.0, "loop": true},
	"show_character": {"type": "show_character", "character": "", "position": "center", "expression": "default", "animation": "fade_in", "focus": true},
	"move_character": {"type": "move_character", "character": "", "position": "center", "expression": "default", "animation": "move", "focus": true},
	"hide_character": {"type": "hide_character", "character": "", "animation": "fade_out"},
	"period_card": {"type": "period_card", "bg_id": "", "period_label": "", "location_name": "", "hold_duration": 2.0},
	"choice": {"type": "choice", "options": [{"id": "option_1", "text": "新选项", "kind": "intimacy", "response": "", "effects": {"intimacy": 0, "trust": 0}}]},
	"jump": {"type": "jump", "target_chapter": "end"},
	"set_variable": {"type": "set_variable", "var_name": "", "var_value": true},
	"ai_chat": {"type": "ai_chat", "prompt_override": ""},
	"guided_ai_chat": {
		"type": "guided_ai_chat",
		"session_id": "guided_story_chat",
		"narrative_anchor": "描述本轮不可被改写的剧情事实。",
		"scene_objective": "描述本轮对话需要达成的剧情目标。",
		"allowed_topics": [],
		"forbidden_facts": [],
		"required_beats": [],
		"redirect_instruction": "玩家偏题时先简短回应，再自然拉回当前主线。",
		"max_player_rounds": 4,
		"game_minutes": 30,
		"action_cost": 0,
		"allow_early_completion": false,
		"hide_manual_end": true,
		"closing_instruction": "自然收束当前话题，不要提及系统、回合数或限制。",
		"fallback_closing_text": "（轻轻点头）那今天就先聊到这里吧。",
		"outcome_branches": {}
	},
	"start_free_chat": {"type": "start_free_chat", "strategy": "", "max_rounds": 3},
	"voice_call": {"type": "voice_call", "call_id": ""},
	"show_player_call_name_popup": {"type": "show_player_call_name_popup"}
}

const EVENT_TEMPLATES := {
	"地点与时段开场": [
		{"type": "period_card", "bg_id": "", "period_label": "", "location_name": "", "hold_duration": 2.0},
		{"type": "background", "bg_id": "", "transition_type": "fade", "duration": 0.5},
		{"type": "bgm", "audio_id": "", "action": "switch", "fade_time": 1.0, "loop": true},
		{"type": "dialogue", "speaker": "旁白", "content": "描述当前的时间、地点与氛围。"}
	],
	"双人会面": [
		{"type": "show_character", "character": "", "position": "center", "expression": "default", "animation": "fade_in", "focus": true},
		{"type": "dialogue", "speaker": "旁白", "content": "角色进入了场景。"},
		{"type": "move_character", "character": "", "position": "left", "expression": "default", "animation": "move", "focus": false},
		{"type": "show_character", "character": "", "position": "right", "expression": "default", "animation": "fade_in", "focus": true},
		{"type": "dialogue", "speaker": "旁白", "content": "两人开始交谈。"}
	],
	"回应型玩家选择": [
		{"type": "dialogue", "speaker": "旁白", "content": "现在需要作出回应。"},
		{"type": "choice", "options": [
			{"id": "option_intimacy", "text": "坦率表达自己的感受", "kind": "intimacy", "response": "我想更坦率地告诉你。", "effects": {"intimacy": 2, "trust": 0}},
			{"id": "option_trust", "text": "认真倾听对方", "kind": "trust", "response": "不用着急，我会认真听完。", "effects": {"intimacy": 0, "trust": 2}}
		]},
		{"type": "dialogue", "speaker": "旁白", "content": "短暂的交流后，两人的话题继续下去。"}
	],
	"固定剧情 AI 插曲": [
		{"type": "dialogue", "speaker": "旁白", "content": "接下来可以自由聊聊刚才发生的事。"},
		{"type": "ai_chat", "prompt_override": "围绕刚才发生的事件进行一次克制、连贯且不偏离当前关系阶段的交流。"},
		{"type": "dialogue", "speaker": "旁白", "content": "交流结束后，故事继续。"}
	],
	"引导式 AI 主线": [
		{"type": "dialogue", "speaker": "旁白", "content": "描述进入本轮主线对话前的场景。"},
		{
			"type": "guided_ai_chat",
			"session_id": "guided_story_chat",
			"narrative_anchor": "描述本轮不可被改写的剧情事实。",
			"scene_objective": "描述本轮对话需要达成的剧情目标。",
			"allowed_topics": [],
			"forbidden_facts": [],
			"required_beats": [{"id": "beat_1", "instruction": "描述角色必须自然表达的第一个剧情点。"}],
			"redirect_instruction": "玩家偏题时先简短回应，再自然拉回当前主线。",
			"max_player_rounds": 4,
			"game_minutes": 30,
			"action_cost": 0,
			"allow_early_completion": false,
			"hide_manual_end": true,
			"closing_instruction": "自然收束当前话题，不要提及系统、回合数或限制。",
			"fallback_closing_text": "（轻轻点头）那今天就先聊到这里吧。",
			"outcome_branches": {"complete": "end", "incomplete": "end"}
		},
		{"type": "dialogue", "speaker": "旁白", "content": "描述本轮交流结束后的余韵。"}
	],
	"章节收束与结算": [
		{"type": "hide_character", "character": "", "animation": "fade_out"},
		{"type": "audio", "audio_id": "", "audio_type": "bgs", "action": "stop", "fade_time": 0.5, "loop": false},
		{"type": "bgm", "audio_id": "", "action": "stop", "fade_time": 1.0, "loop": false},
		{"type": "set_variable", "var_name": "", "var_value": true},
		{"type": "jump", "target_chapter": "end"}
	]
}

const EVENT_TEMPLATE_NAMES := [
	"地点与时段开场",
	"双人会面",
	"回应型玩家选择",
	"固定剧情 AI 插曲",
	"引导式 AI 主线",
	"章节收束与结算"
]

const TEMPLATE_MENU_CUSTOM_START := 1000
const TEMPLATE_MENU_SAVE := 9000
const TEMPLATE_MENU_DELETE := 9001
const TOOL_VALIDATE := 1
const TOOL_SIMULATE := 2
const TOOL_NODE_TEMPLATES := 3
const TOOL_COVERAGE_REPORT := 4
const CONTENT_MOBILE_CHAT := 10
const CONTENT_FIXED_CALL := 11
const CONTENT_AI_WORKBENCH := 12
const CONTENT_MOBILE_AI := 13
const CONTENT_REFERENCES := 14
const CONTENT_GUIDE_FLOW := 15
const CONTENT_SCHEDULE := 16
const CONTENT_CONCERN_AI := 17
const SYSTEM_SCHEMA_MIGRATION := 20
const SYSTEM_RUNTIME_DEBUG := 21
const CREATE_CONTENT_TYPES := [
	["main_story", "主线剧情"],
	["map_story", "地图世界"],
	["mobile_chat", "手机消息"],
	["fixed_call", "固定来电"]
]

var current_path := ""
var current_data: Dictionary = {}
var current_chapter := ""
var selected_event_index := -1
var selected_event_indices: Array[int] = []
var syncing_graph_selection := false
var dirty := false
var saved_data: Dictionary = {}
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var chapter_dialog_mode := ""
var copied_event: Dictionary = {}
var copied_events: Array[Dictionary] = []
var event_search_results: Array[Dictionary] = []
var event_search_result_index := -1
var template_library_path := EventTemplateService.DEFAULT_PATH
var custom_event_templates: Array[Dictionary] = []
var template_menu_actions := {}
var active_workspace := "story"

@onready var search_edit: LineEdit = %SearchEdit
@onready var story_tree: Tree = %StoryTree
@onready var chapter_select: OptionButton = %ChapterSelect
@onready var graph_edit: GraphEdit = %GraphEdit
@onready var document_title: Label = %DocumentTitle
@onready var document_path: Label = %DocumentPath
@onready var inspector_title: Label = %InspectorTitle
@onready var event_inspector: VBoxContainer = %EventInspector
@onready var event_type_select: OptionButton = %EventTypeSelect
@onready var event_template_menu: MenuButton = %EventTemplateMenu
@onready var event_search_edit: LineEdit = %EventSearchEdit
@onready var event_search_status: Label = %EventSearchStatus
@onready var previous_event_match_button: Button = %PreviousEventMatchButton
@onready var next_event_match_button: Button = %NextEventMatchButton
@onready var copy_event_button: Button = %CopyEventButton
@onready var paste_event_button: Button = %PasteEventButton
@onready var duplicate_event_button: Button = %DuplicateEventButton
@onready var move_up_button: Button = %MoveUpButton
@onready var move_down_button: Button = %MoveDownButton
@onready var delete_event_button: Button = %DeleteEventButton
@onready var chapter_entry_filter: LineEdit = %ChapterEntryFilter
@onready var focus_selection_button: Button = %FocusSelectionButton
@onready var save_button: Button = %SaveButton
@onready var undo_button: Button = %UndoButton
@onready var redo_button: Button = %RedoButton
@onready var status_label: Label = %StatusLabel
@onready var diagnostics_tree: Tree = %DiagnosticsTree
@onready var simulation_window: Window = %BranchSimulationWindow
@onready var simulation_results: Tree = %SimulationResults
@onready var simulation_summary: Label = %SimulationSummary
@onready var workspace_split: HSplitContainer = %WorkspaceSplit


func _ready() -> void:
	resized.connect(_apply_story_workspace_layout)
	_setup_embedded_fixed_content()
	event_inspector.set_resource_catalog(StoryResourceCatalog.build())
	search_edit.text_changed.connect(_populate_story_tree)
	story_tree.item_selected.connect(_on_story_selected)
	diagnostics_tree.item_activated.connect(_navigate_to_selected_diagnostic)
	chapter_select.item_selected.connect(_on_chapter_selected)
	event_search_edit.text_changed.connect(_refresh_event_search)
	event_search_edit.text_submitted.connect(_on_event_search_submitted)
	previous_event_match_button.pressed.connect(navigate_event_search.bind(-1))
	next_event_match_button.pressed.connect(navigate_event_search.bind(1))
	graph_edit.node_selected.connect(_on_graph_node_selected)
	graph_edit.node_deselected.connect(_on_graph_node_deselected)
	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	graph_edit.begin_node_move.connect(_on_graph_move_started)
	graph_edit.end_node_move.connect(_on_graph_move_finished)
	event_inspector.event_applied.connect(_apply_event_data)
	save_button.pressed.connect(save_current_story)
	%RefreshButton.pressed.connect(_refresh_stories)
	%ArrangeButton.pressed.connect(graph_edit.arrange_nodes)
	chapter_entry_filter.text_changed.connect(_filter_chapter_entries)
	focus_selection_button.pressed.connect(focus_selected_event)
	%ValidateButton.pressed.connect(_refresh_diagnostics)
	%SimulateButton.pressed.connect(_open_branch_simulation)
	%AIWorkbenchButton.pressed.connect(%DateAIWorkbench.open_workbench)
	%ConcernAIButton.pressed.connect(%ConcernAIWorkbench.open_workbench)
	%MobileChatButton.pressed.connect(%MobileChatCatalogWindow.open_catalog)
	%FixedCallButton.pressed.connect(%FixedVoiceCallCatalogWindow.open_catalog)
	%MobileAIButton.pressed.connect(%MobileAIWorkbench.open_workbench)
	%StoryReferencesButton.pressed.connect(%StoryReferenceCatalogWindow.open_catalog)
	%GuideFlowButton.pressed.connect(%GuideFlowEditorWindow.open_editor)
	%ScheduleEntriesButton.pressed.connect(%StoryScheduleEntryEditorWindow.open_editor)
	%SchemaMigrationButton.pressed.connect(%StorySchemaMigrationWindow.open_editor)
	%RuntimeDebugButton.pressed.connect(%StoryRuntimeDebugWindow.open_monitor)
	%NodeTemplatesButton.pressed.connect(_open_node_template_library)
	%StoryNodeTemplateLibraryWindow.instantiate_requested.connect(_instantiate_node_template)
	%CoverageReportButton.pressed.connect(%StoryCoverageReportWindow.open_report)
	%StoryCoverageReportWindow.navigate_requested.connect(navigate_to_story_event)
	_setup_toolbar_menus()
	%RunSimulationButton.pressed.connect(run_branch_simulation)
	%CloseSimulationButton.pressed.connect(simulation_window.hide)
	simulation_window.close_requested.connect(simulation_window.hide)
	simulation_results.item_activated.connect(_navigate_to_simulation_result)
	_setup_simulation_tree()
	diagnostics_tree.set_column_title(0, "级别")
	diagnostics_tree.set_column_title(1, "位置")
	diagnostics_tree.set_column_title(2, "说明")
	diagnostics_tree.set_column_expand(0, false)
	diagnostics_tree.set_column_custom_minimum_width(0, 76)
	diagnostics_tree.set_column_custom_minimum_width(1, 150)
	undo_button.pressed.connect(undo)
	redo_button.pressed.connect(redo)
	%AddChapterButton.pressed.connect(_open_add_chapter_dialog)
	%RenameChapterButton.pressed.connect(_open_rename_chapter_dialog)
	%DeleteChapterButton.pressed.connect(%DeleteChapterDialog.popup_centered)
	%ChapterNameDialog.confirmed.connect(_confirm_chapter_name)
	%DeleteChapterDialog.confirmed.connect(delete_current_chapter)
	%SaveEventTemplateDialog.confirmed.connect(_confirm_save_event_template)
	%DeleteEventTemplateDialog.confirmed.connect(_confirm_delete_event_template)
	%CreateContentButton.pressed.connect(_open_create_content_dialog)
	%CreateContentDialog.confirmed.connect(_confirm_create_content)
	%CreateContentType.item_selected.connect(_update_create_content_form)
	%CreateContentId.text_changed.connect(_update_create_content_form.unbind(1))
	%CreateContentCharacter.text_changed.connect(_update_create_content_form.unbind(1))
	for definition in CREATE_CONTENT_TYPES:
		%CreateContentType.add_item(str(definition[1]))
		%CreateContentType.set_item_metadata(%CreateContentType.item_count - 1, definition[0])
	%AddEventButton.pressed.connect(add_event)
	copy_event_button.pressed.connect(copy_selected_event)
	paste_event_button.pressed.connect(paste_event)
	duplicate_event_button.pressed.connect(duplicate_selected_event)
	move_up_button.pressed.connect(move_selected_event.bind(-1))
	move_down_button.pressed.connect(move_selected_event.bind(1))
	delete_event_button.pressed.connect(delete_selected_event)
	for event_type in CREATE_EVENT_TYPES:
		event_type_select.add_item(str(EVENT_TYPE_LABELS.get(event_type, event_type)))
		event_type_select.set_item_metadata(event_type_select.item_count - 1, event_type)
	event_template_menu.get_popup().id_pressed.connect(_on_event_template_selected)
	_refresh_event_template_menu()
	_refresh_stories()
	call_deferred("_apply_story_workspace_layout")


func _apply_story_workspace_layout() -> void:
	if not is_instance_valid(workspace_split):
		return
	var available_width := maxi(roundi(workspace_split.size.x), 1)
	var minimum_canvas_width := mini(300, maxi(1, available_width - 240))
	var maximum_canvas_width := maxi(minimum_canvas_width, available_width - 240)
	workspace_split.split_offset = clampi(roundi(available_width * 0.66), minimum_canvas_width, maximum_canvas_width)


func set_runtime_debugger_plugin(debugger_plugin: EditorDebuggerPlugin) -> void:
	%StoryRuntimeDebugWindow.set_debug_store(debugger_plugin.store)
	%StoryCoverageReportWindow.set_debug_store(debugger_plugin.store)


func _refresh_event_template_menu() -> void:
	var popup := event_template_menu.get_popup()
	popup.clear()
	template_menu_actions.clear()
	for template_index in EVENT_TEMPLATE_NAMES.size():
		var template_name: String = EVENT_TEMPLATE_NAMES[template_index]
		popup.add_item(template_name, template_index)
		template_menu_actions[template_index] = {"kind": "builtin", "name": template_name}
	var load_result := EventTemplateService.load_templates(template_library_path)
	custom_event_templates.clear()
	if load_result.get("ok", false):
		custom_event_templates.assign(load_result.get("templates", []))
		if not custom_event_templates.is_empty():
			popup.add_separator("项目自定义模板")
			for custom_index in custom_event_templates.size():
				var template := custom_event_templates[custom_index]
				var menu_id := TEMPLATE_MENU_CUSTOM_START + custom_index
				popup.add_item(str(template.get("name", "未命名模板")), menu_id)
				template_menu_actions[menu_id] = {"kind": "custom", "template": template}
	else:
		popup.add_separator("项目自定义模板")
		popup.add_item("自定义模板加载失败", TEMPLATE_MENU_CUSTOM_START)
		popup.set_item_disabled(popup.item_count - 1, true)
		_set_status(str(load_result.get("error", "自定义模板加载失败。")), true)
	popup.add_separator()
	popup.add_item("保存选中事件组合为模板...", TEMPLATE_MENU_SAVE)
	popup.add_item("删除自定义模板...", TEMPLATE_MENU_DELETE)
	_update_event_template_menu_state()


func _on_event_template_selected(menu_id: int) -> void:
	if menu_id == TEMPLATE_MENU_SAVE:
		_open_save_event_template_dialog()
		return
	if menu_id == TEMPLATE_MENU_DELETE:
		_open_delete_event_template_dialog()
		return
	var action := template_menu_actions.get(menu_id, {}) as Dictionary
	if str(action.get("kind", "")) == "builtin":
		insert_event_template(str(action.get("name", "")))
	elif str(action.get("kind", "")) == "custom":
		var template := action.get("template", {}) as Dictionary
		_insert_template_events(str(template.get("name", "自定义模板")), template.get("events", []) as Array)


func _open_save_event_template_dialog() -> void:
	if selected_event_index < 0:
		return
	%TemplateNameEdit.text = ""
	%SaveEventTemplateDialog.popup_centered()
	%TemplateNameEdit.grab_focus()


func _confirm_save_event_template() -> void:
	var events := _current_events()
	var indices := _validated_contiguous_selection()
	if indices.is_empty():
		_set_status("请选择一组连续事件后再保存模板。", true)
		return
	var selected_events: Array[Dictionary] = []
	for event_index in indices:
		selected_events.append((events[event_index] as Dictionary).duplicate(true))
	var result := EventTemplateService.save_events(%TemplateNameEdit.text, selected_events, template_library_path)
	if not result.get("ok", false):
		_set_status(str(result.get("error", "保存自定义模板失败。")), true)
		return
	_refresh_event_template_menu()
	_set_status("已保存项目自定义模板“%s”。" % %TemplateNameEdit.text.strip_edges(), false)


func _open_delete_event_template_dialog() -> void:
	%DeleteTemplateSelect.clear()
	for template in custom_event_templates:
		%DeleteTemplateSelect.add_item(str(template.get("name", "未命名模板")))
		%DeleteTemplateSelect.set_item_metadata(%DeleteTemplateSelect.item_count - 1, str(template.get("id", "")))
	if %DeleteTemplateSelect.item_count > 0:
		%DeleteEventTemplateDialog.popup_centered()


func _confirm_delete_event_template() -> void:
	if %DeleteTemplateSelect.item_count == 0:
		return
	var template_name: String = %DeleteTemplateSelect.get_item_text(%DeleteTemplateSelect.selected)
	var template_id := str(%DeleteTemplateSelect.get_item_metadata(%DeleteTemplateSelect.selected))
	var result := EventTemplateService.delete_template(template_id, template_library_path)
	if not result.get("ok", false):
		_set_status(str(result.get("error", "删除自定义模板失败。")), true)
		return
	_refresh_event_template_menu()
	_set_status("已删除项目自定义模板“%s”。" % template_name, false)


func _shortcut_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	if _text_control_has_focus():
		return
	var handled := false
	if key_event.ctrl_pressed:
		match key_event.keycode:
			KEY_C:
				handled = copy_selected_event()
			KEY_V:
				handled = paste_event()
			KEY_D:
				handled = duplicate_selected_event()
			KEY_Z:
				if key_event.shift_pressed:
					handled = redo()
				else:
					handled = undo()
			KEY_Y:
				handled = redo()
	if handled:
		get_viewport().set_input_as_handled()


func _text_control_has_focus() -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return focus_owner is LineEdit or focus_owner is TextEdit


func has_unsaved_changes() -> bool:
	return dirty or %MobileChatCatalogWindow.has_unsaved_changes() or %FixedVoiceCallCatalogWindow.has_unsaved_changes()


func save_all_content() -> void:
	if dirty:
		save_current_story()
	if %MobileChatCatalogWindow.has_unsaved_changes():
		%MobileChatCatalogWindow.save_current_chat()
	if %FixedVoiceCallCatalogWindow.has_unsaved_changes():
		%FixedVoiceCallCatalogWindow.save_current_calls()


func save_current_story() -> void:
	if current_path.is_empty() or current_data.is_empty():
		return
	var result := JsonService.save_dictionary(current_path, current_data)
	if result.get("ok", false):
		saved_data = current_data.duplicate(true)
		dirty = false
		_update_title()
		_set_status("已保存 %s" % current_path, false)
	else:
		_set_status(str(result.get("error", "保存失败。")), true)


func _refresh_stories() -> void:
	_populate_story_tree(search_edit.text)
	_set_status("已扫描主线、地图世界、手机消息和固定来电。", false)


func _open_create_content_dialog() -> void:
	%CreateContentId.clear()
	%CreateContentName.clear()
	%CreateContentCharacter.clear()
	%CreateContentError.text = ""
	%CreateContentType.select(0)
	_update_create_content_form()
	%CreateContentDialog.popup_centered()
	%CreateContentId.grab_focus.call_deferred()


func _update_create_content_form(_index: int = 0) -> void:
	var kind := str(%CreateContentType.get_selected_metadata())
	var needs_character := kind in ["mobile_chat", "fixed_call"]
	$CreateContentDialog/Form/CharacterLabel.visible = needs_character
	%CreateContentCharacter.visible = needs_character
	$CreateContentDialog/Form/NameLabel.visible = kind in ["main_story", "map_story"]
	%CreateContentName.visible = kind in ["main_story", "map_story"]
	var content_id: String = %CreateContentId.text.strip_edges()
	var paths := ContentCreationService.DEFAULT_ROOTS
	%CreateContentPath.text = "保存位置：共享固定来电数组" if kind == "fixed_call" else "保存位置：%s" % str(paths.get(kind, "")).path_join((content_id if not content_id.is_empty() else "<内容 ID>") + ".json")
	var valid: bool = not content_id.is_empty() and (not needs_character or not %CreateContentCharacter.text.strip_edges().is_empty())
	%CreateContentDialog.get_ok_button().disabled = not valid


func _confirm_create_content() -> void:
	var kind := str(%CreateContentType.get_selected_metadata())
	var result := ContentCreationService.create(kind, %CreateContentId.text, {"name": %CreateContentName.text.strip_edges(), "character_id": %CreateContentCharacter.text.strip_edges()})
	if not result.get("ok", false):
		%CreateContentError.text = str(result.get("error", "创建失败。"))
		%CreateContentDialog.popup_centered()
		return
	search_edit.clear()
	_populate_story_tree()
	_open_created_content(result.get("target", {}) as Dictionary)
	_set_status("已创建并打开：%s" % %CreateContentId.text.strip_edges(), false)


func _open_created_content(target: Dictionary) -> void:
	match str(target.get("kind", "")):
		"story":
			_show_workspace("story")
			load_story(str(target.get("path", "")))
		"mobile_chat":
			var chats := MobileChatScanner.scan()
			for chat_index in chats.size():
				if str(chats[chat_index].id) == str(target.get("id", "")):
					_show_workspace("mobile_chat")
					%MobileChatCatalogWindow.refresh_catalog()
					%MobileChatCatalogWindow.call_deferred("select_chat", chat_index)
					return
		"fixed_call":
			var calls := FixedCallScanner.scan()
			for call_index in calls.size():
				if str(calls[call_index].id) == str(target.get("id", "")):
					_show_workspace("fixed_call")
					%FixedVoiceCallCatalogWindow.refresh_catalog()
					%FixedVoiceCallCatalogWindow.call_deferred("select_call", call_index)
					return


func _populate_story_tree(filter_text: String = "") -> void:
	story_tree.clear()
	var root := story_tree.create_item()
	var category_items := {
		"main": _create_library_category(root, "主线剧情"),
		"events": _create_library_category(root, "地图世界"),
		"mobile_chat": _create_library_category(root, "手机消息"),
		"fixed_call": _create_library_category(root, "固定来电")
	}
	var normalized_filter := filter_text.strip_edges().to_lower()
	var visible_count := 0
	for story in StoryScanner.scan():
		var searchable := (str(story.name) + " " + str(story.path)).to_lower()
		if not normalized_filter.is_empty() and not searchable.contains(normalized_filter):
			continue
		var category := str(story.category)
		var item := story_tree.create_item(category_items[category])
		item.set_text(0, str(story.name))
		item.set_tooltip_text(0, str(story.path))
		item.set_metadata(0, {"kind": "story", "path": story.path})
		visible_count += 1
	var chats := MobileChatScanner.scan()
	for chat_index in chats.size():
		var chat := chats[chat_index]
		var searchable := (str(chat.id) + " " + str(chat.character_id) + " " + str(chat.path)).to_lower()
		if not normalized_filter.is_empty() and not searchable.contains(normalized_filter):
			continue
		var item := story_tree.create_item(category_items.mobile_chat)
		item.set_text(0, str(chat.id))
		item.set_tooltip_text(0, "%s · %d 条消息" % [str(chat.character_id), int(chat.message_count)])
		item.set_metadata(0, {"kind": "mobile_chat", "index": chat_index})
		visible_count += 1
	var calls := FixedCallScanner.scan()
	for call_index in calls.size():
		var call := calls[call_index]
		var searchable := (str(call.id) + " " + str(call.character_id)).to_lower()
		if not normalized_filter.is_empty() and not searchable.contains(normalized_filter):
			continue
		var item := story_tree.create_item(category_items.fixed_call)
		item.set_text(0, str(call.id))
		item.set_tooltip_text(0, "%s · %d 行台词" % [str(call.character_id), int(call.line_count)])
		item.set_metadata(0, {"kind": "fixed_call", "index": call_index})
		visible_count += 1
	%LibrarySummary.text = "显示 %d 项固定内容" % visible_count


func _create_library_category(root: TreeItem, label: String) -> TreeItem:
	var item := story_tree.create_item(root)
	item.set_text(0, label)
	item.set_selectable(0, false)
	return item


func _on_story_selected() -> void:
	var item := story_tree.get_selected()
	if item == null:
		return
	var target: Variant = item.get_metadata(0)
	if not target is Dictionary:
		return
	match str(target.get("kind", "")):
		"story":
			_show_workspace("story")
			load_story(str(target.get("path", "")))
		"mobile_chat":
			_show_workspace("mobile_chat")
			%MobileChatCatalogWindow.refresh_catalog()
			%MobileChatCatalogWindow.call_deferred("select_chat", int(target.get("index", 0)))
		"fixed_call":
			_show_workspace("fixed_call")
			%FixedVoiceCallCatalogWindow.refresh_catalog()
			%FixedVoiceCallCatalogWindow.call_deferred("select_call", int(target.get("index", 0)))


func _setup_embedded_fixed_content() -> void:
	_embed_editor(%MobileChatCatalogWindow, %MobileChatEmbed)
	_embed_editor(%FixedVoiceCallCatalogWindow, %FixedCallEmbed)
	%MobileChatCatalogWindow.set_embedded_mode(true)
	%FixedVoiceCallCatalogWindow.set_embedded_mode(true)
	_show_workspace("story")


func _embed_editor(editor: Control, container: Control) -> void:
	editor.reparent(container)
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	editor.show()


func _show_workspace(kind: String) -> void:
	active_workspace = kind
	%WorkspaceSplit.visible = kind == "story"
	%MobileChatEmbed.visible = kind == "mobile_chat"
	%FixedCallEmbed.visible = kind == "fixed_call"
	%DocumentState.text = {"story": "剧情节点", "mobile_chat": "手机消息", "fixed_call": "固定来电"}.get(kind, "工作区")
	if kind != "story":
		document_title.text = "手机消息编辑器" if kind == "mobile_chat" else "固定来电编辑器"
		document_path.text = MobileChatScanner.CHAT_ROOT if kind == "mobile_chat" else FixedCallScanner.CALL_PATH
		%DocumentState.modulate = Color("#9eb2bd")


func _setup_toolbar_menus() -> void:
	var story_popup: PopupMenu = %StoryToolsMenu.get_popup()
	_add_menu_items(story_popup, [[TOOL_VALIDATE, "校验当前剧情"], [TOOL_SIMULATE, "分支模拟"], [TOOL_NODE_TEMPLATES, "节点模板库"], [TOOL_COVERAGE_REPORT, "覆盖率报告"]])
	story_popup.id_pressed.connect(_on_toolbar_menu_selected)
	var content_popup: PopupMenu = %ContentToolsMenu.get_popup()
	_add_menu_items(content_popup, [[CONTENT_AI_WORKBENCH, "AI 约会"], [CONTENT_CONCERN_AI, "AI 心事"], [CONTENT_MOBILE_AI, "手机 AI"], [CONTENT_REFERENCES, "剧情引用"], [CONTENT_GUIDE_FLOW, "Guide Flow"], [CONTENT_SCHEDULE, "入口调度"]])
	content_popup.id_pressed.connect(_on_toolbar_menu_selected)
	var system_popup: PopupMenu = %SystemToolsMenu.get_popup()
	_add_menu_items(system_popup, [[SYSTEM_SCHEMA_MIGRATION, "Schema 迁移"], [SYSTEM_RUNTIME_DEBUG, "运行时监视"]])
	system_popup.id_pressed.connect(_on_toolbar_menu_selected)


func _add_menu_items(popup: PopupMenu, definitions: Array) -> void:
	popup.clear()
	for definition in definitions:
		popup.add_item(str(definition[1]), int(definition[0]))


func _on_toolbar_menu_selected(id: int) -> void:
	match id:
		TOOL_VALIDATE: _refresh_diagnostics()
		TOOL_SIMULATE: _open_branch_simulation()
		TOOL_NODE_TEMPLATES: _open_node_template_library()
		TOOL_COVERAGE_REPORT: %StoryCoverageReportWindow.open_report()
		CONTENT_MOBILE_CHAT:
			_show_workspace("mobile_chat")
			%MobileChatCatalogWindow.refresh_catalog()
		CONTENT_FIXED_CALL:
			_show_workspace("fixed_call")
			%FixedVoiceCallCatalogWindow.refresh_catalog()
		CONTENT_AI_WORKBENCH: %DateAIWorkbench.open_workbench()
		CONTENT_CONCERN_AI: %ConcernAIWorkbench.open_workbench()
		CONTENT_MOBILE_AI: %MobileAIWorkbench.open_workbench()
		CONTENT_REFERENCES: %StoryReferenceCatalogWindow.open_catalog()
		CONTENT_GUIDE_FLOW: %GuideFlowEditorWindow.open_editor()
		CONTENT_SCHEDULE: %StoryScheduleEntryEditorWindow.open_editor()
		SYSTEM_SCHEMA_MIGRATION: %StorySchemaMigrationWindow.open_editor()
		SYSTEM_RUNTIME_DEBUG: %StoryRuntimeDebugWindow.open_monitor()


func load_story(path: String) -> void:
	if dirty and path != current_path:
		_set_status("当前剧情有未保存修改，请先保存后再切换。", true)
		return
	var result := JsonService.load_dictionary(path)
	if not result.get("ok", false):
		_set_status(str(result.get("error", "读取失败。")), true)
		return
	current_path = path
	current_data = result.data
	saved_data = current_data.duplicate(true)
	undo_stack.clear()
	redo_stack.clear()
	dirty = false
	event_search_edit.clear()
	_clear_event_search()
	_clear_selection()
	_populate_chapters()
	_update_title()
	_refresh_diagnostics()
	_set_status("已加载 %s" % path.get_file(), false)


func navigate_to_story_event(path: String, chapter_id: String, event_index: int) -> bool:
	if path != current_path:
		if dirty:
			_set_status("当前剧情有未保存修改，无法跳转到报告位置。", true)
			return false
		load_story(path)
	if current_path != path:
		return false
	_select_chapter_by_id(chapter_id)
	if current_chapter != chapter_id:
		return false
	_select_event(chapter_id, event_index)
	focus_selected_event()
	return selected_event_index == event_index


func _populate_chapters() -> void:
	chapter_select.clear()
	var chapters := current_data.get("chapters", {}) as Dictionary
	var chapter_ids := chapters.keys()
	chapter_ids.sort()
	for chapter_id_value in chapter_ids:
		chapter_select.add_item(str(chapter_id_value))
	event_inspector.set_chapter_ids(chapter_ids)
	if chapter_select.item_count == 0:
		_clear_graph()
		return
	var start_index := 0
	for index in chapter_select.item_count:
		if chapter_select.get_item_text(index) == "start":
			start_index = index
			break
	chapter_select.select(start_index)
	_show_chapter(chapter_select.get_item_text(start_index))


func _on_chapter_selected(index: int) -> void:
	_show_chapter(chapter_select.get_item_text(index))


func _refresh_event_search(query: String) -> void:
	event_search_results.clear()
	event_search_result_index = -1
	var normalized_query := query.strip_edges().to_lower()
	if normalized_query.is_empty() or current_data.is_empty():
		_update_event_search_controls()
		return
	var chapters := current_data.get("chapters", {}) as Dictionary
	var chapter_ids := chapters.keys()
	chapter_ids.sort()
	for chapter_id_value in chapter_ids:
		var chapter_id := str(chapter_id_value)
		var chapter := chapters.get(chapter_id, {}) as Dictionary
		var events := chapter.get("events", []) as Array
		for event_index in events.size():
			var event_value: Variant = events[event_index]
			if not event_value is Dictionary:
				continue
			var event := event_value as Dictionary
			var event_type := str(event.get("type", "unknown"))
			var searchable := [chapter_id, str(event_index + 1), "#%d" % (event_index + 1), event_type, str(EVENT_TYPE_LABELS.get(event_type, event_type))]
			_append_searchable_values(event, searchable)
			if _searchable_values_match(searchable, normalized_query):
				event_search_results.append({"chapter_id": chapter_id, "event_index": event_index})
	_update_event_search_controls()


func _append_searchable_values(value: Variant, output: Array) -> void:
	if value is Dictionary:
		for child_value in (value as Dictionary).values():
			_append_searchable_values(child_value, output)
	elif value is Array:
		for child_value in value as Array:
			_append_searchable_values(child_value, output)
	elif value is String or value is int or value is float or value is bool:
		output.append(str(value))


func _searchable_values_match(values: Array, query: String) -> bool:
	for value in values:
		if str(value).to_lower().contains(query):
			return true
	return false


func _on_event_search_submitted(_query: String) -> void:
	navigate_event_search(1)


func navigate_event_search(direction: int) -> bool:
	if event_search_results.is_empty():
		return false
	event_search_result_index = posmod(event_search_result_index + direction, event_search_results.size())
	var result := event_search_results[event_search_result_index]
	_navigate_to_event(str(result.chapter_id), int(result.event_index), true)
	_update_event_search_controls()
	return true


func _navigate_to_event(chapter_id: String, event_index: int, focus_event: bool = false) -> void:
	if chapter_id != current_chapter:
		_select_chapter_by_id(chapter_id)
	_select_event(chapter_id, event_index)
	if focus_event:
		focus_selected_event()


func _clear_event_search() -> void:
	event_search_results.clear()
	event_search_result_index = -1
	_update_event_search_controls()


func _update_event_search_controls() -> void:
	var has_results := not event_search_results.is_empty()
	previous_event_match_button.disabled = not has_results
	next_event_match_button.disabled = not has_results
	if event_search_edit.text.strip_edges().is_empty():
		event_search_status.text = "输入关键词"
	elif not has_results:
		event_search_status.text = "无匹配事件"
	elif event_search_result_index < 0:
		event_search_status.text = "共 %d 条" % event_search_results.size()
	else:
		event_search_status.text = "%d / %d" % [event_search_result_index + 1, event_search_results.size()]


func _show_chapter(chapter_id: String) -> void:
	current_chapter = chapter_id
	_clear_selection()
	_clear_graph()
	var events := _current_events()
	var previous_node: GraphNode
	for event_index in events.size():
		var event_value: Variant = events[event_index]
		if not event_value is Dictionary:
			continue
		var event_node := EventNodeScene.instantiate()
		graph_edit.add_child(event_node)
		event_node.setup(chapter_id, event_index, event_value)
		event_node.event_activated.connect(_select_event)
		if previous_node != null:
			graph_edit.connect_node(previous_node.name, 0, event_node.name, 0, true)
		previous_node = event_node
	_add_chapter_entries(events)
	_connect_branch_edges(events)
	_filter_chapter_entries(chapter_entry_filter.text)
	graph_edit.scroll_offset = Vector2.ZERO
	_update_workspace_context()


func _add_chapter_entries(events: Array) -> void:
	var chapter_ids := (current_data.get("chapters", {}) as Dictionary).keys()
	chapter_ids.sort()
	chapter_ids.append("end")
	var columns := maxi(1, mini(4, events.size()))
	var base_y := 120.0 + ceilf(float(maxi(events.size(), 1)) / float(columns)) * 190.0
	for index in chapter_ids.size():
		var chapter_id := str(chapter_ids[index])
		var entry_node: GraphNode = ChapterEntryNodeScene.instantiate()
		graph_edit.add_child(entry_node)
		entry_node.setup(chapter_id, Vector2(80.0 + (index % 4) * 230.0, base_y + floori(index / 4.0) * 130.0))
		entry_node.chapter_activated.connect(_navigate_to_chapter)


func _connect_branch_edges(events: Array) -> void:
	for event_index in events.size():
		var event_value: Variant = events[event_index]
		if not event_value is Dictionary:
			continue
		var event := event_value as Dictionary
		var source_name: String = "event_%s_%d" % [current_chapter.validate_node_name(), event_index]
		var event_type := str(event.get("type", ""))
		if event_type == "jump":
			_connect_branch(source_name, 0, str(event.get("target_chapter", "")))
		elif event_type == "choice":
			var options := event.get("options", []) as Array
			for option_index in options.size():
				var option_value: Variant = options[option_index]
				if option_value is Dictionary:
					_connect_branch(source_name, option_index, str((option_value as Dictionary).get("target_chapter", "")))


func _connect_branch(source_name: String, source_port: int, target_chapter: String) -> void:
	if target_chapter.is_empty():
		return
	var target_name := "chapter_entry_%s" % target_chapter.validate_node_name()
	if graph_edit.has_node(NodePath(target_name)):
		graph_edit.connect_node(source_name, source_port, target_name, 0, true)


func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, _to_port: int) -> void:
	var source := graph_edit.get_node_or_null(NodePath(from_node))
	var target := graph_edit.get_node_or_null(NodePath(to_node))
	if source == null or target == null or not "event_index" in source or not "chapter_id" in target:
		return
	_set_branch_target(int(source.event_index), int(from_port), str(target.chapter_id))


func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, _to_port: int) -> void:
	if not str(to_node).begins_with("chapter_entry_"):
		return
	var source := graph_edit.get_node_or_null(NodePath(from_node))
	if source != null and "event_index" in source:
		_set_branch_target(int(source.event_index), int(from_port), "")


func _set_branch_target(event_index: int, branch_port: int, target_chapter: String) -> void:
	var events := _current_events()
	if event_index < 0 or event_index >= events.size() or not events[event_index] is Dictionary:
		return
	var event := events[event_index] as Dictionary
	var event_type := str(event.get("type", ""))
	_record_history()
	if event_type == "jump":
		event["target_chapter"] = target_chapter
	elif event_type == "choice":
		var options := event.get("options", []) as Array
		if branch_port < 0 or branch_port >= options.size() or not options[branch_port] is Dictionary:
			undo_stack.pop_back()
			_update_history_buttons()
			return
		var option := options[branch_port] as Dictionary
		if target_chapter.is_empty():
			option.erase("target_chapter")
		else:
			option["target_chapter"] = target_chapter
	else:
		undo_stack.pop_back()
		_update_history_buttons()
		return
	_refresh_dirty_state()
	_show_chapter(current_chapter)
	_select_event(current_chapter, event_index)
	_refresh_diagnostics()
	_set_status("分支连接已更新，尚未写入文件。", false)


func _navigate_to_chapter(chapter_id: String) -> void:
	if chapter_id != "end":
		_select_chapter_by_id(chapter_id)


func _filter_chapter_entries(filter_text: String) -> void:
	var normalized_filter := filter_text.strip_edges().to_lower()
	for child in graph_edit.get_children():
		if child is GraphNode and str(child.name).begins_with("chapter_entry_"):
			child.visible = normalized_filter.is_empty() or str(child.chapter_id).to_lower().contains(normalized_filter)


func focus_selected_event() -> void:
	if selected_event_index < 0:
		return
	var node_name := "event_%s_%d" % [current_chapter.validate_node_name(), selected_event_index]
	var event_node := graph_edit.get_node_or_null(NodePath(node_name)) as GraphNode
	if event_node == null:
		return
	var viewport_center := graph_edit.size * 0.5 / graph_edit.zoom
	graph_edit.scroll_offset = event_node.position_offset + event_node.size * 0.5 - viewport_center


func _clear_graph() -> void:
	graph_edit.clear_connections()
	for child in graph_edit.get_children():
		if child is GraphNode:
			graph_edit.remove_child(child)
			child.queue_free()


func _on_graph_node_selected(node: Node) -> void:
	if syncing_graph_selection or not node.has_method("refresh"):
		return
	_refresh_graph_selection(int(node.event_index))


func _on_graph_node_deselected(node: Node) -> void:
	if syncing_graph_selection or not node.has_method("refresh"):
		return
	_refresh_graph_selection(-1)


func _refresh_graph_selection(preferred_index: int) -> void:
	selected_event_indices.clear()
	for child in graph_edit.get_children():
		if child is GraphNode and child.has_method("refresh") and child.selected:
			selected_event_indices.append(int(child.event_index))
	selected_event_indices.sort()
	if selected_event_indices.is_empty():
		_clear_selection()
		return
	var primary_index := preferred_index if selected_event_indices.has(preferred_index) else selected_event_indices[0]
	_load_primary_event(primary_index)


func _load_primary_event(event_index: int) -> void:
	var events := _current_events()
	if event_index < 0 or event_index >= events.size() or not events[event_index] is Dictionary:
		return
	selected_event_index = event_index
	var event := events[event_index] as Dictionary
	var event_type := str(event.get("type", "unknown"))
	var selection_label := "%d 个事件 · 主选 #%d" % [selected_event_indices.size(), event_index + 1] if selected_event_indices.size() > 1 else "事件 #%d" % (event_index + 1)
	inspector_title.text = "%s · %s" % [selection_label, str(EVENT_TYPE_LABELS.get(event_type, event_type))]
	event_inspector.load_event(event)
	_update_event_buttons()
	_update_workspace_context()


func _select_event(chapter_id: String, event_index: int) -> void:
	if chapter_id != current_chapter:
		return
	var events := _current_events()
	if event_index < 0 or event_index >= events.size() or not events[event_index] is Dictionary:
		return
	selected_event_indices.assign([event_index])
	_sync_graph_selection(event_index)
	_load_primary_event(event_index)


func _apply_event_data(event_data: Dictionary) -> void:
	if selected_event_index < 0:
		return
	var events := _current_events()
	_record_history()
	var updated_event := event_data.duplicate(true)
	var previous_event := events[selected_event_index] as Dictionary
	if previous_event.has("_editor_position"):
		updated_event["_editor_position"] = (previous_event.get("_editor_position", {}) as Dictionary).duplicate(true)
	events[selected_event_index] = updated_event
	_refresh_dirty_state()
	var node_name := "event_%s_%d" % [current_chapter.validate_node_name(), selected_event_index]
	var event_node := graph_edit.get_node_or_null(node_name)
	if event_node != null:
		event_node.refresh(events[selected_event_index])
	_select_event(current_chapter, selected_event_index)
	_refresh_event_search(event_search_edit.text)
	_refresh_diagnostics()
	_set_status("事件修改已应用，尚未写入文件。", false)


func _on_graph_move_started() -> void:
	_record_history()


func _on_graph_move_finished() -> void:
	if not _commit_graph_positions():
		if not undo_stack.is_empty():
			undo_stack.pop_back()
		_update_history_buttons()
		return
	_refresh_dirty_state()
	_set_status("节点布局已更新，保存剧情后会持久化。", false)


func _commit_graph_positions() -> bool:
	var events := _current_events()
	var changed := false
	for child in graph_edit.get_children():
		if not child is GraphNode or not child.has_method("refresh"):
			continue
		var event_index := int(child.event_index)
		if event_index < 0 or event_index >= events.size() or not events[event_index] is Dictionary:
			continue
		var event := events[event_index] as Dictionary
		var position_data := {"x": child.position_offset.x, "y": child.position_offset.y}
		if event.get("_editor_position", {}) != position_data:
			event["_editor_position"] = position_data
			changed = true
	return changed


func add_event() -> void:
	if current_data.is_empty() or current_chapter.is_empty():
		_set_status("请先打开一个剧情章节。", true)
		return
	var event_type := str(event_type_select.get_item_metadata(event_type_select.selected))
	var new_event := (EVENT_DEFAULTS.get(event_type, {"type": event_type}) as Dictionary).duplicate(true)
	var events := _current_events()
	var insert_index := events.size() if selected_event_index < 0 else selected_event_index + 1
	_record_history()
	events.insert(insert_index, new_event)
	_commit_structure_change(insert_index, "已新增 %s 事件。" % event_type)


func insert_event_template(template_name: String) -> bool:
	if current_data.is_empty() or current_chapter.is_empty() or not EVENT_TEMPLATES.has(template_name):
		return false
	return _insert_template_events(template_name, EVENT_TEMPLATES[template_name] as Array)


func _insert_template_events(template_name: String, template_events: Array) -> bool:
	if current_data.is_empty() or current_chapter.is_empty():
		return false
	if template_events.is_empty():
		return false
	var events := _current_events()
	var insert_index := events.size() if selected_event_index < 0 else selected_event_index + 1
	_record_history()
	for template_event_index in template_events.size():
		var template_event := template_events[template_event_index] as Dictionary
		events.insert(insert_index + template_event_index, template_event.duplicate(true))
	_commit_structure_change(insert_index, "已插入“%s”组合模板，共 %d 个事件。" % [template_name, template_events.size()])
	return true


func _open_node_template_library() -> void:
	%StoryNodeTemplateLibraryWindow.open_library(current_data, template_library_path)


func _instantiate_node_template(template: Dictionary, parameters: Dictionary) -> bool:
	if current_data.is_empty() or current_chapter.is_empty():
		_set_status("请先打开一个剧情章节。", true)
		return false
	var result := NodeTemplateInstantiator.instantiate_template(template, parameters, current_data)
	if not result.get("ok", false):
		_set_status("节点模板实例化失败。", true)
		return false
	var events := _current_events()
	var insert_index := events.size() if selected_event_index < 0 else selected_event_index + 1
	_record_history()
	for event_offset in (result.get("events", []) as Array).size():
		events.insert(insert_index + event_offset, (result.events as Array)[event_offset])
	var chapters := current_data.get("chapters", {}) as Dictionary
	for chapter_id in (result.get("chapters", {}) as Dictionary):
		chapters[chapter_id] = (result.chapters as Dictionary)[chapter_id]
	_populate_chapters()
	_select_chapter_by_id(current_chapter)
	_commit_structure_change(insert_index, "已实例化节点模板“%s”。" % str(template.get("name", "未命名")))
	_refresh_event_template_menu()
	return true


func copy_selected_event() -> bool:
	var events := _current_events()
	var indices := _validated_contiguous_selection()
	if indices.is_empty():
		return false
	copied_events.clear()
	for event_index in indices:
		copied_events.append((events[event_index] as Dictionary).duplicate(true))
	copied_event = copied_events[0].duplicate(true)
	_update_event_buttons()
	_set_status("已复制 %d 个连续事件，可粘贴到任意章节。" % copied_events.size(), false)
	return true


func paste_event() -> bool:
	if current_data.is_empty() or current_chapter.is_empty() or copied_events.is_empty():
		return false
	var events := _current_events()
	var indices := _validated_contiguous_selection()
	var insert_index: int = events.size() if indices.is_empty() else int(indices.back()) + 1
	_record_history()
	for copied_index in copied_events.size():
		events.insert(insert_index + copied_index, copied_events[copied_index].duplicate(true))
	_commit_structure_change(insert_index, "已粘贴 %d 个事件。" % copied_events.size())
	return true


func duplicate_selected_event() -> bool:
	var events := _current_events()
	var indices := _validated_contiguous_selection()
	if indices.is_empty():
		return false
	var insert_index: int = int(indices.back()) + 1
	_record_history()
	for selection_offset in indices.size():
		events.insert(insert_index + selection_offset, (events[indices[selection_offset]] as Dictionary).duplicate(true))
	_commit_structure_change(insert_index, "已创建 %d 个事件副本。" % indices.size())
	return true


func delete_selected_event() -> void:
	var events := _current_events()
	var indices := _validated_contiguous_selection()
	if indices.is_empty():
		return
	var removed_index: int = indices[0]
	_record_history()
	for index in range(indices.size() - 1, -1, -1):
		events.remove_at(indices[index])
	var next_index := mini(removed_index, events.size() - 1)
	_commit_structure_change(next_index, "已删除 %d 个事件。" % indices.size())


func _validated_contiguous_selection() -> Array[int]:
	var events := _current_events()
	var indices := selected_event_indices.duplicate()
	if indices.is_empty() and selected_event_index >= 0:
		indices.append(selected_event_index)
	indices.sort()
	for position in indices.size():
		var event_index: int = indices[position]
		if event_index < 0 or event_index >= events.size() or not events[event_index] is Dictionary:
			return []
		if position > 0 and event_index != indices[position - 1] + 1:
			_set_status("组合操作仅支持连续事件，请重新框选。", true)
			return []
	return indices


func move_selected_event(direction: int) -> void:
	var events := _current_events()
	if selected_event_index < 0 or selected_event_index >= events.size():
		return
	var target_index := selected_event_index + direction
	if target_index < 0 or target_index >= events.size():
		return
	_record_history()
	var selected_event: Variant = events[selected_event_index]
	events[selected_event_index] = events[target_index]
	events[target_index] = selected_event
	_commit_structure_change(target_index, "已调整事件顺序。")


func _commit_structure_change(next_selection: int, message: String) -> void:
	_refresh_dirty_state()
	_show_chapter(current_chapter)
	var events := _current_events()
	if next_selection >= 0 and next_selection < events.size():
		_select_event(current_chapter, next_selection)
	_refresh_event_search(event_search_edit.text)
	_refresh_diagnostics()
	_set_status(message + " 尚未写入文件。", false)


func create_chapter(chapter_id: String) -> bool:
	var normalized_id := chapter_id.strip_edges()
	var chapters := current_data.get("chapters", {}) as Dictionary
	if normalized_id.is_empty() or chapters.has(normalized_id):
		_set_status("章节 ID 不能为空且不能重复。", true)
		return false
	_record_history()
	chapters[normalized_id] = {"events": []}
	_refresh_dirty_state()
	_populate_chapters()
	_select_chapter_by_id(normalized_id)
	_refresh_event_search(event_search_edit.text)
	_set_status("已新增章节 %s，尚未写入文件。" % normalized_id, false)
	return true


func rename_current_chapter(new_id: String) -> bool:
	var normalized_id := new_id.strip_edges()
	var chapters := current_data.get("chapters", {}) as Dictionary
	if current_chapter.is_empty() or normalized_id.is_empty() or (normalized_id != current_chapter and chapters.has(normalized_id)):
		_set_status("新章节 ID 不能为空且不能与现有章节重复。", true)
		return false
	if normalized_id == current_chapter:
		return true
	_record_history()
	var old_id := current_chapter
	chapters[normalized_id] = chapters[old_id]
	chapters.erase(old_id)
	_refresh_dirty_state()
	_populate_chapters()
	_select_chapter_by_id(normalized_id)
	_refresh_event_search(event_search_edit.text)
	_set_status("已将章节 %s 重命名为 %s。" % [old_id, normalized_id], false)
	return true


func delete_current_chapter() -> bool:
	var chapters := current_data.get("chapters", {}) as Dictionary
	if current_chapter.is_empty() or not chapters.has(current_chapter):
		return false
	if chapters.size() <= 1:
		_set_status("剧情至少需要保留一个章节。", true)
		return false
	_record_history()
	var removed_id := current_chapter
	chapters.erase(removed_id)
	_refresh_dirty_state()
	_populate_chapters()
	_refresh_event_search(event_search_edit.text)
	_set_status("已删除章节 %s，尚未写入文件。" % removed_id, false)
	return true


func undo() -> bool:
	if undo_stack.is_empty():
		return false
	redo_stack.append(_make_snapshot())
	_restore_snapshot(undo_stack.pop_back())
	_set_status("已撤销最近一次编辑。", false)
	return true


func redo() -> bool:
	if redo_stack.is_empty():
		return false
	undo_stack.append(_make_snapshot())
	_restore_snapshot(redo_stack.pop_back())
	_set_status("已重做最近一次编辑。", false)
	return true


func _record_history() -> void:
	undo_stack.append(_make_snapshot())
	redo_stack.clear()
	_update_history_buttons()


func _make_snapshot() -> Dictionary:
	return {"data": current_data.duplicate(true), "chapter": current_chapter, "event_index": selected_event_index, "event_indices": selected_event_indices.duplicate()}


func _restore_snapshot(snapshot: Dictionary) -> void:
	current_data = (snapshot.get("data", {}) as Dictionary).duplicate(true)
	var chapter_id := str(snapshot.get("chapter", ""))
	var event_index := int(snapshot.get("event_index", -1))
	var event_indices: Array[int] = []
	event_indices.assign(snapshot.get("event_indices", []))
	_populate_chapters()
	_select_chapter_by_id(chapter_id)
	var events := _current_events()
	if not event_indices.is_empty():
		_set_graph_selection(event_indices, event_index)
	elif event_index >= 0 and event_index < events.size():
		_select_event(current_chapter, event_index)
	_refresh_dirty_state()
	_refresh_event_search(event_search_edit.text)
	_refresh_diagnostics()
	_update_history_buttons()


func _refresh_dirty_state() -> void:
	dirty = current_data != saved_data
	_update_title()
	_update_history_buttons()


func _update_history_buttons() -> void:
	undo_button.disabled = undo_stack.is_empty()
	redo_button.disabled = redo_stack.is_empty()


func _select_chapter_by_id(chapter_id: String) -> void:
	for index in chapter_select.item_count:
		if chapter_select.get_item_text(index) == chapter_id:
			chapter_select.select(index)
			_show_chapter(chapter_id)
			return


func _open_add_chapter_dialog() -> void:
	chapter_dialog_mode = "add"
	%ChapterNameDialog.title = "新增章节"
	%ChapterNameEdit.text = ""
	%ChapterNameDialog.popup_centered()
	%ChapterNameEdit.grab_focus()


func _open_rename_chapter_dialog() -> void:
	if current_chapter.is_empty():
		return
	chapter_dialog_mode = "rename"
	%ChapterNameDialog.title = "重命名章节"
	%ChapterNameEdit.text = current_chapter
	%ChapterNameDialog.popup_centered()
	%ChapterNameEdit.grab_focus()
	%ChapterNameEdit.select_all()


func _confirm_chapter_name() -> void:
	if chapter_dialog_mode == "add":
		create_chapter(%ChapterNameEdit.text)
	elif chapter_dialog_mode == "rename":
		rename_current_chapter(%ChapterNameEdit.text)


func _setup_simulation_tree() -> void:
	for column in 6:
		simulation_results.set_column_expand(column, column in [2, 3, 4])
	simulation_results.set_column_title(0, "路径")
	simulation_results.set_column_title(1, "状态")
	simulation_results.set_column_title(2, "选择链")
	simulation_results.set_column_title(3, "累计效果")
	simulation_results.set_column_title(4, "最终变量")
	simulation_results.set_column_title(5, "步数")


func _open_branch_simulation() -> void:
	if current_data.is_empty():
		_set_status("请先打开一个剧情。", true)
		return
	(load(WINDOW_LAYOUT_PATH) as GDScript).new().open_window(simulation_window, Vector2i(900, 620), Vector2i(620, 440))
	run_branch_simulation()


func run_branch_simulation() -> Array[Dictionary]:
	simulation_results.clear()
	var root := simulation_results.create_item()
	var parser := JSON.new()
	var parse_error := parser.parse(%InitialVariablesEdit.text)
	if parse_error != OK or not parser.data is Dictionary:
		simulation_summary.text = "初始变量必须是 JSON 对象。"
		simulation_summary.modulate = Color("#ff7f78")
		return []
	var results := StoryBranchSimulator.simulate(current_data, parser.data)
	var ended_count := 0
	var problem_count := 0
	for result_index in results.size():
		var result := results[result_index]
		var status := str(result.get("status", "error"))
		if status == "ended":
			ended_count += 1
		else:
			problem_count += 1
		var item := simulation_results.create_item(root)
		item.set_text(0, "#%d" % (result_index + 1))
		item.set_text(1, status.to_upper())
		item.set_text(2, _format_simulation_choices(result.get("choices", []) as Array))
		item.set_text(3, JSON.stringify(result.get("effects", {})))
		item.set_text(4, JSON.stringify(result.get("variables", {})))
		item.set_text(5, str((result.get("trace", []) as Array).size()))
		item.set_tooltip_text(1, str(result.get("message", "")))
		item.set_metadata(0, result)
	simulation_summary.text = "共 %d 条路径：%d 条结束，%d 条循环或错误。" % [results.size(), ended_count, problem_count]
	simulation_summary.modulate = Color("#ff7f78") if problem_count > 0 else Color("#73d9b0")
	return results


func _format_simulation_choices(choices: Array) -> String:
	var labels: Array[String] = []
	for choice_value in choices:
		if choice_value is Dictionary:
			var choice := choice_value as Dictionary
			labels.append(str(choice.get("text", choice.get("id", "选项"))))
	return " → ".join(labels) if not labels.is_empty() else "线性路径"


func _navigate_to_simulation_result() -> void:
	var item := simulation_results.get_selected()
	if item == null:
		return
	var result_value: Variant = item.get_metadata(0)
	if not result_value is Dictionary:
		return
	var trace := (result_value as Dictionary).get("trace", []) as Array
	if trace.is_empty() or not trace.back() is Dictionary:
		return
	var last_step := trace.back() as Dictionary
	var chapter_id := str(last_step.get("chapter", ""))
	var event_index := int(last_step.get("event_index", -1))
	simulation_window.hide()
	_select_chapter_by_id(chapter_id)
	_select_event(chapter_id, event_index)


func _clear_selection() -> void:
	selected_event_index = -1
	selected_event_indices.clear()
	_sync_graph_selection(-1)
	inspector_title.text = "事件 Inspector"
	if is_instance_valid(event_inspector):
		event_inspector.clear_event()
	_update_event_buttons()
	_update_workspace_context()


func _sync_graph_selection(event_index: int) -> void:
	_set_graph_selection([event_index] if event_index >= 0 else [], event_index)


func _set_graph_selection(indices: Array, primary_index: int) -> void:
	if not is_instance_valid(graph_edit):
		return
	syncing_graph_selection = true
	for child in graph_edit.get_children():
		if child is GraphNode and child.has_method("set_highlighted"):
			child.set_highlighted(indices.has(int(child.event_index)))
	syncing_graph_selection = false
	selected_event_indices.clear()
	selected_event_indices.assign(indices)
	selected_event_indices.sort()
	if not selected_event_indices.is_empty():
		_load_primary_event(primary_index if selected_event_indices.has(primary_index) else selected_event_indices[0])


func _update_event_buttons() -> void:
	var event_count := _current_events().size() if not current_chapter.is_empty() else 0
	var has_selection := not selected_event_indices.is_empty() and selected_event_index >= 0 and selected_event_index < event_count
	_update_event_template_menu_state()
	copy_event_button.disabled = not has_selection
	paste_event_button.disabled = current_data.is_empty() or current_chapter.is_empty() or copied_events.is_empty()
	duplicate_event_button.disabled = not has_selection
	delete_event_button.disabled = not has_selection
	focus_selection_button.disabled = not has_selection
	var has_single_selection := selected_event_indices.size() == 1
	move_up_button.disabled = not has_selection or not has_single_selection or selected_event_index == 0
	move_down_button.disabled = not has_selection or not has_single_selection or selected_event_index >= event_count - 1


func _update_event_template_menu_state() -> void:
	if not is_instance_valid(event_template_menu):
		return
	var popup := event_template_menu.get_popup()
	var can_insert := not current_data.is_empty() and not current_chapter.is_empty()
	for menu_id in template_menu_actions:
		var item_index := popup.get_item_index(int(menu_id))
		if item_index >= 0:
			popup.set_item_disabled(item_index, not can_insert)
	var save_index := popup.get_item_index(TEMPLATE_MENU_SAVE)
	if save_index >= 0:
		popup.set_item_disabled(save_index, selected_event_index < 0)
	var delete_index := popup.get_item_index(TEMPLATE_MENU_DELETE)
	if delete_index >= 0:
		popup.set_item_disabled(delete_index, custom_event_templates.is_empty())


func _refresh_diagnostics() -> void:
	diagnostics_tree.clear()
	var root := diagnostics_tree.create_item()
	if current_data.is_empty():
		%DiagnosticsSummary.text = "打开剧情后自动校验"
		return
	var diagnostics := StoryValidator.validate(current_data)
	var error_count := 0
	var warning_count := 0
	for diagnostic in diagnostics:
		if str(diagnostic.severity).to_lower() == "error":
			error_count += 1
		elif str(diagnostic.severity).to_lower() == "warning":
			warning_count += 1
		var item := diagnostics_tree.create_item(root)
		item.set_text(0, str(diagnostic.severity).to_upper())
		item.set_text(1, str(diagnostic.location))
		item.set_text(2, str(diagnostic.message))
		item.set_metadata(0, diagnostic)
	if diagnostics.is_empty():
		var item := diagnostics_tree.create_item(root)
		item.set_text(0, "OK")
		item.set_text(2, "未发现结构错误。")
	%DiagnosticsSummary.text = "校验通过" if diagnostics.is_empty() else "错误 %d · 警告 %d" % [error_count, warning_count]
	%DiagnosticsSummary.modulate = Color("#73d9b0") if error_count == 0 else Color("#ff7f78")


func _navigate_to_selected_diagnostic() -> void:
	var item := diagnostics_tree.get_selected()
	if item == null:
		return
	var diagnostic_value: Variant = item.get_metadata(0)
	if diagnostic_value is Dictionary:
		_navigate_to_diagnostic(diagnostic_value as Dictionary)


func _navigate_to_diagnostic(diagnostic: Dictionary) -> void:
	var location := str(diagnostic.get("location", ""))
	var parts := location.split(" / ")
	if parts.is_empty():
		return
	var chapter_id := str(parts[0])
	var chapters := current_data.get("chapters", {}) as Dictionary
	if not chapters.has(chapter_id):
		_set_status("该诊断位于剧情根节点，无法定位到事件。", true)
		return
	_select_chapter_by_id(chapter_id)
	if parts.size() > 1 and str(parts[1]).begins_with("#"):
		var event_index := str(parts[1]).trim_prefix("#").to_int() - 1
		_select_event(chapter_id, event_index)
	_set_status("已定位诊断：%s" % str(diagnostic.get("message", "")), false)


func _current_events() -> Array:
	var chapters := current_data.get("chapters", {}) as Dictionary
	var chapter := chapters.get(current_chapter, {}) as Dictionary
	return chapter.get("events", []) as Array


func _update_title() -> void:
	if active_workspace != "story":
		return
	var script_id := str(current_data.get("script_id", "未打开剧情"))
	document_title.text = script_id + (" *" if dirty else "")
	document_path.text = current_path
	save_button.disabled = current_path.is_empty() or not dirty
	%DocumentState.text = "未保存" if dirty else ("已保存" if not current_path.is_empty() else "等待选择")
	%DocumentState.modulate = Color("#f0bf67") if dirty else Color("#73d9b0") if not current_path.is_empty() else Color("#9eb2bd")
	_update_workspace_context()


func _set_status(message: String, is_error: bool) -> void:
	status_label.text = message
	status_label.modulate = Color("#ff7f78") if is_error else Color("#9eb2bd")


func _update_workspace_context() -> void:
	if not is_node_ready():
		return
	var event_count := _current_events().size() if not current_chapter.is_empty() else 0
	var selection_text := "未选择事件" if selected_event_index < 0 else "事件 #%d" % (selected_event_index + 1)
	%ContextStatus.text = "%s | %s | %d 个事件 | %s" % [current_path.get_file() if not current_path.is_empty() else "未打开文件", current_chapter if not current_chapter.is_empty() else "未选择章节", event_count, selection_text]
	if current_data.is_empty():
		%GuideTitle.text = "从左侧选择剧情，开始编排事件"
	elif event_count == 0:
		%GuideTitle.text = "当前章节为空：选择事件类型后点击“新增事件”"
	elif selected_event_index < 0:
		%GuideTitle.text = "点击画布中的事件节点，在右侧编辑内容"
	else:
		%GuideTitle.text = "正在编辑 %s · 事件 #%d" % [current_chapter, selected_event_index + 1]