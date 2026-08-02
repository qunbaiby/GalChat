extends Button

signal option_selected(text: String)

const DEFAULT_ICON_PATH := "res://assets/images/icons/ui/system/chat.svg"
const PRESENTATION_TOPIC := "topic"
const PRESENTATION_AI_REPLY := "ai_reply"
const KIND_STYLE := {
	"default": {
		"accent_color": Color(0.82, 0.88, 0.96, 1.0),
		"icon_bg": Color(0.09, 0.12, 0.18, 0.92)
	},
	"intimacy": {
		"accent_color": Color(0.98, 0.68, 0.8, 1.0),
		"icon_bg": Color(0.22, 0.1, 0.18, 0.94)
	},
	"trust": {
		"accent_color": Color(0.63, 0.82, 0.99, 1.0),
		"icon_bg": Color(0.08, 0.16, 0.25, 0.94)
	},
	"study": {
		"accent_color": Color(0.69, 0.95, 0.83, 1.0),
		"icon_bg": Color(0.08, 0.18, 0.16, 0.94)
	},
	"life": {
		"accent_color": Color(0.88, 0.9, 0.99, 1.0),
		"icon_bg": Color(0.1, 0.13, 0.23, 0.94)
	},
	"emotion": {
		"accent_color": Color(1.0, 0.74, 0.82, 1.0),
		"icon_bg": Color(0.22, 0.1, 0.18, 0.94)
	}
}

@onready var icon_panel: PanelContainer = $HBox/IconPanel
@onready var icon_rect: TextureRect = $HBox/IconPanel/IconRect
@onready var accent_bar: ColorRect = $HBox/AccentBar
@onready var divider: ColorRect = $HBox/Divider
@onready var primary_label: Label = $HBox/TextVBox/PrimaryLabel

@export var ai_reply_normal_style: StyleBoxFlat
@export var ai_reply_hover_style: StyleBoxFlat

var _option_text: String = ""
var _option_kind: String = "default"
var _presentation_mode: String = PRESENTATION_TOPIC

func _ready() -> void:
	pressed.connect(_on_pressed)

func setup(option_data: Variant, presentation_mode: String = PRESENTATION_TOPIC) -> void:
	var final_primary := ""
	var final_kind := "default"
	var final_icon_path := DEFAULT_ICON_PATH

	if option_data is Dictionary:
		var data := option_data as Dictionary
		final_primary = _pick_first_non_empty(data, ["text", "content", "label", "summary"])
		final_kind = str(data.get("kind", "default")).strip_edges()
		final_icon_path = str(data.get("icon_path", DEFAULT_ICON_PATH)).strip_edges()
	else:
		final_primary = str(option_data).strip_edges()

	if final_primary == "":
		final_primary = "..."

	_option_text = final_primary
	_option_kind = final_kind
	_presentation_mode = presentation_mode
	if primary_label:
		primary_label.text = final_primary
	_apply_kind_style(final_kind, final_icon_path)
	_apply_presentation_mode()

func _pick_first_non_empty(data: Dictionary, keys: Array[String]) -> String:
	for key in keys:
		var value := str(data.get(key, "")).strip_edges()
		if value != "":
			return value
	return ""

func _apply_kind_style(kind: String, icon_path: String) -> void:
	var style: Dictionary = KIND_STYLE.get(kind, KIND_STYLE["default"])
	var accent: Color = style.get("accent_color", Color(0.82, 0.88, 0.96, 1.0))
	if primary_label:
		primary_label.add_theme_color_override("font_color", accent)
	if accent_bar:
		accent_bar.color = accent
	if icon_panel:
		var panel_style := icon_panel.get_theme_stylebox("panel")
		if panel_style is StyleBoxFlat:
			var stylebox := (panel_style as StyleBoxFlat).duplicate()
			stylebox.bg_color = style.get("icon_bg", Color(0.09, 0.12, 0.18, 0.92))
			icon_panel.add_theme_stylebox_override("panel", stylebox)
	if icon_rect:
		var texture: Texture2D = null
		if icon_path != "" and ResourceLoader.exists(icon_path):
			texture = load(icon_path) as Texture2D
		if texture == null and ResourceLoader.exists(DEFAULT_ICON_PATH):
			texture = load(DEFAULT_ICON_PATH) as Texture2D
		icon_rect.texture = texture

func _apply_presentation_mode() -> void:
	var is_ai_reply := _presentation_mode == PRESENTATION_AI_REPLY
	if is_ai_reply:
		custom_minimum_size = Vector2(0.0, 54.0)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if ai_reply_normal_style:
			add_theme_stylebox_override("normal", ai_reply_normal_style)
		if ai_reply_hover_style:
			add_theme_stylebox_override("hover", ai_reply_hover_style)
			add_theme_stylebox_override("pressed", ai_reply_hover_style)
		if primary_label:
			primary_label.add_theme_color_override("font_color", Color(0.91, 0.94, 0.95, 1.0))
			primary_label.add_theme_font_size_override("font_size", 16)
		icon_panel.hide()
		divider.hide()
		accent_bar.show()
		return
	custom_minimum_size = Vector2(450.0, 58.0)
	icon_panel.show()
	divider.show()
	accent_bar.hide()

func _on_pressed() -> void:
	option_selected.emit(_option_text)

func get_option_text() -> String:
	return _option_text

func get_option_kind() -> String:
	return _option_kind

func get_presentation_mode() -> String:
	return _presentation_mode
