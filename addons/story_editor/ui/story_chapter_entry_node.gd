@tool
extends GraphNode

signal chapter_activated(chapter_id: String)

const BRANCH_COLOR := Color("#58c99b")

var chapter_id := ""
var initial_position := Vector2.ZERO


func setup(next_chapter_id: String, position: Vector2) -> void:
	chapter_id = next_chapter_id
	initial_position = position
	name = node_name_for(chapter_id)
	if is_node_ready():
		_apply_setup()


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	_apply_setup()


func _apply_setup() -> void:
	title = "剧情结束" if chapter_id == "end" else "章节入口"
	%ChapterLabel.text = chapter_id
	position_offset = initial_position
	set_slot(0, true, 1, BRANCH_COLOR, false, 0, Color.WHITE)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		chapter_activated.emit(chapter_id)


static func node_name_for(next_chapter_id: String) -> String:
	return "chapter_entry_%s" % next_chapter_id.validate_node_name()