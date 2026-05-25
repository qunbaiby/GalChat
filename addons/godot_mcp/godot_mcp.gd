@tool
extends EditorPlugin

var server_node: Node

func _enter_tree() -> void:
	# 初始化并添加 HTTP 服务器节点
	server_node = preload("res://addons/godot_mcp/http_server.gd").new()
	server_node.name = "GodotMCPServer"
	add_child(server_node)

func _exit_tree() -> void:
	# 清理 HTTP 服务器节点
	if server_node:
		if server_node.has_method("stop"):
			server_node.stop()
		server_node.queue_free()
