extends Panel

signal back_requested

@onready var back_button: Button = $BackButton
@onready var player_nickname_input: LineEdit = $Margin/VBox/Scroll/ContentVBox/BasicCard/Margin/VBox/PlayerNicknameRow/PlayerNicknameInput
@onready var disturbance_mode_option: OptionButton = $Margin/VBox/Scroll/ContentVBox/BasicCard/Margin/VBox/ModeRow/PetDisturbanceModeOption
@onready var quiet_ranges_input: LineEdit = $Margin/VBox/Scroll/ContentVBox/BasicCard/Margin/VBox/QuietTimeRow/PetQuietRangesInput

@onready var pet_global_cooldown_label: Label = $Margin/VBox/Scroll/ContentVBox/BehaviorCard/Margin/VBox/PetGlobalCooldownLabel
@onready var pet_global_cooldown_spin_box: SpinBox = $Margin/VBox/Scroll/ContentVBox/BehaviorCard/Margin/VBox/PetGlobalCooldownSpinBox
@onready var scroll_container: ScrollContainer = $Margin/VBox/Scroll

@onready var pet_enable_app_observe_check: CheckButton = $Margin/VBox/Scroll/ContentVBox/SwitchCard/Margin/VBox/PetEnableAppObserveCheck
@onready var pet_enable_hourly_chime_check: CheckButton = $Margin/VBox/Scroll/ContentVBox/SwitchCard/Margin/VBox/PetEnableHourlyChimeCheck
@onready var pet_enable_afk_greeting_check: CheckButton = $Margin/VBox/Scroll/ContentVBox/SwitchCard/Margin/VBox/PetEnableAfkGreetingCheck

@onready var pet_observe_allow_input: TextEdit = $Margin/VBox/Scroll/ContentVBox/PolicyCard/Margin/VBox/PetObserveAllowInput
@onready var pet_never_capture_input: TextEdit = $Margin/VBox/Scroll/ContentVBox/PolicyCard/Margin/VBox/PetNeverCaptureInput
@onready var pet_sensitive_window_input: TextEdit = $Margin/VBox/Scroll/ContentVBox/PolicyCard/Margin/VBox/PetSensitiveWindowInput

const PET_MODES := ["摸鱼模式", "专注模式", "安静模式", "深夜模式"]
var _is_loading_ui: bool = false

func _ready() -> void:
    back_button.pressed.connect(_on_back_pressed)
    disturbance_mode_option.clear()
    for mode_name in PET_MODES:
        disturbance_mode_option.add_item(mode_name)
    pet_global_cooldown_spin_box.value_changed.connect(_on_pet_cooldown_changed)
    scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    disturbance_mode_option.item_selected.connect(_on_pet_setting_changed)
    pet_enable_app_observe_check.toggled.connect(_on_pet_setting_toggled)
    pet_enable_hourly_chime_check.toggled.connect(_on_pet_setting_toggled)
    pet_enable_afk_greeting_check.toggled.connect(_on_pet_setting_toggled)
    player_nickname_input.text_submitted.connect(_on_text_setting_submitted)
    player_nickname_input.focus_exited.connect(_on_text_setting_focus_exited)
    quiet_ranges_input.text_submitted.connect(_on_text_setting_submitted)
    quiet_ranges_input.focus_exited.connect(_on_text_setting_focus_exited)
    pet_observe_allow_input.focus_exited.connect(_on_text_setting_focus_exited)
    pet_never_capture_input.focus_exited.connect(_on_text_setting_focus_exited)
    pet_sensitive_window_input.focus_exited.connect(_on_text_setting_focus_exited)
    visibility_changed.connect(_on_visibility_changed)
    _load_ui_data()

func _on_visibility_changed() -> void:
    if visible:
        _load_ui_data()
    elif not _is_loading_ui:
        save_settings()

func _load_ui_data() -> void:
    _is_loading_ui = true
    var config = GameDataManager.config
    player_nickname_input.text = config.player_nickname
    quiet_ranges_input.text = config.pet_quiet_time_ranges
    pet_observe_allow_input.text = config.pet_observe_allow_list
    pet_never_capture_input.text = config.pet_never_capture_list
    pet_sensitive_window_input.text = config.pet_sensitive_window_list
    pet_enable_app_observe_check.button_pressed = config.pet_enable_app_observe
    pet_enable_hourly_chime_check.button_pressed = config.pet_enable_hourly_chime
    pet_enable_afk_greeting_check.button_pressed = config.pet_enable_afk_greeting
    pet_global_cooldown_spin_box.value = config.pet_global_cooldown

    var selected_idx := PET_MODES.find(str(config.pet_disturbance_mode))
    disturbance_mode_option.select(selected_idx if selected_idx >= 0 else 0)
    _update_pet_labels()
    _is_loading_ui = false

func save_settings() -> void:
    if _is_loading_ui:
        return
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
    config.pet_global_cooldown = int(pet_global_cooldown_spin_box.value)
    config.save_config()
    config.apply_settings()
    _notify_pet_runtime_config_changed()

func _on_back_pressed() -> void:
    save_settings()
    back_requested.emit()

func _on_pet_cooldown_changed(_value: float) -> void:
    _update_pet_labels()
    if _is_loading_ui:
        return
    var config = GameDataManager.config
    config.pet_global_cooldown = int(pet_global_cooldown_spin_box.value)
    config.apply_settings()
    _notify_pet_runtime_config_changed()
    save_settings()

func _on_pet_setting_changed(_index: int) -> void:
    if _is_loading_ui:
        return
    save_settings()

func _on_pet_setting_toggled(_pressed: bool) -> void:
    if _is_loading_ui:
        return
    save_settings()

func _on_text_setting_submitted(_text: String) -> void:
    if _is_loading_ui:
        return
    save_settings()

func _on_text_setting_focus_exited() -> void:
    if _is_loading_ui:
        return
    save_settings()

func _notify_pet_runtime_config_changed() -> void:
    var root := get_tree().root
    for child in root.get_children():
        if child.name == "DesktopPet":
            if child.has_method("refresh_runtime_settings"):
                child.refresh_runtime_settings()
            var body = child.get_node_or_null("Control/PetBody")
            if body and body.has_method("_update_sprite_scale"):
                body._update_sprite_scale()

func _update_pet_labels() -> void:
    pet_global_cooldown_label.text = "全局最小冷却: %d 秒" % int(pet_global_cooldown_spin_box.value)
