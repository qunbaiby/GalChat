class_name QuickOptionListHelper
extends RefCounted

const QUICK_OPTION_ITEM_SCENE_PATH = "res://scenes/ui/story/quick_option_item.tscn"
const QUICK_OPTION_LOADING_ITEM_SCENE_PATH = "res://scenes/ui/story/quick_option_loading_item.tscn"
const ICON_TOPIC_LIFE := "res://assets/images/icons/ui/system/topic_life.svg"
const ICON_TOPIC_STUDY := "res://assets/images/icons/ui/system/topic_study.svg"
const ICON_CHOICE_INTIMACY := "res://assets/images/icons/ui/system/choice_intimacy.svg"
const ICON_CHOICE_TRUST := "res://assets/images/icons/ui/system/choice_trust.svg"
const ICON_TOPIC_EMOTION := "res://assets/images/icons/ui/system/topic_emotion.svg"

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

static func normalize_dialogue_choice_options(options: Array) -> Array:
	var normalized: Array = []
	for index in range(options.size()):
		var option_data = options[index]
		var text := ""
		var focus := "intimacy" if index == 0 else "trust"
		if option_data is Dictionary:
			text = _pick_option_text(option_data)
			var raw_focus := str(option_data.get("focus", option_data.get("kind", focus))).strip_edges().to_lower()
			if raw_focus != "":
				focus = raw_focus
		else:
			text = str(option_data).strip_edges()
		if text == "":
			continue
		normalized.append(build_dialogue_choice_item(text, focus))
	return normalized

static func _pick_option_text(option_data: Dictionary) -> String:
	for key in ["text", "content", "label", "summary"]:
		var value := str(option_data.get(key, "")).strip_edges()
		if value != "":
			return value
	return ""

static func build_dialogue_choice_item(text: String, focus: String) -> Dictionary:
	var final_focus := focus
	if final_focus != "trust":
		final_focus = "intimacy"
	var title := "亲密提升"
	var icon_path := ICON_CHOICE_INTIMACY
	if final_focus == "trust":
		title = "信任提升"
		icon_path = ICON_CHOICE_TRUST
	return {
		"text": text,
		"title": title,
		"kind": final_focus,
		"icon_path": icon_path
	}

static func build_topic_option_item(text: String, topic_kind: String) -> Dictionary:
	var title := "生活话题"
	var icon_path := ICON_TOPIC_LIFE
	var final_kind := "life"
	match topic_kind:
		"story":
			title = "主线话题"
			icon_path = ICON_TOPIC_EMOTION
			final_kind = "story"
		"study":
			title = "学习话题"
			icon_path = ICON_TOPIC_STUDY
			final_kind = "study"
		"emotion":
			title = "情感话题"
			icon_path = ICON_TOPIC_EMOTION
			final_kind = "emotion"
		_:
			title = "生活话题"
			icon_path = ICON_TOPIC_LIFE
			final_kind = "life"
	return {
		"text": text,
		"title": title,
		"kind": final_kind,
		"icon_path": icon_path
	}

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
		if typeof(option_text) != TYPE_STRING and typeof(option_text) != TYPE_DICTIONARY:
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
		if typeof(option_text) != TYPE_STRING and typeof(option_text) != TYPE_DICTIONARY:
			continue
		var clean_text := ""
		if option_text is Dictionary:
			var final_data := option_text as Dictionary
			clean_text = _pick_option_text(final_data)
		else:
			clean_text = regex.sub(str(option_text), "", true).strip_edges()
			if clean_text == "":
				clean_text = str(option_text)

		var item = scene.instantiate()
		container.add_child(item)
		if option_text is Dictionary:
			item.setup(option_text, min_height)
		else:
			item.setup(clean_text, min_height)
		item.option_selected.connect(on_selected.bind(index))
