@tool
extends Node

var tcp_server: TCPServer
var port: int = 8081
var clients: Array[StreamPeerTCP] = []
const MCP_VERSION := "1.2.0"

func _ready() -> void:
	tcp_server = TCPServer.new()
	var err = tcp_server.listen(port)
	if err == OK:
		print("[Godot MCP] Server listening on port ", port)
	else:
		printerr("[Godot MCP] Failed to listen on port ", port, ". Error code: ", err)

func stop() -> void:
	if tcp_server:
		tcp_server.stop()
		tcp_server = null
	for client in clients:
		if client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			client.disconnect_from_host()
	clients.clear()
	print("[Godot MCP] Server stopped.")

func _process(_delta: float) -> void:
	if not tcp_server:
		return
		
	# 接受新连接
	if tcp_server.is_connection_available():
		var peer = tcp_server.take_connection()
		if peer:
			clients.append(peer)
			
	# 处理现有连接
	var i = clients.size() - 1
	while i >= 0:
		var client = clients[i]
		client.poll()
		var status = client.get_status()
		
		if status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR:
			clients.remove_at(i)
		elif status == StreamPeerTCP.STATUS_CONNECTED:
			var available_bytes = client.get_available_bytes()
			if available_bytes > 0:
				var request_str = client.get_string(available_bytes)
				handle_request(client, request_str)
				client.disconnect_from_host() # 短连接，响应后即关闭
				clients.remove_at(i)
		i -= 1

func handle_request(client: StreamPeerTCP, request_str: String) -> void:
	var request_parts = request_str.split("\r\n\r\n", false, 1)
	var header_str = request_parts[0]
	var body_str = request_parts[1] if request_parts.size() > 1 else ""
	var lines = header_str.split("\r\n")
	if lines.size() == 0:
		return
		
	var request_line = lines[0].split(" ")
	if request_line.size() < 2:
		return
		
	var method = request_line[0]
	var path_and_query = request_line[1]
	
	var parts = path_and_query.split("?")
	var path = parts[0]
	var query = ""
	if parts.size() > 1:
		query = parts[1]
		
	var query_params = {}
	if query != "":
		for pair in query.split("&"):
			var kv = pair.split("=")
			if kv.size() == 2:
				query_params[kv[0]] = kv[1].uri_decode()
	
	# 处理预检请求
	if method == "OPTIONS":
		send_response(client, 204, "No Content", "")
		return
		
	if method == "GET":
		if path == "/health":
			handle_health(client)
		elif path == "/editor_status":
			handle_editor_status(client)
		elif path == "/current_scene":
			handle_get_current_scene(client)
		elif path == "/selected_node":
			handle_get_selected_node(client)
		elif path == "/find_node":
			handle_find_node(client, query_params)
		elif path == "/scene_tree":
			handle_get_scene_tree(client)
		elif path == "/node":
			handle_get_node(client, query_params)
		else:
			send_response(client, 404, "Not Found", JSON.stringify({"error": "Not Found"}))
	elif method == "POST":
		var body_data = _parse_json_body(client, body_str)
		if body_data == null:
			return

		if path == "/open_scene":
			handle_open_scene(client, body_data)
		elif path == "/play_scene":
			handle_play_scene(client, body_data)
		elif path == "/set_node_property":
			handle_set_node_property(client, body_data)
		elif path == "/save_scene":
			handle_save_scene(client, body_data)
		elif path == "/save_all_scenes":
			handle_save_all_scenes(client)
		else:
			send_response(client, 404, "Not Found", JSON.stringify({"error": "Not Found"}))
	else:
		send_response(client, 405, "Method Not Allowed", JSON.stringify({"error": "Method Not Allowed"}))

func send_response(client: StreamPeerTCP, status_code: int, status_text: String, body: String) -> void:
	var response = "HTTP/1.1 " + str(status_code) + " " + status_text + "\r\n"
	response += "Content-Type: application/json; charset=utf-8\r\n"
	response += "Access-Control-Allow-Origin: *\r\n"
	response += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
	response += "Access-Control-Allow-Headers: Content-Type\r\n"
	
	var body_buffer = body.to_utf8_buffer()
	response += "Content-Length: " + str(body_buffer.size()) + "\r\n"
	response += "Connection: close\r\n"
	response += "\r\n"
	
	client.put_data(response.to_utf8_buffer())
	if body_buffer.size() > 0:
		client.put_data(body_buffer)

func _get_edited_scene_root() -> Node:
	return EditorInterface.get_edited_scene_root()

