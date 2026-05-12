extends Node

const SAVE_PATH = "user://data/moments_data.json"

var moments_data: Array = []

func _ready() -> void:
	load_data()
	call_deferred("_connect_signals")

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
	add_moment(author, moment_data.get("date", Time.get_date_string_from_system()), moment_data.get("content", ""), images, 0, false, [], avatar)

func _on_ai_reply_generated(post_id: String, reply_text: String) -> void:
	var moment_data = get_moment(post_id)
	if not moment_data.is_empty():
		var author = moment_data.get("author", "未知")
		add_comment(post_id, author, reply_text)


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_create_default_data()
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
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
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("data"):
		dir.make_dir("data")
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(moments_data, "\t"))
		file.close()
	else:
		push_error("Failed to save moments data")

func _create_default_data() -> void:
	moments_data = []
	save_data()

func get_all_moments() -> Array:
	return moments_data

func get_moment(id: String) -> Dictionary:
	for moment in moments_data:
		if moment.get("id") == id:
			return moment
	return {}

func add_moment(author: String, time: String, content: String, images: Array = [], likes: int = 0, is_liked: bool = false, comments: Array = [], avatar: String = "") -> void:
	var moment = {
		"id": str(Time.get_unix_time_from_system()) + "_" + str(randi() % 1000),
		"author": author,
		"avatar": avatar,
		"time": time,
		"content": content,
		"images": images,
		"likes": likes,
		"is_liked": is_liked,
		"comments": comments
	}
	moments_data.push_front(moment)
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

func add_comment(moment_id: String, author: String, content: String) -> void:
	for i in range(moments_data.size()):
		if moments_data[i].get("id") == moment_id:
			var comments = moments_data[i].get("comments", [])
			comments.append({
				"author": author,
				"content": content
			})
			moments_data[i]["comments"] = comments
			save_data()
			break
