extends PanelContainer

@onready var emoji_label: Label = $MarginContainer/VBoxContainer/EmotionRow/EmojiLabel
@onready var title_label: Label = $MarginContainer/VBoxContainer/EmotionRow/TitleLabel
@onready var tooltip_panel: PanelContainer = $TooltipPanel
@onready var desc_label: Label = $TooltipPanel/Margin/DescLabel

@onready var intimacy_val: Label = $MarginContainer/VBoxContainer/IntimacyRow/ProgressBar/ValueLabel
@onready var intimacy_bar: ProgressBar = $MarginContainer/VBoxContainer/IntimacyRow/ProgressBar

@onready var trust_val: Label = $MarginContainer/VBoxContainer/TrustRow/ProgressBar/ValueLabel
@onready var trust_bar: ProgressBar = $MarginContainer/VBoxContainer/TrustRow/ProgressBar

@onready var exp_val: Label = $MarginContainer/VBoxContainer/ExpRow/ProgressBar/ValueLabel
@onready var exp_bar: ProgressBar = $MarginContainer/VBoxContainer/ExpRow/ProgressBar

var update_timer: Timer

func _ready() -> void:
    update_timer = Timer.new()
    update_timer.wait_time = 0.1
    update_timer.autostart = true
    update_timer.timeout.connect(update_ui)
    add_child(update_timer)
    
    # Tooltip events
    title_label.mouse_entered.connect(_on_stage_hover_entered)
    title_label.mouse_exited.connect(_on_stage_hover_exited)
    tooltip_panel.hide()
    
    update_ui()

func _on_stage_hover_entered() -> void:
    tooltip_panel.show()
    # Position tooltip near the title label explicitly (on its right side)
    tooltip_panel.global_position = title_label.global_position + Vector2(title_label.size.x + 10, -20)
    
    # Fade in animation
    tooltip_panel.modulate.a = 0.0
    var tween = create_tween()
    tween.tween_property(tooltip_panel, "modulate:a", 1.0, 0.2)

func _on_stage_hover_exited() -> void:
    var tween = create_tween()
    tween.tween_property(tooltip_panel, "modulate:a", 0.0, 0.2)
    tween.tween_callback(tooltip_panel.hide)


func get_stage_color(stage: int) -> Color:
    match stage:
        1: return Color("9e9e9e") # 初始 (灰色)
        2: return Color("81d4fa") # 拘谨 (浅蓝)
        3: return Color("4dd0e1") # 熟络 (青色)
        4: return Color("81c784") # 亲近 (浅绿)
        5: return Color("aed581") # 信赖 (绿色)
        6: return Color("fff176") # 暧昧 (浅黄)
        7: return Color("ffb74d") # 倾心 (橙色)
        8: return Color("f06292") # 热恋 (粉色)
        9: return Color("ba68c8") # 挚爱 (紫色)
        _: return Color.WHITE

func set_bar_color(bar: ProgressBar, color: Color) -> void:
    var stylebox = StyleBoxFlat.new()
    stylebox.bg_color = color
    bar.add_theme_stylebox_override("fill", stylebox)

func update_ui() -> void:
    if not visible: return
    
    var profile = GameDataManager.profile
    var current_stage = profile.current_stage
    var conf = profile.get_current_stage_config()
    
    if conf.is_empty(): return
    
    emoji_label.text = conf.get("emojiIcon", "")
    title_label.text = conf.get("stageTitle", "")
    desc_label.text = conf.get("stageDesc", "")
    
    var prev_stage = max(1, current_stage - 1)
    var prev_conf = profile.get_stage_config(prev_stage)
    var min_val = 0.0
    if current_stage > 1 and not prev_conf.is_empty():
        min_val = float(prev_conf.get("threshold", 0))
    
    var threshold = float(conf.get("threshold", 100))
    var display_max = threshold
    if threshold >= 9999: # 满级情况处理
        display_max = min_val + 500 # 给进度条一个虚拟的最大值用于显示
        
    var stage_color = get_stage_color(current_stage)
    set_bar_color(intimacy_bar, stage_color)
    set_bar_color(trust_bar, stage_color)
    set_bar_color(exp_bar, stage_color)
        
    var int_display = "%.1f / %d" % [profile.intimacy, int(display_max)] if threshold >= 9999 else "%.1f / %d" % [profile.intimacy, int(threshold)]
    intimacy_val.text = int_display
    intimacy_bar.min_value = 0
    intimacy_bar.max_value = display_max
    intimacy_bar.value = min(profile.intimacy, display_max)
    
    var trust_display = "%.1f / %d" % [profile.trust, int(display_max)] if threshold >= 9999 else "%.1f / %d" % [profile.trust, int(threshold)]
    trust_val.text = trust_display
    trust_bar.min_value = 0
    trust_bar.max_value = display_max
    trust_bar.value = min(profile.trust, display_max)
    
    var exp_display = "%d / %d" % [profile.interaction_exp, int(display_max)] if threshold >= 9999 else "%d / %d" % [profile.interaction_exp, int(threshold)]
    exp_val.text = exp_display
    exp_bar.min_value = 0
    exp_bar.max_value = display_max
    exp_bar.value = min(profile.interaction_exp, display_max)

func show_panel() -> void:
    update_ui()
    show()
