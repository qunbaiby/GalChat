extends HBoxContainer
class_name RelationGraphView

const MemoryAlbumManagerScript = preload("res://scripts/data/memory_album_manager.gd")
const GRAPH_PATH_TEMPLATE: String = "res://assets/data/relationships/%s_relationship_graph.json"
@onready var graph_card: PanelContainer = $GraphCard
@onready var detail_card: PanelContainer = $DetailCard
@onready var graph_header: PanelContainer = $GraphCard/VBox/HeaderPanel
@onready var graph_summary_label: Label = $GraphCard/VBox/ToolbarMargin/Toolbar/SummaryChip/SummaryLabel
@onready var graph_canvas: Control = $GraphCard/VBox/Viewport/ViewportMargin/ViewportFrame/CanvasMargin/RelationGraphCanvas
@onready var hide_locked_check: CheckButton = $GraphCard/VBox/ToolbarMargin/Toolbar/HideLockedCheck
@onready var faction_option: OptionButton = $GraphCard/VBox/ToolbarMargin/Toolbar/FactionOption
@onready var detail_header: PanelContainer = $DetailCard/VBox/HeaderPanel
@onready var detail_overview_tag: Label = $DetailCard/VBox/Margin/ContentScroll/ContentVBox/OverviewCard/OverviewMargin/OverviewVBox/OverviewTag
@onready var detail_title_label: Label = $DetailCard/VBox/Margin/ContentScroll/ContentVBox/DetailTitle
@onready var detail_body_label: RichTextLabel = $DetailCard/VBox/Margin/ContentScroll/ContentVBox/DetailBody
@onready var detail_footer_label: RichTextLabel = $DetailCard/VBox/Margin/ContentScroll/ContentVBox/DetailFooter

var graph_data: Dictionary = {}
var dynamic_state: Dictionary = {}
var current_char_id: String = ""
var memory_entries: Array = []
var custom_layouts: Dictionary = {}

var _node_cache: Dictionary = {}
var _edge_cache: Dictionary = {}

var _pending_selection_kind: String = ""
var _pending_selection_id: String = ""

func _ready() -> void:
	graph_canvas.connect("node_selected", Callable(self, "_on_graph_node_selected"))
	graph_canvas.connect("edge_selected", Callable(self, "_on_graph_edge_selected"))
	if graph_canvas.has_signal("layout_changed"):
		graph_canvas.connect("layout_changed", Callable(self, "_on_layout_changed"))
		
	hide_locked_check.toggled.connect(_on_filter_changed)
	faction_option.item_selected.connect(_on_filter_changed)

func set_archive_data(char_id: String, profile) -> void:
	current_char_id = char_id
	graph_data = _load_graph_data(char_id)
	
	custom_layouts.clear()
	_load_custom_layouts(char_id)
	
	if not custom_layouts.is_empty():
		for node in graph_data.get("nodes", []):
			if node is Dictionary:
				var node_id = str(node.get("id", ""))
				if custom_layouts.has(node_id):
					if not node.has("position") or not (node["position"] is Dictionary):
						node["position"] = {}
					node["position"]["x"] = custom_layouts[node_id].get("x", 0.0)
					node["position"]["y"] = custom_layouts[node_id].get("y", 0.0)
					
	_build_caches()
	_populate_factions()
	dynamic_state = _build_dynamic_state(profile)
	memory_entries = _build_memory_entries()
	_update_summary_text()

	graph_canvas.call("set_graph_data", graph_data, dynamic_state)

	if _find_edge("player_luna").is_empty():
		_pending_selection_kind = "node"
		_pending_selection_id = str(graph_data.get("center_node_id", "luna"))
	else:
		_pending_selection_kind = "edge"
		_pending_selection_id = "player_luna"

	call_deferred("_apply_pending_selection")

func _apply_pending_selection() -> void:
	if _pending_selection_id == "":
		return

	if _pending_selection_kind == "node":
		_show_node_detail(_pending_selection_id)
		graph_canvas.call("select_node", _pending_selection_id)
	else:
		_show_edge_detail(_pending_selection_id)
		graph_canvas.call("select_edge", _pending_selection_id)

	_pending_selection_kind = ""
	_pending_selection_id = ""

func _populate_factions() -> void:
	faction_option.clear()
	faction_option.add_item("全部阵营", 0)
	faction_option.set_item_metadata(0, "")
	
	var factions = {}
	for node in graph_data.get("nodes", []):
		if node is Dictionary:
			var f = str(node.get("faction", ""))
			if f != "" and not factions.has(f):
				factions[f] = true
	
	var id = 1
	for f in factions.keys():
		faction_option.add_item(f, id)
		faction_option.set_item_metadata(id, f)
		id += 1

