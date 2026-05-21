extends PanelContainer

const INFO_POPUP_SCENE = preload("res://scenes/ui/common/info_popup.tscn")

@onready var gold_box = $MarginContainer/HBoxContainer/GoldBox
@onready var energy_box = $MarginContainer/HBoxContainer/EnergyBox
@onready var mood_box = $MarginContainer/HBoxContainer/MoodBox
@onready var stress_box = $MarginContainer/HBoxContainer/StressBox

@onready var gold_icon = $MarginContainer/HBoxContainer/GoldBox/Icon
@onready var energy_icon = $MarginContainer/HBoxContainer/EnergyBox/Icon
@onready var mood_icon = $MarginContainer/HBoxContainer/MoodBox/Icon
@onready var stress_icon = $MarginContainer/HBoxContainer/StressBox/Icon

@onready var gold_label = $MarginContainer/HBoxContainer/GoldBox/ValueLabel
@onready var energy_value = $MarginContainer/HBoxContainer/EnergyBox/ProgressBar/ValueLabel
@onready var energy_progress = $MarginContainer/HBoxContainer/EnergyBox/ProgressBar
@onready var mood_value = $MarginContainer/HBoxContainer/MoodBox/ProgressBar/ValueLabel
@onready var mood_progress = $MarginContainer/HBoxContainer/MoodBox/ProgressBar
@onready var stress_value = $MarginContainer/HBoxContainer/StressBox/ProgressBar/ValueLabel
@onready var stress_progress = $MarginContainer/HBoxContainer/StressBox/ProgressBar

func _ready() -> void:
    _update_ui()
    
    # Make boxes clickable
    gold_box.gui_input.connect(_on_gold_gui_input)
    energy_box.gui_input.connect(_on_energy_gui_input)
    mood_box.gui_input.connect(_on_mood_gui_input)
    stress_box.gui_input.connect(_on_stress_gui_input)
    
    gold_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    energy_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    mood_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    stress_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    
    if GameDataManager.profile:
        if not GameDataManager.profile.is_connected("profile_updated", _update_ui):
            GameDataManager.profile.profile_updated.connect(_update_ui)
    
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
    
    # Update Mood
    var curr_mood = profile.mood_value
    var max_mood = 100.0 # mood_value 0-100
    var mood_percent = (curr_mood / max_mood) * 100.0
    mood_value.text = str(int(mood_percent)) + "%"
    mood_progress.max_value = max_mood
    mood_progress.value = curr_mood

func _on_gold_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        _show_info_popup("货币", gold_icon.texture, "用于在商店购买各类物品，或者进行某些特定活动。", str(GameDataManager.profile.gold))

func _on_energy_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        _show_info_popup("行动力", energy_icon.texture, "用于大地图出行或进行各种日程安排，每回合会回复至满值。", "%d/%d" % [GameDataManager.profile.current_energy, GameDataManager.profile.max_energy])

func _on_mood_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        var mood_percent = int(GameDataManager.profile.mood_value)
        _show_info_popup("心情", mood_icon.texture, "保持良好的心情可以提高各项活动的收益，降低则可能触发负面效果。", "%d%%" % mood_percent)

func _on_stress_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        var stress_percent = int((GameDataManager.profile.stress / GameDataManager.profile.max_stress) * 100.0)
        _show_info_popup("压力", stress_icon.texture, "过高的压力会导致负面事件发生，可以通过休息或特定活动来降低。", "%d%%" % stress_percent)

func _show_info_popup(item_name: String, icon: Texture2D, desc: String, owned: String) -> void:
    var popup = INFO_POPUP_SCENE.instantiate()
    get_tree().current_scene.add_child(popup)
    popup.setup("详情", item_name, icon, desc, owned)
