extends Window

@onready var input_edit: TextEdit = $Control/InputLayer/MarginContainer/HBoxContainer/InputField
@onready var send_button: Button = $Control/InputLayer/MarginContainer/HBoxContainer/SendButton
@onready var quick_tools_panel: PanelContainer = $Control/QuickToolsPanel
@onready var dashboard_root: Control = $Control/QuickToolsPanel/MarginContainer/VBoxContainer/Screen/ScreenMargin/ScreenStack/DashboardRoot
@onready var tool_title_label: Label = $Control/QuickToolsPanel/MarginContainer/VBoxContainer/Screen/ScreenMargin/ScreenStack/DashboardRoot/TimeWidget/MarginContainer/HeaderRow/InfoVBox/DatePill/DateMargin/Title
@onready var tool_subtitle_label: Label = $Control/QuickToolsPanel/MarginContainer/VBoxContainer/Screen/ScreenMargin/ScreenStack/DashboardRoot/TimeWidget/MarginContainer/HeaderRow/InfoVBox/WeekPill/WeekMargin/SubTitle
@onready var tool_clock_label: Label = $Control/QuickToolsPanel/MarginContainer/VBoxContainer/Screen/ScreenMargin/ScreenStack/DashboardRoot/TimeWidget/MarginContainer/HeaderRow/InfoVBox/ClockLabel
@onready var tool_mode_chip: Label = get_node_or_null("Control/QuickToolsPanel/MarginContainer/VBoxContainer/Screen/ScreenMargin/ScreenStack/DashboardRoot/TimeWidget/MarginContainer/HeaderRow/ModeChip") as Label
@onready var main_window_button: Button = $Control/QuickToolsPanel/MarginContainer/VBoxContainer/Screen/ScreenMargin/ScreenStack/DashboardRoot/ToolButtons/MainWindowButton
@onready var dialogue_button: Button = $Control/QuickToolsPanel/MarginContainer/VBoxContainer/Screen/ScreenMargin/ScreenStack/DashboardRoot/PrimaryButtons/DialogueButton
@onready var pet_settings_button: Button = get_node_or_null("Control/QuickToolsPanel/MarginContainer/VBoxContainer/Screen/ScreenMargin/ScreenStack/DashboardRoot/ToolButtons/PetSettingsButton") as Button
@onready var close_button: Button = $Control/QuickToolsPanel/MarginContainer/VBoxContainer/Screen/ScreenMargin/ScreenStack/DashboardRoot/OtherButtons/CloseButton
@onready var pomodoro_toggle_button: Button = $Control/QuickToolsPanel/MarginContainer/VBoxContainer/Screen/ScreenMargin/ScreenStack/DashboardRoot/PrimaryButtons/PomodoroToggleButton
@onready var music_toggle_button: Button = $Control/QuickToolsPanel/MarginContainer/VBoxContainer/Screen/ScreenMargin/ScreenStack/DashboardRoot/PrimaryButtons/MusicToggleButton
@onready var mute_button: Button = $Control/QuickToolsPanel/MarginContainer/VBoxContainer/Screen/ScreenMargin/ScreenStack/DashboardRoot/ToolButtons/MuteButton
@onready var hide_tool_button: Button = $Control/QuickToolsPanel/MarginContainer/VBoxContainer/Screen/ScreenMargin/ScreenStack/DashboardRoot/HideToolButton
@onready var pomodoro_panel_host: Control = $Control/QuickToolsPanel/MarginContainer/VBoxContainer/Screen/ScreenMargin/ScreenStack/PomodoroPanelHost
@onready var music_panel_host: Control = $Control/QuickToolsPanel/MarginContainer/VBoxContainer/Screen/ScreenMargin/ScreenStack/MusicPanelHost
@onready var settings_panel_host: Control = get_node_or_null("Control/QuickToolsPanel/MarginContainer/VBoxContainer/Screen/ScreenMargin/ScreenStack/SettingsPanelHost") as Control

@onready var input_layer: PanelContainer = $Control/InputLayer
@onready var voice_record_button: Button = $Control/InputLayer/MarginContainer/HBoxContainer/VoiceRecordButton
@onready var close_input_button: Button = $Control/InputLayer/MarginContainer/HBoxContainer/Close

@onready var deepseek_client: DeepSeekClient = $DeepSeekClient
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var mic_capture: AudioStreamPlayer = $MicCapture
@onready var music_player: AudioStreamPlayer = $MusicPlayer


var qwen_asr_client = null
@onready var pet_body = get_node_or_null("Control/PetBody")

var dragging: bool = false
var drag_offset: Vector2i = Vector2i.ZERO

var pet_prompt: String = ""
var is_chatting: bool = false
var current_response: String = ""
var chat_history: Array = []
var _current_character_id: String = ""

var is_processing_bubbles: bool = false
var bubble_queue: Array = []
var _tts_finished: bool = false

# 高级特性状态变量
var _last_reaction_tick: int = 0
var _last_hourly_chime_hour: int = -1
var _poll_timer: Timer
var _ready_tick_msec: int = 0

# 积压任务队列
var _pending_proactive_prompt: String = ""
var _is_afk: bool = false

# 应用识别相关状态变量
var _window_detector: Node
var _time_since_last_switch: float = 0.0
var _current_app_name: String = ""
var _last_chatted_app: String = ""

var is_dialogue_panel_open: bool = false
var _spectrum_analyzer: AudioEffectSpectrumAnalyzerInstance
var is_standalone_mode: bool = false
var _pomodoro_panel_instance: Control = null
var _music_panel_instance: Control = null
var _settings_panel_instance: Control = null
var _active_tool_key: String = ""
var _root_window_parked: bool = false
var _root_window_saved_position: Vector2i = Vector2i.ZERO
var _root_window_saved_size: Vector2i = Vector2i.ZERO
var _root_window_saved_mode: int = Window.MODE_WINDOWED

const PET_MODE_QUIET := "安静模式"
const PET_MODE_FOCUS := "专注模式"
const PET_MODE_LOAF := "摸鱼模式"
const PET_MODE_NIGHT := "深夜模式"
const SOFT_REMINDER_APP_TYPES := ["通讯聊天软件", "办公文档软件"]

func _ready() -> void:
	_current_character_id = GameDataManager.config.current_character_id
	_ready_tick_msec = Time.get_ticks_msec()
	# 初始化上次交互时间为 0，避免启动后立刻触发被拦截
	# _last_reaction_tick = 0
	
	# 设置窗口属性：无边框透明
	transparent_bg = true
	transparent = true
	borderless = true
	always_on_top = true
	unresizable = true
	transient = false
	exclusive = false
	
	# 设置为小窗口大小
	var target_size = Vector2i(1280, 720)
	size = target_size
	
	# 获取当前鼠标所在的屏幕索引
	var screen_idx = DisplayServer.get_screen_from_rect(Rect2i(DisplayServer.mouse_get_position(), Vector2i.ONE))
	var screen_rect = DisplayServer.screen_get_usable_rect(screen_idx)
	
	# 初始位置：右下角
	var init_pos = Vector2i(screen_rect.end.x - target_size.x - 20, screen_rect.end.y - target_size.y - 20)
	position = init_pos
	
	# 确保内部 Control 占满整个小窗口
	var control_node = $Control
	control_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	control_node.size = Vector2(1280, 720)
	control_node.position = Vector2.ZERO
	
	if is_standalone_mode:
		pass # 不再修改文字，保持 "主界面"
		
	input_layer.hide()
	quick_tools_panel.hide()
	pomodoro_panel_host.hide()
	music_panel_host.hide()
	if settings_panel_host:
		settings_panel_host.hide()
	quick_tools_panel.gui_input.connect(_on_tool_panel_gui_input)
	pomodoro_panel_host.gui_input.connect(_on_tool_panel_gui_input)
	music_panel_host.gui_input.connect(_on_tool_panel_gui_input)
	if settings_panel_host:
		settings_panel_host.gui_input.connect(_on_tool_panel_gui_input)
	
	# TTSManager 已在全局自动处理配置，这里不需要额外配置
	
	# 连接信号
	send_button.pressed.connect(_on_send_pressed)
	main_window_button.pressed.connect(_on_main_window_pressed)
	close_button.pressed.connect(_on_close_pressed)
	dialogue_button.pressed.connect(_on_dialogue_button_pressed)
	if pet_settings_button:
		pet_settings_button.pressed.connect(_on_pet_settings_pressed)
	close_input_button.pressed.connect(_on_close_input_pressed)
	voice_record_button.button_down.connect(_on_voice_record_down)
	voice_record_button.button_up.connect(_on_voice_record_up)
	pomodoro_toggle_button.pressed.connect(_on_pomodoro_toggle_pressed)
	music_toggle_button.pressed.connect(_on_music_toggle_pressed)
	mute_button.pressed.connect(_on_mute_button_pressed)
	hide_tool_button.pressed.connect(func(): _set_menu_visible(false))
	
	if GameDataManager.config.qwen_asr_enabled:
		var QwenASRClient = load("res://scripts/api/qwen_asr_client.gd")
		if QwenASRClient:
			qwen_asr_client = QwenASRClient.new()
			qwen_asr_client.name = "QwenASRClient"
			add_child(qwen_asr_client)
			qwen_asr_client.transcribe_completed.connect(_on_asr_success)
			qwen_asr_client.transcribe_failed.connect(_on_asr_failed)
		
	# 注意：TextEdit 没有 text_submitted，因此我们需要在 _input 里面监听回车或者单独处理。这里先移除之前的 line_edit 特有信号。
	# 监听 text_changed 拦截换行
	input_edit.text_changed.connect(_on_input_text_changed)
	
	# 增加一个定时器，每秒强制更新一次鼠标穿透状态，防止在等待或状态切换时意外失去穿透
	var passthrough_timer = Timer.new()
	passthrough_timer.wait_time = 1.0
	passthrough_timer.autostart = true
	passthrough_timer.timeout.connect(_update_mouse_passthrough)
	add_child(passthrough_timer)
	
	deepseek_client.chat_stream_started.connect(_on_chat_started)
	deepseek_client.chat_stream_delta.connect(_on_chat_delta)
	deepseek_client.chat_request_completed.connect(_on_chat_completed)
	deepseek_client.chat_request_failed.connect(_on_chat_failed)
	
	deepseek_client.vision_request_completed.connect(_on_vision_completed)
	deepseek_client.vision_request_failed.connect(_on_vision_failed)
	
	TTSManager.tts_success.connect(_on_tts_success)
	TTSManager.tts_failed.connect(_on_tts_failed)
	
	# 获取音频分析器用于绘制波形环
	var bus_idx = AudioServer.get_bus_index("Voice")
	if bus_idx >= 0:
		for i in range(AudioServer.get_bus_effect_count(bus_idx)):
			var effect = AudioServer.get_bus_effect(bus_idx, i)
			if effect is AudioEffectSpectrumAnalyzer:
				_spectrum_analyzer = AudioServer.get_bus_effect_instance(bus_idx, i)
				break
	
	_load_prompt()
	
	# 连接 Control 面板的输入信号以处理拖拽
	control_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 初始化轮询定时器
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 1.0 # 改为1秒以便更平滑地显示倒计时
	_poll_timer.autostart = true
	_poll_timer.timeout.connect(_on_poll_timer_timeout)
	add_child(_poll_timer)
	
	if pet_body:
		pet_body.bubbles_changed.connect(func(): call_deferred("_update_mouse_passthrough"))
		pet_body.pet_clicked.connect(_trigger_pet_touch)
	
	input_layer.visibility_changed.connect(func(): call_deferred("_update_mouse_passthrough"))
	quick_tools_panel.visibility_changed.connect(func(): call_deferred("_update_mouse_passthrough"))
	pomodoro_panel_host.visibility_changed.connect(func(): call_deferred("_update_mouse_passthrough"))
	music_panel_host.visibility_changed.connect(func(): call_deferred("_update_mouse_passthrough"))
	if settings_panel_host:
		settings_panel_host.visibility_changed.connect(func(): call_deferred("_update_mouse_passthrough"))

	_load_quick_tool_state()
	
	# 初始化时延迟调用以更新鼠标穿透区域
	call_deferred("_update_mouse_passthrough")
	call_deferred("_sync_root_window_focusability")
	
	# 实例化 WindowDetector (通过字符串路径加载，避免非 C# 版本下报错)
	var window_detector_path = "res://scripts/csharp/WindowDetector.cs"
	if FileAccess.file_exists(window_detector_path):
		var WindowDetectorObj = load(window_detector_path)
		if WindowDetectorObj:
			_window_detector = WindowDetectorObj.new()
			add_child(_window_detector)
	else:
		pass
	
	# 延迟一帧后显示窗口，以防止初次渲染的黑/灰块
	call_deferred("show")

