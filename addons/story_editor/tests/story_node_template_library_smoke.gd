extends SceneTree

const Service = preload("res://addons/story_editor/core/story_event_template_service.gd")
const Instantiator = preload("res://addons/story_editor/core/story_node_template_instantiator.gd")
const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")
const PATH := "user://story_node_template_library_smoke.json"

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	JsonService.save_dictionary(PATH, {"schema_version": 1, "templates": [{"id": "legacy", "name": "旧模板", "events": [{"type": "dialogue", "content": "旧"}], "unknown": 7}]})
	var legacy := Service.load_templates(PATH)
	_expect(legacy.ok and legacy.templates[0].kind == "event" and legacy.templates[0].unknown == 7, "v1 模板未兼容归一化或未知字段丢失。")
	var template := {"id": "branch", "name": "分支模板", "kind": "choice_branch", "parameters": [{"name": "speaker", "required": true}], "payload": {"entry_events": [{"type": "dialogue", "speaker": {"$param": "speaker"}, "content": "你好 ${speaker}", "event_id": "opening"}, {"type": "choice", "options": [{"id": "accept", "text": "接受", "target_chapter": {"$chapter": "accept"}}, {"id": "accept", "text": "再选", "target_chapter": {"$chapter": "accept"}}]}], "chapters": {"accept": {"events": [{"type": "jump", "target_chapter": "end"}]}}}, "unknown": {"keep": true}}
	_expect(not Instantiator.instantiate_template(template, {}, {"chapters": {}}).ok, "必填参数缺失未被拒绝。")
	var data := {"chapters": {"start": {"events": [{"type": "dialogue", "event_id": "opening"}]}, "branch_accept": {"events": []}}}
	var result := Instantiator.instantiate_template(template, {"speaker": "jing"}, data, Vector2(100, 50))
	_expect(result.ok and result.events.size() == 2 and result.chapters.has("branch_accept_2"), "分支章节未唯一实例化。")
	_expect(result.events[0].speaker == "jing" and result.events[0].content == "你好 jing" and result.events[0].event_id != "opening", "参数或事件 ID 未实例化。")
	_expect(result.events[1].options[0].target_chapter == "branch_accept_2" and result.events[1].options[0].id != result.events[1].options[1].id, "章节引用或 Choice ID 未重写。")
	_expect(result.events[0]._editor_position == {"x": 100.0, "y": 50.0}, "相对布局未平移。")
	var save := Service.save_template(template, PATH)
	_expect(save.ok and int((JsonService.load_dictionary(PATH).data as Dictionary).schema_version) == 2, "v2 模板未原子保存。")
	if FileAccess.file_exists(PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	if failures.is_empty(): print("STORY_NODE_TEMPLATE_LIBRARY_SMOKE_OK"); quit(0); return
	for failure in failures: push_error("STORY_NODE_TEMPLATE_LIBRARY_SMOKE: %s" % failure)
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)