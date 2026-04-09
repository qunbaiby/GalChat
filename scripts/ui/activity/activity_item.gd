extends PanelContainer

signal activity_pressed(activity_id: String)
signal activity_hovered(act_data: Dictionary)

@onready var button: Button = $Button
@onready var icon_rect: TextureRect = $Margin/HBox/Icon
@onready var name_label: Label = $Margin/HBox/VBox/TopHBox/NameLabel
@onready var cost_label: Label = $Margin/HBox/VBox/TopHBox/CostLabel
@onready var desc_label: Label = $Margin/HBox/VBox/DescLabel

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
		
	if act_data.has("energy_cost"):
		cost_label.text = "消耗精力: %d" % act_data.energy_cost
		
	if act_data.has("desc"):
		desc_label.text = act_data.desc
		
	if act_data.has("icon_path") and act_data.icon_path != "":
		var tex = load(act_data.icon_path)
		if tex:
			icon_rect.texture = tex

func _on_pressed() -> void:
	if _act_data.has("id"):
		activity_pressed.emit(_act_data.id)

func _on_hovered() -> void:
	activity_hovered.emit(_act_data)
