extends PanelContainer

@onready var stage_num_label: Label = $MarginContainer/VBoxContainer/Header/StageInfo/StageNumLabel
@onready var stage_title_label: Label = $MarginContainer/VBoxContainer/Header/StageInfo/StageTitleLabel
@onready var flavor_panel: PanelContainer = $MarginContainer/VBoxContainer/Header/FlavorBadge
@onready var flavor_label: Label = $MarginContainer/VBoxContainer/Header/FlavorBadge/Margin/FlavorLabel

@onready var intimacy_val: Label = $MarginContainer/VBoxContainer/ValuesRow/IntimacyBlock/IntimacyVal
@onready var trust_val: Label = $MarginContainer/VBoxContainer/ValuesRow/TrustBlock/TrustVal

@onready var resonance_bar: ProgressBar = $MarginContainer/VBoxContainer/ProgressSection/ResonanceBar
@onready var resonance_val: Label = $MarginContainer/VBoxContainer/ProgressSection/ResonanceBar/ValueLabel
@onready var milestone_lbl: Label = $MarginContainer/VBoxContainer/ProgressSection/MilestoneLabel

@onready var tooltip_panel: PanelContainer = $TooltipPanel
@onready var desc_label: Label = $TooltipPanel/Margin/DescLabel

var update_timer: Timer

func _ready() -> void:
	update_timer = Timer.new()
	update_timer.wait_time = 0.1
	update_timer.autostart = true
	update_timer.timeout.connect(update_ui)
	add_child(update_timer)
	
	# Tooltip events
	stage_num_label.mouse_entered.connect(_on_stage_hover_entered)
	stage_num_label.mouse_exited.connect(_on_stage_hover_exited)
	flavor_panel.mouse_entered.connect(_on_stage_hover_entered)
	flavor_panel.mouse_exited.connect(_on_stage_hover_exited)
	tooltip_panel.hide()
	
	update_ui()

func _on_stage_hover_entered() -> void:
	tooltip_panel.show()
	tooltip_panel.reset_size()
	tooltip_panel.global_position = stage_num_label.global_position - Vector2(tooltip_panel.size.x + 10, -20)
	
	var tween = create_tween()
	tooltip_panel.modulate.a = 0.0
	tween.tween_property(tooltip_panel, "modulate:a", 1.0, 0.2)

func _on_stage_hover_exited() -> void:
	var tween = create_tween()
	tween.tween_property(tooltip_panel, "modulate:a", 0.0, 0.2)
	tween.tween_callback(tooltip_panel.hide)

func set_bar_color(bar: ProgressBar, color: Color) -> void:
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = color
	stylebox.corner_radius_top_left = 6
	stylebox.corner_radius_top_right = 6
	stylebox.corner_radius_bottom_left = 6
	stylebox.corner_radius_bottom_right = 6
	bar.add_theme_stylebox_override("fill", stylebox)
	
	var bg_stylebox = StyleBoxFlat.new()
	bg_stylebox.bg_color = Color(0.1, 0.1, 0.1, 0.6)
	bg_stylebox.corner_radius_top_left = 6
	bg_stylebox.corner_radius_top_right = 6
	bg_stylebox.corner_radius_bottom_left = 6
	bg_stylebox.corner_radius_bottom_right = 6
	bar.add_theme_stylebox_override("background", bg_stylebox)

func update_ui() -> void:
	if not visible: return
	
	var profile = GameDataManager.profile
	var current_stage = profile.current_stage
	var conf = profile.get_current_stage_config()
	
	if conf.is_empty(): return
	
	stage_num_label.text = "STAGE %d" % current_stage
	stage_title_label.text = conf.get("stageTitle", conf.get("stageName", conf.get("name", "")))
	
	var I = max(profile.intimacy, 1.0)
	var T = max(profile.trust, 1.0)
	var flavor_name = "防备疏离"
	var flavor_color = Color("9e9e9e")
	var flavor_desc = ""
	
	if I >= T * 1.5 and I >= 30:
		flavor_name = "偏执迷恋"
		flavor_color = Color("e57373") # 偏红
		flavor_desc = "【风味】极度缺乏安全感，对你有着强烈的占有欲，患得患失。"
	elif T >= I * 1.5 and T >= 30:
		flavor_name = "灵魂知己"
		flavor_color = Color("64b5f6") # 偏蓝
		flavor_desc = "【风味】毫无防备的默契盟友，彼此完全信任，但暂无强烈的恋爱冲动。"
	elif I >= 50 and T >= 50:
		flavor_name = "灵魂伴侣"
		flavor_color = Color("f06292") # 偏粉
		flavor_desc = "【风味】极致的爱意与绝对的安全感，完全卸下伪装的专属依赖。"
	else:
		flavor_name = "防备疏离"
		flavor_color = Color("9e9e9e") # 灰色
		flavor_desc = "【风味】仍然保持着安全的社交距离，带着审视与戒备。"
		
	flavor_label.text = flavor_name
	
	var badge_style = StyleBoxFlat.new()
	badge_style.bg_color = flavor_color
	badge_style.corner_radius_top_left = 12
	badge_style.corner_radius_top_right = 12
	badge_style.corner_radius_bottom_left = 12
	badge_style.corner_radius_bottom_right = 12
	flavor_panel.add_theme_stylebox_override("panel", badge_style)
	
	var stage_desc = "【阶段】" + conf.get("stageDesc", conf.get("relationship_desc", conf.get("description", "")))
	desc_label.text = stage_desc + "\n\n" + flavor_desc
	
	intimacy_val.text = "%.1f" % profile.intimacy
	trust_val.text = "%.1f" % profile.trust
	
	var current_resonance = profile.intimacy + profile.trust
	var res_threshold = float(conf.get("resonance_threshold", 9999))
	var display_res_max = res_threshold
	if res_threshold >= 9999:
		display_res_max = max(current_resonance, 100)
	
	var res_display = "✨ 共感度: %.1f / MAX" % current_resonance if res_threshold >= 9999 else "✨ 共感度: %.1f / %d" % [current_resonance, int(res_threshold)]
	resonance_val.text = res_display
	resonance_bar.min_value = 0
	resonance_bar.max_value = display_res_max
	resonance_bar.value = min(current_resonance, display_res_max)
	set_bar_color(resonance_bar, flavor_color)
	
	var milestone_event = conf.get("milestone_event", "")
	if milestone_event == "" or current_stage >= 9:
		milestone_lbl.hide()
	else:
		milestone_lbl.show()
		var event_manager = get_tree().root.get_node_or_null("EventManager")
		if event_manager and event_manager.has_method("is_event_triggered") and event_manager.is_event_triggered(milestone_event):
			milestone_lbl.text = "📌 里程碑事件: 已达成"
			milestone_lbl.add_theme_color_override("font_color", Color("81c784")) # 绿
		else:
			milestone_lbl.text = "📌 里程碑事件: 尚未达成"
			milestone_lbl.add_theme_color_override("font_color", Color("e57373")) # 红

func show_panel() -> void:
	update_ui()
	show()
