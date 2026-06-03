extends Node

const LEGACY_SAVE_PATH = "user://data/moments_data.json"
const PhotoMemoryManagerScript = preload("res://scripts/data/photo_memory_manager.gd")

var moments_data: Array = []
signal moments_updated

func _ready() -> void:
	call_deferred("reload_for_current_character")
	call_deferred("_connect_signals")

func _get_current_char_id() -> String:
	if GameDataManager.profile and str(GameDataManager.profile.current_character_id) != "":
		return str(GameDataManager.profile.current_character_id)
	if GameDataManager.config and str(GameDataManager.config.current_character_id) != "":
		return str(GameDataManager.config.current_character_id)
	return "default"

func _get_save_path(char_id: String = "") -> String:
	var final_char_id = char_id.strip_edges()
	if final_char_id == "":
		final_char_id = _get_current_char_id()
	return "user://saves/%s/moments_data.json" % final_char_id

func reload_for_current_character(char_id: String = "") -> void:
	load_data(char_id)

func _connect_signals() -> void:
	var deepseek_client = _get_deepseek_client()
	if deepseek_client:
		if deepseek_client.has_signal("moment_reply_generated") and not deepseek_client.moment_reply_generated.is_connected(_on_ai_reply_generated):
			deepseek_client.moment_reply_generated.connect(_on_ai_reply_generated)
		if deepseek_client.has_signal("moment_generated") and not deepseek_client.moment_generated.is_connected(_on_ai_moment_generated):
			deepseek_client.moment_generated.connect(_on_ai_moment_generated)

func _get_deepseek_client() -> Node:
	var llm_manager = get_node_or_null("/root/LLMManager")
	if llm_manager and llm_manager.has("deepseek_client"):
		return llm_manager.deepseek_client
	if get_tree().current_scene and get_tree().current_scene.has_node("DeepSeekClient"):
		return get_tree().current_scene.get_node("DeepSeekClient")
	if get_node_or_null("/root/DeepSeekClient"):
		return get_node("/root/DeepSeekClient")
	if get_tree().root.has_node("MainScene/DeepSeekClient"):
		return get_node("/root/MainScene/DeepSeekClient")
	return null

func _process(delta: float) -> void:
	# Try connecting periodically if not connected yet
	_connect_signals()

func _on_ai_moment_generated(moment_data: Dictionary) -> void:
	var author = moment_data.get("author", "AI")
	var avatar = moment_data.get("avatar", "")
	var images = []
	if moment_data.has("image_url") and not moment_data["image_url"].is_empty():
		images.append(moment_data["image_url"])
	add_moment(author, moment_data.get("date", Time.get_date_string_from_system()), moment_data.get("content", ""), images, 0, false, [], avatar, true)
	if GameDataManager.save_manager and GameDataManager.save_manager.has_method("auto_save"):
		GameDataManager.save_manager.call_deferred("auto_save")

func _on_ai_reply_generated(post_id: String, reply_text: String) -> void:
	var moment_data = get_moment(post_id)
	if not moment_data.is_empty():
		var author = moment_data.get("author", "未知")
		add_comment(post_id, author, reply_text, true)
		if GameDataManager.save_manager and GameDataManager.save_manager.has_method("auto_save"):
			GameDataManager.save_manager.call_deferred("auto_save")


func load_data(char_id: String = "") -> void:
	moments_data = []
	var save_path = _get_save_path(char_id)
	_migrate_legacy_data_if_needed(save_path)
	if not FileAccess.file_exists(save_path):
		_create_default_data()
		return
		
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(content)
		if error == OK:
			if typeof(json.data) == TYPE_ARRAY:
				moments_data = json.data
			else:
				push_error("Moments data is not an array")
				_create_default_data()
		else:
			push_error("Failed to parse moments data: ", json.get_error_message())
			_create_default_data()

func save_data() -> void:
	var save_path = _get_save_path()
	var save_dir = save_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)
		
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(moments_data, "\t"))
		file.close()
		moments_updated.emit()
	else:
		push_error("Failed to save moments data")

func _create_default_data() -> void:
	moments_data = []
	save_data()

