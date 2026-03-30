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
    if stage <= 2:
        return Color.CYAN
    elif stage <= 4:
        return Color.GREEN
    elif stage <= 6:
        return Color.ORANGE
    else:
        return Color.PURPLE

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
        
    var int_display = "%.1f / MAX" % profile.intimacy if threshold >= 9999 else "%.1f / %d" % [profile.intimacy, int(threshold)]
    intimacy_val.text = int_display
    intimacy_bar.min_value = min_val
    intimacy_bar.max_value = display_max
    intimacy_bar.value = min(profile.intimacy, display_max)
    
    var trust_display = "%.1f / MAX" % profile.trust if threshold >= 9999 else "%.1f / %d" % [profile.trust, int(threshold)]
    trust_val.text = trust_display
    trust_bar.min_value = min_val
    trust_bar.max_value = display_max
    trust_bar.value = min(profile.trust, display_max)
    
    var exp_display = "%d / MAX" % profile.interaction_exp if threshold >= 9999 else "%d / %d" % [profile.interaction_exp, int(threshold)]
    exp_val.text = exp_display
    exp_bar.min_value = min_val
    exp_bar.max_value = display_max
    exp_bar.value = min(profile.interaction_exp, display_max)
    
    var color = get_stage_color(current_stage)
    set_bar_color(intimacy_bar, color)
    set_bar_color(trust_bar, color)
    set_bar_color(exp_bar, color)

func show_panel() -> void:
    update_ui()
    show()
