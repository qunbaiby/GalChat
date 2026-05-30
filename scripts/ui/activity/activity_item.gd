extends PanelContainer

signal activity_pressed(id: String)
signal activity_hovered(data: Dictionary)

@onready var btn: Button = $Button
@onready var icon: TextureRect = %Icon
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

func _ready() -> void:
    if btn == null:
        push_error("ActivityItem 缺少 Button 节点，无法绑定交互。")
        return

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
        
    var max_prog = data.get("max_progress", 0)
    var increment = data.get("progress_increment", 0)
    
    if progress_container:
        if max_prog > 0:
            progress_container.show()
            progress_bar.max_value = max_prog
            progress_bar.value = cur_prog
            progress_label.text = "%d/%d" % [cur_prog, max_prog]
            increment_label.text = "单次 +%d" % increment
            increment_label.show()
        else:
            progress_container.hide()
    
    if data.has("icon_path") and data.icon_path != "":
        var tex = load(data.icon_path)
        if tex and icon:
            icon.texture = tex
            
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
        
    var s_change = data.get("stress_change", 0)
    if cost_container and s_change != 0:
        var tag = CostTagScene.instantiate()
        cost_container.add_child(tag)
        if s_change > 0:
            tag.setup("stress_increase", s_change)
        else:
            tag.setup("stress_decrease", s_change)
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
            progress_label.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2))
        else:
            progress_label.text = "%d/%d" % [current_prog_val, max_prog]
            progress_bar.value = current_prog_val
            progress_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))

func _on_pressed() -> void:
    if activity_data.has("id"):
        activity_pressed.emit(activity_data.id)

func _on_hovered() -> void:
    if not activity_data.is_empty():
        activity_hovered.emit(activity_data)
