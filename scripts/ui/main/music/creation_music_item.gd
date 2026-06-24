extends PanelContainer

const MusicLibrary = preload("res://scripts/data/music_library.gd")

signal selected(track_id: String)
signal preview_requested(track_id: String)
signal appreciate_requested(track_id: String)
signal favorite_requested(track_id: String)
signal playlist_requested(track_id: String)

@onready var order_label: Label = $RootMargin/RootHBox/OrderLabel
@onready var title_label: Label = $RootMargin/RootHBox/InfoVBox/TitleLabel
@onready var subtitle_label: Label = $RootMargin/RootHBox/InfoVBox/SubtitleLabel
@onready var type_label: Label = $RootMargin/RootHBox/TypeLabel
@onready var preview_button: Button = $RootMargin/RootHBox/ActionsHBox/PreviewButton
@onready var appreciate_button: Button = $RootMargin/RootHBox/ActionsHBox/AppreciateButton
@onready var favorite_button: Button = $RootMargin/RootHBox/ActionsHBox/FavoriteButton
@onready var playlist_button: Button = $RootMargin/RootHBox/ActionsHBox/PlaylistButton
@onready var duration_label: Label = $RootMargin/RootHBox/DurationLabel

var _track_id: String = ""
var _selected: bool = false
var _playing: bool = false

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	preview_button.pressed.connect(_on_preview_pressed)
	appreciate_button.pressed.connect(_on_appreciate_pressed)
	favorite_button.pressed.connect(_on_favorite_pressed)
	playlist_button.pressed.connect(_on_playlist_pressed)

func setup(track: Dictionary, order_index: int, duration_text: String, is_selected: bool, is_playing: bool) -> void:
	_track_id = str(track.get("id", ""))
	order_label.text = str(order_index)
	title_label.text = MusicLibrary.get_track_title(track)
	subtitle_label.text = MusicLibrary.get_track_subtitle(track)
	type_label.text = MusicLibrary.get_track_type(track)
	duration_label.text = duration_text
	favorite_button.text = "已收藏" if bool(track.get("is_favorite", false)) else "收藏"
	favorite_button.disabled = false
	playlist_button.text = "已加入" if bool(track.get("in_playlist", false)) else "加播单"
	playlist_button.disabled = bool(track.get("in_playlist", false))
	set_selected_state(is_selected, is_playing)

func set_selected_state(is_selected: bool, is_playing: bool = false) -> void:
	_selected = is_selected
	_playing = is_playing
	if _playing:
		add_theme_stylebox_override("panel", get_theme_stylebox("pressed"))
	elif _selected:
		add_theme_stylebox_override("panel", get_theme_stylebox("hover"))
	else:
		add_theme_stylebox_override("panel", get_theme_stylebox("normal"))
	preview_button.text = "暂停" if _playing else "试听"

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected.emit(_track_id)

func _on_preview_pressed() -> void:
	preview_requested.emit(_track_id)

func _on_appreciate_pressed() -> void:
	appreciate_requested.emit(_track_id)

func _on_favorite_pressed() -> void:
	favorite_requested.emit(_track_id)

func _on_playlist_pressed() -> void:
	playlist_requested.emit(_track_id)