func _on_filter_changed(_val = null) -> void:
	var hide_locked = hide_locked_check.button_pressed
	var faction = faction_option.get_item_metadata(faction_option.selected) if faction_option.selected >= 0 else ""
	if graph_canvas.has_method("set_filters"):
		graph_canvas.call("set_filters", hide_locked, faction)

func _load_graph_data(char_id: String) -> Dictionary:
	var path: String = GRAPH_PATH_TEMPLATE % char_id
	if not FileAccess.file_exists(path):
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var json: JSON = JSON.new()
	var error: int = json.parse(file.get_as_text())
	file.close()
	if error != OK or not (json.data is Dictionary):
		return {}

	return json.data

func _build_dynamic_state(profile) -> Dictionary:
	var state: Dictionary = {
		"player_profile": {
			"stage": int(profile.current_stage),
			"stage_title": _get_profile_stage_title(profile),
			"intimacy": float(profile.intimacy),
			"trust": float(profile.trust),
			"resonance": float(profile.intimacy + profile.trust)
		},
		"npc_states": {}
	}

	var npc_manager = GameDataManager.npc_relationship_manager
	for node in graph_data.get("nodes", []):
		if not (node is Dictionary and str(node.get("type", "")) == "npc"):
			continue

		var npc_id: String = str(node.get("id", ""))
		var stage_title: String = _get_npc_stage_title(npc_id)
		state["npc_states"][npc_id] = {
			"stage": npc_manager.get_stage(npc_id) if npc_manager else 1,
			"stage_title": stage_title,
			"intimacy": npc_manager.get_intimacy(npc_id) if npc_manager else 0.0,
			"trust": npc_manager.get_trust(npc_id) if npc_manager else 0.0,
			"resonance": (npc_manager.get_intimacy(npc_id) + npc_manager.get_trust(npc_id)) if npc_manager else 0.0
		}

	return state

func _get_profile_stage_title(profile) -> String:
	for stage in profile.stages_config:
		if not (stage is Dictionary):
			continue
		var stage_id: int = int(stage.get("stage", 1))
		if stage_id == int(profile.current_stage):
			return str(stage.get("stageTitle", "阶段%d" % stage_id))
	return "阶段%d" % int(profile.current_stage)

func _get_npc_stage_title(npc_id: String) -> String:
	var npc_rel = GameDataManager.npc_relationship_manager
	var stage_config: Dictionary = npc_rel.get_stage_config(npc_id) if npc_rel else {}
	if stage_config.is_empty():
		return "初始关系"
	return str(stage_config.get("stageTitle", "初始关系"))

func _build_memory_entries() -> Array:
	var album = MemoryAlbumManagerScript.new()
	return album.build_entries()

func _update_summary_text() -> void:
	var node_total: int = graph_data.get("nodes", []).size()
	var edge_total: int = graph_data.get("edges", []).size()
	graph_summary_label.text = "%d 节点 · %d 关系" % [node_total, edge_total]

func _on_graph_node_selected(node_id: String) -> void:
	_show_node_detail(node_id)

func _on_graph_edge_selected(edge_id: String) -> void:
	_show_edge_detail(edge_id)

func _format_section(title: String, content: String) -> String:
	return "[color=#999999][font_size=14]【%s】[/font_size][/color]\n%s" % [title, content]

func _show_node_detail(node_id: String) -> void:
	var node: Dictionary = _find_node(node_id)
	if node.is_empty():
		return

	detail_title_label.text = str(node.get("name", "未知角色"))
	detail_overview_tag.text = "角色档案"

	var body_lines: Array[String] = []
	body_lines.append(_format_section("解锁状态", "未解锁" if _is_node_locked(node) else "已解锁"))
	
	var role: String = str(node.get("role", ""))
	if role != "":
		body_lines.append(_format_section("身份", role))

	var summary: String = str(node.get("summary", ""))
	if summary != "":
		body_lines.append(_format_section("概述", summary))

	var tags: Array = node.get("tags", [])
	if tags is Array and tags.size() > 0:
		body_lines.append(_format_section("关键词", " / ".join(tags)))

	var dynamic_lines: Array[String] = _build_node_dynamic_lines(node_id)
	if dynamic_lines.size() > 0:
		body_lines.append(_format_section("当前状态", "\n".join(dynamic_lines)))

	detail_body_label.text = "\n\n".join(body_lines)
	detail_footer_label.text = _build_node_footer(node_id)

