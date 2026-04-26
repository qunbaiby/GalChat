extends PanelContainer

@onready var gold_label = $MarginContainer/HBoxContainer/GoldBox/ValueLabel
@onready var energy_value = $MarginContainer/HBoxContainer/EnergyBox/ProgressBar/ValueLabel
@onready var energy_progress = $MarginContainer/HBoxContainer/EnergyBox/ProgressBar
@onready var stress_value = $MarginContainer/HBoxContainer/StressBox/ProgressBar/ValueLabel
@onready var stress_progress = $MarginContainer/HBoxContainer/StressBox/ProgressBar

func _ready() -> void:
    _update_ui()
    # Connect to signals if there is a data change signal
    # Since there is no specific signal for these changes in GameDataManager yet, we'll update it whenever main scene updates
    
func _update_ui() -> void:
    if not GameDataManager.profile:
        return
        
    var profile = GameDataManager.profile
    
    # Update Gold
    gold_label.text = str(profile.gold) + "G"
    
    # Update Energy
    var curr_en = profile.current_energy
    var max_en = profile.max_energy
    energy_value.text = str(curr_en) + "/" + str(max_en)
    energy_progress.max_value = max_en
    energy_progress.value = curr_en
    
    # Update Stress
    var curr_stress = profile.stress
    var max_stress = profile.max_stress
    var stress_percent = (curr_stress / max_stress) * 100.0
    stress_value.text = str(int(stress_percent)) + "%"
    stress_progress.max_value = max_stress
    stress_progress.value = curr_stress
    
    # Colorize progress bars
    var energy_style = StyleBoxFlat.new()
    energy_style.bg_color = Color("#00a2e8") # Cyan blue
    energy_progress.add_theme_stylebox_override("fill", energy_style)
    
    var stress_style = StyleBoxFlat.new()
    stress_style.bg_color = Color("#ff7f27") # Orange
    stress_progress.add_theme_stylebox_override("fill", stress_style)