func _load_quick_tool_state() -> void:
	_update_mute_button()
	_update_mode_chip()
	_update_panel_clock()

func _set_menu_visible(visible_state: bool) -> void:
	quick_tools_panel.visible = visible_state
	if visible_state:
		_hide_side_tool_panels()
		_update_panel_clock()
	else:
		_hide_side_tool_panels()

func _get_pet_body_local_rect() -> Rect2:
	if pet_body and pet_body.has_method("get_body_global_rect"):
		var body_rect: Rect2 = pet_body.get_body_global_rect()
		if body_rect.size.x > 0.0 and body_rect.size.y > 0.0:
			# Control.get_global_rect() 在这里返回的是桌宠窗口内部坐标，不需要再减窗口屏幕坐标
			return body_rect
	return Rect2(Vector2.ZERO, Vector2(size))

func _clamp_window_position_to_pet_body(target_pos: Vector2i, screen_rect: Rect2i) -> Vector2i:
	var body_local_rect := _get_pet_body_local_rect()
	var min_x := int(round(screen_rect.position.x - body_local_rect.position.x))
	var max_x := int(round(screen_rect.end.x - body_local_rect.end.x))
	var min_y := int(round(screen_rect.position.y - body_local_rect.position.y))
	var max_y := int(round(screen_rect.end.y - body_local_rect.end.y))
	var clamped_pos := target_pos
	
	if min_x > max_x:
		clamped_pos.x = min_x
	else:
		clamped_pos.x = clampi(clamped_pos.x, min_x, max_x)
	
	if min_y > max_y:
		clamped_pos.y = min_y
	else:
		clamped_pos.y = clampi(clamped_pos.y, min_y, max_y)
	
	return clamped_pos

func _get_pomodoro_panel_instance() -> Control:
	if is_instance_valid(_pomodoro_panel_instance):
		return _pomodoro_panel_instance
	var panel_scene := load("res://scenes/ui/desktop_pet/pomodoro_panel.tscn")
	if panel_scene == null:
		return null
	_pomodoro_panel_instance = panel_scene.instantiate()
	_pomodoro_panel_instance.visible = false
	pomodoro_panel_host.add_child(_pomodoro_panel_instance)
	_pomodoro_panel_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pomodoro_panel_instance.position = Vector2.ZERO
	_pomodoro_panel_instance.size = pomodoro_panel_host.size
	if _pomodoro_panel_instance.has_signal("back_requested"):
		_pomodoro_panel_instance.back_requested.connect(_hide_side_tool_panels)
	return _pomodoro_panel_instance

