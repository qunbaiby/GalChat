extends SceneTree

const Service = preload("res://addons/story_editor/core/story_content_creation_service.gd")
const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var root := "user://story_creation_smoke"
	var roots := {"main_story": root.path_join("main"), "map_story": root.path_join("events"), "mobile_chat": root.path_join("chats")}
	var calls_path := root.path_join("fixed_calls.json")
	JsonService.save_array(calls_path, [])
	var main := Service.create("main_story", "new_main", {"name": "新主线"}, roots, calls_path)
	var map_story := Service.create("map_story", "new_map", {}, roots, calls_path)
	var chat := Service.create("mobile_chat", "new_chat", {"character_id": "jing"}, roots, calls_path)
	var call := Service.create("fixed_call", "new_call", {"character_id": "jing"}, roots, calls_path)
	_expect(main.ok and map_story.ok and chat.ok and call.ok, "四类固定内容未全部创建成功。")
	_expect((JsonService.load_dictionary(main.path).data as Dictionary).chapters.has("start"), "新剧情缺少 start 章节。")
	_expect((JsonService.load_dictionary(chat.path).data as Dictionary).messages.size() == 1, "新手机消息缺少初始消息。")
	_expect((JsonService.load_array(calls_path).data as Array).size() == 1, "新固定来电未追加到共享数组。")
	_expect(not Service.create("main_story", "new_main", {}, roots, calls_path).ok, "重复剧情 ID 覆盖了原文件。")
	_expect(not Service.create("mobile_chat", "bad id", {"character_id": "jing"}, roots, calls_path).ok, "非法 ID 未被拒绝。")
	_expect(not Service.create("fixed_call", "missing_character", {}, roots, calls_path).ok, "缺少角色 ID 的固定来电未被拒绝。")
	_remove_tree(ProjectSettings.globalize_path(root))
	if failures.is_empty(): print("STORY_CONTENT_CREATION_SMOKE_OK"); quit(0); return
	for failure in failures: push_error("STORY_CONTENT_CREATION_SMOKE: %s" % failure)
	quit(1)

func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path): return
	var directory := DirAccess.open(path)
	for entry in directory.get_files(): DirAccess.remove_absolute(path.path_join(entry))
	for child in directory.get_directories(): _remove_tree(path.path_join(child))
	DirAccess.remove_absolute(path)

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)