func _parse_json_body(client: StreamPeerTCP, body_str: String):
	if body_str.strip_edges() == "":
		return {}

	var json = JSON.new()
	var err = json.parse(body_str)
	if err != OK:
		send_response(client, 400, "Bad Request", JSON.stringify({"error": "Invalid JSON body"}))
		return null

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		send_response(client, 400, "Bad Request", JSON.stringify({"error": "JSON body must be an object"}))
		return null

	return data

func _serialize_node_basic(node: Node) -> Dictionary:
	return {
		"name": node.name,
		"class": node.get_class(),
		"path": str(node.get_path())
	}

func _find_node_by_path(root: Node, node_path: String) -> Node:
	if str(root.get_path()) == node_path:
		return root
	return root.get_node_or_null(node_path)

func _coerce_value(raw_value, value_type: String):
	match value_type:
		"", "auto", "json":
			return raw_value
		"string":
			return str(raw_value)
		"int":
			return int(raw_value)
		"float":
			return float(raw_value)
		"bool":
			if typeof(raw_value) == TYPE_BOOL:
				return raw_value
			var lowered = str(raw_value).to_lower()
			return lowered == "true" or lowered == "1" or lowered == "yes"
		"node_path":
			return NodePath(str(raw_value))
		"vector2":
			if typeof(raw_value) == TYPE_ARRAY and raw_value.size() >= 2:
				return Vector2(float(raw_value[0]), float(raw_value[1]))
			if typeof(raw_value) == TYPE_DICTIONARY:
				return Vector2(float(raw_value.get("x", 0.0)), float(raw_value.get("y", 0.0)))
		"vector2i":
			if typeof(raw_value) == TYPE_ARRAY and raw_value.size() >= 2:
				return Vector2i(int(raw_value[0]), int(raw_value[1]))
			if typeof(raw_value) == TYPE_DICTIONARY:
				return Vector2i(int(raw_value.get("x", 0)), int(raw_value.get("y", 0)))
		"vector3":
			if typeof(raw_value) == TYPE_ARRAY and raw_value.size() >= 3:
				return Vector3(float(raw_value[0]), float(raw_value[1]), float(raw_value[2]))
			if typeof(raw_value) == TYPE_DICTIONARY:
				return Vector3(float(raw_value.get("x", 0.0)), float(raw_value.get("y", 0.0)), float(raw_value.get("z", 0.0)))
		"vector3i":
			if typeof(raw_value) == TYPE_ARRAY and raw_value.size() >= 3:
				return Vector3i(int(raw_value[0]), int(raw_value[1]), int(raw_value[2]))
			if typeof(raw_value) == TYPE_DICTIONARY:
				return Vector3i(int(raw_value.get("x", 0)), int(raw_value.get("y", 0)), int(raw_value.get("z", 0)))
		"color":
			if typeof(raw_value) == TYPE_ARRAY and raw_value.size() >= 3:
				var alpha = float(raw_value[3]) if raw_value.size() >= 4 else 1.0
				return Color(float(raw_value[0]), float(raw_value[1]), float(raw_value[2]), alpha)
			if typeof(raw_value) == TYPE_DICTIONARY:
				return Color(
					float(raw_value.get("r", 0.0)),
					float(raw_value.get("g", 0.0)),
					float(raw_value.get("b", 0.0)),
					float(raw_value.get("a", 1.0))
				)
	return raw_value

func handle_open_scene(client: StreamPeerTCP, body_data: Dictionary) -> void:
	var scene_path = String(body_data.get("scene_path", ""))
	if scene_path == "":
		send_response(client, 400, "Bad Request", JSON.stringify({"error": "Missing scene_path"}))
		return

	if not FileAccess.file_exists(scene_path):
		send_response(client, 404, "Not Found", JSON.stringify({"error": "Scene file does not exist"}))
		return

	var set_inherited = bool(body_data.get("set_inherited", false))
	EditorInterface.open_scene_from_path(scene_path, set_inherited)

	send_response(client, 200, "OK", JSON.stringify({
		"opened": true,
		"scene_path": scene_path,
		"set_inherited": set_inherited
	}))

