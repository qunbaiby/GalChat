extends Control

@onready var energy_label: Label = $Panel/VBoxContainer/EnergyLabel
@onready var core_label: Label = $Panel/VBoxContainer/CoreLabel
@onready var basic_stats_label: RichTextLabel = $Panel/VBoxContainer/BasicStatsLabel
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)

func show_panel() -> void:
	_update_ui()
	show()

func _update_ui() -> void:
	var profile = GameDataManager.profile
	var stats = GameDataManager.stats_system
	
	energy_label.text = "当前精力：%.1f / %.1f" % [profile.current_energy, profile.max_energy]
	
	var core_p = stats.get_core_physical(profile)
	var core_i = stats.get_core_intelligence(profile)
	var core_c = stats.get_core_charm(profile)
	
	core_label.text = "【核心三维】\n体 (Physical): %d / 150\n智 (Intelligence): %d / 150\n魅 (Charm): %d / 150" % [core_p, core_i, core_c]
	
	var basic_text = "[b]【六大基础属性】[/b]\n\n"
	basic_text += "身体素质: %.1f / 2000\n" % profile.physical_fitness
	basic_text += "体能活力: %.1f / 2000\n\n" % profile.vitality
	basic_text += "学业素养: %.1f / 2000\n" % profile.academic_quality
	basic_text += "知识储备: %.1f / 2000\n\n" % profile.knowledge_reserve
	basic_text += "社交情商: %.1f / 2000\n" % profile.social_eq
	basic_text += "创意审美: %.1f / 2000" % profile.creative_aesthetics
	
	basic_stats_label.text = basic_text

func _on_close_pressed() -> void:
	hide()
