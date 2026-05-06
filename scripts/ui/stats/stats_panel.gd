extends PanelContainer

var core_stats_def = [
    {
        "id": "physical",
        "name": "体力",
        "color": Color("e76f51"),
        "icon": "res://assets/images/icons/ui/stats/core_physical.svg",
        "sub_stats": [
            {"id": "stat_stamina", "name": "体能续航"},
            {"id": "stat_body_management", "name": "形体管控"},
            {"id": "stat_focus", "name": "凝心专注"},
            {"id": "stat_rhythm", "name": "律动反应"}
        ]
    },
    {
        "id": "intelligence",
        "name": "智力",
        "color": Color("2a9d8f"),
        "icon": "res://assets/images/icons/ui/stats/core_intelligence.svg",
        "sub_stats": [
            {"id": "stat_artistic_literacy", "name": "艺术素养"},
            {"id": "stat_verbal_expression", "name": "言辞表达"},
            {"id": "stat_planning", "name": "统筹企划"},
            {"id": "stat_art_theory", "name": "艺理钻研"}
        ]
    },
    {
        "id": "charm",
        "name": "魅力",
        "color": Color("e0aaff"),
        "icon": "res://assets/images/icons/ui/stats/core_charm.svg",
        "sub_stats": [
            {"id": "stat_temperament", "name": "格调气质"},
            {"id": "stat_manner", "name": "举止仪范"},
            {"id": "stat_emotional_infection", "name": "共情感染"},
            {"id": "stat_stage_performance", "name": "舞台表现"}
        ]
    },
    {
        "id": "sensibility",
        "name": "感性",
        "color": Color("80ed99"),
        "icon": "res://assets/images/icons/ui/stats/aesthetics.svg",
        "sub_stats": [
            {"id": "stat_empathy", "name": "情思体悟"},
            {"id": "stat_inspiration", "name": "创想灵感"},
            {"id": "stat_aesthetics", "name": "美学品鉴"},
            {"id": "stat_art_perception", "name": "艺术感知"}
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
    # 清理旧的UI节点
    for child in get_children():
        child.free()
        
    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 15)
    margin.add_theme_constant_override("margin_top", 15)
    margin.add_theme_constant_override("margin_right", 15)
    margin.add_theme_constant_override("margin_bottom", 15)
    add_child(margin)
    
    var grid = GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 15)
    grid.add_theme_constant_override("v_separation", 15)
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
    margin.add_child(grid)
    
    for def in core_stats_def:
        var panel = PanelContainer.new()
        panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
        
        var style = StyleBoxFlat.new()
        style.bg_color = Color("faf3e8") # Light paper background
        style.corner_radius_top_left = 5
        style.corner_radius_top_right = 5
        style.corner_radius_bottom_left = 5
        style.corner_radius_bottom_right = 5
        style.border_width_bottom = 2
        style.border_color = Color("d4c4a8")
        panel.add_theme_stylebox_override("panel", style)
        grid.add_child(panel)
        
        var p_margin = MarginContainer.new()
        p_margin.add_theme_constant_override("margin_left", 15)
        p_margin.add_theme_constant_override("margin_top", 10)
        p_margin.add_theme_constant_override("margin_right", 15)
        p_margin.add_theme_constant_override("margin_bottom", 10)
        panel.add_child(p_margin)
        
        var vbox = VBoxContainer.new()
        p_margin.add_child(vbox)
        
        # Top Header HBox
        var header = HBoxContainer.new()
        vbox.add_child(header)
        
        var icon_rect = TextureRect.new()
        if FileAccess.file_exists(def.icon):
            icon_rect.texture = load(def.icon)
        icon_rect.custom_minimum_size = Vector2(30, 30)
        icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        header.add_child(icon_rect)
        
        var title_vbox = VBoxContainer.new()
        title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        header.add_child(title_vbox)
        
        var title_hbox = HBoxContainer.new()
        title_vbox.add_child(title_hbox)
        
        var name_lbl = Label.new()
        name_lbl.text = def.name
        name_lbl.add_theme_color_override("font_color", Color("333333"))
        name_lbl.add_theme_font_size_override("font_size", 18)
        title_hbox.add_child(name_lbl)
        
        var spacer = Control.new()
        spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        title_hbox.add_child(spacer)
        
        var val_lbl = Label.new()
        val_lbl.name = "ValLabel"
        val_lbl.add_theme_color_override("font_color", Color("555555"))
        val_lbl.add_theme_font_size_override("font_size", 14)
        title_hbox.add_child(val_lbl)
        
        var pbar = ProgressBar.new()
        pbar.name = "PBar"
        pbar.custom_minimum_size = Vector2(0, 6)
        pbar.show_percentage = false
        var sb_bg = StyleBoxFlat.new()
        sb_bg.bg_color = Color("e0e0e0")
        sb_bg.corner_radius_top_left = 3
        sb_bg.corner_radius_top_right = 3
        sb_bg.corner_radius_bottom_left = 3
        sb_bg.corner_radius_bottom_right = 3
        var sb_fg = StyleBoxFlat.new()
        sb_fg.bg_color = def.color
        sb_fg.corner_radius_top_left = 3
        sb_fg.corner_radius_top_right = 3
        sb_fg.corner_radius_bottom_left = 3
        sb_fg.corner_radius_bottom_right = 3
        pbar.add_theme_stylebox_override("background", sb_bg)
        pbar.add_theme_stylebox_override("fill", sb_fg)
        title_vbox.add_child(pbar)
        
        var grade_lbl = Label.new()
        grade_lbl.name = "GradeLabel"
        grade_lbl.add_theme_color_override("font_color", Color("cfa670"))
        grade_lbl.add_theme_font_size_override("font_size", 28)
        grade_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        header.add_child(grade_lbl)
        
        var sep = HSeparator.new()
        sep.add_theme_constant_override("separation", 10)
        var sep_style = StyleBoxLine.new()
        sep_style.color = Color("d4c4a8")
        sep_style.thickness = 1
        sep.add_theme_stylebox_override("separator", sep_style)
        vbox.add_child(sep)
        
        # Sub stats Grid
        var sub_grid = GridContainer.new()
        sub_grid.columns = 2
        sub_grid.add_theme_constant_override("h_separation", 15)
        sub_grid.add_theme_constant_override("v_separation", 5)
        vbox.add_child(sub_grid)
        
        for sub in def.sub_stats:
            var sub_hbox = HBoxContainer.new()
            sub_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            sub_grid.add_child(sub_hbox)
            
            var sub_name = Label.new()
            sub_name.text = sub.name
            sub_name.add_theme_color_override("font_color", Color("555555"))
            sub_name.add_theme_font_size_override("font_size", 14)
            sub_hbox.add_child(sub_name)
            
            var sub_spacer = Control.new()
            sub_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            sub_hbox.add_child(sub_spacer)
            
            var sub_val = Label.new()
            sub_val.name = sub.id
            sub_val.text = "0"
            sub_val.add_theme_color_override("font_color", Color("333333"))
            sub_val.add_theme_font_size_override("font_size", 14)
            sub_hbox.add_child(sub_val)
            
        panel.set_meta("def", def)
        
    _update_ui()

func _update_ui() -> void:
    if not is_inside_tree() or get_child_count() == 0: return
    var profile = GameDataManager.profile
    var stats = GameDataManager.stats_system
    
    var core_vals = {
        "physical": stats.get_core_physical(profile),
        "intelligence": stats.get_core_intelligence(profile),
        "charm": stats.get_core_charm(profile),
        "sensibility": stats.get_core_sensibility(profile)
    }
    
    var grid = get_child(0).get_child(0)
    for panel in grid.get_children():
        var def = panel.get_meta("def")
        var c_val = core_vals[def.id]
        var info = get_grade_info(c_val)
        
        var val_lbl = panel.find_child("ValLabel", true, false)
        var grade_lbl = panel.find_child("GradeLabel", true, false)
        var pbar = panel.find_child("PBar", true, false)
        
        val_lbl.text = "%d (%d/%d)" % [c_val, c_val, int(info.next)]
        grade_lbl.text = info.grade
        
        pbar.min_value = info.prev
        pbar.max_value = info.next
        pbar.value = c_val
        
        for sub in def.sub_stats:
            var s_lbl = panel.find_child(sub.id, true, false)
            if s_lbl:
                s_lbl.text = str(int(profile.get(sub.id)))