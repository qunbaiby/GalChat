extends VBoxContainer

@onready var header_btn = $HeaderButton
@onready var location_list = $LocationList

func set_title(title: String) -> void:
	if header_btn:
		header_btn.text = title

func _ready() -> void:
	header_btn.pressed.connect(_on_header_pressed)

func _on_header_pressed() -> void:
	location_list.visible = not location_list.visible

func add_location_node(node: Node) -> void:
	location_list.add_child(node)
