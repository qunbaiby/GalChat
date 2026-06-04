extends PanelContainer

const INFO_POPUP_SCENE = preload("res://scenes/ui/common/info_popup.tscn")

@onready var gold_box = $MarginContainer/HBoxContainer/GoldSlot
@onready var energy_box = $MarginContainer/HBoxContainer/EnergySlot
@onready var stress_box = $MarginContainer/HBoxContainer/StressSlot

@onready var gold_icon = $MarginContainer/HBoxContainer/GoldSlot/IconControl/Icon
@onready var energy_icon = $MarginContainer/HBoxContainer/EnergySlot/IconControl/Icon
@onready var stress_icon = $MarginContainer/HBoxContainer/StressSlot/IconControl/Icon

@onready var gold_label = $MarginContainer/HBoxContainer/GoldSlot/BgPanel/Margin/ValueLabel
@onready var energy_value = $MarginContainer/HBoxContainer/EnergySlot/BgPanel/Margin/ValueLabel
@onready var stress_value = $MarginContainer/HBoxContainer/StressSlot/BgPanel/Margin/ValueLabel

func _ready() -> void:
    _update_ui()
    
    # Make boxes clickable
    gold_box.gui_input.connect(_on_gold_gui_input)
    energy_box.gui_input.connect(_on_energy_gui_input)
    stress_box.gui_input.connect(_on_stress_gui_input)
    
    gold_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    energy_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
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
    
    # Update Stress
    stress_value.text = str(int(profile.stress))
    
func _on_gold_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        _show_info_popup("货币", gold_icon.texture, "用于在商店购买各类物品，或者进行某些特定活动。", str(GameDataManager.profile.gold))

func _on_energy_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        _show_info_popup("行动力", energy_icon.texture, "用于大地图出行或进行各种日程安排，每回合会回复至满值。", "%d/%d" % [GameDataManager.profile.current_energy, GameDataManager.profile.max_energy])

func _on_stress_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        var stress_val = int(GameDataManager.profile.stress)
        _show_info_popup("压力", stress_icon.texture, "过高的压力会导致负面事件发生，可以通过休息或特定活动来降低。", str(stress_val))

func _show_info_popup(item_name: String, icon: Texture2D, desc: String, owned: String) -> void:
    var popup = INFO_POPUP_SCENE.instantiate()
    get_tree().current_scene.add_child(popup)
    popup.setup("详情", item_name, icon, desc, owned)
