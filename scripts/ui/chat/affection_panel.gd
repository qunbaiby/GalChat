extends Control

@onready var emoji_label: Label = $CenterContainer/Panel/VBoxContainer/HeaderBox/EmojiLabel
@onready var stage_label: Label = $CenterContainer/Panel/VBoxContainer/HeaderBox/StageLabel
@onready var title_label: Label = $CenterContainer/Panel/VBoxContainer/TitleLabel
@onready var desc_label: Label = $CenterContainer/Panel/VBoxContainer/DescLabel

@onready var intimacy_val: Label = $CenterContainer/Panel/VBoxContainer/StatsBox/IntimacyBox/LabelBox/Value
@onready var intimacy_bar: ProgressBar = $CenterContainer/Panel/VBoxContainer/StatsBox/IntimacyBox/ProgressBar

@onready var trust_val: Label = $CenterContainer/Panel/VBoxContainer/StatsBox/TrustBox/LabelBox/Value
@onready var trust_bar: ProgressBar = $CenterContainer/Panel/VBoxContainer/StatsBox/TrustBox/ProgressBar

@onready var exp_val: Label = $CenterContainer/Panel/VBoxContainer/StatsBox/ExpBox/LabelBox/Value
@onready var exp_bar: ProgressBar = $CenterContainer/Panel/VBoxContainer/StatsBox/ExpBox/ProgressBar

@onready var close_btn: Button = $CenterContainer/Panel/VBoxContainer/CloseButton

var update_timer: Timer

func _ready() -> void:
    close_btn.pressed.connect(_on_close_pressed)
    
    update_timer = Timer.new()
    update_timer.wait_time = 0.1
    update_timer.autostart = true
    update_timer.timeout.connect(update_ui)
    add_child(update_timer)
    
    update_ui()

func _on_close_pressed() -> void:
    hide()

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

@onready var blur_bg: TextureRect = $BlurBackground

func update_ui() -> void:
    if not visible: return
    
    var profile = GameDataManager.profile
    var current_stage = profile.current_stage
    var conf = profile.get_current_stage_config()
    
    if conf.is_empty(): return
    
    var sprite_path = GameDataManager.mood_system.get_mood_sprite_path(profile.current_mood)
    if sprite_path != "":
        # 如果是本地项目中的 .png，通过 load() 获取
        var tex = load(sprite_path)
        if tex:
            blur_bg.texture = tex
    
    emoji_label.text = conf.get("emojiIcon", "")
    stage_label.text = "Stage " + str(current_stage)
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
