extends PanelContainer

@onready var name_label: Label = $NameLabel
@onready var check_mark: Label = $CheckMark
@onready var icon_rect: TextureRect = $IconPlate/IconRect
@onready var icon_plate: PanelContainer = $IconPlate
@onready var accent_bar: ColorRect = $AccentBar
@onready var event_badge: PanelContainer = $EventBadge

const STATE_PENDING := "pending"
const STATE_CURRENT := "current"
const STATE_COMPLETED := "completed"
const MAIN_STORY_ICON_PATH := "res://assets/images/icons/ui/main/diary_book.svg"

var _pending_style: StyleBoxFlat
var _current_style: StyleBoxFlat
var _completed_style: StyleBoxFlat
var _current_state: String = STATE_PENDING
var _has_story_badge: bool = false

func _ready() -> void:
	_pending_style = get_theme_stylebox("panel").duplicate() as StyleBoxFlat

	_current_style = _pending_style.duplicate()
	_current_style.bg_color = Color(0.97, 0.99, 1.0, 1)
	_current_style.border_color = Color(0.44, 0.67, 0.95, 0.95)
	_current_style.border_width_left = 2
	_current_style.border_width_top = 2
	_current_style.border_width_right = 2
	_current_style.border_width_bottom = 2
	_current_style.shadow_color = Color(0.2, 0.42, 0.82, 0.18)
	_current_style.shadow_size = 10

	_completed_style = _pending_style.duplicate()
	_completed_style.bg_color = Color(0.94, 0.98, 0.97, 1)
	_completed_style.border_color = Color(0.57, 0.82, 0.76, 0.85)
	_completed_style.border_width_left = 2
	_completed_style.border_width_top = 2
	_completed_style.border_width_right = 2
	_completed_style.border_width_bottom = 2

	if icon_plate:
		var icon_plate_style := StyleBoxFlat.new()
		icon_plate_style.bg_color = Color(0.92, 0.95, 0.98, 0.96)
		icon_plate_style.border_width_left = 1
		icon_plate_style.border_width_top = 1
		icon_plate_style.border_width_right = 1
		icon_plate_style.border_width_bottom = 1
		icon_plate_style.border_color = Color(0.78, 0.84, 0.9, 0.92)
		icon_plate_style.corner_radius_top_left = 14
		icon_plate_style.corner_radius_top_right = 14
		icon_plate_style.corner_radius_bottom_left = 14
		icon_plate_style.corner_radius_bottom_right = 14
		icon_plate_style.shadow_color = Color(0.08, 0.12, 0.18, 0.12)
		icon_plate_style.shadow_size = 6
		icon_plate.add_theme_stylebox_override("panel", icon_plate_style)
	if event_badge:
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color(0.89, 0.58, 0.73, 0.96)
		badge_style.corner_radius_top_left = 9
		badge_style.corner_radius_top_right = 9
		badge_style.corner_radius_bottom_left = 9
		badge_style.corner_radius_bottom_right = 9
		event_badge.add_theme_stylebox_override("panel", badge_style)
	_apply_state_style()

func setup(slot_name: String, course_data: Dictionary = {}) -> void:
	name_label.text = slot_name
	_apply_course_visual(course_data)

func _apply_course_visual(course_data: Dictionary) -> void:
	if icon_rect == null or event_badge == null:
		return

	var is_story_event: bool = bool(course_data.get("is_event", false)) or str(course_data.get("script_path", "")).strip_edges() != ""
	var icon_path: String = str(course_data.get("icon_path", ""))
	if is_story_event and icon_path == "":
		icon_path = MAIN_STORY_ICON_PATH

	var icon_texture: Texture2D = null
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var loaded_icon: Resource = load(icon_path)
		if loaded_icon is Texture2D:
			icon_texture = loaded_icon as Texture2D

	_has_story_badge = is_story_event
	icon_rect.texture = icon_texture
	icon_rect.visible = icon_texture != null
	event_badge.visible = is_story_event
	_apply_state_style()

func set_state(state: String) -> void:
	_current_state = state
	if not is_node_ready():
		return
	_apply_state_style()

func set_completed(completed: bool) -> void:
	set_state(STATE_COMPLETED if completed else STATE_PENDING)

func _apply_state_style() -> void:
	if not is_node_ready():
		return

	match _current_state:
		STATE_CURRENT:
			add_theme_stylebox_override("panel", _current_style)
			name_label.add_theme_color_override("font_color", Color(0.17, 0.31, 0.54, 1))
			check_mark.visible = false
			if accent_bar:
				accent_bar.color = Color(0.43, 0.68, 0.98, 1)
			if icon_plate:
				icon_plate.modulate = Color(1, 1, 1, 1)
			if icon_rect and icon_rect.visible:
				icon_rect.modulate = Color(1, 1, 1, 1)
		STATE_COMPLETED:
			add_theme_stylebox_override("panel", _completed_style)
			name_label.add_theme_color_override("font_color", Color(0.18, 0.34, 0.31, 1))
			check_mark.visible = true
			if accent_bar:
				accent_bar.color = Color(0.57, 0.82, 0.76, 1)
			if icon_plate:
				icon_plate.modulate = Color(0.97, 1, 0.99, 1)
			if icon_rect and icon_rect.visible:
				icon_rect.modulate = Color(1, 1, 1, 0.96)
		_:
			add_theme_stylebox_override("panel", _pending_style)
			name_label.add_theme_color_override("font_color", Color(0.42, 0.48, 0.52, 1))
			check_mark.visible = false
			if accent_bar:
				accent_bar.color = Color(0.7, 0.75, 0.82, 0.0)
			if icon_plate:
				icon_plate.modulate = Color(0.96, 0.97, 1, 0.92)
			if icon_rect and icon_rect.visible:
				icon_rect.modulate = Color(1, 1, 1, 0.88)

	if event_badge:
		event_badge.visible = _has_story_badge
		event_badge.modulate = Color(1, 1, 1, 1.0 if _current_state != STATE_PENDING else 0.88)
