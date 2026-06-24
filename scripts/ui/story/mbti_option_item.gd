class_name MBTIOptionItem
extends Button

signal selected(mbti_id: String, mbti_name: String)

var _mbti_id: String = ""
var _mbti_name: String = ""
var _mbti_desc: String = ""
var _normal_style: StyleBoxFlat
var _hover_style: StyleBoxFlat
var _selected_style: StyleBoxFlat

@onready var mbti_label: Label = $MBTIMargin/MBTIContainer/MBTI
@onready var info_label: Label = $MBTIMargin/MBTIContainer/Info

func _ready() -> void:
	_cache_styles()
	pressed.connect(_on_pressed)
	_refresh_text()
	set_selected_state(false)

func setup_item(mbti_id: String, mbti_name: String, mbti_desc: String) -> void:
	_mbti_id = mbti_id
	_mbti_name = mbti_name
	_mbti_desc = mbti_desc
	_refresh_text()

func get_mbti_id() -> String:
	return _mbti_id

func set_selected_state(is_selected: bool) -> void:
	if _normal_style == null or _hover_style == null or _selected_style == null:
		_cache_styles()
	var normal_style: StyleBoxFlat = _selected_style if is_selected else _normal_style
	var hover_style: StyleBoxFlat = _selected_style if is_selected else _hover_style
	add_theme_stylebox_override("normal", normal_style)
	add_theme_stylebox_override("hover", hover_style)
	add_theme_stylebox_override("pressed", _selected_style)
	add_theme_stylebox_override("focus", normal_style)

func _cache_styles() -> void:
	if _normal_style == null:
		_normal_style = _duplicate_stylebox(get_theme_stylebox("normal"))
	if _hover_style == null:
		_hover_style = _duplicate_stylebox(get_theme_stylebox("hover"))
	if _selected_style == null:
		_selected_style = _duplicate_stylebox(get_theme_stylebox("pressed"))

func _duplicate_stylebox(stylebox: StyleBox) -> StyleBoxFlat:
	if stylebox is StyleBoxFlat:
		return (stylebox as StyleBoxFlat).duplicate() as StyleBoxFlat
	return StyleBoxFlat.new()

func _refresh_text() -> void:
	if _mbti_id == "":
		text = ""
		mbti_label.text = ""
		info_label.text = ""
		return
	text = ""
	mbti_label.text = "%s (%s)" % [_mbti_id, _mbti_name]
	info_label.text = _mbti_desc

func _on_pressed() -> void:
	selected.emit(_mbti_id, _mbti_name)
