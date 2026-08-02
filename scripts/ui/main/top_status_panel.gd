extends PanelContainer

const INFO_POPUP_SCENE = preload("res://scenes/ui/common/info_popup.tscn")
const DELTA_GAIN_COLOR := Color(0.35, 1.0, 0.76, 1.0)
const DELTA_LOSS_COLOR := Color(1.0, 0.42, 0.38, 1.0)
const DELTA_FLOAT_DISTANCE := 28.0

@onready var gold_box = $MarginContainer/HBoxContainer/GoldSlot
@onready var energy_box = $MarginContainer/HBoxContainer/EnergySlot
@onready var energy_bg_panel: PanelContainer = $MarginContainer/HBoxContainer/EnergySlot/BgPanel

@onready var gold_icon = $MarginContainer/HBoxContainer/GoldSlot/IconControl/Icon
@onready var energy_icon = $MarginContainer/HBoxContainer/EnergySlot/IconControl/Icon

@onready var gold_label = $MarginContainer/HBoxContainer/GoldSlot/BgPanel/Margin/ValueLabel
@onready var energy_value = $MarginContainer/HBoxContainer/EnergySlot/BgPanel/Margin/ValueLabel
@onready var gold_delta_label: Label = $MarginContainer/HBoxContainer/GoldSlot/DeltaLabel
@onready var energy_delta_label: Label = $MarginContainer/HBoxContainer/EnergySlot/DeltaLabel

var _last_gold := 0
var _last_energy := 0
var _resource_values_initialized := false
var _gold_delta_tween: Tween
var _energy_delta_tween: Tween
var _gold_delta_base_position := Vector2.ZERO
var _energy_delta_base_position := Vector2.ZERO

func _ready() -> void:
    _gold_delta_base_position = gold_delta_label.position
    _energy_delta_base_position = energy_delta_label.position
    _update_ui()
    
    # Make boxes clickable
    gold_box.gui_input.connect(_on_gold_gui_input)
    energy_box.gui_input.connect(_on_energy_gui_input)
    
    gold_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    energy_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    
    if GameDataManager.profile:
        if not GameDataManager.profile.is_connected("profile_updated", _update_ui):
            GameDataManager.profile.profile_updated.connect(_update_ui)

func _process(_delta: float) -> void:
    if not _resource_values_initialized or not GameDataManager.profile:
        return
    if int(GameDataManager.profile.gold) != _last_gold or int(GameDataManager.profile.current_energy) != _last_energy:
        _update_ui()
    
func _update_ui() -> void:
    if not GameDataManager.profile:
        return
        
    var profile = GameDataManager.profile
    var current_gold := int(profile.gold)
    var current_energy := int(profile.current_energy)

    if _resource_values_initialized:
        _show_resource_delta(gold_delta_label, current_gold - _last_gold, true)
        _show_resource_delta(energy_delta_label, current_energy - _last_energy, false)
    else:
        _resource_values_initialized = true
    _last_gold = current_gold
    _last_energy = current_energy
    
    # Update Gold
    gold_label.text = str(current_gold) + "G"
    
    # Update Energy
    var max_en = profile.max_energy
    energy_value.text = str(current_energy) + "/" + str(max_en)

func _show_resource_delta(label: Label, delta: int, is_gold: bool) -> void:
    if delta == 0 or not is_instance_valid(label):
        return
    var active_tween := _gold_delta_tween if is_gold else _energy_delta_tween
    if active_tween != null and active_tween.is_valid():
        active_tween.kill()
    var base_position := _gold_delta_base_position if is_gold else _energy_delta_base_position
    label.text = "%+d" % delta
    label.add_theme_color_override("font_color", DELTA_GAIN_COLOR if delta > 0 else DELTA_LOSS_COLOR)
    label.position = base_position + Vector2(0.0, 4.0)
    label.modulate.a = 0.0
    label.show()
    var tween := create_tween().set_parallel(true)
    tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(label, "position", base_position + Vector2(0.0, -DELTA_FLOAT_DISTANCE), 0.9)
    tween.tween_property(label, "modulate:a", 1.0, 0.12)
    tween.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.6)
    tween.tween_callback(label.hide).set_delay(0.91)
    if is_gold:
        _gold_delta_tween = tween
    else:
        _energy_delta_tween = tween
    
func _on_gold_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        _show_info_popup("货币", gold_icon.texture, "用于在商店购买各类物品，或者进行某些特定活动。", str(GameDataManager.profile.gold))

func _on_energy_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        _show_info_popup("精力", energy_icon.texture, "用于大地图出行或进行各种日程安排，每回合会回复至满值。", "%d/%d" % [GameDataManager.profile.current_energy, GameDataManager.profile.max_energy])

func get_energy_guide_focus_target() -> Control:
    return energy_bg_panel

func _show_info_popup(item_name: String, icon: Texture2D, desc: String, owned: String) -> void:
    var popup = INFO_POPUP_SCENE.instantiate()
    get_tree().current_scene.add_child(popup)
    popup.setup("详情", item_name, icon, desc, owned)
