extends Control

@onready var ring: Control = $Panel/MarginContainer/VBoxContainer/CenterContainer/Ring
@onready var mode_label: Label = $Panel/MarginContainer/VBoxContainer/CenterContainer/Ring/VBox/ModeLabel
@onready var time_label: Label = $Panel/MarginContainer/VBoxContainer/CenterContainer/Ring/VBox/TimeLabel
@onready var state_label: Label = $Panel/MarginContainer/VBoxContainer/CenterContainer/Ring/VBox/StateLabel
@onready var round_label: Label = $Panel/MarginContainer/VBoxContainer/CenterContainer/Ring/VBox/RoundLabel

@onready var play_btn: Button = $Panel/MarginContainer/VBoxContainer/Controls/PlayButton
@onready var pause_btn: Button = $Panel/MarginContainer/VBoxContainer/Controls/PauseButton
@onready var reset_btn: Button = $Panel/MarginContainer/VBoxContainer/Controls/ResetButton

@onready var work_spin: SpinBox = $Panel/MarginContainer/VBoxContainer/Settings/WorkSet/WorkSpin
@onready var rest_spin: SpinBox = $Panel/MarginContainer/VBoxContainer/Settings/RestSet/RestSpin
@onready var loop_spin: SpinBox = $Panel/MarginContainer/VBoxContainer/Settings/LoopSet/LoopSpin

@onready var close_btn: Button = $Panel/CloseButton

var timer: Timer
var time_left: int = 0
var total_time: int = 0
var current_state: String = "idle" # idle, work, rest
var current_round: int = 1
var max_rounds: int = 2

var WORK_COLOR = Color(1.0, 0.4, 0.4)
var REST_COLOR = Color(0.4, 1.0, 0.4)

func _ready() -> void:
    timer = Timer.new()
    timer.one_shot = false
    timer.timeout.connect(_on_timer_tick)
    add_child(timer)
    
    play_btn.pressed.connect(_on_play_pressed)
    pause_btn.pressed.connect(_on_pause_pressed)
    reset_btn.pressed.connect(_on_reset_pressed)
    close_btn.pressed.connect(queue_free)
    
    work_spin.value_changed.connect(_on_settings_changed)
    rest_spin.value_changed.connect(_on_settings_changed)
    loop_spin.value_changed.connect(_on_settings_changed)
    
    _load_settings()
    _reset_timer()

func _load_settings() -> void:
    if GameDataManager.pomodoro_data.has("work_duration"):
        work_spin.value = GameDataManager.pomodoro_data["work_duration"]
    if GameDataManager.pomodoro_data.has("break_duration"):
        rest_spin.value = GameDataManager.pomodoro_data["break_duration"]
    if GameDataManager.pomodoro_data.has("loops"):
        loop_spin.value = GameDataManager.pomodoro_data["loops"]
    max_rounds = int(loop_spin.value)

func _save_settings() -> void:
    GameDataManager.pomodoro_data["work_duration"] = int(work_spin.value)
    GameDataManager.pomodoro_data["break_duration"] = int(rest_spin.value)
    GameDataManager.pomodoro_data["loops"] = int(loop_spin.value)
    GameDataManager.save_pomodoro_data()

func _on_settings_changed(_val: float) -> void:
    max_rounds = int(loop_spin.value)
    _save_settings()
    if current_state == "idle":
        _reset_timer()

func _on_play_pressed() -> void:
    if current_state == "idle" or current_state == "paused":
        if current_state == "idle":
            _start_work()
        else:
            current_state = "work" if mode_label.text == "工作" else "rest"
            state_label.text = "进行中"
            timer.start(1.0)

func _start_work() -> void:
    current_state = "work"
    mode_label.text = "工作"
    state_label.text = "专注中"
    state_label.add_theme_color_override("font_color", WORK_COLOR)
    total_time = int(work_spin.value) * 60
    time_left = total_time
    round_label.text = "第 %d / %d 轮" % [current_round, max_rounds]
    _update_ui()
    timer.start(1.0)

func _start_rest() -> void:
    current_state = "rest"
    mode_label.text = "休息"
    state_label.text = "休息中"
    state_label.add_theme_color_override("font_color", REST_COLOR)
    total_time = int(rest_spin.value) * 60
    time_left = total_time
    _update_ui()
    timer.start(1.0)

func _on_pause_pressed() -> void:
    if current_state == "work" or current_state == "rest":
        current_state = "paused"
        state_label.text = "已暂停"
        state_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
        timer.stop()

func _on_reset_pressed() -> void:
    _reset_timer()

func _reset_timer() -> void:
    timer.stop()
    current_state = "idle"
    current_round = 1
    mode_label.text = "工作"
    state_label.text = "空闲中"
    state_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
    round_label.text = "第 %d / %d 轮" % [current_round, max_rounds]
    total_time = int(work_spin.value) * 60
    time_left = total_time
    _update_ui()

func _on_timer_tick() -> void:
    if time_left > 0:
        time_left -= 1
        _update_ui()
        
        if current_state == "work" and time_left % 60 == 0:
            GameDataManager.pomodoro_data["total_focus_time"] += 1
            GameDataManager.save_pomodoro_data()
    else:
        timer.stop()
        if current_state == "work":
            if current_round >= max_rounds:
                state_label.text = "全部完成！"
                current_state = "idle"
            else:
                _start_rest()
        elif current_state == "rest":
            current_round += 1
            _start_work()

func _update_ui() -> void:
    var m = int(time_left / 60)
    var s = int(time_left % 60)
    time_label.text = "%02d:%02d" % [m, s]
    
    var p = 0.0
    if total_time > 0:
        p = 1.0 - (float(time_left) / float(total_time))
    
    var color = WORK_COLOR if current_state == "work" else REST_COLOR
    if current_state == "idle" or current_state == "paused":
        color = Color(0.3, 0.7, 1.0) if mode_label.text == "工作" else REST_COLOR
        
    ring.set_progress(p, color)
