extends SceneTree

const WindowScene = preload("res://addons/story_editor/ui/story_node_template_library_window.tscn")
const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")
const PATH := "user://story_node_template_library_window_smoke.json"

var failures: Array[String] = []
var request: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	JsonService.save_dictionary(PATH, {"schema_version": 2, "templates": [{"id": "hello", "name": "问候", "kind": "event", "description": "参数化对白", "parameters": [{"name": "speaker", "required": true, "default": "jing"}], "payload": {"events": [{"type": "dialogue", "speaker": {"$param": "speaker"}, "content": "你好"}]}}]})
	var window := WindowScene.instantiate()
	root.add_child(window)
	window.instantiate_requested.connect(_capture_request)
	await process_frame
	window.open_library({"chapters": {"start": {"events": []}}}, PATH)
	await process_frame
	var list := window.get_node("Root/Body/TemplateList") as ItemList
	_expect(window.visible and not window.wrap_controls, "节点模板库未作为独立窗口显示。")
	_expect(list.item_count == 1, "v2 项目模板未加载到列表。")
	list.select(0)
	window.call("_on_template_selected", 0)
	var parameters := window.get_node("Root/Body/Details/ParametersEdit") as TextEdit
	_expect(parameters.text.contains("jing"), "参数默认值未填入。")
	window.call("_request_insert")
	_expect(request.get("template", {}).get("id", "") == "hello" and request.get("parameters", {}).get("speaker", "") == "jing", "窗口未发出准确的实例化请求。")
	window.queue_free()
	if FileAccess.file_exists(PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	if failures.is_empty(): print("STORY_NODE_TEMPLATE_LIBRARY_WINDOW_SMOKE_OK"); quit(0); return
	for failure in failures: push_error("STORY_NODE_TEMPLATE_LIBRARY_WINDOW_SMOKE: %s" % failure)
	quit(1)

func _capture_request(template: Dictionary, parameters: Dictionary) -> void:
	request = {"template": template, "parameters": parameters}

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)