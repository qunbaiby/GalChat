extends Control

signal node_selected(node_id: String)
signal edge_selected(edge_id: String)
signal layout_changed(node_id: String, new_pos: Vector2)

const EDGE_HIT_DISTANCE: float = 12.0 # Slightly larger for better hit detection
const NodeCardScene = preload("res://scenes/ui/archive/relation_graph_node_card.tscn")

var graph_data: Dictionary = {}
var dynamic_state: Dictionary = {}
var selected_node_id: String = ""
var selected_edge_id: String = ""

var _node_cards: Dictionary = {}
var _node_cache: Dictionary = {}
var _edge_cache: Dictionary = {}

var pan_offset: Vector2 = Vector2.ZERO
var zoom_level: float = 1.0
var _is_panning: bool = false
var _filter_hide_locked: bool = false
var _filter_faction: String = ""

func set_filters(hide_locked: bool, faction: String) -> void:
	_filter_hide_locked = hide_locked
	_filter_faction = faction
	_apply_nodes()
	queue_redraw()

func _is_node_filtered(node_data: Dictionary) -> bool:
	if _filter_hide_locked and _is_node_locked(node_data):
		return true
	if _filter_faction != "":
		var f = str(node_data.get("faction", ""))
		if f != _filter_faction:
			return true
	return false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _on_node_dragged(node_id: String, new_anchor_pos: Vector2) -> void:
	var card = _get_node_card(node_id)
	if card == null:
		return

	var graph_pos = (new_anchor_pos - pan_offset) / zoom_level
	var clamped_graph_pos = _clamp_anchor_position(graph_pos)
	
	_set_card_anchor_position(card, clamped_graph_pos)
	_store_node_anchor_position(node_id, clamped_graph_pos)
	queue_redraw()
	layout_changed.emit(node_id, clamped_graph_pos)

func set_graph_data(data: Dictionary, state: Dictionary) -> void:
	graph_data = data
	dynamic_state = state
	_rebuild_caches()
	_apply_canvas_size()
	_build_dynamic_nodes()
	_apply_nodes()
	queue_redraw()

func _rebuild_caches() -> void:
	_node_cache.clear()
	for node in graph_data.get("nodes", []):
		if node is Dictionary:
			_node_cache[str(node.get("id", ""))] = node
			
	_edge_cache.clear()
	for edge in graph_data.get("edges", []):
		if edge is Dictionary:
			_edge_cache[str(edge.get("id", ""))] = edge

func _build_dynamic_nodes() -> void:
	for child in get_children():
		child.queue_free()
	_node_cards.clear()

	for node_data in graph_data.get("nodes", []):
		if not node_data is Dictionary:
			continue
		var node_id: String = str(node_data.get("id", ""))
		if node_id == "":
			continue

		var card = NodeCardScene.instantiate()
		card.z_index = 1
		add_child(card)
		_node_cards[node_id] = card
		
		card.pressed.connect(_on_node_pressed)
		if card.has_signal("node_dragged"):
			card.connect("node_dragged", Callable(self, "_on_node_dragged"))

		# 重点：初始化时直接设置卡片位置
		var anchor_position: Vector2 = _clamp_anchor_position(_resolve_node_anchor_position(node_data, card))
		_set_card_anchor_position(card, anchor_position)

		var is_filtered = _is_node_filtered(node_data)
		var is_locked: bool = _is_node_locked(node_data)
		card.visible = not is_filtered
		
		if not is_filtered:
			card.call(
				"setup_from_node",
				node_data,
				_build_node_tooltip(node_data),
				_load_node_avatar(node_data),
				_get_node_placeholder(node_data)
			)

			var base_color: Color = _get_node_color(node_data)
			var active_color: Color = _get_node_active_color(node_data, base_color)
			card.call("update_visual", node_data, _get_node_subtitle(node_data), base_color, active_color, node_id == selected_node_id, is_locked)

func select_node(node_id: String) -> void:
	selected_node_id = node_id
	selected_edge_id = ""
	_apply_nodes()
	queue_redraw()

func select_edge(edge_id: String) -> void:
	selected_edge_id = edge_id
	selected_node_id = ""
	_apply_nodes()
	queue_redraw()

