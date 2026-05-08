extends PanelContainer

signal activity_pressed(id: String)
signal activity_hovered(data: Dictionary)

@onready var btn: Button = $Button
@onready var icon: TextureRect = $Margin/HBox/Icon
@onready var name_label: Label = $Margin/HBox/VBox/NameLabel
@onready var energy_cost: Label = $Margin/HBox/VBox/CostHBox/EnergyCost
@onready var rewards_hbox: HBoxContainer = $Margin/HBox/VBox/RewardsHBox

var activity_data: Dictionary = {}

var stat_name_map = {
	"stat_stamina": "体能",
	"stat_body_management": "形体",
	"stat_focus": "专注",
	"stat_rhythm": "律动",
	"stat_artistic_literacy": "艺术",
	"stat_verbal_expression": "表达",
	"stat_planning": "企划",
	"stat_art_theory": "艺理",
	"stat_temperament": "气质",
	"stat_manner": "仪范",
	"stat_emotional_infection": "共情",
	"stat_stage_performance": "表现",
	"stat_empathy": "情思",
	"stat_inspiration": "灵感",
	"stat_aesthetics": "美学",
	"stat_art_perception": "感知",
	"energy_recovery": "精力恢复"
}

func _ready() -> void:
	btn.pressed.connect(_on_pressed)
	btn.mouse_entered.connect(_on_hovered)
	
	# Visual feedback for hover
	btn.mouse_entered.connect(func(): modulate = Color(1.1, 1.1, 1.1))
	btn.mouse_exited.connect(func(): modulate = Color(1.0, 1.0, 1.0))

func setup(data: Dictionary) -> void:
	activity_data = data
	name_label.text = data.get("name", "未知")
	
	if data.has("icon_path") and data.icon_path != "":
		var tex = load(data.icon_path)
		if tex:
			icon.texture = tex
			
	var cost = data.get("energy_cost", 0)
	if cost > 0:
		energy_cost.text = "精力 -%d" % cost
		energy_cost.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	else:
		energy_cost.text = "精力 -0"
		energy_cost.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		
	# Clear old rewards
	for child in rewards_hbox.get_children():
		child.queue_free()
		
	if data.has("rewards"):
		for key in data.rewards.keys():
			var range_arr = data.rewards[key]
			var avg_val = (range_arr[0] + range_arr[1]) / 2.0
			
			var lbl = Label.new()
			var disp_name = stat_name_map.get(key, key)
			lbl.text = "%s +%d" % [disp_name, int(avg_val)]
			
			# Style the label like a tag
			lbl.add_theme_color_override("font_color", Color.WHITE)
			lbl.add_theme_font_size_override("font_size", 12)
			
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.9, 0.6, 0.2) # Default orange-ish
			if key == "energy_recovery":
				style.bg_color = Color(0.3, 0.7, 0.4)
			elif key.begins_with("stat_"):
				style.bg_color = Color(0.4, 0.6, 0.9)
				
			style.corner_radius_top_left = 4
			style.corner_radius_top_right = 4
			style.corner_radius_bottom_right = 4
			style.corner_radius_bottom_left = 4
			style.content_margin_left = 6
			style.content_margin_right = 6
			style.content_margin_top = 2
			style.content_margin_bottom = 2
			
			lbl.add_theme_stylebox_override("normal", style)
			rewards_hbox.add_child(lbl)

func _on_pressed() -> void:
	if activity_data.has("id"):
		activity_pressed.emit(activity_data.id)

func _on_hovered() -> void:
	if not activity_data.is_empty():
		activity_hovered.emit(activity_data)