func _get_music_panel_instance() -> Control:
	if is_instance_valid(_music_panel_instance):
		return _music_panel_instance
	var panel_scene := load("res://scenes/ui/desktop_pet/desktop_pet_music_panel.tscn")
	if panel_scene == null:
		return null
	_music_panel_instance = panel_scene.instantiate()
	_music_panel_instance.visible = false
	music_panel_host.add_child(_music_panel_instance)
	if _music_panel_instance is Control:
		(_music_panel_instance as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
		(_music_panel_instance as Control).position = Vector2.ZERO
		(_music_panel_instance as Control).size = music_panel_host.size
	if _music_panel_instance.has_signal("back_requested"):
		_music_panel_instance.back_requested.connect(_hide_side_tool_panels)
	return _music_panel_instance

func _get_settings_panel_instance() -> Control:
	if is_instance_valid(_settings_panel_instance):
		return _settings_panel_instance
	if settings_panel_host == null:
		return null
	var panel_scene := load("res://scenes/ui/desktop_pet/desktop_pet_settings_panel.tscn")
	if panel_scene == null:
		return null
	_settings_panel_instance = panel_scene.instantiate()
	_settings_panel_instance.visible = false
	settings_panel_host.add_child(_settings_panel_instance)
	if _settings_panel_instance is Control:
		(_settings_panel_instance as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
		(_settings_panel_instance as Control).position = Vector2.ZERO
		(_settings_panel_instance as Control).size = settings_panel_host.size
	if _settings_panel_instance.has_signal("back_requested"):
		_settings_panel_instance.back_requested.connect(_hide_side_tool_panels)
	return _settings_panel_instance

func _update_mode_chip() -> void:
	if tool_mode_chip == null:
		return
	tool_mode_chip.text = _get_pet_mode()

func _update_panel_clock() -> void:
	if tool_title_label == null or tool_subtitle_label == null or tool_clock_label == null:
		return
	var time_dict := Time.get_datetime_dict_from_system()
	var weekday_names := ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]
	var weekday_idx := int(time_dict.get("weekday", 0))
	weekday_idx = clampi(weekday_idx, 0, weekday_names.size() - 1)
	var hour := int(time_dict.get("hour", 0))
	var minute := int(time_dict.get("minute", 0))
	tool_title_label.text = "%04d.%02d.%02d" % [
		int(time_dict.get("year", 0)),
		int(time_dict.get("month", 0)),
		int(time_dict.get("day", 0))
	]
	tool_subtitle_label.text = weekday_names[weekday_idx]
	tool_clock_label.text = "%02d:%02d" % [hour, minute]

func _get_clock_greeting(hour: int) -> String:
	if hour < 6:
		return "夜深了，别忘记休息。"
	if hour < 11:
		return "早安，今天也一起加油。"
	if hour < 14:
		return "中午啦，记得吃饭。"
	if hour < 19:
		return "下午时间，慢慢推进就好。"
	return "晚上也有我陪着你。"

func _update_mute_button() -> void:
	if mute_button == null:
		return
	if _is_pet_temporarily_muted():
		var remain_minutes := maxi(1, int(ceil(float(GameDataManager.config.pet_muted_until_unix - int(Time.get_unix_time_from_system())) / 60.0)))
		mute_button.text = "取消静音(%d分)" % remain_minutes
	else:
		mute_button.text = "静音30分"

func _on_pomodoro_toggle_pressed() -> void:
	_consume_desktop_pet_ui_input()
	var panel = _get_pomodoro_panel_instance()
	_set_menu_visible(true)
	_show_side_tool_panel("pomodoro", panel)

func _on_music_toggle_pressed() -> void:
	_consume_desktop_pet_ui_input()
	_open_music_panel(false)

func _on_pet_settings_pressed() -> void:
	_consume_desktop_pet_ui_input()
	var panel = _get_settings_panel_instance()
	_set_menu_visible(true)
	_show_side_tool_panel("settings", panel)

func _on_mute_button_pressed() -> void:
	if GameDataManager == null or GameDataManager.config == null:
		return
	if _is_pet_temporarily_muted():
		GameDataManager.config.pet_muted_until_unix = 0
	else:
		GameDataManager.config.pet_muted_until_unix = int(Time.get_unix_time_from_system()) + 1800
	GameDataManager.config.save_config()
	_update_mute_button()
	_update_mode_chip()

func _show_side_tool_panel(tool_key: String, panel: Control) -> void:
	if panel == null:
		return
	if not quick_tools_panel.visible:
		quick_tools_panel.show()
	if _active_tool_key == tool_key and panel.visible:
		_hide_side_tool_panels()
		return
	_hide_side_tool_panels()
	if dashboard_root:
		dashboard_root.hide()
	match tool_key:
		"pomodoro":
			pomodoro_panel_host.show()
		"music":
			music_panel_host.show()
		"settings":
			if settings_panel_host:
				settings_panel_host.show()
		_:
			pass
	panel.show()
	_active_tool_key = tool_key
	call_deferred("_update_mouse_passthrough")

func _open_music_panel(force_open: bool = true) -> void:
	var panel = _get_music_panel_instance()
	if panel and panel.has_method("set_audio_player"):
		panel.set_audio_player(music_player)
	if not quick_tools_panel.visible:
		quick_tools_panel.show()
	_update_panel_clock()
	if force_open and panel:
		_hide_side_tool_panels()
		if dashboard_root:
			dashboard_root.hide()
		music_panel_host.show()
		panel.show()
		_active_tool_key = "music"
		call_deferred("_update_mouse_passthrough")
		return
	_show_side_tool_panel("music", panel)

func _refresh_music_panel_state() -> void:
	var panel = _get_music_panel_instance()
	if panel and panel.has_method("set_audio_player"):
		panel.set_audio_player(music_player)
	if panel and panel.has_method("_update_ui"):
		panel._update_ui()

func _consume_desktop_pet_ui_input() -> void:
	if get_viewport():
		get_viewport().set_input_as_handled()

func _on_tool_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		_consume_desktop_pet_ui_input()

func _hide_side_tool_panels() -> void:
	_active_tool_key = ""
	if dashboard_root:
		dashboard_root.show()
	if pomodoro_panel_host:
		pomodoro_panel_host.hide()
		for child in pomodoro_panel_host.get_children():
			if child is CanvasItem:
				child.visible = false
	if music_panel_host:
		music_panel_host.hide()
		for child in music_panel_host.get_children():
			if child is CanvasItem:
				child.visible = false
	if settings_panel_host:
		settings_panel_host.hide()
		for child in settings_panel_host.get_children():
			if child.has_method("save_settings"):
				child.save_settings()
			if child is CanvasItem:
				child.visible = false
	call_deferred("_update_mouse_passthrough")

func _get_main_bgm_player() -> AudioStreamPlayer:
	var root := get_tree().current_scene
	if root == null:
		return null
	var bgm_node := root.get_node_or_null("BGM")
	if bgm_node is AudioStreamPlayer:
		return bgm_node as AudioStreamPlayer
	return null

func _get_pet_mode() -> String:
	if GameDataManager and GameDataManager.config:
		var mode_name := str(GameDataManager.config.pet_disturbance_mode).strip_edges()
		if mode_name != "":
			return mode_name
	return PET_MODE_LOAF

func _is_mode_allows_app_observe() -> bool:
	match _get_pet_mode():
		PET_MODE_QUIET, PET_MODE_FOCUS, PET_MODE_NIGHT:
			return false
		_:
			return true

func _is_mode_allows_hourly_chime() -> bool:
	match _get_pet_mode():
		PET_MODE_QUIET, PET_MODE_FOCUS:
			return false
		_:
			return true

func _is_mode_allows_afk_greeting() -> bool:
	match _get_pet_mode():
		PET_MODE_QUIET:
			return false
		_:
			return true

func _is_mode_allows_memory_revisit() -> bool:
	match _get_pet_mode():
		PET_MODE_LOAF:
			return true
		_:
			return false

func _is_pet_temporarily_muted() -> bool:
	if GameDataManager == null or GameDataManager.config == null:
		return false
	return int(Time.get_unix_time_from_system()) < int(GameDataManager.config.pet_muted_until_unix)

func _is_proactive_temporarily_blocked() -> bool:
	return _is_pet_temporarily_muted() or _is_in_quiet_time_range()

func _split_policy_keywords(raw_text: String) -> Array[String]:
	var normalized := raw_text.replace("\r", "\n").replace("，", ",").replace("；", ",").replace(";", ",").replace("\t", ",")
	var result: Array[String] = []
	for line in normalized.split("\n"):
		for part in line.split(","):
			var keyword := part.strip_edges().to_lower()
			if keyword != "":
				result.append(keyword)
	return result

func _matches_policy_keywords(process_name: String, window_title: String, raw_keywords: String) -> bool:
	var keywords := _split_policy_keywords(raw_keywords)
	if keywords.is_empty():
		return false
	var haystack := ("%s\n%s" % [process_name, window_title]).to_lower()
	for keyword in keywords:
		if keyword in haystack:
			return true
	return false

func _parse_clock_minutes(clock_text: String) -> int:
	var text := clock_text.strip_edges()
	var parts := text.split(":")
	if parts.size() != 2:
		return -1
	if not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return -1
	var hour := clampi(int(parts[0]), 0, 23)
	var minute := clampi(int(parts[1]), 0, 59)
	return hour * 60 + minute

func _is_in_quiet_time_range() -> bool:
	if GameDataManager == null or GameDataManager.config == null:
		return false
	var raw_ranges := str(GameDataManager.config.pet_quiet_time_ranges).strip_edges()
	if raw_ranges == "":
		return false
	var normalized := raw_ranges.replace("\r", "\n").replace("，", ",").replace("；", ",").replace(";", ",")
	var time_dict := Time.get_datetime_dict_from_system()
	var current_minutes := int(time_dict["hour"]) * 60 + int(time_dict["minute"])
	for line in normalized.split("\n"):
		for part in line.split(","):
			var range_text := part.strip_edges()
			if range_text == "":
				continue
			var times := range_text.split("-")
			if times.size() != 2:
				continue
			var start_minutes := _parse_clock_minutes(times[0])
			var end_minutes := _parse_clock_minutes(times[1])
			if start_minutes < 0 or end_minutes < 0:
				continue
			if start_minutes <= end_minutes:
				if current_minutes >= start_minutes and current_minutes <= end_minutes:
					return true
			else:
				if current_minutes >= start_minutes or current_minutes <= end_minutes:
					return true
	return false

func _is_soft_reminder_app(app_type: String) -> bool:
	return app_type in SOFT_REMINDER_APP_TYPES

func _build_safe_app_display_name(process_name: String, window_title: String, app_type: String, hide_window_detail: bool) -> String:
	if hide_window_detail:
		if app_type != "":
			return app_type
		if process_name != "":
			return process_name
	if window_title != "":
		return window_title
	if app_type != "":
		return app_type
	return process_name if process_name != "" else "某个应用"

func _process(delta: float) -> void:
	_sync_root_window_focusability()
	if not pet_body:
		return
		
	if is_chatting:
		pet_body.set_pet_state(1) # Thinking
	elif audio_player and audio_player.playing:
		pet_body.set_pet_state(2) # Speaking
		if _spectrum_analyzer:
			var magnitude = _spectrum_analyzer.get_magnitude_for_frequency_range(0, 4000)
			var volume = (magnitude.x + magnitude.y) / 2.0
			pet_body.update_voice_volume(volume * 5.0)
	else:
		# Check proactive cooldown
		if not is_dialogue_panel_open and _is_mode_allows_app_observe() and not _is_proactive_temporarily_blocked():
			var current_tick = Time.get_ticks_msec()
			var time_since_last_reaction = current_tick - _last_reaction_tick
			
			# 持续增加观察时间，使其平滑
			if _current_app_name != "":
				_time_since_last_switch += delta
			
			var target_progress = 0.0
			
			# 获取配置
			var observe_time = max(0.1, float(GameDataManager.config.pet_new_app_observe_time))
			var global_cd = max(0.1, float(GameDataManager.config.pet_global_cooldown) * 1000.0)
			var same_app_cd = max(0.1, float(GameDataManager.config.pet_same_app_cooldown) * 1000.0)
			
			if _current_app_name != "" and _last_chatted_app != _current_app_name:
				# 新应用：需要停留 observe_time 秒，且距离上次聊天至少 global_cd 秒
				var switch_progress = _time_since_last_switch / observe_time
				var reaction_progress = float(time_since_last_reaction) / global_cd
				target_progress = min(switch_progress, reaction_progress)
			else:
				# 相同应用：只需要满足 same_app_cd 的冷却
				target_progress = float(time_since_last_reaction) / same_app_cd
				
			if target_progress < 1.0 and _current_app_name != "":
				pet_body.set_pet_state(3, target_progress) # 统一使用绿色状态环
			else:
				pet_body.set_pet_state(0) # Idle
		else:
			pet_body.set_pet_state(0) # Idle

func _on_dialogue_button_pressed() -> void:
	input_layer.show()
	is_dialogue_panel_open = true
	_set_menu_visible(false)
	_hide_side_tool_panels()

func _on_close_input_pressed() -> void:
	input_layer.hide()
	is_dialogue_panel_open = false

func _on_voice_record_down() -> void:
	voice_record_button.text = "松开发送"
	voice_record_button.modulate = Color(0.8, 0.2, 0.2)
	if mic_capture:
		mic_capture.play()
	if GameDataManager.config.qwen_asr_enabled and qwen_asr_client:
		qwen_asr_client.start_recording()

func _on_voice_record_up() -> void:
	voice_record_button.text = "🎙"
	voice_record_button.modulate = Color(1, 1, 1)
	if mic_capture:
		mic_capture.stop()
	if GameDataManager.config.qwen_asr_enabled and qwen_asr_client:
		qwen_asr_client.stop_recording()

func _on_asr_success(text: String) -> void:
	if not text.is_empty():
		input_edit.text = text

func _on_asr_failed(err: String) -> void:
	print("ASR Error: ", err)

func _on_input_text_changed() -> void:
	# TextEdit supports multiple lines, but we can intercept Enter to send
	var text = input_edit.text
	if text.ends_with("\n"):
		input_edit.text = text.strip_edges()
		_on_send_pressed()
	elif text.length() > 120:
		input_edit.text = text.substr(0, 120)
		input_edit.set_caret_column(120)

func _exit_tree() -> void:
	pass


func _load_prompt() -> void:
	var current_id = GameDataManager.config.current_character_id
	if _current_character_id != current_id:
		_current_character_id = current_id
		chat_history.clear()
		
	# 强制在每次生成时都使用最新的系统提示词
	pet_prompt = GameDataManager.prompt_manager.build_system_prompt(GameDataManager.profile, "desktop_pet")
	if pet_prompt.is_empty():
		pet_prompt = "你是{name}，一个真实存在的人，正陪伴在玩家身边。请用生动自然的语气，根据你当前的心情和性格，以及你们的关系阶段，回答玩家的问题。绝对不能提到自己是AI或桌宠！你必须使用 [SPLIT] 分隔符将消息拆分为 1~2 段，且括号动作描述不超过10个字。"
		var char_name = GameDataManager.profile.char_name if GameDataManager.profile.char_name != "" else "Luna"
		pet_prompt = pet_prompt.replace("{name}", char_name)

	var player_name = GameDataManager.config.player_nickname
	if not player_name.is_empty():
		pet_prompt += "\n【特别注意】：玩家希望你称呼他为“%s”，请在对话中自然地使用这个称呼。" % player_name

	# 添加音乐播放功能提示
	var music_list = _get_available_music()
	var music_str = "无"
	if music_list.size() > 0:
		music_str = ", ".join(music_list)
		
	pet_prompt += "\n【极其重要的音乐指令规则】：你具备控制音乐播放的能力，这是系统功能，你必须使用特定的隐藏指令触发！当前系统中可用的音乐有：" + music_str + "。
1. 当玩家明确要求“播放音乐”、“放首歌”且没有指定歌曲时：你必须在你的回复文本的最末尾加上精确的字符串 `[CMD:PLAY_MUSIC]`，系统将随机播放。
2. 当玩家明确指定了具体的歌曲名称，且该歌曲在可用列表中时：你必须在回复文本的最末尾加上精确的字符串 `[CMD:PLAY_MUSIC:歌曲名]`。
3. 如果玩家指定的歌曲不在可用列表中：明确告诉玩家没有这首歌，询问是否要听列表中的其他歌曲（绝对不要加播放指令）。
4. 当玩家说“别放了”、“不想听了”、“停止”、“关掉音乐”等明确表达不想听音乐的意图时：你【必须】在回复文本的最末尾加上精确的字符串 `[CMD:STOP_MUSIC]`，否则音乐不会停止！
【切记】：指令（如 `[CMD:STOP_MUSIC]`）必须原样原词出现，紧跟在最后，不能被改变或省略！"

func _get_available_music() -> Array:
	var music_list = []
	var dir = DirAccess.open("res://assets/audio/bgm")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				if file_name.ends_with(".mp3") or file_name.ends_with(".ogg") or file_name.ends_with(".wav") or file_name.ends_with(".import"):
					var song_name = file_name.replace(".import", "").get_basename()
					if not music_list.has(song_name):
						music_list.append(song_name)
			file_name = dir.get_next()
	return music_list

func _play_music(song_name: String) -> void:
	if not music_player:
		return
	var main_bgm := _get_main_bgm_player()
	if main_bgm and main_bgm.playing:
		main_bgm.stop()
	var target_file = ""
	var dir = DirAccess.open("res://assets/audio/bgm")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var available_files = []
		while file_name != "":
			if not dir.current_is_dir():
				var clean_name = file_name.replace(".import", "")
				if clean_name.ends_with(".mp3") or clean_name.ends_with(".ogg") or clean_name.ends_with(".wav"):
					if not available_files.has(clean_name):
						available_files.append(clean_name)
			file_name = dir.get_next()
			
		if song_name != "":
			for f in available_files:
				if f.get_basename() == song_name:
					target_file = f
					break
					
		if target_file == "" and available_files.size() > 0:
			target_file = available_files[randi() % available_files.size()]
			
	if target_file != "":
		print("[DesktopPet Music] Playing: ", target_file)
		var stream = load("res://assets/audio/bgm/" + target_file)
		if stream:
			music_player.stream = stream
			music_player.play()
			_open_music_panel(true)
			_refresh_music_panel_state()

func _stop_music() -> void:
	if music_player and music_player.playing:
		print("[DesktopPet Music] Stopping music.")
		music_player.stop()
	_refresh_music_panel_state()

func _on_poll_timer_timeout() -> void:
	_check_vision_recovery()
	_update_mute_button()
	_update_mode_chip()
	_update_panel_clock()
	
	if GameDataManager.config.pet_enable_hourly_chime and _is_mode_allows_hourly_chime():
		_check_hourly_chime()
	if GameDataManager.config.pet_enable_app_observe and _is_mode_allows_app_observe():
		_check_active_window()
	if GameDataManager.config.pet_enable_afk_greeting and _is_mode_allows_afk_greeting():
		_check_afk_state()
		
	_process_pending_proactive()
	_try_trigger_memory_revisit()

func _try_trigger_memory_revisit() -> void:
	if is_chatting or is_dialogue_panel_open:
		return
	if not _is_mode_allows_memory_revisit():
		return
	if _is_proactive_temporarily_blocked():
		return
	if not _pending_proactive_prompt.is_empty():
		return
	if GameDataManager.memory_manager == null:
		return
	if Time.get_ticks_msec() - _ready_tick_msec < 15000:
		return
	
	var current_tick = Time.get_ticks_msec()
	var global_cd = float(GameDataManager.config.pet_global_cooldown) * 1000.0
	if current_tick - _last_reaction_tick < global_cd:
		return
	
	var trigger_context = GameDataManager.memory_manager.build_reality_memory_context()
	var revisit_data = GameDataManager.memory_manager.get_revisit_event_candidate(trigger_context)
	if revisit_data.is_empty():
		return
	
	_last_reaction_tick = current_tick
	GameDataManager.memory_manager.mark_memory_revisited(revisit_data.get("memory_id", ""), trigger_context)
	var prompt = GameDataManager.prompt_manager.build_memory_revisit_prompt(GameDataManager.profile, revisit_data, trigger_context)
	_trigger_proactive_chat(prompt)

func _check_vision_recovery() -> void:
	if GameDataManager.config.vision_use_count <= 0:
		return
		
	var current_time = int(Time.get_unix_time_from_system())
	var last_recovery = GameDataManager.config.vision_last_recovery_time
	
	# 每天重置或者每小时恢复2次，这里采用每小时恢复2次的细水长流机制
	# 3600秒 = 1小时
	if last_recovery == 0:
		GameDataManager.config.vision_last_recovery_time = current_time
		GameDataManager.config.save_config()
		return
		
	var hours_passed = (current_time - last_recovery) / 3600
	if hours_passed >= 1:
		# 每过去1小时，恢复2次使用机会 (即减少使用次数)
		var recover_amount = hours_passed * 2
		GameDataManager.config.vision_use_count = max(0, GameDataManager.config.vision_use_count - recover_amount)
		GameDataManager.config.vision_last_recovery_time = current_time
		GameDataManager.config.save_config()
		print("[DesktopPet] 恢复多模态视觉次数: %d 次，当前使用次数: %d" % [recover_amount, GameDataManager.config.vision_use_count])

func _process_pending_proactive() -> void:
	if _pending_proactive_prompt.is_empty():
		return
	if is_chatting or is_dialogue_panel_open:
		return
	if _is_proactive_temporarily_blocked():
		return
		
	var current_tick = Time.get_ticks_msec()
	var global_cd = float(GameDataManager.config.pet_global_cooldown) * 1000.0
	
	if current_tick - _last_reaction_tick >= global_cd:
		print("[DesktopPet Debug] 触发积压的主动问候")
		var prompt = _pending_proactive_prompt
		_pending_proactive_prompt = ""
		_trigger_proactive_chat(prompt)

func _check_afk_state() -> void:
	if not is_instance_valid(_window_detector) or not _window_detector.has_method("GetIdleTimeMs"):
		return
		
	var idle_time = _window_detector.call("GetIdleTimeMs")
	# 600000 毫秒 = 10分钟
	if idle_time > 600000:
		if not _is_afk:
			_is_afk = true
			print("[DesktopPet Debug] 玩家进入 AFK 状态 (打瞌睡)")
			
			var time_dict = Time.get_datetime_dict_from_system()
			var prompt = """【系统提示：当前现实时间是 %02d:%02d，玩家已经离开电脑超过10分钟，完全没有动静。】
请你代入当前身份，像真人一样对玩家的长时间离开做出自言自语的反应。可以表现出犯困、无聊、或是猜测玩家去干什么了。
- 反应要生动多样！结合你们的【微习惯与口癖】。
- 【格式强制】：你的回复必须完全遵循系统提示词中的【对话结构策略】（使用[SPLIT]等规则，必须包含括号动作描写）。""" % [time_dict["hour"], time_dict["minute"]]
			_trigger_proactive_chat(prompt)
	else:
		if _is_afk:
			_is_afk = false
			print("[DesktopPet Debug] 玩家从 AFK 状态返回")
			
			var time_dict = Time.get_datetime_dict_from_system()
			var prompt = """【系统提示：当前现实时间是 %02d:%02d，玩家离开了电脑超过10分钟后，刚刚回来了，晃动了鼠标。】
请代入当前身份，像真人一样对玩家的回归做出反应。可以表现出刚睡醒的样子，或是埋怨玩家离开太久，或是温馨地欢迎回来。
- 【格式强制】：你的回复必须完全遵循系统提示词中的【对话结构策略】（使用[SPLIT]等规则，必须包含括号动作描写）。""" % [time_dict["hour"], time_dict["minute"]]
			_trigger_proactive_chat(prompt)

func _get_time_constraint(hour: int) -> String:
	if hour >= 6 and hour < 11:
		return "现在是清晨/上午，请展现出活力，【绝对禁止】说出“晚安”、“好困”或催促睡觉的词汇。"
	elif hour >= 11 and hour < 14:
		return "现在是中午，可以提醒玩家吃午饭或稍微午休，【绝对禁止】说出“晚安”或催促晚上睡觉的词汇。"
	elif hour >= 14 and hour < 19:
		return "现在是下午，请陪伴玩家度过这段时间，可以说些提神的话，【绝对禁止】说出“晚安”、“好困”或催促睡觉的词汇。"
	elif hour >= 19 and hour < 23:
		return "现在是晚上，可以聊些轻松的话题，如果时间较晚可以适当提醒准备休息。"
	else:
		return "现在是深夜，玩家还在熬夜，可以表现出困意、心疼或强制要求玩家去睡觉。"

func _is_app_observe_allowed_by_policy(process_name: String, window_title: String) -> bool:
	if GameDataManager == null or GameDataManager.config == null:
		return true
	var allow_list := str(GameDataManager.config.pet_observe_allow_list).strip_edges()
	if allow_list == "":
		return true
	return _matches_policy_keywords(process_name, window_title, allow_list)

func _should_capture_for_app(process_name: String, window_title: String, app_type: String, is_sensitive_window: bool) -> bool:
	if GameDataManager == null or GameDataManager.config == null:
		return false
	if is_sensitive_window:
		return false
	if _is_soft_reminder_app(app_type):
		return false
	if _matches_policy_keywords(process_name, window_title, str(GameDataManager.config.pet_never_capture_list)):
		return false
	if _get_pet_mode() == PET_MODE_NIGHT:
		return false
	return true

func _build_soft_app_prompt(hour: int, minute: int, display_name: String, app_type: String) -> String:
	return """【系统提示：当前现实时间是 %02d:%02d，玩家正在处理一个%s（归类为%s）。】
请你用更轻一点、尽量不打扰的语气陪玩家一句。
- 只做弱提醒或温柔陪伴，不要追问具体内容，更不要复述隐私细节。
- 如果是聊天或文档场景，重点提供情绪价值、提醒休息或安静陪着，不要表现得像在偷看屏幕。
- 【格式强制】：必须遵循【对话结构策略】，使用[SPLIT]拆分句子，必须包含括号动作描写。
- 绝对不要在台词中报出当前时间，绝对不能提到你是AI或桌宠。""" % [hour, minute, display_name, app_type]

func _check_active_window() -> void:
	if is_dialogue_panel_open:
		return
	if not is_instance_valid(_window_detector):
		return
	if _is_proactive_temporarily_blocked():
		return
	if is_chatting:
		return
		
	var window_title = _window_detector.call("GetCurrentWindowTitle")
	var process_name = _window_detector.call("GetCurrentProcessName")
	
	if window_title == null: window_title = ""
	if process_name == null: process_name = ""
	
	if window_title == "" and process_name == "":
		return
	if not _is_app_observe_allowed_by_policy(process_name, window_title):
		return
		
	var app_identifier = process_name + "|" + window_title
	
	if _current_app_name != app_identifier:
		_current_app_name = app_identifier
		_time_since_last_switch = 0.0
		
	var observe_time = float(GameDataManager.config.pet_new_app_observe_time)
	var global_cd = float(GameDataManager.config.pet_global_cooldown) * 1000.0
	var same_app_cd = float(GameDataManager.config.pet_same_app_cooldown) * 1000.0

	# 打印前置的停留倒计时
	if _time_since_last_switch < observe_time:
		var remain = observe_time - _time_since_last_switch
		print("[DesktopPet Debug] 观察新应用中 (%s)... 触发还需: %.1f 秒" % [process_name, remain])
		
	var current_tick = Time.get_ticks_msec()
	
	# 修改逻辑：当停留超过设定时间时，允许触发
	if _time_since_last_switch >= observe_time:
		var cooldown_time = same_app_cd # 同一个应用连续停留，按配置冷却
		if _last_chatted_app != app_identifier:
			cooldown_time = global_cd # 刚切到新应用，只需要和上一次任何对话间隔全局冷却
			
		if current_tick - _last_reaction_tick < cooldown_time:
			# 还在冷却中
			var remaining = (cooldown_time - (current_tick - _last_reaction_tick)) / 1000.0
			print("[DesktopPet Debug] 主动聊天冷却中: 剩余 %.1f 秒" % remaining)
			return
			
		_last_chatted_app = app_identifier
		_last_reaction_tick = current_tick
		
		# 为了保证即使触发了 Vision 逻辑，底层的定时更新机制也能重置透明穿透
		call_deferred("_update_mouse_passthrough")
		
		var app_type = _map_app_type(window_title, process_name)
		var is_sensitive_window := _matches_policy_keywords(process_name, window_title, str(GameDataManager.config.pet_sensitive_window_list))
		var soft_reminder := is_sensitive_window or _is_soft_reminder_app(app_type)
		var display_name := _build_safe_app_display_name(process_name, window_title, app_type, soft_reminder)
		var time_dict = Time.get_datetime_dict_from_system()
		var h = time_dict["hour"]
		var m = time_dict["minute"]
		
		# 尝试截图 (优先截取当前活动窗口)
		var base64_image = ""
		var allow_capture := _should_capture_for_app(process_name, window_title, app_type, is_sensitive_window)
		if allow_capture and GameDataManager.config.vision_enabled and not GameDataManager.config.vision_api_key.is_empty():
			# 检查多模态视觉限制次数
			if GameDataManager.config.vision_use_count >= GameDataManager.config.max_vision_uses:
				print("[DesktopPet Debug] Vision uses limit reached (%d/%d). Skipping vision for now." % [GameDataManager.config.vision_use_count, GameDataManager.config.max_vision_uses])
			else:
				if _window_detector.has_method("CaptureForegroundWindowToBase64"):
					base64_image = _window_detector.call("CaptureForegroundWindowToBase64")
				elif _window_detector.has_method("CaptureScreenToBase64"):
					base64_image = _window_detector.call("CaptureScreenToBase64")
					
				if base64_image != "":
					GameDataManager.config.vision_use_count += 1
					GameDataManager.config.save_config()
			
		if base64_image != "":
			print("[DesktopPet Debug] Vision API Triggered! App: ", display_name)
			# 这里只要求大模型做纯粹的画面分析，绝对不包含任何角色扮演和对话要求
			var prompt = """【系统提示：当前现实时间是 %02d:%02d，玩家正在看名为“%s”的应用。这是该应用的窗口截图。】
请作为专业的视觉“互动话题提取系统”，精准提取画面中【最能引发角色互动、吃醋、好奇或心疼的细节信息】（控制在150字以内）。
要求：
1. 【屏蔽噪音】：忽略无用的UI外壳、菜单栏、行号、背景图等冗余元素。
2. 【提取社交雷达】：如果屏幕上有聊天、通讯、社交媒体或邮件，必须且只需提取出：在和谁聊天（对方名字/备注）？聊了什么核心内容？对方头像或性别？
3. 【提取工作细节】：如果屏幕上是代码、文档或表格，必须提取出：玩家正在解决什么具体的难题？文档标题是什么？代码中有什么能让外行人觉得“好厉害”或“好辛苦”的关键词？
4. 【提取娱乐焦点】：如果屏幕上是视频、游戏或网页，必须提取出：画面里有什么有趣的角色、商品或事件？这东西看起来是轻松的还是恐怖的？
5. 绝对不要进行角色扮演或输出对话！只需输出客观、提炼过、能够作为【绝佳聊天话题】的关键信息。""" % [h, m, window_title]
			_trigger_vision_chat(prompt, base64_image)
		else:
			var prompt := ""
			if soft_reminder:
				prompt = _build_soft_app_prompt(h, m, display_name, app_type)
			else:
				prompt = """【系统提示：当前现实时间是 %02d:%02d，玩家正在看着屏幕上名为“%s”的内容（这可能是一个%s）。】
请你代入当前设定的身份和性格，像真人一样对玩家屏幕上的内容做出最自然、最符合人设的反应。
- 【拒绝人机感与套路】：不要无脑套用模板或者道歉！展现你“温柔体贴”、“天然呆”或“安静陪伴”的一面。比如好奇应用里的内容，或者心疼玩家太辛苦，提供情绪价值。
- 结合你们的关系阶段和当前的【微习惯与口癖】，表现得软糯、真诚且自然。
- 【格式强制】：必须遵循【对话结构策略】，使用[SPLIT]拆分句子，必须包含括号动作描写。
- 绝对不要在台词中报出当前时间，绝对不能提到你是AI或桌宠。""" % [h, m, display_name, app_type]
			print("[DesktopPet Debug] Triggering proactive chat: ", prompt)
			_trigger_proactive_chat(prompt)

func _trigger_vision_chat(prompt_text: String, base64_image: String) -> void:
	if is_chatting: return
	is_chatting = true
	current_response = ""
	bubble_queue.clear()
	if pet_body: pet_body.clear_bubbles()
	if audio_player and audio_player.playing: audio_player.stop()
	
	# 构建专属的独立请求记录
	chat_history.append({"role": "user", "content": "【屏幕截图发送成功】" + prompt_text})
	if chat_history.size() > 10: chat_history = chat_history.slice(-10)
	_load_prompt()
	
	print("\n[DesktopPet Vision] --- Sending Vision Request ---")
	print("Prompt text length: ", prompt_text.length())
	print("Base64 length: ", base64_image.length())

	deepseek_client.send_vision_request(pet_prompt, prompt_text, base64_image)

func _on_vision_completed(response: Dictionary) -> void:
	print("\n[DesktopPet Vision] --- Vision Analysis Completed ---")
	
	var analysis_text = ""
	
	# 兼容原版 OpenAI/Chat 接口格式 (choices)
	if response.has("choices") and response.choices.size() > 0:
		var msg = response.choices[0].get("message", {})
		analysis_text = msg.get("content", "").strip_edges()
		
	# 兼容 Volcengine v3 Responses 接口格式 (output)
	elif response.has("output") and typeof(response["output"]) == TYPE_ARRAY:
		for item in response["output"]:
			if item.get("type") == "message" and item.has("content"):
				var contents = item["content"]
				if typeof(contents) == TYPE_ARRAY and contents.size() > 0:
					for c in contents:
						if c.get("type") == "output_text":
							analysis_text += c.get("text", "")
							
	analysis_text = analysis_text.strip_edges()
	
	if analysis_text != "":
		print("[DesktopPet Vision] Raw Analysis Output:\n", analysis_text)
		
		# 将分析结果作为主动聊天的触发器，发给专门负责角色扮演的文本大模型
		var prompt = """【系统提示：视觉分析系统刚刚捕捉到了玩家当前正在查看的屏幕画面。】
以下是屏幕画面的详细分析结果：
%s

请你严格代入当前设定的身份和性格，基于以上画面分析，像真人一样对玩家屏幕上的内容做出最自然、最符合人设的反应。
- 【拒绝人机感与刻板印象】：不要每次都只套用固定模板！展现你性格的所有面。
- 【严格遵循情感阶段】：无论画面内容是日常软件还是玩家的私人社交记录，你的反应【必须完全以系统传入的“当前关系阶段”和“特殊场景反应”设定为最高准则】！仔细阅读传入的情感阶段设定，阶段未到绝对不可越界吃醋或发火。
- 【生动自然】：要有真人的温度，结合【微习惯与口癖】，可以有轻微的迟疑，但要真诚有趣。
- 绝对不要在台词中报出时间，绝不提自己是AI/桌宠。
- 【格式强制】：回复必须遵循【对话结构策略】，用 [SPLIT] 拆分长句，必须包含括号动作描写。""" % [analysis_text]
		
		# 必须先重置 is_chatting，否则 _trigger_proactive_chat 会被拦截
		is_chatting = false
		_trigger_proactive_chat(prompt)
	else:
		print("[DesktopPet Vision] Failed to parse analysis choices. Raw response:\n", response)
		is_chatting = false
		var text = "（看着屏幕发呆）……"
		chat_history.append({"role": "assistant", "content": text})
		display_bubble(text)

func _on_vision_failed(error_msg: String) -> void:
	print("[DesktopPet Debug] Vision request failed: ", error_msg)
	
	# 特别处理 429 频率限制错误
	if "429" in error_msg or "频率" in error_msg or "请求过于频繁" in error_msg:
		# 当遇到频率限制时，将下次触发时间惩罚性地延后 5 分钟 (300,000 毫秒)
		# 因为豆包 Lite 模型的 RPM 限制通常按分钟重置，60秒可能不够安全
		_last_reaction_tick = Time.get_ticks_msec() + 300000
		if pet_body:
			pet_body.add_bubble("[color=orange]（AI服务商频率受限，休息一下...）[/color]")
	else:
		if pet_body:
			pet_body.add_bubble("[color=red]视觉感知失败: " + error_msg + "[/color]")
			
	is_chatting = false

func _map_app_type(window_title_str: String, process: String) -> String:
	var p = process.to_lower()
	var t = window_title_str.to_lower()
	
	var app_db = GameDataManager.app_database
	if app_db and not app_db.is_empty():
		for category_key in app_db:
			var category_data = app_db[category_key]
			var category_name = category_data.get("category_name", "某个应用")
			var keywords = category_data.get("keywords", [])
			
			for keyword in keywords:
				if keyword in p or keyword in t:
					return category_name
	
	# Fallback if not found in database
	if "chrome" in p or "edge" in p or "firefox" in p or "browser" in p:
		return "网页浏览器"
	elif "code" in p or "idea" in p or "studio" in p or "devenv" in p or "pycharm" in p or "cursor" in p or "trae" in p:
		return "编程开发工具"
	elif "word" in p or "excel" in p or "powerpoint" in p or "wps" in p:
		return "办公文档软件"
	elif "steam" in p or "game" in p or "epic" in p:
		return "游戏"
	elif "wechat" in p or "qq" in p or "discord" in p or "telegram" in p:
		return "通讯聊天软件"
	elif "bilibili" in p or "youtube" in p or "video" in p or "player" in p:
		return "视频"
	elif "music" in p or "cloudmusic" in p or "netease" in p or "spotify" in p:
		return "音乐"
		
	return process if process != "" else "未知应用"

func _check_hourly_chime() -> void:
	if is_dialogue_panel_open: return
	if is_chatting:
		return
		
	var time_dict = Time.get_datetime_dict_from_system()
	var current_hour = time_dict["hour"]
	var current_minute = time_dict["minute"]
	
	# 触发条件：分钟在0~2之间，且本小时未报时
	if current_minute >= 0 and current_minute <= 2 and _last_hourly_chime_hour != current_hour:
		
		# 根据不同的时间段给予不同的语境提示，增加话题多样性
		var time_context = ""
		if current_hour >= 6 and current_hour < 9:
			time_context = "现在是早晨，可以聊聊早餐、刚醒来的感受、或者对新一天的元气期许。"
		elif current_hour >= 9 and current_hour < 12:
			time_context = "现在是上午，玩家可能正在工作或学习，可以给点鼓励或者吐槽一下辛苦。"
		elif current_hour >= 12 and current_hour < 14:
			time_context = "现在是中午，到了午饭和午休的时间，可以聊聊吃了什么，或者犯困想午休。"
		elif current_hour >= 14 and current_hour < 18:
			time_context = "现在是下午，容易感到疲惫，可以聊聊下午茶、摸鱼、或者互相打气。"
		elif current_hour >= 18 and current_hour < 22:
			time_context = "现在是晚上，可以聊聊晚餐、放松的休闲时光、或者一天的总结。"
		elif current_hour >= 22 or current_hour < 2:
			time_context = "现在是深夜，可以提醒玩家早点休息、聊聊熬夜、或者表现出自己困了。"
		else: # 2~6
			time_context = "现在是凌晨，非常晚了，强制要求玩家去睡觉，或者表现出极度的困倦和迷糊。"

		var weather_context = ""
		if GameDataManager.weather_manager and GameDataManager.weather_manager.is_weather_ready:
			weather_context = "当前天气是%s，气温约%d度。" % [GameDataManager.weather_manager.current_weather_desc, GameDataManager.weather_manager.current_temp]

		var base_prompt = """【系统提示：现在是现实时间 %02d:00。%s】
请你结合当前时间与天气作为隐性语境，代入当前身份，像真人一样对玩家进行整点报时。
【时间段特定话题】：%s
- 反应要生动多样！切忌千篇一律。不要总是说“我看你在忙”，要根据时间段或天气提供独特的生活化话题。
- 【格式强制】：必须包含括号动作描写，严格遵循系统设定的口癖。绝对不能提到你是AI或桌宠。""" % [current_hour, weather_context, time_context]

		var current_tick = Time.get_ticks_msec()
		var global_cd = float(GameDataManager.config.pet_global_cooldown) * 1000.0
		
		if current_tick - _last_reaction_tick < global_cd:
			# 还在冷却中，存入积压队列，此时才加上延迟的提示
			if _pending_proactive_prompt.is_empty():
				print("[DesktopPet Debug] 报时被冷却拦截，存入积压队列")
				_pending_proactive_prompt = base_prompt + "\n（附加条件：这次报时晚了几分钟，因为刚才看玩家在忙/专注，你特意没打扰，现在才开口，可以稍微提一句体贴或傲娇的抱怨。）"
				_last_hourly_chime_hour = current_hour
			return
			
		_last_hourly_chime_hour = current_hour
		_last_reaction_tick = current_tick
		_trigger_proactive_chat(base_prompt)


func _trigger_proactive_chat(prompt_text: String, force: bool = false) -> void:
	print("[DesktopPet Debug] Triggering proactive chat. is_chatting: ", is_chatting)
	if is_chatting:
		return
	if not force and _is_proactive_temporarily_blocked():
		return
		
	is_chatting = true
	current_response = ""
	
	bubble_queue.clear()
	if pet_body:
		pet_body.clear_bubbles()
	if audio_player and audio_player.playing:
		audio_player.stop()
		
	# 维护历史记录长度
	if chat_history.size() > 10:
		chat_history = chat_history.slice(-10)
		
	# 每次发送前都重新构建 prompt，确保应用识别的 prompt 也是最新的约束
	_load_prompt()
		
	# 构建专属的独立请求记录，不带历史上下文，防止主动吐槽被历史聊天带偏
	var proactive_history = []
	proactive_history.append({"role": "user", "content": prompt_text})
	
	# 我们把这次主动事件塞进专属的桌宠聊天历史里
	chat_history.append({"role": "user", "content": prompt_text})
	
	var pet_messages = [{"role": "system", "content": pet_prompt}]
	for msg in proactive_history:
		pet_messages.append(msg)
		
	deepseek_client.start_chat_stream_with_messages(pet_messages)

func _on_send_pressed() -> void:
	var text = input_edit.text.strip_edges()
	if text.is_empty() or is_chatting:
		return
		
	# 本地瞬间拦截停止指令，做到"话音未落，音乐先停"
	var lower_text = text.to_lower()
	var stop_keywords = ["别放", "不想听", "停止", "关掉", "关音乐", "停音乐", "别播", "不要播", "太吵", "安静点"]
	var should_stop = false
	for kw in stop_keywords:
		if kw in lower_text:
			should_stop = true
			break
			
	if should_stop and music_player and music_player.playing:
		_stop_music()
		text += "\n（系统提示：检测到玩家要求停止，系统已立刻将音乐关闭，请温柔地向玩家确认即可。）"
		
	input_edit.text = ""
	is_chatting = true
	current_response = ""
	
	# 更新最后反应时间
	_last_reaction_tick = Time.get_ticks_msec()
	
	# Reset queue and stop TTS
	bubble_queue.clear()
	if pet_body:
		pet_body.clear_bubbles()
	if audio_player and audio_player.playing:
		audio_player.stop()
	
	# Maintain history (max 10 items to prevent context window overflow)
	if chat_history.size() > 10:
		chat_history = chat_history.slice(-10)
		
	_load_prompt()
	
	# Add user message to history
	# 桌宠特有逻辑：直接在发包前把话塞进去
	# 我们不要再塞进全局的聊天历史里了，而是使用专门的桌宠历史
	chat_history.append({"role": "user", "content": text})
	
	# 构建专门为桌宠发送的历史数组，避免混用
	var pet_messages = [{"role": "system", "content": pet_prompt}]
	for i in range(chat_history.size()):
		var msg = chat_history[i].duplicate()
		if i == chat_history.size() - 1 and msg["role"] == "user":
			# 将音乐指令的双向提醒一次性注入，防止大模型混淆或忘记
			var injection = "\n(系统强制判定：若玩家要求放歌/播放音乐，你【必须】在回复最后加上 [CMD:PLAY_MUSIC]（随机）或 [CMD:PLAY_MUSIC:歌名]（指定）；若玩家要求停止，你【必须】加 [CMD:STOP_MUSIC]！如果不加，系统将无法执行操作！)"
			msg["content"] = str(msg["content"]) + injection
		pet_messages.append(msg)
		
	deepseek_client.start_chat_stream_with_messages(pet_messages)

func _on_chat_started() -> void:
	current_response = ""

func _on_chat_delta(delta_text: String) -> void:
	current_response += delta_text

func _on_chat_completed(response: Dictionary) -> void:
	print("[DesktopPet Debug] Chat request completed. Response keys: ", response.keys())
	is_chatting = false
	
	# Extract response text
	var text = ""
	if response.has("choices") and response.choices.size() > 0:
		text = response.choices[0].message.content
	else:
		text = current_response
		
	# 提前拦截并执行所有音乐指令，做到在说话前立刻响应，并将指令从文本中剔除
	var regex = RegEx.new()
	
	regex.compile("\\[CMD:STOP_MUSIC\\s*\\]")
	if regex.search(text):
		_stop_music()
		text = regex.sub(text, "", true)
		
	regex.compile("\\[CMD:PLAY_MUSIC(?:\\s*:\\s*(.*?))?\\s*\\]")
	var match = regex.search(text)
	if match:
		var specific_song = ""
		if match.get_string(1) != "":
			specific_song = match.get_string(1).strip_edges()
		_play_music(specific_song)
		text = regex.sub(text, "", true)
		
	print("[DesktopPet Debug] === RAW AI RESPONSE ===")
	print(text)
	print("[DesktopPet Debug] =======================")
		
	print("[DesktopPet Debug] Extracted text length: ", text.length())
	if text.is_empty():
		print("[DesktopPet Debug] WARNING: Response text is empty! Fallback to error message.")
		text = "（沉默）……"
		
	# 如果大模型抽风只回复了括号动作而没有文字，强制补充省略号，否则无法发声且很怪异
	var pure_dialogue = _extract_dialogue_text(text)
	if pure_dialogue.is_empty():
		print("[DesktopPet Debug] WARNING: No dialogue text found in response! Appending fallback.")
		text += " ……"
		
	# Add assistant message to history
	chat_history.append({"role": "assistant", "content": text})
		
	var user_text = ""
	if chat_history.size() >= 2:
		var last_msg = chat_history[chat_history.size() - 2]
		if last_msg.has("role") and last_msg["role"] == "user":
			user_text = last_msg["content"]
			
	if user_text != "" and GameDataManager.memory_manager.add_turn():
		deepseek_client.set_next_memory_context(GameDataManager.memory_manager.build_reality_memory_context())
		deepseek_client.extract_memory_from_chat(user_text, text)
		
	display_bubble(text)

func _on_chat_failed(error_msg: String) -> void:
	print("[DesktopPet Debug] Chat request failed: ", error_msg)
	if pet_body:
		pet_body.add_bubble("[color=red]错误: " + error_msg + "[/color]")
	is_chatting = false

func display_bubble(text: String) -> void:
	var processed_text = text
	
	# 兼容处理大模型没有使用 [SPLIT] 而是使用了换行符 \n\n 或 \n 的情况
	if "[SPLIT]" not in processed_text:
		var regex = RegEx.new()
		# 先把所有的回车符统一成换行符
		processed_text = processed_text.replace("\r\n", "\n")
		# 匹配括号在行首的情况，在前面插入 [SPLIT]（除了第一行）
		regex.compile("\\n+\\s*([（\\(])")
		processed_text = regex.sub(processed_text, "[SPLIT]$1", true)
		
		# 如果还是没有拆分开，尝试简单的多换行拆分
		if "[SPLIT]" not in processed_text:
			regex.compile("\\n{2,}")
			processed_text = regex.sub(processed_text, "[SPLIT]", true)
			
	var chunks = ChatSplitHelper.merge_incomplete_parentheses(processed_text.split("[SPLIT]"))
	for chunk in chunks:
		var c = chunk.strip_edges()
		if not c.is_empty():
			# 为每一小段兜底：如果这小段只有括号，没有台词，也补上省略号
			var pure = _extract_dialogue_text(c)
			if pure.is_empty():
				c += " ……"
			bubble_queue.append(c)
			
	if not is_processing_bubbles:
		_process_next_bubble()

func _process_next_bubble() -> void:
	if bubble_queue.is_empty():
		is_processing_bubbles = false
		return
		
	is_processing_bubbles = true
	var chunk = bubble_queue.pop_front()
	
	# Parse green action text and pure dialogue for TTS
	var display_text = _format_action_text(chunk)
	var tts_text = _extract_dialogue_text(chunk)
	
	if pet_body:
		pet_body.add_bubble(display_text, true)
	
	if GameDataManager.config.voice_enabled and _has_readable_text(tts_text):
		var char_id = GameDataManager.config.current_character_id
		var v_type = "ICL_zh_female_bingruoshaonv_tob"
		if GameDataManager.config.character_voice_types.has(char_id):
			v_type = GameDataManager.config.character_voice_types[char_id]
			
		var options = {"voice_type": v_type}
		
		# 移除有垃圾回收风险的 Lambda 和本地数组，使用成员变量控制
		_tts_finished = false
		
		var on_success = func(_stream: AudioStream, _text: String): 
			_tts_finished = true
		var on_failed = func(_err: String, _text: String): 
			_tts_finished = true
			
		TTSManager.tts_success.connect(on_success, CONNECT_ONE_SHOT)
		TTSManager.tts_failed.connect(on_failed, CONNECT_ONE_SHOT)
		
		TTSManager.synthesize(tts_text, options)
		
		# 第一阶段：死等网络请求回来（最多等10秒）
		var wait_net = 0.0
		while not _tts_finished and wait_net < 10.0:
			await get_tree().process_frame
			wait_net += get_process_delta_time()
			
		# 防止意外泄漏断开连接
		if TTSManager.tts_success.is_connected(on_success):
			TTSManager.tts_success.disconnect(on_success)
		if TTSManager.tts_failed.is_connected(on_failed):
			TTSManager.tts_failed.disconnect(on_failed)
			
		# 第二阶段：网络请求回来后，由于播放有一点微小的延迟，我们稍微等几帧确保 audio_player.playing 状态更新
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
			
		# 第三阶段：死等音频播放结束
		var wait_count = 0
		while audio_player and audio_player.playing and wait_count < 1200: # 最多等60秒
			await get_tree().create_timer(0.05).timeout
			wait_count += 1
			
		# 极短的缓冲，让两句话之间显得自然，而不是生硬地等半天
		await get_tree().create_timer(0.2).timeout
	else:
		# 如果没有语音，等待打字机完成 + 短暂暂停
		var duration = chunk.length() * 0.05 + 1.0
		await get_tree().create_timer(duration).timeout
	
	_process_next_bubble()

func _format_action_text(text: String) -> String:
	# 简单正则替换 (...) 和 （...）为绿色
	var regex = RegEx.new()
	regex.compile("\\([^)]+\\)|\\（[^）]+\\）")
	var result = text
	var matches = regex.search_all(text)
	# 为了防止破坏BBCode，从后往前替换或者直接替换
	# 但由于没有嵌套，直接 replace 是可以的
	for m in matches:
		var matched_string = m.get_string()
		result = result.replace(matched_string, "[color=green]" + matched_string + "[/color]")
	return result

func _extract_dialogue_text(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("\\([^)]+\\)|\\（[^）]+\\）")
	return regex.sub(text, "", true).strip_edges()

func _has_readable_text(text: String) -> bool:
	var regex = RegEx.new()
	regex.compile("[a-zA-Z0-9\u4e00-\u9fa5]")
	return regex.search(text) != null

func _on_tts_success(audio_stream: AudioStream, _text: String) -> void:
	if audio_player:
		audio_player.stream = audio_stream
		audio_player.play()

func _on_tts_failed(error_msg: String, _text: String) -> void:
	print("Desktop Pet TTS failed: ", error_msg)

func _on_main_window_pressed() -> void:
	# 请求主窗口焦点
	print("[DesktopPet] 请求打开主界面，保持桌宠运行")
	_restore_main_window_from_pet()
	_set_menu_visible(false)
	_hide_side_tool_panels()
	DisplayServer.window_request_attention()
	
	# 注意：移除了 _on_close_pressed() 以保持桌宠继续运行

func _on_close_pressed() -> void:
	# 先隐藏窗口并切断输入流，防止 _push_unhandled_input_internal 报错
	_restore_main_window_from_pet()
	hide()
	
	if music_player and music_player.playing:
		music_player.stop()
	
	# 取消当前窗口中所有 Control 的焦点
	var focused_node = get_viewport().gui_get_focus_owner()
	if focused_node:
		focused_node.release_focus()
		
	queue_free()
	
func _sync_root_window_focusability(force_root_focusable: bool = false) -> void:
	var root_window := get_tree().root
	if root_window == null:
		return
	if force_root_focusable:
		root_window.unfocusable = false
		return
	if visible and root_window.mode == Window.MODE_MINIMIZED:
		_convert_minimized_root_to_hidden(root_window)
	var should_unfocus := visible and (root_window.mode == Window.MODE_MINIMIZED or not root_window.visible)
	if root_window.unfocusable != should_unfocus:
		root_window.unfocusable = should_unfocus

func _restore_main_window_from_pet() -> void:
	var root_window := get_tree().root
	if root_window == null:
		return
	if _root_window_parked:
		root_window.position = _root_window_saved_position
		if _root_window_saved_size.x > 0 and _root_window_saved_size.y > 0:
			root_window.size = _root_window_saved_size
		root_window.mode = _root_window_saved_mode
		var current_scene := get_tree().current_scene
		if current_scene is CanvasItem:
			(current_scene as CanvasItem).show()
		_root_window_parked = false
	root_window.unfocusable = false
	if root_window.mode == Window.MODE_MINIMIZED:
		root_window.mode = Window.MODE_WINDOWED
	root_window.show()

func park_main_window_for_pet() -> void:
	var root_window := get_tree().root
	if root_window == null:
		return
	if root_window.mode == Window.MODE_MINIMIZED:
		root_window.mode = Window.MODE_WINDOWED
	_convert_minimized_root_to_hidden(root_window)

func _convert_minimized_root_to_hidden(root_window: Window) -> void:
	if not _root_window_parked:
		_root_window_saved_position = root_window.position
		_root_window_saved_size = root_window.size
		_root_window_saved_mode = Window.MODE_WINDOWED if root_window.mode == Window.MODE_MINIMIZED else int(root_window.mode)
	root_window.mode = Window.MODE_WINDOWED
	root_window.position = Vector2i(-32000, -32000)
	root_window.size = Vector2i(1, 1)
	root_window.unfocusable = true
	var current_scene := get_tree().current_scene
	if current_scene is CanvasItem:
		(current_scene as CanvasItem).hide()
	_root_window_parked = true

func is_main_window_parked() -> bool:
	return _root_window_parked

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# 右键点击背景：切换 UI 面板显示/隐藏
			if is_dialogue_panel_open:
				return
			var should_show_menu := not quick_tools_panel.visible
			if should_show_menu:
				_hide_side_tool_panels()
			_set_menu_visible(should_show_menu)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				# 使用绝对屏幕坐标计算偏移，避免视口缩放导致的坐标错位
				drag_offset = DisplayServer.mouse_get_position() - position
			else:
				dragging = false
	elif event is InputEventMouseMotion and dragging:
		var new_pos = DisplayServer.mouse_get_position() - drag_offset
		
		# 使用鼠标所在位置获取目标屏幕索引，这样才能允许跨屏幕拖拽
		var mouse_pos = DisplayServer.mouse_get_position()
		var screen_idx = DisplayServer.get_screen_from_rect(Rect2i(mouse_pos, Vector2i.ONE))
		
		# 获取该屏幕的实际可用区域（排除任务栏等）
		var screen_rect = DisplayServer.screen_get_usable_rect(screen_idx)
		
		# 仅限制桌宠本体不超出屏幕边缘，允许左右工具面板越过屏幕范围
		position = _clamp_window_position_to_pet_body(new_pos, screen_rect)

func _trigger_pet_touch() -> void:
	if is_dialogue_panel_open: return
		
	var current_tick = Time.get_ticks_msec()
	# 增加一个冷却时间，防止疯狂点击
	if current_tick - _last_reaction_tick < 3000:
		return
		
	_last_reaction_tick = current_tick
	
	# 触发聊天
	if not is_chatting:
		var time_dict = Time.get_datetime_dict_from_system()
		var h = time_dict["hour"]
		var m = time_dict["minute"]
		var time_constraint = _get_time_constraint(h)
		var prompt = """【系统提示：当前现实时间是 %02d:%02d，玩家用鼠标轻轻戳了触碰了你一下。】
请你结合当前时间作为隐性语境，代入你的性格和当前心情，像真人一样对玩家的触碰做出最自然的反应。
- 反应要生动多样！可以是撒娇、傲娇吐槽、疑惑等，取决于你们的关系和心情。
- 结合你们的【微习惯与口癖】。
- 【格式强制】：你的回复必须完全遵循系统提示词中的【对话结构策略】（使用[SPLIT]等规则，必须包含括号动作描写）。
- 绝对不要在台词中报出当前时间，绝对不能提到你是AI或桌宠。""" % [h, m]
		_trigger_proactive_chat(prompt, true)

func _update_mouse_passthrough() -> void:
	print("[DesktopPet Debug] _update_mouse_passthrough started")
	# 确保窗口已经有效存在且没有在被销毁的过程中
	if not is_inside_tree() or is_queued_for_deletion():
		print("[DesktopPet Debug] Window not in tree or queued for deletion")
		return
		
	var win_id = get_window_id()
	if win_id == DisplayServer.INVALID_WINDOW_ID:
		print("[DesktopPet Debug] INVALID_WINDOW_ID")
		return
		
	print("[DesktopPet Debug] Gathering rects...")
	var rects: Array[Rect2] = []
	
	# 始终包含左侧和底部边缘的一小块区域作为拖拽抓手，防止全透明后彻底丢失窗口控制权
	rects.append(Rect2(0, size.y - 40, 40, 40))
		
	var i_layer = get_node_or_null("Control/InputLayer")
	if i_layer and i_layer.is_visible_in_tree():
		var in_rect = i_layer.get_global_rect()
		if in_rect.size.x > 0 and in_rect.size.y > 0:
			rects.append(in_rect.grow(5))

	var q_panel = get_node_or_null("Control/QuickToolsPanel")
	if q_panel and q_panel.is_visible_in_tree():
		var quick_rect = q_panel.get_global_rect()
		if quick_rect.size.x > 0 and quick_rect.size.y > 0:
			rects.append(quick_rect.grow(5))

	var pomodoro_host = get_node_or_null("Control/QuickToolsPanel/MarginContainer/VBoxContainer/Screen/ScreenMargin/ScreenStack/PomodoroPanelHost")
	if pomodoro_host and pomodoro_host.is_visible_in_tree():
		var pomodoro_rect = pomodoro_host.get_global_rect()
		if pomodoro_rect.size.x > 0 and pomodoro_rect.size.y > 0:
			rects.append(pomodoro_rect.grow(5))

	var music_host = get_node_or_null("Control/QuickToolsPanel/MarginContainer/VBoxContainer/Screen/ScreenMargin/ScreenStack/MusicPanelHost")
	if music_host and music_host.is_visible_in_tree():
		var music_rect = music_host.get_global_rect()
		if music_rect.size.x > 0 and music_rect.size.y > 0:
			rects.append(music_rect.grow(5))

	var settings_host = get_node_or_null("Control/QuickToolsPanel/MarginContainer/VBoxContainer/Screen/ScreenMargin/ScreenStack/SettingsPanelHost")
	if settings_host and settings_host.is_visible_in_tree():
		var settings_rect = settings_host.get_global_rect()
		if settings_rect.size.x > 0 and settings_rect.size.y > 0:
			rects.append(settings_rect.grow(5))
		
	if pet_body and pet_body.is_visible_in_tree():
		if pet_body.has_method("get_passthrough_rects"):
			var pet_rects = pet_body.get_passthrough_rects()
			for r in pet_rects:
				if r.size.x > 0 and r.size.y > 0:
					rects.append(r)
				
	if rects.is_empty():
		print("[DesktopPet Debug] Rects empty, setting dummy polygon")
		# 如果没有矩形，为了实现全穿透，传递一个在屏幕外的极小多边形
		var dummy := PackedVector2Array([
			Vector2(-10, -10), Vector2(-9, -10),
			Vector2(-9, -9), Vector2(-10, -9)
		])
		if is_inside_tree() and not is_queued_for_deletion():
			DisplayServer.window_set_mouse_passthrough(dummy, win_id)
		return
		
	print("[DesktopPet Debug] Building polygons from %d rects" % rects.size())
	var polys: Array[PackedVector2Array] = []
	for r in rects:
		# 顺时针和逆时针的问题在Godot中要注意，这里先按照一个标准方向构建矩形
		var p = PackedVector2Array([
			r.position,
			Vector2(r.position.x, r.end.y),
			r.end,
			Vector2(r.end.x, r.position.y)
		])
		# Godot中，Geometry2D处理的是逆时针多边形
		if Geometry2D.is_polygon_clockwise(p):
			p.reverse()
		polys.append(p)
		
	print("[DesktopPet Debug] Merging polygons...")
	# 消除重叠，避免零宽桥接在ALTERNATE填充规则下产生漏洞（镂空）
	var changed = true
	var loop_count = 0
	while changed and loop_count < 100: # 防死循环保护
		loop_count += 1
		changed = false
		for i in range(polys.size()):
			for j in range(i + 1, polys.size()):
				var intersection = Geometry2D.intersect_polygons(polys[i], polys[j])
				if intersection.size() > 0:
					var merged = Geometry2D.merge_polygons(polys[i], polys[j])
					polys.remove_at(j)
					polys.remove_at(i)
					for m in merged:
						if m.size() >= 3 and not Geometry2D.is_polygon_clockwise(m):
							polys.append(m)
					changed = true
					break
			if changed:
				break
				
	if loop_count >= 100:
		print("[DesktopPet Debug] ERROR: Polygon merge loop exceeded max iterations!")
				
	if polys.is_empty():
		print("[DesktopPet Debug] Polys empty after merge, setting dummy polygon")
		var dummy := PackedVector2Array([
			Vector2(-10, -10), Vector2(-9, -10),
			Vector2(-9, -9), Vector2(-10, -9)
		])
		if is_inside_tree() and not is_queued_for_deletion():
			DisplayServer.window_set_mouse_passthrough(dummy, win_id)
		return
		
	print("[DesktopPet Debug] Bridging %d final polygons..." % polys.size())
	var polygon := PackedVector2Array()
	var first = polys[0]
	
	if first.size() < 3:
		print("[DesktopPet Debug] ERROR: First polygon has less than 3 points!")
		return
	
	polygon.append_array(first)
	polygon.append(first[0]) # 闭合第一个多边形
	
	# 使用零宽桥接(Zero-width bridge)连接后续独立的多边形，形成单个多边形
	for i in range(1, polys.size()):
		var current = polys[i]
		if current.size() < 3:
			continue
			
		# 从第一个多边形的起点连到当前多边形的起点 (去程桥接)
		polygon.append(first[0])
		polygon.append(current[0])
		
		# 绘制当前多边形
		polygon.append_array(current)
		polygon.append(current[0]) # 闭合当前多边形
		
		# 从当前多边形的起点连回第一个多边形的起点 (回程桥接)
		polygon.append(first[0])
		
	print("[DesktopPet Debug] Setting final passthrough polygon with %d points" % polygon.size())
	if is_inside_tree() and not is_queued_for_deletion():
		DisplayServer.window_set_mouse_passthrough(polygon, win_id)
	print("[DesktopPet Debug] _update_mouse_passthrough completed")
