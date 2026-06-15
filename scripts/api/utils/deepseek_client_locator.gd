class_name DeepSeekClientLocator
extends RefCounted

static func find(context: Node = null) -> Node:
	if context:
		var local_client: Node = _find_in_ancestors(context)
		if local_client:
			return local_client
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root: Window = tree.root
	if root == null:
		return null
	var llm_manager: Node = root.get_node_or_null("LLMManager")
	if llm_manager and llm_manager.has_method("get"):
		var managed_client: Variant = llm_manager.get("deepseek_client")
		if managed_client is Node and is_instance_valid(managed_client):
			return managed_client
	var current_scene: Node = tree.current_scene
	if current_scene:
		var current_scene_client: Node = current_scene.get_node_or_null("DeepSeekClient")
		if current_scene_client:
			return current_scene_client
	var root_client: Node = root.get_node_or_null("DeepSeekClient")
	if root_client:
		return root_client
	var main_scene_client: Node = root.get_node_or_null("MainScene/DeepSeekClient")
	if main_scene_client:
		return main_scene_client
	for child in root.get_children():
		if child is Node:
			if child.name == "DeepSeekClient":
				return child
			var child_client: Node = child.get_node_or_null("DeepSeekClient")
			if child_client:
				return child_client
	return null

static func _find_in_ancestors(context: Node) -> Node:
	var current: Node = context
	while current:
		var direct_client: Node = current.get_node_or_null("DeepSeekClient")
		if direct_client:
			return direct_client
		current = current.get_parent()
	return null