func _draw() -> void:
	for edge in graph_data.get("edges", []):
		if not (edge is Dictionary and _should_draw_edge(edge)):
			continue

		var edge_id: String = str(edge.get("id", ""))
		var is_selected: bool = edge_id == selected_edge_id
		var is_locked: bool = _is_edge_locked(edge)
		var color: Color = _get_edge_color(edge, is_locked, is_selected)
		var custom_width = edge.get("width")
		var width: float = float(custom_width) if custom_width != null else (1.0 if edge.get("is_primary", false) else 0.6)
		if is_selected:
			width += 0.4

		var path_points: Array[Vector2] = _get_edge_path(edge)
		var screen_points: Array[Vector2] = []
		for p in path_points:
			screen_points.append(p * zoom_level + pan_offset)
		
		_draw_edge_path(str(edge.get("line_style", "solid")), screen_points, color, width * zoom_level)

		if is_selected:
			var mid: Vector2 = _get_path_midpoint(screen_points)
			draw_circle(mid, 1.5 * zoom_level, color)
			_draw_edge_label(str(edge.get("title", "关系")), mid, color, zoom_level)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = event.pressed
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_canvas(1.1, event.position)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_canvas(1.0 / 1.1, event.position)
			accept_event()
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var hit_edge_id: String = _find_edge_at_point(event.position)
			if hit_edge_id != "":
				selected_edge_id = hit_edge_id
				selected_node_id = ""
				_apply_nodes()
				queue_redraw()
				edge_selected.emit(hit_edge_id)
				accept_event()
	elif event is InputEventMouseMotion and _is_panning:
		pan_offset += event.relative
		_apply_nodes()
		queue_redraw()
		accept_event()

func _zoom_canvas(factor: float, mouse_pos: Vector2) -> void:
	var old_zoom = zoom_level
	zoom_level = clamp(zoom_level * factor, 0.3, 3.0)
	if zoom_level == old_zoom:
		return
	var graph_pos = (mouse_pos - pan_offset) / old_zoom
	pan_offset = mouse_pos - graph_pos * zoom_level
	_apply_nodes()
	queue_redraw()

func _apply_nodes() -> void:
	for node_id in _get_node_ids():
		var node_data: Dictionary = _find_node(node_id)
		var node_card = _get_node_card(node_id)
		if node_data.is_empty() or node_card == null:
			continue

		var anchor_position: Vector2 = _clamp_anchor_position(_resolve_node_anchor_position(node_data, node_card))
		_set_card_anchor_position(node_card, anchor_position)

		var is_filtered = _is_node_filtered(node_data)
		var is_locked: bool = _is_node_locked(node_data)
		node_card.visible = not is_filtered
		
		if not is_filtered:
			node_card.call(
				"setup_from_node",
				node_data,
				_build_node_tooltip(node_data),
				_load_node_avatar(node_data),
				_get_node_placeholder(node_data)
			)

			var base_color: Color = _get_node_color(node_data)
			var active_color: Color = _get_node_active_color(node_data, base_color)
			node_card.call("update_visual", node_data, _get_node_subtitle(node_data), base_color, active_color, node_id == selected_node_id, is_locked)

func _on_node_pressed(node_id: String) -> void:
	selected_node_id = node_id
	selected_edge_id = ""
	_apply_nodes()
	queue_redraw()
	node_selected.emit(node_id)

func _get_node_ids() -> Array[String]:
	var ids: Array[String] = []
	for node_data in graph_data.get("nodes", []):
		if node_data is Dictionary:
			var node_id: String = str(node_data.get("id", ""))
			if node_id != "":
				ids.append(node_id)
	return ids

func _get_node_card(node_id: String):
	return _node_cards.get(node_id)

func _get_card_anchor_offset(card) -> Vector2:
	if card != null and card.has_method("get_avatar_anchor_offset"):
		return card.call("get_avatar_anchor_offset")
	return card.size * 0.5 if card != null else Vector2.ZERO

func _set_card_anchor_position(card, graph_pos: Vector2) -> void:
	if card == null:
		return
	var offset = _get_card_anchor_offset(card)
	var screen_anchor = graph_pos * zoom_level + pan_offset
	card.scale = Vector2(zoom_level, zoom_level)
	card.position = screen_anchor - offset * zoom_level
	if card.has_method("set_anchor_position"):
		card.call("set_anchor_position", screen_anchor)

func _resolve_node_anchor_position(node_data: Dictionary, node_card) -> Vector2:
	var fallback_anchor: Vector2 = node_card.position + _get_card_anchor_offset(node_card) if node_card != null else Vector2.ZERO
	var pos_dict = node_data.get("position", {})
	if pos_dict is Dictionary:
		return Vector2(
			float(pos_dict.get("x", fallback_anchor.x)),
			float(pos_dict.get("y", fallback_anchor.y))
		)
	return fallback_anchor

