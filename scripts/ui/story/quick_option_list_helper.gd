class_name QuickOptionListHelper
extends RefCounted

const QUICK_OPTION_ITEM_SCENE_PATH = "res://scenes/ui/story/quick_option_item.tscn"
const QUICK_OPTION_LOADING_ITEM_SCENE_PATH = "res://scenes/ui/story/quick_option_loading_item.tscn"

static func _get_option_item_scene() -> PackedScene:
	return load(QUICK_OPTION_ITEM_SCENE_PATH) as PackedScene

static func _get_loading_item_scene() -> PackedScene:
	return load(QUICK_OPTION_LOADING_ITEM_SCENE_PATH) as PackedScene

static func clear_container(container: Node) -> void:
	if not is_instance_valid(container):
		return
	for child in container.get_children():
		child.queue_free()

static func show_loading_item(container: Node, text: String = "正在思考话题...") -> void:
	clear_container(container)
	if not is_instance_valid(container):
		return
	var scene = _get_loading_item_scene()
	if scene == null:
		return
	var item = scene.instantiate()
	if item is Label:
		item.text = text
	container.add_child(item)

static func parse_topic_lines(raw_text: String, fallback: Array, limit: int = 3) -> Array:
	var lines = raw_text.split("\n", false)
	var topics: Array = []
	var regex = RegEx.new()
	regex.compile("^(\\d+\\.|\\-|\\*)\\s*")

	for line in lines:
		var text = line.strip_edges()
		text = regex.sub(text, "")
		if text != "":
			topics.append(text)

	if topics.size() > limit:
		topics = topics.slice(0, limit)
	elif topics.is_empty():
		topics = fallback.duplicate()

	return topics

static func populate_option_items(
	container: Node,
	options: Array,
	on_selected: Callable,
	min_height: float = 50.0
) -> void:
	clear_container(container)
	if not is_instance_valid(container):
		return

	var scene = _get_option_item_scene()
	if scene == null:
		return

	for option_text in options:
		if typeof(option_text) != TYPE_STRING:
			continue
		var item = scene.instantiate()
		container.add_child(item)
		item.setup(option_text, min_height)
		item.option_selected.connect(on_selected)

static func populate_option_items_with_index(
	container: Node,
	options: Array,
	on_selected: Callable,
	min_height: float = 50.0
) -> void:
	clear_container(container)
	if not is_instance_valid(container):
		return

	var scene = _get_option_item_scene()
	if scene == null:
		return

	var regex = RegEx.new()
	regex.compile("（.*?）|\\(.*?\\)")

	for index in range(options.size()):
		var option_text = options[index]
		if typeof(option_text) != TYPE_STRING:
			continue
		var clean_text = regex.sub(option_text, "", true).strip_edges()
		if clean_text == "":
			clean_text = option_text

		var item = scene.instantiate()
		container.add_child(item)
		item.setup(clean_text, min_height)
		item.option_selected.connect(on_selected.bind(index))
