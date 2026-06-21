extends PanelContainer

signal back_requested

@onready var back_button: Button = $Margin/VBox/TopBar/BackButton
@onready var save_button: Button = $Margin/VBox/TopBar/SaveButton
@onready var player_nickname_input: LineEdit = $Margin/VBox/Scroll/ContentVBox/BasicCard/Margin/VBox/PlayerNicknameRow/PlayerNicknameInput
@onready var disturbance_mode_option: OptionButton = $Margin/VBox/Scroll/ContentVBox/BasicCard/Margin/VBox/ModeRow/PetDisturbanceModeOption
@onready var quiet_ranges_input: LineEdit = $Margin/VBox/Scroll/ContentVBox/BasicCard/Margin/VBox/QuietTimeRow/PetQuietRangesInput

@onready var pet_observe_time_label: Label = $Margin/VBox/Scroll/ContentVBox/BehaviorCard/Margin/VBox/PetObserveTimeLabel
@onready var pet_observe_time_slider: HSlider = $Margin/VBox/Scroll/ContentVBox/BehaviorCard/Margin/VBox/PetObserveTimeSlider
@onready var pet_same_app_cooldown_label: Label = $Margin/VBox/Scroll/ContentVBox/BehaviorCard/Margin/VBox/PetSameAppCooldownLabel
@onready var pet_same_app_cooldown_slider: HSlider = $Margin/VBox/Scroll/ContentVBox/BehaviorCard/Margin/VBox/PetSameAppCooldownSlider
@onready var pet_global_cooldown_label: Label = $Margin/VBox/Scroll/ContentVBox/BehaviorCard/Margin/VBox/PetGlobalCooldownLabel
@onready var pet_global_cooldown_slider: HSlider = $Margin/VBox/Scroll/ContentVBox/BehaviorCard/Margin/VBox/PetGlobalCooldownSlider
@onready var pet_scale_label: Label = $Margin/VBox/Scroll/ContentVBox/BehaviorCard/Margin/VBox/PetScaleLabel
@onready var pet_scale_slider: HSlider = $Margin/VBox/Scroll/ContentVBox/BehaviorCard/Margin/VBox/PetScaleSlider

@onready var pet_enable_app_observe_check: CheckButton = $Margin/VBox/Scroll/ContentVBox/SwitchCard/Margin/VBox/PetEnableAppObserveCheck
@onready var pet_enable_hourly_chime_check: CheckButton = $Margin/VBox/Scroll/ContentVBox/SwitchCard/Margin/VBox/PetEnableHourlyChimeCheck
@onready var pet_enable_afk_greeting_check: CheckButton = $Margin/VBox/Scroll/ContentVBox/SwitchCard/Margin/VBox/PetEnableAfkGreetingCheck

@onready var pet_observe_allow_input: TextEdit = $Margin/VBox/Scroll/ContentVBox/PolicyCard/Margin/VBox/PetObserveAllowInput
@onready var pet_never_capture_input: TextEdit = $Margin/VBox/Scroll/ContentVBox/PolicyCard/Margin/VBox/PetNeverCaptureInput
@onready var pet_sensitive_window_input: TextEdit = $Margin/VBox/Scroll/ContentVBox/PolicyCard/Margin/VBox/PetSensitiveWindowInput

const PET_MODES := ["摸鱼模式", "专注模式", "安静模式", "深夜模式"]

func _ready() -> void:
    back_button.pressed.connect(_on_back_pressed)
    save_button.pressed.connect(_on_save_pressed)
    disturbance_mode_option.clear()
    for mode_name in PET_MODES:
        disturbance_mode_option.add_item(mode_name)
    pet_observe_time_slider.value_changed.connect(_on_pet_slider_changed)
    pet_same_app_cooldown_slider.value_changed.connect(_on_pet_slider_changed)
    pet_global_cooldown_slider.value_changed.connect(_on_pet_slider_changed)
    pet_scale_slider.value_changed.connect(_on_pet_slider_changed)
    visibility_changed.connect(_on_visibility_changed)
    _load_ui_data()

func _on_visibility_changed() -> void:
    if visible:
        _load_ui_data()

func _load_ui_data() -> void:
    var config = GameDataManager.config
    player_nickname_input.text = config.player_nickname
    quiet_ranges_input.text = config.pet_quiet_time_ranges
    pet_observe_allow_input.text = config.pet_observe_allow_list
    pet_never_capture_input.text = config.pet_never_capture_list
    pet_sensitive_window_input.text = config.pet_sensitive_window_list
    pet_enable_app_observe_check.button_pressed = config.pet_enable_app_observe
    pet_enable_hourly_chime_check.button_pressed = config.pet_enable_hourly_chime
    pet_enable_afk_greeting_check.button_pressed = config.pet_enable_afk_greeting
    pet_observe_time_slider.value = config.pet_new_app_observe_time
    pet_same_app_cooldown_slider.value = config.pet_same_app_cooldown
    pet_global_cooldown_slider.value = config.pet_global_cooldown
    pet_scale_slider.value = config.pet_scale_multiplier

    var selected_idx := PET_MODES.find(str(config.pet_disturbance_mode))
    disturbance_mode_option.select(selected_idx if selected_idx >= 0 else 0)
    _update_pet_labels()

func save_settings() -> void:
    var config = GameDataManager.config
    config.player_nickname = player_nickname_input.text.strip_edges()
    config.pet_disturbance_mode = disturbance_mode_option.get_item_text(disturbance_mode_option.selected)
    config.pet_quiet_time_ranges = quiet_ranges_input.text.strip_edges()
    config.pet_observe_allow_list = pet_observe_allow_input.text.strip_edges()
    config.pet_never_capture_list = pet_never_capture_input.text.strip_edges()
    config.pet_sensitive_window_list = pet_sensitive_window_input.text.strip_edges()
    config.pet_enable_app_observe = pet_enable_app_observe_check.button_pressed
    config.pet_enable_hourly_chime = pet_enable_hourly_chime_check.button_pressed
    config.pet_enable_afk_greeting = pet_enable_afk_greeting_check.button_pressed
    config.pet_new_app_observe_time = int(pet_observe_time_slider.value)
    config.pet_same_app_cooldown = int(pet_same_app_cooldown_slider.value)
    config.pet_global_cooldown = int(pet_global_cooldown_slider.value)
    config.pet_scale_multiplier = float(pet_scale_slider.value)
    config.save_config()
    config.apply_settings()
    _notify_pet_scale_changed()

func _on_back_pressed() -> void:
    save_settings()
    back_requested.emit()

func _on_save_pressed() -> void:
    save_settings()

func _on_pet_slider_changed(_value: float) -> void:
    _update_pet_labels()
    _notify_pet_scale_changed()

func _notify_pet_scale_changed() -> void:
    var root := get_tree().root
    for child in root.get_children():
        if child.name == "DesktopPet":
            var body = child.get_node_or_null("Control/PetBody")
            if body and body.has_method("_update_sprite_scale"):
                body._update_sprite_scale()

func _update_pet_labels() -> void:
    pet_observe_time_label.text = "新应用观察时间: %d 秒" % int(pet_observe_time_slider.value)
    pet_same_app_cooldown_label.text = "同应用吐槽间隔: %d 秒" % int(pet_same_app_cooldown_slider.value)
    pet_global_cooldown_label.text = "全局最小冷却: %d 秒" % int(pet_global_cooldown_slider.value)
    pet_scale_label.text = "桌宠立绘缩放倍率: %.2fx" % float(pet_scale_slider.value)
