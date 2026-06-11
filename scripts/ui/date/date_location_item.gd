extends MarginContainer

signal add_requested(loc_id: String, loc_name: String, type_id: String)

@onready var add_btn = %AddButton
@onready var thumb_container: Control = $BgPanel/ContentMargin/HBox/ThumbContainer
@onready var thumb_rect = %ThumbRect
@onready var name_lbl = %NameLabel
@onready var desc_lbl = %DescLabel

var _loc_id: String = ""
var _loc_name: String = ""
var _type_id: String = ""

func setup(loc_id: String, loc_name: String, type_id: String = "") -> void:
	_loc_id = loc_id
	_loc_name = loc_name
	_type_id = type_id
	_sync_ui()
	
	if _loc_id.begins_with("custom_"):
		if thumb_container:
			thumb_container.hide()
		if name_lbl:
			name_lbl.add_theme_color_override("font_color", Color(0.96, 0.35, 0.49)) # 粉色特殊高亮
		if desc_lbl:
			desc_lbl.text = "上传一张现实照片，作为独立的现实世界约会场景。"
		if thumb_rect:
			thumb_rect.texture = null
	else:
		if thumb_container:
			thumb_container.show()
		if MapDataManager.has_method("get_location"):
			var loc_data = MapDataManager.get_location(_loc_id)
			if desc_lbl:
				desc_lbl.text = loc_data.get("description", "暂无描述")
			
			var bg_id = loc_data.get("bg_id", "")
			var real_path = ""
			if not bg_id.is_empty():
				if ImageManager.has_method("get_image_path"):
					real_path = ImageManager.get_image_path(bg_id)
				if real_path.is_empty():
					real_path = bg_id
			if not real_path.is_empty() and ResourceLoader.exists(real_path):
				thumb_rect.texture = load(real_path)
			else:
				thumb_rect.texture = null

func _ready() -> void:
	add_btn.pressed.connect(_on_add_pressed)
	_sync_ui()

func _on_add_pressed() -> void:
	add_requested.emit(_loc_id, _loc_name, _type_id)

func _sync_ui() -> void:
	if name_lbl:
		name_lbl.text = _loc_name