func handle_play_scene(client: StreamPeerTCP, body_data: Dictionary) -> void:
	var play_mode = String(body_data.get("mode", "main")).to_lower()
	var was_playing = EditorInterface.is_playing_scene()

	match play_mode:
		"main":
			EditorInterface.play_main_scene()
		"current":
			var root = _get_edited_scene_root()
			if not root:
				send_response(client, 404, "Not Found", JSON.stringify({"error": "No scene currently edited"}))
				return
			EditorInterface.play_current_scene()
		"custom":
			var scene_path = String(body_data.get("scene_path", ""))
			if scene_path == "":
				send_response(client, 400, "Bad Request", JSON.stringify({"error": "Missing scene_path for custom play mode"}))
				return
			if not FileAccess.file_exists(scene_path):
				send_response(client, 404, "Not Found", JSON.stringify({"error": "Scene file does not exist"}))
				return
			EditorInterface.play_custom_scene(scene_path)
		_:
			send_response(client, 400, "Bad Request", JSON.stringify({"error": "Invalid play mode"}))
			return

	send_response(client, 200, "OK", JSON.stringify({
		"started": true,
		"mode": play_mode,
		"was_playing": was_playing,
		"is_playing": EditorInterface.is_playing_scene(),
		"playing_scene": EditorInterface.get_playing_scene()
	}))

func handle_set_node_property(client: StreamPeerTCP, body_data: Dictionary) -> void:
	var root = _get_edited_scene_root()
	if not root:
		send_response(client, 404, "Not Found", JSON.stringify({"error": "No scene currently edited"}))
		return

	var node_path = String(body_data.get("path", ""))
	var property_name = String(body_data.get("property", ""))
	if node_path == "" or property_name == "":
		send_response(client, 400, "Bad Request", JSON.stringify({"error": "Missing path or property"}))
		return

	var target_node = _find_node_by_path(root, node_path)
	if not target_node:
		send_response(client, 404, "Not Found", JSON.stringify({"error": "Node not found"}))
		return

	var raw_value = body_data.get("value", null)
	var value_type = String(body_data.get("value_type", "auto")).to_lower()
	var coerced_value = _coerce_value(raw_value, value_type)
	target_node.set(property_name, coerced_value)

	send_response(client, 200, "OK", JSON.stringify({
		"updated": true,
		"path": node_path,
		"property": property_name,
		"value": str(target_node.get(property_name)),
		"value_type": value_type
	}))

func handle_save_scene(client: StreamPeerTCP, body_data: Dictionary) -> void:
	var root = _get_edited_scene_root()
	if not root:
		send_response(client, 404, "Not Found", JSON.stringify({"error": "No scene currently edited"}))
		return

	var with_preview = bool(body_data.get("with_preview", false))
	if body_data.has("scene_path"):
		var save_path = String(body_data.get("scene_path", ""))
		if save_path == "":
			send_response(client, 400, "Bad Request", JSON.stringify({"error": "scene_path cannot be empty"}))
			return

		EditorInterface.save_scene_as(save_path, with_preview)
		send_response(client, 200, "OK", JSON.stringify({
			"saved": true,
			"mode": "save_as",
			"scene_path": save_path,
			"with_preview": with_preview
		}))
		return

	var err = EditorInterface.save_scene()
	if err != OK:
		send_response(client, 500, "Internal Server Error", JSON.stringify({"error": "Failed to save current scene", "error_code": err}))
		return

	send_response(client, 200, "OK", JSON.stringify({
		"saved": true,
		"mode": "save_current",
		"scene_path": root.scene_file_path,
		"with_preview": with_preview
	}))

func handle_save_all_scenes(client: StreamPeerTCP) -> void:
	EditorInterface.save_all_scenes()
	send_response(client, 200, "OK", JSON.stringify({
		"saved_all": true
	}))

func handle_health(client: StreamPeerTCP) -> void:
	var root = _get_edited_scene_root()
	var response_data = {
		"ok": true,
		"service": "godot_mcp_http",
		"version": MCP_VERSION,
		"port": port,
		"project_path": ProjectSettings.globalize_path("res://"),
		"edited_scene_available": root != null,
		"current_scene_path": root.scene_file_path if root != null else ""
	}
	send_response(client, 200, "OK", JSON.stringify(response_data))

func handle_editor_status(client: StreamPeerTCP) -> void:
	var root = _get_edited_scene_root()
	var selected_nodes: Array = []
	var selection = EditorInterface.get_selection()
	if selection:
		selected_nodes = selection.get_selected_nodes()

	var response_data = {
		"ok": true,
		"project_path": ProjectSettings.globalize_path("res://"),
		"scene_open": root != null,
		"scene_name": root.name if root != null else "",
		"scene_path": root.scene_file_path if root != null else "",
		"is_playing": EditorInterface.is_playing_scene(),
		"playing_scene": EditorInterface.get_playing_scene(),
		"selected_count": selected_nodes.size(),
		"selected_paths": selected_nodes.map(func(node): return str(node.get_path()))
	}
	send_response(client, 200, "OK", JSON.stringify(response_data))