func _store_node_anchor_position(node_id: String, anchor_position: Vector2) -> void:
	var node_data: Dictionary = _find_node(node_id)
	if node_data.is_empty():
		return
	if not node_data.has("position") or not (node_data["position"] is Dictionary):
		node_data["position"] = {}
	node_data["position"]["x"] = anchor_position.x
	node_data["position"]["y"] = anchor_position.y

func _clamp_anchor_position(anchor_position: Vector2) -> Vector2:
	return Vector2(
		clamp(anchor_position.x, -5000.0, 5000.0),
		clamp(anchor_position.y, -5000.0, 5000.0)
	)

func _apply_canvas_size() -> void:
	pass

func _get_canvas_size() -> Vector2:
	var canvas_dict = graph_data.get("canvas_size", {})
	if canvas_dict is Dictionary:
		return Vector2(
			float(canvas_dict.get("width", 330.0)),
			float(canvas_dict.get("height", 440.0))
		)
	return Vector2(330.0, 440.0)

func _get_edge_path(edge: Dictionary) -> Array[Vector2]:
	var from_id: String = str(edge.get("from", ""))
	var to_id: String = str(edge.get("to", ""))
	var from_node = _find_node(from_id)
	var to_node = _find_node(to_id)
	if from_node.is_empty() or to_node.is_empty():
		return []

	var from_pos = _resolve_node_anchor_position(from_node, _get_node_card(from_id))
	var to_pos = _resolve_node_anchor_position(to_node, _get_node_card(to_id))

	return [from_pos, to_pos]

func _draw_edge_path(line_style: String, path_points: Array[Vector2], color: Color, width: float) -> void:
	if path_points.size() < 2:
		return
	for i in range(path_points.size() - 1):
		var start: Vector2 = path_points[i]
		var finish: Vector2 = path_points[i + 1]
		if line_style == "dashed":
			_draw_dashed_line(start, finish, color, width, 7.0, 5.0)
		else:
			draw_line(start, finish, color, width, true)

func _draw_dashed_line(from_pos: Vector2, to_pos: Vector2, color: Color, width: float, dash_length: float, gap_length: float) -> void:
	var total_length: float = from_pos.distance_to(to_pos)
	if total_length <= 0.001:
		return
	var direction: Vector2 = (to_pos - from_pos) / total_length
	var drawn: float = 0.0
	while drawn < total_length:
		var start: Vector2 = from_pos + direction * drawn
		var end_distance: float = min(drawn + dash_length, total_length)
		var finish: Vector2 = from_pos + direction * end_distance
		draw_line(start, finish, color, width, true)
		drawn += dash_length + gap_length

func _find_edge_at_point(point: Vector2) -> String:
	var best_id: String = ""
	var best_distance: float = INF
	for edge in graph_data.get("edges", []):
		if not (edge is Dictionary and _should_draw_edge(edge)):
			continue
		var path_points: Array[Vector2] = _get_edge_path(edge)
		var screen_points: Array[Vector2] = []
		for p in path_points:
			screen_points.append(p * zoom_level + pan_offset)
			
		for i in range(screen_points.size() - 1):
			var distance: float = _distance_to_segment(point, screen_points[i], screen_points[i + 1])
			if distance <= EDGE_HIT_DISTANCE and distance < best_distance:
				best_distance = distance
				best_id = str(edge.get("id", ""))
	return best_id

