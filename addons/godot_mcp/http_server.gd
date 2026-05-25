@tool
extends Node

var tcp_server: TCPServer
var port: int = 8081
var clients: Array[StreamPeerTCP] = []

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
	var lines = request_str.split("\r\n")
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
		if path == "/scene_tree":
			handle_get_scene_tree(client)
		elif path == "/node":
			handle_get_node(client, query_params)
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

func handle_get_scene_tree(client: StreamPeerTCP) -> void:
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		send_response(client, 404, "Not Found", JSON.stringify({"error": "No scene currently edited"}))
		return
		
	var tree_data = build_node_tree(root)
	var json = JSON.stringify(tree_data)
	send_response(client, 200, "OK", json)

func build_node_tree(node: Node) -> Dictionary:
	var data = {
		"name": node.name,
		"class": node.get_class(),
		"path": str(node.get_path()),
		"children": []
	}
	
	for child in node.get_children():
		data["children"].append(build_node_tree(child))
		
	return data

func handle_get_node(client: StreamPeerTCP, query_params: Dictionary) -> void:
	if not query_params.has("path"):
		send_response(client, 400, "Bad Request", JSON.stringify({"error": "Missing path parameter"}))
		return
		
	var node_path = query_params["path"]
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		send_response(client, 404, "Not Found", JSON.stringify({"error": "No scene currently edited"}))
		return
		
	var target_node: Node = null
	
	if str(root.get_path()) == node_path:
		target_node = root
	else:
		# get_node_or_null 支持绝对路径，因此直接使用它来查找
		target_node = root.get_node_or_null(node_path)
		
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
