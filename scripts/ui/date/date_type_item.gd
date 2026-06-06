extends VBoxContainer

@onready var header_btn = $HeaderButton
@onready var icon_rect = $HeaderButton/ContentHBox/IconRect
@onready var title_label = $HeaderButton/ContentHBox/TitleLabel
@onready var location_list = $LocationList

const TYPE_ICON_PATHS := {
	"stroll": "res://assets/images/icons/ui/date/stroll.svg",
	"shopping": "res://assets/images/icons/ui/date/shopping.svg",
	"exhibition": "res://assets/images/icons/ui/date/exhibition.svg",
	"dining": "res://assets/images/icons/ui/date/dining.svg",
	"real_photo": "res://assets/images/icons/ui/story/camera.svg"
}

var _type_id: String = ""
var _title: String = ""

func set_type_info(type_id: String, title: String) -> void:
	_type_id = type_id
	_title = title
	_sync_header()

func _ready() -> void:
	header_btn.pressed.connect(_on_header_pressed)
	_sync_header()

func _on_header_pressed() -> void:
	location_list.visible = not location_list.visible

func add_location_node(node: Node) -> void:
	location_list.add_child(node)

func _sync_header() -> void:
	if title_label:
		title_label.text = _title
	if icon_rect:
		icon_rect.texture = null
		var icon_path := str(TYPE_ICON_PATHS.get(_type_id, ""))
		if icon_path != "" and ResourceLoader.exists(icon_path):
			icon_rect.texture = load(icon_path)