func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var ab_len_sq: float = ab.length_squared()
	if ab_len_sq <= 0.001:
		return point.distance_to(a)
	var t: float = clamp((point - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	return point.distance_to(a + ab * t)

func _should_draw_edge(edge: Dictionary) -> bool:
	if not bool(edge.get("visible", true)):
		return false

	var from_node = _find_node(str(edge.get("from", "")))
	var to_node = _find_node(str(edge.get("to", "")))
	
	if _is_node_filtered(from_node) or _is_node_filtered(to_node):
		return false

	if _is_edge_locked(edge) and _filter_hide_locked:
		return false

	if _is_edge_locked(edge):
		return false

	var edge_id: String = str(edge.get("id", ""))
	if edge.get("is_primary", false):
		return true

	if selected_edge_id == edge_id:
		return true

	if selected_node_id == "":
		return false

	return str(edge.get("from", "")) == selected_node_id or str(edge.get("to", "")) == selected_node_id

func _get_path_midpoint(path_points: Array[Vector2]) -> Vector2:
	if path_points.size() < 2:
		return Vector2.ZERO
	var total_length: float = 0.0
	for i in range(path_points.size() - 1):
		total_length += path_points[i].distance_to(path_points[i + 1])
	var target: float = total_length * 0.5
	var walked: float = 0.0
	for i in range(path_points.size() - 1):
		var start: Vector2 = path_points[i]
		var finish: Vector2 = path_points[i + 1]
		var segment: float = start.distance_to(finish)
		if walked + segment >= target:
			return start.lerp(finish, (target - walked) / max(segment, 0.001))
		walked += segment
	return path_points[path_points.size() - 1]

func _draw_edge_label(title: String, mid: Vector2, color: Color, zoom: float = 1.0) -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		return
	var font_size: int = max(8, int(10 * zoom))
	var text_size: Vector2 = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var size_rect: Vector2 = text_size + Vector2(16 * zoom, 8 * zoom)
	var rect: Rect2 = Rect2(mid - size_rect * 0.5 + Vector2(0, -18 * zoom), size_rect)
	draw_rect(rect, Color(0.07, 0.09, 0.12, 0.96), true)
	draw_rect(rect, color, false, max(1.0, 1.0 * zoom))
	draw_string(font, rect.position + Vector2(8 * zoom, rect.size.y * 0.5 + font_size * 0.35 - 1.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.95, 0.98, 1.0))

func _find_node(node_id: String) -> Dictionary:
	return _node_cache.get(node_id, {})

func _build_node_tooltip(node: Dictionary) -> String:
	var lines: Array[String] = [str(node.get("name", ""))]
	var role: String = str(node.get("role", ""))
	if role != "":
		lines.append(role)
	var subtitle: String = _get_node_subtitle(node)
	if subtitle != "":
		lines.append("当前状态：%s" % subtitle)
	return "\n".join(lines)

func _get_node_subtitle(node: Dictionary) -> String:
	var node_id: String = str(node.get("id", ""))
	if node_id == "player":
		var player_state: Dictionary = dynamic_state.get("player_profile", {})
		return _short_text(str(player_state.get("stage_title", node.get("static_subtitle", ""))), 8)
	if str(node.get("type", "")) == "npc":
		var npc_state: Dictionary = dynamic_state.get("npc_states", {}).get(node_id, {})
		return _short_text(str(npc_state.get("stage_title", node.get("static_subtitle", ""))), 8)
	return _short_text(str(node.get("static_subtitle", "")), 8)

func _get_node_color(node: Dictionary) -> Color:
	var custom_color = str(node.get("color", ""))
	if custom_color != "":
		return Color(custom_color)
		
	match str(node.get("type", "npc")):
		"player":
			return Color("#3f6fae")
		"heroine":
			return Color("#8756a2")
		"memory":
			return Color("#6f627f")
		_:
			return Color("#536f87")

func _get_node_active_color(node: Dictionary, base_color: Color) -> Color:
	var custom_active = str(node.get("active_color", ""))
	if custom_active != "":
		return Color(custom_active)
	
	var node_id: String = str(node.get("id", ""))
	match node_id:
		"player":
			return Color(0.4, 0.7, 1.0, 1.0)
		"luna":
			return Color(0.9, 0.6, 1.0, 1.0)
		_:
			return base_color.lightened(0.2)

func _get_edge_color(edge: Dictionary, is_locked: bool, is_selected: bool) -> Color:
	var color: Color = Color(str(edge.get("color", "#6fd3ff")))
	color.a = 0.52 if edge.get("is_primary", false) else 0.26
	if is_locked:
		color = _mute_color(color, 0.35, 0.7)
		color.a *= 0.7
	if is_selected:
		color = color.lightened(0.15)
		color.a = 0.92
	return color

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
	match str(rule.get("type", "always")):
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
			return float(npc_state.get("intimacy", 0.0)) > 0.0 or float(npc_state.get("trust", 0.0)) > 0.0 or int(npc_state.get("interaction_exp", 0)) > 0 or int(npc_state.get("stage", 1)) > 1
		_:
			return true

func _load_node_avatar(node: Dictionary) -> Texture2D:
	var avatar_path: String = str(node.get("avatar", ""))
	if avatar_path != "" and ResourceLoader.exists(avatar_path):
		return load(avatar_path) as Texture2D
	return null

func _get_node_placeholder(node: Dictionary) -> String:
	var name_text: String = str(node.get("name", "?")).strip_edges()
	return "?" if name_text == "" else name_text.substr(0, 1)

func _mute_color(color: Color, darken_amount: float, blend_amount: float) -> Color:
	var darkened: Color = color.darkened(darken_amount)
	var gray: Color = Color(darkened.v, darkened.v, darkened.v, darkened.a)
	return darkened.lerp(gray, blend_amount)

func _short_text(text: String, limit: int) -> String:
	if text.length() <= limit:
		return text
	return text.substr(0, limit) + "..."
