extends PanelContainer

signal activity_pressed(id: String)
signal activity_hovered(data: Dictionary)

@onready var btn: Button = $Button
@onready var icon: TextureRect = $Margin/HBox/ProgressContainer/Icon
@onready var name_label: Label = $Margin/HBox/VBox/HeaderHBox/NameLabel
@onready var level_label: Label = $Margin/HBox/VBox/HeaderHBox/LevelLabel
@onready var cost_hbox: HBoxContainer = $Margin/HBox/VBox/CostHBox
@onready var energy_cost: Label = $Margin/HBox/VBox/CostHBox/EnergyCost
@onready var gold_cost: Label = $Margin/HBox/VBox/CostHBox/GoldCost
@onready var mood_cost: Label = $Margin/HBox/VBox/CostHBox/MoodCost
@onready var stress_cost: Label = $Margin/HBox/VBox/CostHBox/StressCost
@onready var rewards_hbox: HBoxContainer = $Margin/HBox/VBox/RewardsHBox
@onready var progress_container: VBoxContainer = $Margin/HBox/ProgressContainer
@onready var progress_label: Label = $Margin/HBox/ProgressContainer/ProgressHBox/ProgressLabel
@onready var increment_label: Label = $Margin/HBox/ProgressContainer/ProgressHBox/IncrementLabel
@onready var progress_bar: ProgressBar = $Margin/HBox/ProgressContainer/ProgressBar

var activity_data: Dictionary = {}
var current_prog_val: int = 0

func _ready() -> void:
	btn.pressed.connect(_on_pressed)
	btn.mouse_entered.connect(_on_hovered)
	
	# Visual feedback for hover
	btn.mouse_entered.connect(func(): modulate = Color(1.1, 1.1, 1.1))
	btn.mouse_exited.connect(func(): modulate = Color(1.0, 1.0, 1.0))

func setup(data: Dictionary, cur_prog: int = 0) -> void:
	if not is_node_ready():
		await ready
		
	activity_data = data
	current_prog_val = cur_prog
	name_label.text = data.get("name", "未知")
	
	if level_label:
		if data.has("level"):
			level_label.text = str(data.level)
			level_label.show()
		else:
			level_label.hide()
		
	var max_prog = data.get("max_progress", 0)
	var increment = data.get("progress_increment", 0)
	
	if progress_container:
		if max_prog > 0:
			progress_container.show()
			progress_bar.max_value = max_prog
			progress_bar.value = cur_prog
			progress_label.text = "进度: %d/%d" % [cur_prog, max_prog]
			increment_label.text = "+%d/次" % increment
		else:
			progress_container.hide()
	
	if data.has("icon_path") and data.icon_path != "":
		var tex = load(data.icon_path)
		if tex and icon:
			icon.texture = tex
			
	var g_cost = data.get("gold_cost", 0)
	if gold_cost:
		if g_cost > 0:
			gold_cost.text = "金币 -%d" % g_cost
			gold_cost.show()
		else:
			gold_cost.hide()
		
	var m_change = data.get("mood_change", 0)
	if mood_cost:
		if m_change != 0:
			if m_change > 0:
				mood_cost.text = "心情 +%d" % m_change
				mood_cost.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
			else:
				mood_cost.text = "心情 %d" % m_change
				mood_cost.add_theme_color_override("font_color", Color(0.3, 0.5, 0.8))
			mood_cost.show()
		else:
			mood_cost.hide()
		
	var s_change = data.get("stress_change", 0)
	if stress_cost:
		if s_change != 0:
			if s_change > 0:
				stress_cost.text = "压力 +%d" % s_change
				stress_cost.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
			else:
				stress_cost.text = "压力 %d" % s_change
				stress_cost.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
			stress_cost.show()
		else:
			stress_cost.hide()
		
	# 如果全隐藏，则隐藏整个 hbox
	if cost_hbox:
		if g_cost <= 0 and m_change == 0 and s_change == 0:
			cost_hbox.hide()
		else:
			cost_hbox.show()
		
	# 强行隐藏行动力标签，因为已经废弃
	if energy_cost:
		energy_cost.hide()
		
	# Clear old rewards
	for child in rewards_hbox.get_children():
		child.queue_free()
		
	if data.has("rewards"):
		for key in data.rewards.keys():
			var range_arr = data.rewards[key]
			var avg_val = (range_arr[0] + range_arr[1]) / 2.0
			
			var lbl = Label.new()
			var disp_name = GameDataManager.stats_system.get_sub_stat_name(key) if GameDataManager.stats_system else key
			lbl.text = "%s +%d" % [disp_name, int(avg_val)]
			
			# Style the label like a tag
			lbl.add_theme_color_override("font_color", Color.WHITE)
			lbl.add_theme_font_size_override("font_size", 12)
			
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.9, 0.6, 0.2) # Default orange-ish
			if key.begins_with("stat_"):
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

func update_preview(preview_count: int) -> void:
	if not is_node_ready():
		await ready
		
	var max_prog = activity_data.get("max_progress", 0)
	var increment = activity_data.get("progress_increment", 0)
	
	if max_prog > 0:
		var total_added = increment * preview_count
		var preview_prog = min(current_prog_val + total_added, max_prog)
		
		if total_added > 0:
			progress_label.text = "进度: %d(+%d)/%d" % [current_prog_val, total_added, max_prog]
			progress_bar.value = preview_prog
			progress_label.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2))
		else:
			progress_label.text = "进度: %d/%d" % [current_prog_val, max_prog]
			progress_bar.value = current_prog_val
			progress_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))

func _on_pressed() -> void:
	if activity_data.has("id"):
		activity_pressed.emit(activity_data.id)

func _on_hovered() -> void:
	if not activity_data.is_empty():
		activity_hovered.emit(activity_data)