func _show_edge_detail(edge_id: String) -> void:
	var edge: Dictionary = _find_edge(edge_id)
	if edge.is_empty():
		return

	detail_title_label.text = str(edge.get("title", "未命名关系"))
	detail_overview_tag.text = "关系档案"

	var body_lines: Array[String] = []
	body_lines.append(_format_section("解锁状态", "未解锁" if _is_edge_locked(edge) else "已解锁"))
	body_lines.append(_format_section("关系双方", "%s -> %s" % [_get_node_name(str(edge.get("from", ""))), _get_node_name(str(edge.get("to", "")))]))

	var summary: String = str(edge.get("summary", ""))
	if summary != "":
		body_lines.append(_format_section("关系说明", summary))

	var keywords: Array = edge.get("keywords", [])
	if keywords is Array and keywords.size() > 0:
		body_lines.append(_format_section("关键词", " / ".join(keywords)))

	var dynamic_text: String = _build_edge_dynamic_text(edge)
	if dynamic_text != "":
		body_lines.append(_format_section("当前进度", dynamic_text))

	detail_body_label.text = "\n\n".join(body_lines)
	detail_footer_label.text = _build_edge_footer(edge)

func _build_node_dynamic_lines(node_id: String) -> Array[String]:
	var lines: Array[String] = []

	if node_id == "player":
		var player_state: Dictionary = dynamic_state.get("player_profile", {})
		lines.append("阶段：%s" % str(player_state.get("stage_title", "初遇")))
		lines.append("亲密：%.0f" % float(player_state.get("intimacy", 0.0)))
		lines.append("信任：%.0f" % float(player_state.get("trust", 0.0)))
		lines.append("共鸣：%.0f" % float(player_state.get("resonance", 0.0)))
	elif dynamic_state.get("npc_states", {}).has(node_id):
		var npc_state: Dictionary = dynamic_state["npc_states"][node_id]
		lines.append("阶段：%s" % str(npc_state.get("stage_title", "初始关系")))
		lines.append("亲密：%.0f" % float(npc_state.get("intimacy", 0.0)))
		lines.append("信任：%.0f" % float(npc_state.get("trust", 0.0)))
		lines.append("共鸣：%.0f" % float(npc_state.get("resonance", 0.0)))

	return lines

func _build_node_footer(node_id: String) -> String:
	var connected_titles: Array[String] = []
	for edge in graph_data.get("edges", []):
		if not (edge is Dictionary):
			continue
		var from_id: String = str(edge.get("from", ""))
		var to_id: String = str(edge.get("to", ""))
		if from_id == node_id or to_id == node_id:
			connected_titles.append(str(edge.get("title", "")))

	var footer_lines: Array[String] = []
	if connected_titles.size() > 0:
		footer_lines.append(_format_section("关联关系", "，".join(connected_titles)))

	var memory_hint: String = _find_memory_hint_for_node(node_id)
	if memory_hint != "":
		footer_lines.append(_format_section("记忆线索", memory_hint))

	var node: Dictionary = _find_node(node_id)
	var unlock_hint: String = str(node.get("unlock_hint", ""))
	if unlock_hint != "":
		footer_lines.append(_format_section("解锁提示", unlock_hint))

	return "\n\n".join(footer_lines)

func _build_edge_dynamic_text(edge: Dictionary) -> String:
	var source: Dictionary = edge.get("dynamic_source", {})
	var source_type: String = str(source.get("type", ""))

	if source_type == "player_profile":
		var player_state: Dictionary = dynamic_state.get("player_profile", {})
		return "阶段：%s\n亲密：%.0f\n信任：%.0f\n共鸣：%.0f" % [
			str(player_state.get("stage_title", "初遇")),
			float(player_state.get("intimacy", 0.0)),
			float(player_state.get("trust", 0.0)),
			float(player_state.get("resonance", 0.0))
		]

	if source_type == "npc_relationship":
		var npc_id: String = str(source.get("npc_id", ""))
		var npc_state: Dictionary = dynamic_state.get("npc_states", {}).get(npc_id, {})
		return "阶段：%s\n亲密：%.0f\n信任：%.0f\n共鸣：%.0f" % [
			str(npc_state.get("stage_title", "初始关系")),
			float(npc_state.get("intimacy", 0.0)),
			float(npc_state.get("trust", 0.0)),
			float(npc_state.get("resonance", 0.0))
		]

	return ""