func _migrate_legacy_data_if_needed(save_path: String) -> void:
	if FileAccess.file_exists(save_path) or not FileAccess.file_exists(LEGACY_SAVE_PATH):
		return
	var legacy_file = FileAccess.open(LEGACY_SAVE_PATH, FileAccess.READ)
	if legacy_file == null:
		return
	var legacy_content = legacy_file.get_as_text()
	legacy_file.close()
	var json = JSON.new()
	if json.parse(legacy_content) != OK or not json.data is Array:
		return
	var save_dir = save_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)
	var target_file = FileAccess.open(save_path, FileAccess.WRITE)
	if target_file:
		target_file.store_string(JSON.stringify(json.data, "\t"))
		target_file.close()

func get_all_moments() -> Array:
	return moments_data

func get_moment(id: String) -> Dictionary:
	for moment in moments_data:
		if moment.get("id") == id:
			return moment
	return {}

func add_moment(author: String, time: String, content: String, images: Array = [], likes: int = 0, is_liked: bool = false, comments: Array = [], avatar: String = "", is_unread: bool = false) -> void:
	var moment = {
		"id": str(Time.get_unix_time_from_system()) + "_" + str(randi() % 1000),
		"author": author,
		"avatar": avatar,
		"time": time,
		"content": content,
		"images": images,
		"likes": likes,
		"is_liked": is_liked,
		"comments": comments,
		"is_unread": is_unread
	}
	moments_data.push_front(moment)
	_register_moment_images(moment)
	save_data()

func toggle_like(id: String) -> void:
	for i in range(moments_data.size()):
		if moments_data[i].get("id") == id:
			moments_data[i]["is_liked"] = not moments_data[i].get("is_liked", false)
			if moments_data[i]["is_liked"]:
				moments_data[i]["likes"] = moments_data[i].get("likes", 0) + 1
			else:
				moments_data[i]["likes"] = max(0, moments_data[i].get("likes", 0) - 1)
			save_data()
			break

func add_comment(moment_id: String, author: String, content: String, is_unread: bool = false) -> void:
	for i in range(moments_data.size()):
		if moments_data[i].get("id") == moment_id:
			var comments = moments_data[i].get("comments", [])
			comments.append({
				"author": author,
				"content": content,
				"time": Time.get_datetime_string_from_system(),
				"is_unread": is_unread
			})
			moments_data[i]["comments"] = comments
			save_data()
			break

func get_unread_moments_count() -> int:
	var count = 0
	for moment in moments_data:
		if moment.get("is_unread", false):
			count += 1
		for comment in moment.get("comments", []):
			if comment.get("is_unread", false):
				count += 1
	return count

func mark_all_read() -> void:
	var has_changed = false
	for i in range(moments_data.size()):
		if moments_data[i].get("is_unread", false):
			moments_data[i]["is_unread"] = false
			has_changed = true
		var comments = moments_data[i].get("comments", [])
		for j in range(comments.size()):
			if comments[j].get("is_unread", false):
				comments[j]["is_unread"] = false
				has_changed = true
		moments_data[i]["comments"] = comments
	if has_changed:
		save_data()

func _register_moment_images(moment: Dictionary) -> void:
	var images = moment.get("images", [])
	if not images is Array or images.is_empty():
		return
	var photo_manager = PhotoMemoryManagerScript.new()
	var context = GameDataManager.memory_manager.build_story_memory_context() if GameDataManager.memory_manager else {}
	context["context_domain"] = "story"
	if str(moment.get("time", "")).strip_edges() != "":
		context["story_time"] = str(moment.get("time", ""))
	var current_char_id = ""
	if GameDataManager.profile and str(GameDataManager.profile.current_character_id) != "":
		current_char_id = str(GameDataManager.profile.current_character_id)
	for image_path in images:
		if typeof(image_path) != TYPE_STRING:
			continue
		var final_path = str(image_path).strip_edges()
		if final_path == "":
			continue
		if GameDataManager.config and str(GameDataManager.config.default_image_path) == final_path:
			continue
		photo_manager.register_photo(final_path, "moment_image", {
			"album_category": "moment",
			"memory_context": context,
			"preferred_layers": ["bond", "emotion"],
			"source_title": "她分享过的瞬间",
			"source_text": str(moment.get("content", "")),
			"source_id": str(moment.get("id", "")),
			"source_char_id": current_char_id
		})
