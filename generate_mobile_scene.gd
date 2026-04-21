extends SceneTree

func _init():
    var root = Control.new()
    root.name = "MobileInterface"
    root.layout_mode = 1
    root.anchors_preset = Control.PRESET_FULL_RECT
    root.visible = false
    
    var script = load("res://scripts/ui/mobile/mobile_interface.gd")
    root.set_script(script)
    var theme = load("res://assets/themes/galchat_theme.tres")
    root.theme = theme

    var color_rect = ColorRect.new()
    color_rect.name = "ColorRect"
    color_rect.layout_mode = 1
    color_rect.anchors_preset = Control.PRESET_FULL_RECT
    color_rect.color = Color(0, 0, 0, 0)
    root.add_child(color_rect)
    color_rect.owner = root

    var phone_panel = PanelContainer.new()
    phone_panel.name = "PhonePanel"
    phone_panel.custom_minimum_size = Vector2(400, 700)
    phone_panel.layout_mode = 1
    phone_panel.anchors_preset = 7 # Center Bottom
    phone_panel.anchor_left = 0.5
    phone_panel.anchor_top = 1.0
    phone_panel.anchor_right = 0.5
    phone_panel.anchor_bottom = 1.0
    phone_panel.offset_left = -200
    phone_panel.offset_top = 0
    phone_panel.offset_right = 200
    phone_panel.offset_bottom = 700
    phone_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
    phone_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
    
    var stylebox = StyleBoxFlat.new()
    # Gradient like the image: Top dark purple/blue, bottom lighter blue/green
    stylebox.bg_color = Color(0.12, 0.14, 0.25, 1.0)
    stylebox.corner_radius_top_left = 35
    stylebox.corner_radius_top_right = 35
    stylebox.corner_radius_bottom_right = 35
    stylebox.corner_radius_bottom_left = 35
    stylebox.border_width_left = 6
    stylebox.border_width_top = 6
    stylebox.border_width_right = 6
    stylebox.border_width_bottom = 6
    stylebox.border_color = Color(0.05, 0.25, 0.25, 1)
    
    phone_panel.add_theme_stylebox_override("panel", stylebox)
    root.add_child(phone_panel)
    phone_panel.owner = root

    var vbox = VBoxContainer.new()
    vbox.name = "VBoxContainer"
    vbox.theme_override_constants["separation"] = 10
    phone_panel.add_child(vbox)
    vbox.owner = root

    # --- Top Bar (Status Bar) ---
    var top_bar = MarginContainer.new()
    top_bar.name = "TopBar"
    top_bar.add_theme_constant_override("margin_left", 20)
    top_bar.add_theme_constant_override("margin_right", 20)
    top_bar.add_theme_constant_override("margin_top", 10)
    vbox.add_child(top_bar)
    top_bar.owner = root

    var top_bar_hbox = HBoxContainer.new()
    top_bar_hbox.name = "HBox"
    top_bar.add_child(top_bar_hbox)
    top_bar_hbox.owner = root
    
    var small_time = Label.new()
    small_time.name = "SmallTimeLabel"
    small_time.text = "08:08"
    small_time.add_theme_font_size_override("font_size", 12)
    top_bar_hbox.add_child(small_time)
    small_time.owner = root

    var spacer_top = Control.new()
    spacer_top.name = "Spacer"
    spacer_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_bar_hbox.add_child(spacer_top)
    spacer_top.owner = root
    
    var notch = Panel.new()
    notch.name = "Notch"
    notch.custom_minimum_size = Vector2(100, 20)
    var notch_style = StyleBoxFlat.new()
    notch_style.bg_color = Color(0, 0, 0, 1)
    notch_style.corner_radius_bottom_left = 10
    notch_style.corner_radius_bottom_right = 10
    notch.add_theme_stylebox_override("panel", notch_style)
    # Notch is positioned absolutely or as part of hbox? Better absolute to overlap
    
    var status_icons = Label.new()
    status_icons.name = "StatusIcons"
    status_icons.text = "Signal 100%"
    status_icons.add_theme_font_size_override("font_size", 12)
    top_bar_hbox.add_child(status_icons)
    status_icons.owner = root

    # --- Clock & Weather Area ---
    var clock_weather_margin = MarginContainer.new()
    clock_weather_margin.name = "ClockWeatherArea"
    clock_weather_margin.add_theme_constant_override("margin_left", 25)
    clock_weather_margin.add_theme_constant_override("margin_right", 25)
    clock_weather_margin.add_theme_constant_override("margin_top", 20)
    vbox.add_child(clock_weather_margin)
    clock_weather_margin.owner = root

    var cw_hbox = HBoxContainer.new()
    cw_hbox.name = "HBox"
    clock_weather_margin.add_child(cw_hbox)
    cw_hbox.owner = root

    var clock_vbox = VBoxContainer.new()
    clock_vbox.name = "ClockVBox"
    cw_hbox.add_child(clock_vbox)
    clock_vbox.owner = root

    var big_time = Label.new()
    big_time.name = "BigTimeLabel"
    big_time.text = "08:08"
    big_time.add_theme_font_size_override("font_size", 48)
    clock_vbox.add_child(big_time)
    big_time.owner = root

    var date_label = Label.new()
    date_label.name = "DateLabel"
    date_label.text = "10月19日星期四"
    date_label.add_theme_font_size_override("font_size", 14)
    clock_vbox.add_child(date_label)
    date_label.owner = root

    var spacer_cw = Control.new()
    spacer_cw.name = "Spacer"
    spacer_cw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cw_hbox.add_child(spacer_cw)
    spacer_cw.owner = root

    var weather_vbox = VBoxContainer.new()
    weather_vbox.name = "WeatherVBox"
    weather_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    cw_hbox.add_child(weather_vbox)
    weather_vbox.owner = root

    var temp_label = Label.new()
    temp_label.name = "TempLabel"
    temp_label.text = "⛅ 18°C"
    temp_label.add_theme_font_size_override("font_size", 24)
    weather_vbox.add_child(temp_label)
    temp_label.owner = root

    var high_low_label = Label.new()
    high_low_label.name = "HighLowLabel"
    high_low_label.text = "20 / 12"
    high_low_label.add_theme_font_size_override("font_size", 12)
    high_low_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    weather_vbox.add_child(high_low_label)
    high_low_label.owner = root

    # --- Apps Scroll Area ---
    var scroll = ScrollContainer.new()
    scroll.name = "ScrollContainer"
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    
    var scroll_margin = MarginContainer.new()
    scroll_margin.name = "Margin"
    scroll_margin.add_theme_constant_override("margin_left", 20)
    scroll_margin.add_theme_constant_override("margin_right", 20)
    scroll_margin.add_theme_constant_override("margin_top", 20)
    scroll.add_child(scroll_margin)
    
    vbox.add_child(scroll)
    scroll.owner = root
    scroll_margin.owner = root

    var app_grid = GridContainer.new()
    app_grid.name = "AppGrid"
    app_grid.columns = 4
    app_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    app_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
    app_grid.add_theme_constant_override("h_separation", 25)
    app_grid.add_theme_constant_override("v_separation", 25)
    scroll_margin.add_child(app_grid)
    app_grid.owner = root
    
    # We will generate dummy apps and the Archive app
    var apps = ["手机管家", "主题", "游戏", "电子邮件", "日历", "时钟", "设置", "阅读", "音乐", "运动健康", "备忘录", "相机", "应用市场", "图库", "文件夹", "档案"]
    for i in range(apps.size()):
        var app_name = apps[i]
        var app_btn = Button.new()
        if app_name == "档案":
            app_btn.name = "ArchiveAppButton"
        else:
            app_btn.name = "AppBtn_" + str(i)
        
        app_btn.custom_minimum_size = Vector2(65, 85)
        app_btn.flat = true
        app_grid.add_child(app_btn)
        app_btn.owner = root
        
        var app_vbox = VBoxContainer.new()
        app_vbox.name = "VBox"
        app_vbox.anchors_preset = Control.PRESET_FULL_RECT
        app_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
        app_btn.add_child(app_vbox)
        app_vbox.owner = root
        
        var icon_bg = Panel.new()
        icon_bg.name = "Icon"
        icon_bg.custom_minimum_size = Vector2(50, 50)
        icon_bg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var icon_style = StyleBoxFlat.new()
        
        # Randomish colors
        var colors = [Color(0.3,0.8,0.5), Color(0.8,0.3,0.4), Color(0.2,0.6,0.9), Color(0.9,0.7,0.2), Color(0.5,0.4,0.8)]
        icon_style.bg_color = colors[i % colors.size()]
        icon_style.corner_radius_top_left = 15
        icon_style.corner_radius_top_right = 15
        icon_style.corner_radius_bottom_right = 15
        icon_style.corner_radius_bottom_left = 15
        icon_bg.add_theme_stylebox_override("panel", icon_style)
        app_vbox.add_child(icon_bg)
        icon_bg.owner = root
        
        var app_label = Label.new()
        app_label.name = "Label"
        app_label.text = app_name
        app_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        app_label.add_theme_font_size_override("font_size", 12)
        app_label.add_theme_color_override("font_color", Color(1,1,1,0.8))
        app_vbox.add_child(app_label)
        app_label.owner = root

    # --- Dock Area ---
    var dock_margin = MarginContainer.new()
    dock_margin.name = "DockArea"
    dock_margin.add_theme_constant_override("margin_left", 20)
    dock_margin.add_theme_constant_override("margin_right", 20)
    dock_margin.add_theme_constant_override("margin_bottom", 10)
    vbox.add_child(dock_margin)
    dock_margin.owner = root

    var dock_hbox = HBoxContainer.new()
    dock_hbox.name = "DockHBox"
    dock_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
    dock_hbox.add_theme_constant_override("separation", 25)
    dock_margin.add_child(dock_hbox)
    dock_hbox.owner = root

    var dock_apps = ["拨号", "联系人", "信息", "浏览器"]
    for i in range(dock_apps.size()):
        var app_name = dock_apps[i]
        var app_btn = Button.new()
        app_btn.name = "DockBtn_" + str(i)
        app_btn.custom_minimum_size = Vector2(65, 85)
        app_btn.flat = true
        dock_hbox.add_child(app_btn)
        app_btn.owner = root
        
        var app_vbox = VBoxContainer.new()
        app_vbox.name = "VBox"
        app_vbox.anchors_preset = Control.PRESET_FULL_RECT
        app_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
        app_btn.add_child(app_vbox)
        app_vbox.owner = root
        
        var icon_bg = Panel.new()
        icon_bg.name = "Icon"
        icon_bg.custom_minimum_size = Vector2(50, 50)
        icon_bg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var icon_style = StyleBoxFlat.new()
        var colors = [Color(0.2,0.8,0.4), Color(0.9,0.6,0.2), Color(0.3,0.7,0.9), Color(0.4,0.6,0.9)]
        icon_style.bg_color = colors[i]
        icon_style.corner_radius_top_left = 25 # Circle
        icon_style.corner_radius_top_right = 25
        icon_style.corner_radius_bottom_right = 25
        icon_style.corner_radius_bottom_left = 25
        icon_bg.add_theme_stylebox_override("panel", icon_style)
        app_vbox.add_child(icon_bg)
        icon_bg.owner = root
        
        var app_label = Label.new()
        app_label.name = "Label"
        app_label.text = app_name
        app_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        app_label.add_theme_font_size_override("font_size", 12)
        app_label.add_theme_color_override("font_color", Color(1,1,1,0.8))
        app_vbox.add_child(app_label)
        app_label.owner = root

    # --- Home Button (Close) ---
    var home_margin = MarginContainer.new()
    home_margin.name = "HomeMargin"
    home_margin.add_theme_constant_override("margin_bottom", 15)
    vbox.add_child(home_margin)
    home_margin.owner = root

    var home_center = CenterContainer.new()
    home_center.name = "HomeCenter"
    home_margin.add_child(home_center)
    home_center.owner = root

    var close_button = Button.new()
    close_button.name = "CloseButton"
    close_button.custom_minimum_size = Vector2(80, 5)
    var home_style = StyleBoxFlat.new()
    home_style.bg_color = Color(1, 1, 1, 0.5)
    home_style.corner_radius_top_left = 5
    home_style.corner_radius_top_right = 5
    home_style.corner_radius_bottom_right = 5
    home_style.corner_radius_bottom_left = 5
    close_button.add_theme_stylebox_override("normal", home_style)
    close_button.add_theme_stylebox_override("hover", home_style)
    close_button.add_theme_stylebox_override("pressed", home_style)
    close_button.text = ""
    home_center.add_child(close_button)
    close_button.owner = root

    # Add Notch to phone_panel
    var notch_panel = Panel.new()
    notch_panel.name = "Notch"
    notch_panel.custom_minimum_size = Vector2(140, 25)
    notch_panel.anchors_preset = 5 # Top Center
    notch_panel.anchor_left = 0.5
    notch_panel.anchor_right = 0.5
    notch_panel.offset_left = -70
    notch_panel.offset_right = 70
    notch_panel.offset_bottom = 25
    var n_style = StyleBoxFlat.new()
    n_style.bg_color = Color(0.05, 0.05, 0.05, 1)
    n_style.corner_radius_bottom_left = 15
    n_style.corner_radius_bottom_right = 15
    notch_panel.add_theme_stylebox_override("panel", n_style)
    phone_panel.add_child(notch_panel)
    notch_panel.owner = root

    # AnimationPlayer
    var anim_player = AnimationPlayer.new()
    anim_player.name = "AnimationPlayer"
    
    var anim_lib = AnimationLibrary.new()
    
    var anim_reset = Animation.new()
    anim_reset.length = 0.001
    anim_reset.add_track(Animation.TYPE_VALUE)
    anim_reset.track_set_path(0, "PhonePanel:position")
    anim_reset.track_insert_key(0, 0.0, Vector2(440, 720))
    anim_reset.add_track(Animation.TYPE_VALUE)
    anim_reset.track_set_path(1, "ColorRect:color")
    anim_reset.track_insert_key(1, 0.0, Color(0,0,0,0))
    anim_lib.add_animation("RESET", anim_reset)

    var anim_up = Animation.new()
    anim_up.length = 0.3
    anim_up.add_track(Animation.TYPE_VALUE)
    anim_up.track_set_path(0, "PhonePanel:position")
    anim_up.track_insert_key(0, 0.0, Vector2(440, 720))
    anim_up.track_insert_key(0, 0.3, Vector2(440, 10))
    anim_up.track_set_interpolation_type(0, Animation.INTERPOLATION_CUBIC)
    anim_up.add_track(Animation.TYPE_VALUE)
    anim_up.track_set_path(1, "ColorRect:color")
    anim_up.track_insert_key(1, 0.0, Color(0,0,0,0))
    anim_up.track_insert_key(1, 0.3, Color(0,0,0,0.3))
    anim_lib.add_animation("slide_up", anim_up)

    var anim_down = Animation.new()
    anim_down.length = 0.2
    anim_down.add_track(Animation.TYPE_VALUE)
    anim_down.track_set_path(0, "PhonePanel:position")
    anim_down.track_insert_key(0, 0.0, Vector2(440, 10))
    anim_down.track_insert_key(0, 0.2, Vector2(440, 720))
    anim_down.track_set_interpolation_type(0, Animation.INTERPOLATION_CUBIC)
    anim_down.add_track(Animation.TYPE_VALUE)
    anim_down.track_set_path(1, "ColorRect:color")
    anim_down.track_insert_key(1, 0.0, Color(0,0,0,0.3))
    anim_down.track_insert_key(1, 0.2, Color(0,0,0,0))
    anim_lib.add_animation("slide_down", anim_down)

    anim_player.add_animation_library("", anim_lib)
    root.add_child(anim_player)
    anim_player.owner = root

    var packed_scene = PackedScene.new()
    packed_scene.pack(root)
    ResourceSaver.save(packed_scene, "res://scenes/ui/mobile/mobile_interface.tscn")
    quit()
