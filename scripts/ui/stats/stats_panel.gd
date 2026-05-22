extends PanelContainer

var core_stats_def = [
    {
        "id": "physical",
        "sub_stats": [
            "stat_stamina",
            "stat_body",
            "stat_focus",
            "stat_rhythm"
        ]
    },
    {
        "id": "intelligence",
        "sub_stats": [
            "stat_knowledge",
            "stat_expression",
            "stat_planning",
            "stat_art_theory"
        ]
    },
    {
        "id": "charm",
        "sub_stats": [
            "stat_temperament",
            "stat_manner",
            "stat_etiquette",
            "stat_stage"
        ]
    },
    {
        "id": "sensibility",
        "sub_stats": [
            "stat_empathy",
            "stat_inspiration",
            "stat_aesthetics",
            "stat_perception"
        ]
    }
]

func get_grade_info(val: float) -> Dictionary:
    var levels = [0, 800, 1400, 2000, 2800, 3600, 4400, 5200, 6000, 7200, 8000]
    var grades = ["E-", "E", "D", "D+", "C", "C+", "B", "B+", "A", "S"]
    var idx = 0
    var next_target = 8000.0
    var prev_target = 0.0
    var grade = "S+"
    for i in range(1, levels.size()):
        if val < levels[i]:
            grade = grades[i-1]
            next_target = float(levels[i])
            prev_target = float(levels[i-1])
            break
    if val >= 8000:
        prev_target = 8000.0
        next_target = 8000.0
    return { "grade": grade, "next": next_target, "prev": prev_target }

func _ready() -> void:
    _update_ui()

func _update_ui() -> void:
    if not is_inside_tree(): return
    var profile = GameDataManager.profile
    var stats = GameDataManager.stats_system
    
    var core_vals = {
        "physical": stats.get_core_physical(profile),
        "intelligence": stats.get_core_intelligence(profile),
        "charm": stats.get_core_charm(profile),
        "sensibility": stats.get_core_sensibility(profile)
    }
    
    var grid = $MarginContainer/GridContainer
    
    for def in core_stats_def:
        var panel_name = "StatBlock_" + def.id.capitalize()
        var panel = grid.get_node_or_null(panel_name)
        if not panel:
            continue
            
        var c_val = core_vals[def.id]
        var info = get_grade_info(c_val)
        
        var val_lbl = panel.find_child("ValLabel", true, false)
        var grade_lbl = panel.find_child("GradeLabel", true, false)
        var pbar = panel.find_child("PBar", true, false)
        
        if val_lbl: val_lbl.text = "%d (%d/%d)" % [c_val, c_val, int(info.next)]
        if grade_lbl: grade_lbl.text = info.grade
        
        if pbar:
            pbar.min_value = info.prev
            pbar.max_value = info.next
            pbar.value = c_val
        
        for sub_id in def.sub_stats:
            var sub_hbox_name = "Sub_" + sub_id
            var sub_hbox = panel.find_child(sub_hbox_name, true, false)
            if sub_hbox:
                var s_lbl = sub_hbox.find_child("Val", true, false)
                if s_lbl:
                    s_lbl.text = str(int(profile.get(sub_id)))
