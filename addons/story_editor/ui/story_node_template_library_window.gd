@tool
extends Window

signal instantiate_requested(template: Dictionary, parameters: Dictionary)

const Service = preload("res://addons/story_editor/core/story_event_template_service.gd")
const Instantiator = preload("res://addons/story_editor/core/story_node_template_instantiator.gd")
const WINDOW_LAYOUT_PATH := "res://addons/story_editor/core/editor_window_layout.gd"

var library_path := Service.DEFAULT_PATH
var current_data: Dictionary = {}
var templates: Array[Dictionary] = []
var selected_template: Dictionary = {}

func _ready() -> void:
	close_requested.connect(hide)
	%RefreshButton.pressed.connect(refresh_library)
	%SearchEdit.text_changed.connect(_populate_list)
	%KindFilter.item_selected.connect(_on_filter_changed)
	%TemplateList.item_selected.connect(_on_template_selected)
	%InsertButton.pressed.connect(_request_insert)
	%RenameButton.pressed.connect(_rename_selected)
	%DeleteButton.pressed.connect(_delete_selected)
	for kind in ["全部类型", "event", "fragment", "choice_branch", "chapter"]:
		%KindFilter.add_item(kind)

func open_library(data: Dictionary, path: String = Service.DEFAULT_PATH) -> void:
	current_data = data
	library_path = path
	(load(WINDOW_LAYOUT_PATH) as GDScript).new().open_window(self, Vector2i(1040, 680), Vector2i(760, 520))
	refresh_library()

func refresh_library() -> void:
	var result := Service.load_templates(library_path)
	templates.clear()
	if result.get("ok", false):
		templates.assign(result.get("templates", []))
		%Status.text = "%d 个项目模板" % templates.size()
	else:
		%Status.text = str(result.get("error", "模板加载失败。"))
	_populate_list(%SearchEdit.text)

func _populate_list(query: String = "") -> void:
	%TemplateList.clear()
	var kind: String = "" if %KindFilter.selected <= 0 else %KindFilter.get_item_text(%KindFilter.selected)
	for template in templates:
		if not kind.is_empty() and str(template.get("kind", "fragment")) != kind:
			continue
		var search_text := "%s %s %s" % [template.get("name", ""), template.get("description", ""), template.get("kind", "")]
		if not query.strip_edges().is_empty() and not search_text.to_lower().contains(query.to_lower()):
			continue
		%TemplateList.add_item("%s  ·  %s" % [str(template.get("name", "未命名")), str(template.get("kind", "fragment"))])
		%TemplateList.set_item_metadata(%TemplateList.item_count - 1, template)
	_clear_selection()

func _on_filter_changed(_index: int) -> void:
	_populate_list(%SearchEdit.text)

func _on_template_selected(index: int) -> void:
	selected_template = %TemplateList.get_item_metadata(index) as Dictionary
	%TemplateName.text = str(selected_template.get("name", "未命名模板"))
	%Description.text = str(selected_template.get("description", ""))
	%PayloadPreview.text = JSON.stringify(selected_template.get("payload", {}), "  ")
	var defaults := {}
	for definition in selected_template.get("parameters", []):
		if definition is Dictionary:
			defaults[str(definition.get("name", ""))] = definition.get("default", null)
	%ParametersEdit.text = JSON.stringify(defaults, "  ")
	%RenameEdit.text = str(selected_template.get("name", ""))
	%InsertButton.disabled = false
	%RenameButton.disabled = false
	%DeleteButton.disabled = false

func _request_insert() -> void:
	var parameters: Variant = JSON.parse_string(%ParametersEdit.text)
	if not parameters is Dictionary:
		%Status.text = "参数必须是 JSON 对象。"
		return
	var preview := Instantiator.instantiate_template(selected_template, parameters, current_data)
	if not preview.get("ok", false):
		%Status.text = str((preview.get("diagnostics", [{}]) as Array)[0].get("message", "模板参数无效。"))
		return
	instantiate_requested.emit(selected_template, parameters)
	%Status.text = "已请求插入“%s”。" % str(selected_template.get("name", "模板"))

func _rename_selected() -> void:
	var result := Service.rename_template(str(selected_template.get("id", "")), %RenameEdit.text, library_path)
	%Status.text = "模板已重命名。" if result.get("ok", false) else str(result.get("error", "重命名失败。"))
	if result.get("ok", false): refresh_library()

func _delete_selected() -> void:
	var result := Service.delete_template(str(selected_template.get("id", "")), library_path)
	%Status.text = "模板已删除。" if result.get("ok", false) else str(result.get("error", "删除失败。"))
	if result.get("ok", false): refresh_library()

func _clear_selection() -> void:
	selected_template.clear()
	%TemplateName.text = "选择模板"
	%Description.text = ""
	%PayloadPreview.text = ""
	%ParametersEdit.text = "{}"
	%InsertButton.disabled = true
	%RenameButton.disabled = true
	%DeleteButton.disabled = true