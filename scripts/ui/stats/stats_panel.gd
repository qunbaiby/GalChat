extends PanelContainer

@onready var val_phys: Label = $MarginContainer/VBoxContainer/CoreStatsHBox/CoreVBox_Physical/ValueLabel
@onready var val_int: Label = $MarginContainer/VBoxContainer/CoreStatsHBox/CoreVBox_Intelligence/ValueLabel
@onready var val_charm: Label = $MarginContainer/VBoxContainer/CoreStatsHBox/CoreVBox_Charm/ValueLabel

@onready var basic_vbox: GridContainer = $MarginContainer/VBoxContainer/BasicStatsVBox

var basic_stats_def = [
    {"id": "physical_fitness", "node": "Stat_PhysicalFitness"},
    {"id": "vitality", "node": "Stat_Vitality"},
    {"id": "academic_quality", "node": "Stat_Academic"},
    {"id": "knowledge_reserve", "node": "Stat_Knowledge"},
    {"id": "social_eq", "node": "Stat_SocialEQ"},
    {"id": "creative_aesthetics", "node": "Stat_Aesthetics"}
]

func _ready() -> void:
    _update_ui()

func get_grade_info(val: float) -> Dictionary:
    # Returns { "grade": String, "next_target": float }
    if val < 200: return { "grade": "D", "next": 200 }
    if val < 350: return { "grade": "D+", "next": 350 }
    if val < 500: return { "grade": "C", "next": 500 }
    if val < 700: return { "grade": "C+", "next": 700 }
    if val < 900: return { "grade": "B", "next": 900 }
    if val < 1100: return { "grade": "B+", "next": 1100 }
    if val < 1300: return { "grade": "A", "next": 1300 }
    if val < 1500: return { "grade": "A+", "next": 1500 }
    if val < 1800: return { "grade": "S", "next": 1800 }
    return { "grade": "S+", "next": 2000 }

func _update_ui() -> void:
    if not is_inside_tree():
        return
        
    var profile = GameDataManager.profile
    var stats = GameDataManager.stats_system
    
    val_phys.text = str(stats.get_core_physical(profile))
    val_int.text = str(stats.get_core_intelligence(profile))
    val_charm.text = str(stats.get_core_charm(profile))
    
    var idx = 0
    for child in basic_vbox.get_children():
        if child is PanelContainer: # e.g. Stat_PhysicalFitness
            if idx >= basic_stats_def.size(): break
            var stat_id = basic_stats_def[idx].id
            var current_val = float(profile.get(stat_id))
            var info = get_grade_info(current_val)

            var next_label = child.find_child("NextLabel", true, false) as Label
            var pbar = child.find_child("PBar", true, false) as ProgressBar 
            var grade_label = child.find_child("GradeLabel", true, false) as Label
            var value_label = pbar.get_node_or_null("ValueLabel") if pbar else null
            
            if grade_label: grade_label.text = info.grade

            if current_val >= 2000:
                if next_label: next_label.text = "已满级"
                if value_label: value_label.text = "%d / %d" % [int(current_val), 2000]
                if pbar:
                    pbar.min_value = 0
                    pbar.max_value = 1
                    pbar.value = 1
            else:
                if next_label: next_label.text = "还差 %d" % int(info.next - current_val)
                if value_label: value_label.text = "%d / %d" % [int(current_val), int(info.next)]
                if pbar:
                    # Calculate progress in current bracket
                    var prev_target = 0.0
                    var levels = [0, 200, 350, 500, 700, 900, 1100, 1300, 1500, 1800, 2000]
                    for l in levels:
                        if current_val >= l:
                            prev_target = float(l)
                        else:
                            break

                    pbar.min_value = prev_target
                    pbar.max_value = info.next
                    pbar.value = current_val

            idx += 1