func handle_get_current_scene(client: StreamPeerTCP) -> void:
	var root = _get_edited_scene_root()
	if not root:
		send_response(client, 404, "Not Found", JSON.stringify({"error": "No scene currently edited"}))
		return

	var response_data = _serialize_node_basic(root)
	response_data["scene_file_path"] = root.scene_file_path
	response_data["child_count"] = root.get_child_count()
	send_response(client, 200, "OK", JSON.stringify(response_data))

func handle_get_selected_node(client: StreamPeerTCP) -> void:
	var selection = EditorInterface.get_selection()
	if not selection:
		send_response(client, 404, "Not Found", JSON.stringify({"error": "Editor selection is unavailable"}))
		return

	var selected_nodes: Array = selection.get_selected_nodes()
	if selected_nodes.is_empty():
		send_response(client, 404, "Not Found", JSON.stringify({"error": "No node is currently selected"}))
		return

	var nodes_data: Array = []
	for node in selected_nodes:
		nodes_data.append(_serialize_node_basic(node))

	var response_data = {
		"count": selected_nodes.size(),
		"nodes": nodes_data,
		"primary": nodes_data[0]
	}
	send_response(client, 200, "OK", JSON.stringify(response_data))

func handle_find_node(client: StreamPeerTCP, query_params: Dictionary) -> void:
	var root = _get_edited_scene_root()
	if not root:
		send_response(client, 404, "Not Found", JSON.stringify({"error": "No scene currently edited"}))
		return

	var name_query = String(query_params.get("name", "")).to_lower()
	var class_query = String(query_params.get("class_name", "")).to_lower()
	var path_query = String(query_params.get("path_contains", "")).to_lower()
	var limit = int(query_params.get("limit", "20"))
	if limit <= 0:
		limit = 20

	var matches: Array = []
	_collect_matching_nodes(root, name_query, class_query, path_query, limit, matches)

	var response_data = {
		"count": matches.size(),
		"matches": matches
	}
	send_response(client, 200, "OK", JSON.stringify(response_data))

func _collect_matching_nodes(node: Node, name_query: String, class_query: String, path_query: String, limit: int, matches: Array) -> void:
	if matches.size() >= limit:
		return

	var node_name = String(node.name).to_lower()
	var node_class = String(node.get_class()).to_lower()
	var node_path = String(node.get_path()).to_lower()

	var matched = true
	if name_query != "" and node_name.find(name_query) == -1:
		matched = false
	if class_query != "" and node_class.find(class_query) == -1:
		matched = false
	if path_query != "" and node_path.find(path_query) == -1:
		matched = false

	if matched:
		matches.append(_serialize_node_basic(node))
		if matches.size() >= limit:
			return

	for child in node.get_children():
		_collect_matching_nodes(child, name_query, class_query, path_query, limit, matches)
		if matches.size() >= limit:
			return

func handle_get_scene_tree(client: StreamPeerTCP) -> void:
	var root = _get_edited_scene_root()
	if not root:
		send_response(client, 404, "Not Found", JSON.stringify({"error": "No scene currently edited"}))
		return
		
	var tree_data = build_node_tree(root)
	var json = JSON.stringify(tree_data)
	send_response(client, 200, "OK", json)

func build_node_tree(node: Node) -> Dictionary:
	var data = _serialize_node_basic(node)
	data["children"] = []
	
	for child in node.get_children():
		data["children"].append(build_node_tree(child))
		
	return data

func handle_get_node(client: StreamPeerTCP, query_params: Dictionary) -> void:
	if not query_params.has("path"):
		send_response(client, 400, "Bad Request", JSON.stringify({"error": "Missing path parameter"}))
		return
		
	var node_path = query_params["path"]
	var root = _get_edited_scene_root()
	if not root:
		send_response(client, 404, "Not Found", JSON.stringify({"error": "No scene currently edited"}))
		return
		
	var target_node: Node = _find_node_by_path(root, node_path)
		
	if not target_node:
		send_response(client, 404, "Not Found", JSON.stringify({"error": "Node not found"}))
		return
		
	var properties = []
	for prop in target_node.get_property_list():
		var prop_name = prop["name"]
		var val = target_node.get(prop_name)
		
		# 将不支持 JSON 序列化的类型转换为字符串
		var val_str = str(val) if val != null else "null"
		
		properties.append({
			"name": prop_name,
			"type": prop["type"],
			"value": val_str
		})
		
	var response_data = {
		"name": target_node.name,
		"class": target_node.get_class(),
		"path": str(target_node.get_path()),
		"properties": properties
	}
	
	send_response(client, 200, "OK", JSON.stringify(response_data))
