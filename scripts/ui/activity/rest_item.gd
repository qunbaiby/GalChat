extends PanelContainer

signal rest_pressed(activity_id: String)
signal rest_hovered(act_data: Dictionary)

@onready var button: Button = $Button
@onready var name_label: Label = $Margin/HBox/NameLabel

var _act_data: Dictionary = {}

func _ready() -> void:
	button.pressed.connect(_on_pressed)
	button.mouse_entered.connect(_on_hovered)
	
	# Visual feedback for hover
	button.mouse_entered.connect(func(): modulate = Color(1.1, 1.1, 1.1))
	button.mouse_exited.connect(func(): modulate = Color(1.0, 1.0, 1.0))

func setup(act_data: Dictionary) -> void:
	_act_data = act_data
	
	if act_data.has("name"):
		name_label.text = act_data.name

func _on_pressed() -> void:
	if _act_data.has("id"):
		rest_pressed.emit(_act_data.id)

func _on_hovered() -> void:
	rest_hovered.emit(_act_data)
