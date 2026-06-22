extends Button

signal activity_pressed(id: String)
signal activity_hovered(data: Dictionary)

@onready var icon_rect: TextureRect = %Icon
@onready var name_label: Label = %NameLabel
@onready var cost_container: Container = %CostContainer
@onready var rewards_container: Container = %RewardsContainer
@onready var progress_container: Container = %ProgressContainer
@onready var progress_label: Label = %ProgressLabel
@onready var increment_label: Label = %IncrementLabel
@onready var progress_bar: ProgressBar = %ProgressBar

const RewardTagScene = preload("res://scenes/ui/activity/activity_reward_tag.tscn")
const CostTagScene = preload("res://scenes/ui/activity/activity_cost_tag.tscn")

var activity_data: Dictionary = {}
var current_prog_val: int = 0
const DEFAULT_PROGRESS_COLOR := Color(0.5, 0.54, 0.62, 1)
const PREVIEW_PROGRESS_COLOR := Color(0.2, 0.6, 0.2, 1)
var _clip_style_normal: StyleBoxFlat
var _clip_style_hover: StyleBoxFlat
var _progress_bg_normal: StyleBoxFlat
var _progress_bg_hover: StyleBoxFlat
var _progress_fill_normal: StyleBoxFlat
var _progress_fill_hover: StyleBoxFlat

func _ready() -> void:
	_disable_child_mouse_interaction(self)
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_hovered)
	mouse_entered.connect(_apply_hover_style)
	mouse_exited.connect(_apply_normal_style)
	_capture_styles()
	_apply_normal_style()

func _disable_child_mouse_interaction(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_disable_child_mouse_interaction(child)

func _capture_styles() -> void:
	var clip_mask_panel: PanelContainer = $ClipMask
	if clip_mask_panel:
		var clip_style := clip_mask_panel.get_theme_stylebox("panel")
		if clip_style is StyleBoxFlat:
			_clip_style_normal = (clip_style as StyleBoxFlat).duplicate()
			_clip_style_hover = _clip_style_normal.duplicate()
			_clip_style_hover.bg_color = Color(0.985, 0.992, 0.995, 1)

	if progress_bar:
		var progress_bg := progress_bar.get_theme_stylebox("background")
		if progress_bg is StyleBoxFlat:
			_progress_bg_normal = (progress_bg as StyleBoxFlat).duplicate()
			_progress_bg_hover = _progress_bg_normal.duplicate()
			_progress_bg_hover.bg_color = Color(0.82, 0.88, 0.92, 1)

		var progress_fill := progress_bar.get_theme_stylebox("fill")
		if progress_fill is StyleBoxFlat:
			_progress_fill_normal = (progress_fill as StyleBoxFlat).duplicate()
			_progress_fill_hover = _progress_fill_normal.duplicate()
			_progress_fill_hover.bg_color = Color(0.43, 0.74, 0.92, 1)

func _apply_normal_style() -> void:
	if _clip_style_normal:
		$ClipMask.add_theme_stylebox_override("panel", _clip_style_normal)
	if _progress_bg_normal:
		progress_bar.add_theme_stylebox_override("background", _progress_bg_normal)
	if _progress_fill_normal:
		progress_bar.add_theme_stylebox_override("fill", _progress_fill_normal)

func _apply_hover_style() -> void:
	if _clip_style_hover:
		$ClipMask.add_theme_stylebox_override("panel", _clip_style_hover)
	if _progress_bg_hover:
		progress_bar.add_theme_stylebox_override("background", _progress_bg_hover)
	if _progress_fill_hover:
		progress_bar.add_theme_stylebox_override("fill", _progress_fill_hover)

func setup(data: Dictionary, cur_prog: int = 0) -> void:
	if not is_node_ready():
		await ready
		
	activity_data = data
	current_prog_val = cur_prog
	name_label.text = data.get("name", "未知")
		
	var max_prog = data.get("max_progress", 0)
	var increment = data.get("progress_increment", 0)
	
	if progress_container:
		if max_prog > 0:
			progress_container.show()
			progress_bar.max_value = max_prog
			progress_bar.value = cur_prog
			progress_label.text = "%d/%d" % [cur_prog, max_prog]
			progress_label.add_theme_color_override("font_color", DEFAULT_PROGRESS_COLOR)
			increment_label.text = "单次 +%d" % increment
			increment_label.show()
		else:
			progress_container.hide()
	
	if data.has("icon_path") and data.icon_path != "":
		var tex = load(data.icon_path)
		if tex and icon_rect:
			icon_rect.texture = tex
	elif icon_rect:
		icon_rect.texture = null
			
	# Clear old costs
	if cost_container:
		for child in cost_container.get_children():
			child.queue_free()
			
	var has_cost = false
			
	var g_cost = data.get("gold_cost", 0)
	if cost_container and g_cost > 0:
		var tag = CostTagScene.instantiate()
		cost_container.add_child(tag)
		tag.setup("gold", g_cost)
		has_cost = true
		
	var m_change = data.get("mood_change", 0)
	if cost_container and m_change != 0:
		var tag = CostTagScene.instantiate()
		cost_container.add_child(tag)
		if m_change > 0:
			tag.setup("mood_increase", m_change)
		else:
			tag.setup("mood_decrease", m_change)
		has_cost = true
		
	if cost_container:
		if has_cost:
			cost_container.show()
		else:
			cost_container.hide()

	# Clear old rewards
	if rewards_container:
		for child in rewards_container.get_children():
			child.queue_free()

	if data.has("rewards") and rewards_container:
		for key in data.rewards.keys():
			var range_arr = data.rewards[key]
			var avg_val = (range_arr[0] + range_arr[1]) / 2.0
			
			var disp_name = GameDataManager.stats_system.get_sub_stat_name(key) if GameDataManager.stats_system else key
			
			var tag = RewardTagScene.instantiate()
			rewards_container.add_child(tag)
			tag.setup(key, disp_name, int(avg_val))

func update_preview(preview_count: int) -> void:
	if not is_node_ready():
		await ready
		
	var max_prog = activity_data.get("max_progress", 0)
	var increment = activity_data.get("progress_increment", 0)
	
	if max_prog > 0:
		var total_added = increment * preview_count
		var preview_prog = min(current_prog_val + total_added, max_prog)
		
		if total_added > 0:
			progress_label.text = "%d(+%d)/%d" % [current_prog_val, total_added, max_prog]
			progress_bar.value = preview_prog
			progress_label.add_theme_color_override("font_color", PREVIEW_PROGRESS_COLOR)
		else:
			progress_label.text = "%d/%d" % [current_prog_val, max_prog]
			progress_bar.value = current_prog_val
			progress_label.add_theme_color_override("font_color", DEFAULT_PROGRESS_COLOR)

func _on_pressed() -> void:
	if activity_data.has("id"):
		activity_pressed.emit(activity_data.id)

func _on_hovered() -> void:
	if not activity_data.is_empty():
		activity_hovered.emit(activity_data)