func _build_edge_footer(edge: Dictionary) -> String:
	var footer_lines: Array[String] = []

	var memory_hint: String = str(edge.get("memory_hint", ""))
	if memory_hint != "":
		footer_lines.append(_format_section("记忆线索", memory_hint))

	var unlock_hint: String = str(edge.get("unlock_hint", ""))
	if unlock_hint != "":
		footer_lines.append(_format_section("解锁提示", unlock_hint))

	var related_count: int = memory_entries.size()
	if related_count > 0:
		footer_lines.append(_format_section("档案关联", "关系图已接入纪念册数据源，当前共可复用 %d 条条目作为后续扩展素材。" % related_count))

	return "\n\n".join(footer_lines)

func _find_memory_hint_for_node(node_id: String) -> String:
	for edge in graph_data.get("edges", []):
		if not (edge is Dictionary):
			continue
		if str(edge.get("from", "")) == node_id or str(edge.get("to", "")) == node_id:
			var hint: String = str(edge.get("memory_hint", ""))
			if hint != "":
				return hint
	return ""

func _get_node_name(node_id: String) -> String:
	var node: Dictionary = _find_node(node_id)
	return str(node.get("name", node_id))

func _find_node(node_id: String) -> Dictionary:
	return _node_cache.get(node_id, {})

func _find_edge(edge_id: String) -> Dictionary:
	return _edge_cache.get(edge_id, {})

func _build_caches() -> void:
	_node_cache.clear()
	for node in graph_data.get("nodes", []):
		if node is Dictionary:
			_node_cache[str(node.get("id", ""))] = node
	_edge_cache.clear()
	for edge in graph_data.get("edges", []):
		if edge is Dictionary:
			_edge_cache[str(edge.get("id", ""))] = edge

func _load_custom_layouts(char_id: String) -> void:
	var path: String = GameDataManager.get_archive_state_path("graph_layout_%s.json" % char_id)
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				custom_layouts = json.data
			file.close()

func _save_custom_layouts() -> void:
	if current_char_id == "": return
	var path: String = GameDataManager.get_archive_state_path("graph_layout_%s.json" % current_char_id)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(custom_layouts))
		file.close()

func _on_layout_changed(node_id: String, new_pos: Vector2) -> void:
	custom_layouts[node_id] = {"x": new_pos.x, "y": new_pos.y}
	_save_custom_layouts()

func _is_node_locked(node: Dictionary) -> bool:
	var unlock_rule: Dictionary = node.get("unlock", {})
	return not _evaluate_unlock_rule(unlock_rule)

func _is_edge_locked(edge: Dictionary) -> bool:
	var unlock_rule: Dictionary = edge.get("unlock", {})
	if not _evaluate_unlock_rule(unlock_rule):
		return true
	var from_node: Dictionary = _find_node(str(edge.get("from", "")))
	var to_node: Dictionary = _find_node(str(edge.get("to", "")))
	return (not from_node.is_empty() and _is_node_locked(from_node)) or (not to_node.is_empty() and _is_node_locked(to_node))

func _evaluate_unlock_rule(rule: Dictionary) -> bool:
	if rule.is_empty():
		return true

	var rule_type: String = str(rule.get("type", "always"))
	match rule_type:
		"always":
			return true
		"profile_stage_at_least":
			var player_state: Dictionary = dynamic_state.get("player_profile", {})
			return int(player_state.get("stage", 1)) >= int(rule.get("stage", 1))
		"player_resonance_at_least":
			var player_state: Dictionary = dynamic_state.get("player_profile", {})
			return float(player_state.get("resonance", 0.0)) >= float(rule.get("value", 0.0))
		"npc_stage_at_least":
			var npc_id: String = str(rule.get("npc_id", ""))
			var npc_state: Dictionary = dynamic_state.get("npc_states", {}).get(npc_id, {})
			return int(npc_state.get("stage", 1)) >= int(rule.get("stage", 1))
		"npc_contact_started":
			var npc_id: String = str(rule.get("npc_id", ""))
			var npc_state: Dictionary = dynamic_state.get("npc_states", {}).get(npc_id, {})
			return float(npc_state.get("intimacy", 0.0)) > 0.0 \
				or float(npc_state.get("trust", 0.0)) > 0.0 \
				or int(npc_state.get("stage", 1)) > 1
		_:
			return true
