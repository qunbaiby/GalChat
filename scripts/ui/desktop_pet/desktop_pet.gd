extends Window

const MusicLibraryData = preload("res://scripts/data/music_library.gd")
const MUSIC_PLAYER_SCENE: PackedScene = preload("res://scenes/ui/main/music/music_player.tscn")
const AFFECTION_PANEL_SCENE: PackedScene = preload("res://scenes/ui/mobile/affection_panel.tscn")
const ARCHIVE_MEMORY_PANEL_SCENE: PackedScene = preload("res://scenes/ui/archive/archive_memory_panel.tscn")
const POMODORO_PANEL_SCENE: PackedScene = preload("res://scenes/ui/desktop_pet/pomodoro_panel.tscn")
const SETTINGS_PANEL_SCENE: PackedScene = preload("res://scenes/ui/desktop_pet/desktop_pet_settings_panel.tscn")

@onready var input_edit: TextEdit = $Control/InputLayer/MarginContainer/HBoxContainer/InputField
@onready var send_button: Button = $Control/InputLayer/MarginContainer/HBoxContainer/SendButton
@onready var quick_tools_panel: PanelContainer = $Control/QuickToolsPanel
@onready var tool_mode_chip: Label = get_node_or_null("Control/QuickToolsPanel/Canvas/ShellMargin/MainHBox/LeftColumn/HeaderCard/HeaderMargin/HeaderVBox/NameRow/ModeChip") as Label
@onready var tool_nav_button: Button = get_node_or_null("Control/QuickToolsPanel/Canvas/ToolNavButton") as Button
@onready var avatar_dock: Control = get_node_or_null("Control/AvatarDock") as Control
@onready var main_window_button: Button = get_node_or_null("Control/QuickToolsPanel/Canvas/ShellMargin/MainHBox/LeftColumn/Screen/ScreenInner/ToolContentArea/ScreenMargin/DashboardRoot/MainWindowButton") as Button
@onready var dialogue_button: Button = $Control/QuickToolsPanel/Canvas/ShellMargin/MainHBox/LeftColumn/Screen/ScreenInner/ToolContentArea/ScreenMargin/DashboardRoot/PrimaryButtons/DialogueButton
@onready var pet_settings_button: Button = get_node_or_null("Control/QuickToolsPanel/Canvas/ShellMargin/MainHBox/LeftColumn/Screen/ScreenInner/ToolContentArea/ScreenMargin/DashboardRoot/SecondaryRows/SecondRow/PetSettingsButton") as Button
@onready var affection_button: Button = get_node_or_null("Control/QuickToolsPanel/Canvas/ShellMargin/MainHBox/LeftColumn/Screen/ScreenInner/ToolContentArea/ScreenMargin/DashboardRoot/SecondaryRows/FirstRow/AffectionButton") as Button
@onready var memory_button: Button = get_node_or_null("Control/QuickToolsPanel/Canvas/ShellMargin/MainHBox/LeftColumn/Screen/ScreenInner/ToolContentArea/ScreenMargin/DashboardRoot/SecondaryRows/FirstRow/MemoryButton") as Button
@onready var close_button: Button = $Control/QuickToolsPanel/Canvas/ShellMargin/MainHBox/LeftColumn/Screen/ScreenInner/ToolContentArea/ScreenMargin/DashboardRoot/SecondaryRows/SecondRow/CloseButton
@onready var pomodoro_toggle_button: Button = $Control/QuickToolsPanel/Canvas/ShellMargin/MainHBox/LeftColumn/Screen/ScreenInner/ToolContentArea/ScreenMargin/DashboardRoot/PrimaryButtons/PomodoroToggleButton
@onready var music_toggle_button: Button = $Control/QuickToolsPanel/Canvas/ShellMargin/MainHBox/LeftColumn/Screen/ScreenInner/ToolContentArea/ScreenMargin/DashboardRoot/PrimaryButtons/MusicToggleButton
@onready var hide_tool_button: Button = $Control/QuickToolsPanel/Canvas/ShellMargin/MainHBox/LeftColumn/Screen/ScreenInner/ToolContentArea/ScreenMargin/DashboardRoot/HideToolButton

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
var _afk_greeting_trigger_ms: int = 180000

# 应用识别相关状态变量
var _window_detector: Node

var is_dialogue_panel_open: bool = false
var _spectrum_analyzer: AudioEffectSpectrumAnalyzerInstance
var is_standalone_mode: bool = false
var _pomodoro_panel_instance: Control = null
var _music_panel_instance: Control = null
var _settings_panel_instance: Control = null
var _affection_panel_instance: Control = null
var _memory_panel_instance: Control = null
var _floating_panel_entries: Dictionary = {}
var _dragging_overlay_key: String = ""
var _dragging_overlay_offset: Vector2 = Vector2.ZERO
var _root_window_parked: bool = false
var _root_window_saved_position: Vector2i = Vector2i.ZERO
var _root_window_saved_size: Vector2i = Vector2i.ZERO
var _root_window_saved_mode: int = Window.MODE_WINDOWED

const PET_MODE_QUIET := "安静模式"
const PET_MODE_FOCUS := "专注模式"
const PET_MODE_LOAF := "摸鱼模式"
const PET_MODE_NIGHT := "深夜模式"
const AFK_GREETING_DELAY_MS := 180000
const SOFT_REMINDER_APP_TYPES := ["通讯聊天软件", "办公文档软件"]
const CHAT_ORIGIN_SYSTEM := "system_trigger"
const CHAT_ORIGIN_TOUCH := "pet_touch"
const CHAT_ORIGIN_PLAYER := "player_input"

var _current_chat_origin: String = CHAT_ORIGIN_SYSTEM
var _last_observed_app_type: String = ""
var _last_observed_display_name: String = ""
var _last_observed_window_title: String = ""
var _last_observed_soft_reminder: bool = false
var _last_observed_analysis_text: String = ""

func _ready() -> void:
	if get_tree().current_scene == self:
		is_standalone_mode = true
	_current_character_id = GameDataManager.config.current_character_id
	_ready_tick_msec = Time.get_ticks_msec()
	_roll_next_afk_greeting_threshold()
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
	control_node.position = Vector2.ZERO
	
	if is_standalone_mode:
		pass # 不再修改文字，保持 "主界面"
		
	input_layer.hide()
	_set_menu_visible(false)
	quick_tools_panel.gui_input.connect(_on_tool_panel_gui_input)
	if avatar_dock:
		avatar_dock.gui_input.connect(_on_tool_panel_gui_input)
	
	# TTSManager 已在全局自动处理配置，这里不需要额外配置
	
	# 连接信号
	send_button.pressed.connect(_on_send_pressed)
	if main_window_button:
		main_window_button.pressed.connect(_on_main_window_pressed)
	close_button.pressed.connect(_on_close_pressed)
	if tool_nav_button:
		tool_nav_button.pressed.connect(_on_tool_nav_pressed)
	dialogue_button.pressed.connect(_on_dialogue_button_pressed)
	if pet_settings_button:
		pet_settings_button.pressed.connect(_on_pet_settings_pressed)
	if affection_button:
		affection_button.pressed.connect(_on_affection_button_pressed)
	if memory_button:
		memory_button.pressed.connect(_on_memory_button_pressed)
	close_input_button.pressed.connect(_on_close_input_pressed)
	voice_record_button.button_down.connect(_on_voice_record_down)
	voice_record_button.button_up.connect(_on_voice_record_up)
	pomodoro_toggle_button.pressed.connect(_on_pomodoro_toggle_pressed)
	music_toggle_button.pressed.connect(_on_music_toggle_pressed)
	if hide_tool_button:
		hide_tool_button.pressed.connect(func(): _set_menu_visible(false))
	
	if GameDataManager.config.qwen_asr_enabled:
		var qwen_asr_script = load("res://scripts/api/qwen_asr_client.gd")
		if qwen_asr_script:
			qwen_asr_client = qwen_asr_script.new()
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
	deepseek_client.emotion_request_completed.connect(_on_pet_emotion_response)
	deepseek_client.emotion_request_failed.connect(_on_pet_emotion_error)
	deepseek_client.character_mood_request_completed.connect(_on_pet_character_mood_response)
	deepseek_client.character_mood_request_failed.connect(_on_pet_character_mood_error)
	
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
		if pet_body.has_signal("pet_right_clicked"):
			pet_body.pet_right_clicked.connect(_on_pet_body_right_clicked)
	
	input_layer.visibility_changed.connect(func(): call_deferred("_update_mouse_passthrough"))
	quick_tools_panel.visibility_changed.connect(func(): call_deferred("_update_mouse_passthrough"))
	if avatar_dock:
		avatar_dock.visibility_changed.connect(func(): call_deferred("_update_mouse_passthrough"))

	_load_quick_tool_state()
	_update_tool_nav_button()
	
	# 初始化时延迟调用以更新鼠标穿透区域
	call_deferred("_update_mouse_passthrough")
	call_deferred("_sync_root_window_focusability")
	if get_tree().current_scene == self:
		call_deferred("park_main_window_for_pet")
	
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
	_update_mode_chip()
	_update_tool_nav_button()

func refresh_runtime_settings() -> void:
	_load_prompt()
	_update_mode_chip()
	_update_tool_nav_button()
	if pet_body and pet_body.has_method("_update_sprite_scale"):
		pet_body._update_sprite_scale()

func _set_menu_visible(visible_state: bool) -> void:
	quick_tools_panel.visible = visible_state
	if avatar_dock != null:
		avatar_dock.visible = visible_state
	_update_tool_nav_button()

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

func _get_overlay_root() -> Control:
	return $Control

func _get_pet_screen_rect() -> Rect2:
	var mouse_pos: Vector2i = DisplayServer.mouse_get_position()
	var screen_idx := DisplayServer.get_screen_from_rect(Rect2i(mouse_pos, Vector2i.ONE))
	var screen_rect_i: Rect2i = DisplayServer.screen_get_usable_rect(screen_idx)
	return Rect2(screen_rect_i.position, screen_rect_i.size)

func _screen_to_local(screen_position: Vector2) -> Vector2:
	return screen_position - Vector2(position.x, position.y)

func _local_to_screen(local_position: Vector2) -> Vector2:
	return Vector2(position.x, position.y) + local_position

func _get_panel_target_size(panel: Control) -> Vector2:
	if panel == null:
		return Vector2.ZERO
	var target_size := panel.custom_minimum_size
	if target_size == Vector2.ZERO:
		target_size = panel.get_combined_minimum_size()
	if target_size == Vector2.ZERO:
		target_size = panel.size
	if target_size.y <= 0.0:
		target_size.y = maxf(panel.size.y, panel.get_combined_minimum_size().y)
	if target_size.x <= 0.0:
		target_size.x = maxf(panel.size.x, panel.get_combined_minimum_size().x)
	return target_size

func _get_overlay_window_target_size(key: String, panel: Control, move_target: Control = null) -> Vector2:
	if _floating_panel_entries.has(key):
		var override_size: Variant = _floating_panel_entries[key].get("window_size_override", Vector2.ZERO)
		if override_size is Vector2 and override_size != Vector2.ZERO:
			return override_size
	var candidates: Array[Vector2] = []
	if is_instance_valid(panel):
		candidates.append(_get_panel_target_size(panel))
		candidates.append(panel.get_combined_minimum_size())
		var panel_rect_size := Vector2(maxf(panel.offset_right - panel.offset_left, 0.0), maxf(panel.offset_bottom - panel.offset_top, 0.0))
		candidates.append(panel_rect_size)
	if is_instance_valid(move_target):
		candidates.append(_get_panel_target_size(move_target))
		candidates.append(move_target.get_combined_minimum_size())
		var move_rect_size := Vector2(maxf(move_target.offset_right - move_target.offset_left, 0.0), maxf(move_target.offset_bottom - move_target.offset_top, 0.0))
		candidates.append(move_rect_size)
	var target_size := Vector2.ZERO
	for candidate in candidates:
		target_size.x = maxf(target_size.x, candidate.x)
		target_size.y = maxf(target_size.y, candidate.y)
	return target_size

func _ensure_floating_wrapper(key: String) -> Control:
	if _floating_panel_entries.has(key):
		var existing_wrapper: Control = _floating_panel_entries[key].get("wrapper", null) as Control
		if is_instance_valid(existing_wrapper):
			return existing_wrapper
	var wrapper := Control.new()
	wrapper.name = "%sFloatingWrapper" % key.capitalize()
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.visible = false
	_get_overlay_root().add_child(wrapper)
	return wrapper

func _ensure_floating_window(key: String) -> Window:
	if _floating_panel_entries.has(key):
		var existing_wrapper = _floating_panel_entries[key].get("wrapper", null)
		if existing_wrapper is Window and is_instance_valid(existing_wrapper):
			return existing_wrapper as Window
	var wrapper := Window.new()
	wrapper.name = "%sFloatingWindow" % key.capitalize()
	wrapper.transparent_bg = true
	wrapper.transparent = true
	wrapper.borderless = true
	wrapper.always_on_top = true
	wrapper.unresizable = true
	wrapper.transient = false
	wrapper.exclusive = false
	wrapper.visible = false
	wrapper.close_requested.connect(func(): _close_floating_panel(key))
	add_child(wrapper)
	return wrapper

func _register_floating_panel_entry(key: String, panel: Control, wrapper, move_target: Control, drag_handle: Control = null, draggable: bool = false) -> void:
	_floating_panel_entries[key] = {
		"wrapper": wrapper,
		"panel": panel,
		"move_target": move_target
	}
	if draggable and drag_handle != null:
		drag_handle.gui_input.connect(func(event: InputEvent): _on_overlay_drag_gui_input(key, move_target, event))
	panel.visibility_changed.connect(func(): _on_floating_panel_visibility_changed(key))

func _on_floating_panel_visibility_changed(key: String) -> void:
	if not _floating_panel_entries.has(key):
		return
	var wrapper = _floating_panel_entries[key].get("wrapper", null)
	var panel: Control = _floating_panel_entries[key].get("panel", null) as Control
	if not is_instance_valid(panel):
		return
	if wrapper is Window and is_instance_valid(wrapper):
		wrapper.visible = panel.visible
	elif wrapper is Control and is_instance_valid(wrapper):
		wrapper.visible = panel.visible
	call_deferred("_update_mouse_passthrough")

func _position_overlay_window(wrapper: Window, target_size: Vector2, anchor_bottom: bool = false, margin: float = 16.0) -> void:
	if wrapper == null:
		return
	var screen_rect: Rect2 = _get_pet_screen_rect()
	var size_i := Vector2i(ceili(target_size.x), ceili(target_size.y))
	wrapper.size = size_i
	var target_screen_pos := Vector2(
		screen_rect.position.x + (screen_rect.size.x - target_size.x) * 0.5,
		screen_rect.position.y + (screen_rect.size.y - target_size.y) * 0.5
	)
	if anchor_bottom:
		target_screen_pos.y = screen_rect.end.y - target_size.y - 26.0
	var min_pos := screen_rect.position + Vector2(margin, margin)
	var max_pos := screen_rect.end - target_size - Vector2(margin, margin)
	if max_pos.x < min_pos.x:
		max_pos.x = min_pos.x
	if max_pos.y < min_pos.y:
		max_pos.y = min_pos.y
	target_screen_pos.x = clampf(target_screen_pos.x, min_pos.x, max_pos.x)
	target_screen_pos.y = clampf(target_screen_pos.y, min_pos.y, max_pos.y)
	wrapper.position = Vector2i(roundi(target_screen_pos.x), roundi(target_screen_pos.y))

func _clamp_overlay_window_to_screen(wrapper: Window, target_size: Vector2, margin: float = 16.0) -> void:
	if wrapper == null:
		return
	var screen_rect: Rect2 = _get_pet_screen_rect()
	var min_pos := screen_rect.position + Vector2(margin, margin)
	var max_pos := screen_rect.end - target_size - Vector2(margin, margin)
	if max_pos.x < min_pos.x:
		max_pos.x = min_pos.x
	if max_pos.y < min_pos.y:
		max_pos.y = min_pos.y
	var screen_position := Vector2(wrapper.position.x, wrapper.position.y)
	screen_position.x = clampf(screen_position.x, min_pos.x, max_pos.x)
	screen_position.y = clampf(screen_position.y, min_pos.y, max_pos.y)
	wrapper.position = Vector2i(roundi(screen_position.x), roundi(screen_position.y))

func _clamp_overlay_position(move_target: Control, margin: float = 16.0) -> void:
	if move_target == null:
		return
	var target_size: Vector2 = _get_panel_target_size(move_target)
	if target_size == Vector2.ZERO:
		target_size = move_target.size
	var screen_rect: Rect2 = _get_pet_screen_rect()
	var min_screen_pos := screen_rect.position + Vector2(margin, margin)
	var max_screen_pos := screen_rect.end - target_size - Vector2(margin, margin)
	if max_screen_pos.x < min_screen_pos.x:
		max_screen_pos.x = min_screen_pos.x
	if max_screen_pos.y < min_screen_pos.y:
		max_screen_pos.y = min_screen_pos.y
	var screen_position := _local_to_screen(move_target.position)
	screen_position.x = clampf(screen_position.x, min_screen_pos.x, max_screen_pos.x)
	screen_position.y = clampf(screen_position.y, min_screen_pos.y, max_screen_pos.y)
	move_target.position = _screen_to_local(screen_position)

func _center_overlay_target(move_target: Control) -> void:
	if move_target == null:
		return
	var target_size: Vector2 = _get_panel_target_size(move_target)
	var screen_rect: Rect2 = _get_pet_screen_rect()
	var screen_position := Vector2(
		round(screen_rect.position.x + (screen_rect.size.x - target_size.x) * 0.5),
		round(screen_rect.position.y + (screen_rect.size.y - target_size.y) * 0.5)
	)
	move_target.position = _screen_to_local(screen_position)
	_clamp_overlay_position(move_target)

func _position_music_overlay(panel: Control) -> void:
	if panel == null:
		return
	var target_size: Vector2 = _get_panel_target_size(panel)
	var screen_rect: Rect2 = _get_pet_screen_rect()
	var screen_position := Vector2(
		round(screen_rect.position.x + (screen_rect.size.x - target_size.x) * 0.5),
		round(screen_rect.end.y - target_size.y - 26.0)
	)
	panel.position = _screen_to_local(screen_position)
	_clamp_overlay_position(panel, 12.0)

func _on_overlay_drag_gui_input(key: String, move_target: Control, event: InputEvent) -> void:
	if move_target == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_consume_desktop_pet_ui_input()
		var entry: Dictionary = _floating_panel_entries.get(key, {})
		var wrapper = entry.get("wrapper", null)
		if wrapper is Window and is_instance_valid(wrapper):
			if event.pressed:
				_dragging_overlay_key = key
				_dragging_overlay_offset = Vector2(DisplayServer.mouse_get_position()) - Vector2(wrapper.position.x, wrapper.position.y)
			elif _dragging_overlay_key == key:
				_dragging_overlay_key = ""
			return
		if event.pressed:
			_dragging_overlay_key = key
			_dragging_overlay_offset = Vector2(DisplayServer.mouse_get_position()) - _local_to_screen(move_target.position)
		elif _dragging_overlay_key == key:
			_dragging_overlay_key = ""
	elif event is InputEventMouseMotion and _dragging_overlay_key == key and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		var entry: Dictionary = _floating_panel_entries.get(key, {})
		var wrapper = entry.get("wrapper", null)
		if wrapper is Window and is_instance_valid(wrapper):
			var target_size := _get_panel_target_size(move_target if move_target != null else entry.get("panel", null) as Control)
			var drag_screen_pos := Vector2(DisplayServer.mouse_get_position()) - _dragging_overlay_offset
			wrapper.position = Vector2i(roundi(drag_screen_pos.x), roundi(drag_screen_pos.y))
			_clamp_overlay_window_to_screen(wrapper, target_size)
			_update_mouse_passthrough()
			return
		move_target.position = _screen_to_local(Vector2(DisplayServer.mouse_get_position()) - _dragging_overlay_offset)
		_clamp_overlay_position(move_target)
		_update_mouse_passthrough()

func _show_floating_panel(key: String, panel: Control, move_target: Control, anchor_bottom: bool = false) -> void:
	if panel == null:
		return
	var wrapper = _floating_panel_entries.get(key, {}).get("wrapper", null)
	if wrapper is Window and is_instance_valid(wrapper):
		if move_target != null:
			var target_size := _get_overlay_window_target_size(key, panel, move_target)
			var preserve_layout: bool = bool(_floating_panel_entries.get(key, {}).get("preserve_layout", false))
			if not preserve_layout:
				panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
				panel.position = Vector2.ZERO
				panel.size = target_size
				panel.custom_minimum_size = target_size
			_position_overlay_window(wrapper, target_size, anchor_bottom, 12.0 if anchor_bottom else 16.0)
		wrapper.show()
	elif is_instance_valid(wrapper):
		wrapper.show()
		wrapper.move_to_front()
	if wrapper is not Window and anchor_bottom:
		_position_music_overlay(move_target)
	else:
		if wrapper is not Window:
			_center_overlay_target(move_target)
	panel.show()
	if panel.focus_mode != Control.FOCUS_NONE:
		panel.grab_focus()
	call_deferred("_update_mouse_passthrough")

func _close_floating_panel(key: String) -> void:
	if not _floating_panel_entries.has(key):
		return
	var entry: Dictionary = _floating_panel_entries[key]
	var wrapper = entry.get("wrapper", null)
	var panel: Control = entry.get("panel", null) as Control
	if is_instance_valid(panel):
		if key == "settings" and panel.has_method("save_settings"):
			panel.save_settings()
		if panel.has_method("hide_panel"):
			panel.hide_panel()
		else:
			panel.hide()
	if is_instance_valid(wrapper):
		wrapper.hide()
	call_deferred("_update_mouse_passthrough")

func _close_all_floating_panels() -> void:
	for key in _floating_panel_entries.keys():
		_close_floating_panel(str(key))

func _get_pomodoro_panel_instance() -> Control:
	if is_instance_valid(_pomodoro_panel_instance):
		return _pomodoro_panel_instance
	_pomodoro_panel_instance = POMODORO_PANEL_SCENE.instantiate()
	var wrapper := _ensure_floating_window("pomodoro")
	wrapper.add_child(_pomodoro_panel_instance)
	_pomodoro_panel_instance.visible = false
	_pomodoro_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_pomodoro_panel_instance.position = Vector2.ZERO
	var drag_handle: Control = _pomodoro_panel_instance.get_node_or_null("Panel/DragBar") as Control
	if drag_handle == null:
		drag_handle = _pomodoro_panel_instance.get_node_or_null("Panel") as Control
	if _pomodoro_panel_instance.has_signal("back_requested"):
		_pomodoro_panel_instance.back_requested.connect(func(): _close_floating_panel("pomodoro"))
	_register_floating_panel_entry("pomodoro", _pomodoro_panel_instance, wrapper, _pomodoro_panel_instance, drag_handle, true)
	return _pomodoro_panel_instance

func _get_music_panel_instance() -> Control:
	if is_instance_valid(_music_panel_instance):
		return _music_panel_instance
	_music_panel_instance = MUSIC_PLAYER_SCENE.instantiate()
	var wrapper := _ensure_floating_window("music")
	wrapper.add_child(_music_panel_instance)
	_music_panel_instance.visible = false
	_music_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_music_panel_instance.position = Vector2.ZERO
	if _music_panel_instance.has_method("set_audio_player"):
		_music_panel_instance.set_audio_player(music_player)
	if _music_panel_instance.has_method("set_desktop_pet_mode"):
		_music_panel_instance.set_desktop_pet_mode(true)
	if _music_panel_instance.has_signal("close_requested"):
		_music_panel_instance.close_requested.connect(func(): _close_floating_panel("music"))
	_register_floating_panel_entry("music", _music_panel_instance, wrapper, _music_panel_instance, null, false)
	_floating_panel_entries["music"]["window_size_override"] = Vector2(350, 60)
	return _music_panel_instance

func _get_affection_panel_instance() -> Control:
	if is_instance_valid(_affection_panel_instance):
		return _affection_panel_instance
	_affection_panel_instance = AFFECTION_PANEL_SCENE.instantiate()
	var wrapper := _ensure_floating_window("affection")
	wrapper.add_child(_affection_panel_instance)
	_affection_panel_instance.visible = false
	_affection_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_affection_panel_instance.position = Vector2.ZERO
	var drag_handle: Control = _affection_panel_instance.get_node_or_null("RootMargin/RootVBox/TopBar") as Control
	if _affection_panel_instance.has_signal("back_requested"):
		_affection_panel_instance.back_requested.connect(func(): _close_floating_panel("affection"))
	_register_floating_panel_entry("affection", _affection_panel_instance, wrapper, _affection_panel_instance, drag_handle, true)
	return _affection_panel_instance

func _get_memory_panel_instance() -> Control:
	if is_instance_valid(_memory_panel_instance):
		return _memory_panel_instance
	_memory_panel_instance = ARCHIVE_MEMORY_PANEL_SCENE.instantiate()
	var wrapper := _ensure_floating_window("memory")
	wrapper.add_child(_memory_panel_instance)
	_memory_panel_instance.visible = false
	_memory_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var drag_handle: Control = _memory_panel_instance.get_node_or_null("CenterContainer/Panel/VBoxContainer/TopBar") as Control
	var move_target: Control = _memory_panel_instance.get_node_or_null("CenterContainer/Panel") as Control
	_register_floating_panel_entry("memory", _memory_panel_instance, wrapper, move_target, drag_handle, true)
	_floating_panel_entries["memory"]["window_size_override"] = Vector2(1040, 660)
	_floating_panel_entries["memory"]["preserve_layout"] = true
	return _memory_panel_instance

func _get_settings_panel_instance() -> Control:
	if is_instance_valid(_settings_panel_instance):
		return _settings_panel_instance
	_settings_panel_instance = SETTINGS_PANEL_SCENE.instantiate()
	var wrapper := _ensure_floating_window("settings")
	wrapper.add_child(_settings_panel_instance)
	_settings_panel_instance.visible = false
	_settings_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_settings_panel_instance.position = Vector2.ZERO
	var drag_handle: Control = _settings_panel_instance.get_node_or_null("Margin/VBox/TopBar") as Control
	if _settings_panel_instance.has_signal("back_requested"):
		_settings_panel_instance.back_requested.connect(func(): _close_floating_panel("settings"))
	_register_floating_panel_entry("settings", _settings_panel_instance, wrapper, _settings_panel_instance, drag_handle, true)
	return _settings_panel_instance

func _update_mode_chip() -> void:
	if tool_mode_chip == null:
		return
	tool_mode_chip.text = _get_pet_mode()

func _update_panel_clock() -> void:
	return

func _update_tool_nav_button() -> void:
	if tool_nav_button == null:
		return
	tool_nav_button.text = "×"
	tool_nav_button.tooltip_text = "收起工具面板"

func _on_tool_nav_pressed() -> void:
	_consume_desktop_pet_ui_input()
	_set_menu_visible(false)

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

func _on_pomodoro_toggle_pressed() -> void:
	_consume_desktop_pet_ui_input()
	var panel = _get_pomodoro_panel_instance()
	_show_floating_panel("pomodoro", panel, panel)

func _on_music_toggle_pressed() -> void:
	_consume_desktop_pet_ui_input()
	_open_music_panel(true)

func _on_pet_settings_pressed() -> void:
	_consume_desktop_pet_ui_input()
	var panel = _get_settings_panel_instance()
	_show_floating_panel("settings", panel, panel)

func _on_affection_button_pressed() -> void:
	_consume_desktop_pet_ui_input()
	var panel = _get_affection_panel_instance()
	if panel and panel.has_method("show_panel"):
		panel.show_panel(GameDataManager.profile if GameDataManager else null)
	_show_floating_panel("affection", panel, panel)

func _on_memory_button_pressed() -> void:
	_consume_desktop_pet_ui_input()
	var panel = _get_memory_panel_instance()
	if panel and panel.has_method("show_desktop_pet_panel"):
		panel.show_desktop_pet_panel()
	var move_target: Control = _floating_panel_entries.get("memory", {}).get("move_target", null) as Control
	_show_floating_panel("memory", panel, move_target)

func _open_music_panel(force_open: bool = true) -> void:
	var panel = _get_music_panel_instance()
	if panel and panel.has_method("set_audio_player"):
		panel.set_audio_player(music_player)
	if panel and panel.has_method("reload_library"):
		panel.reload_library()
	if force_open:
		_show_floating_panel("music", panel, panel, true)

func _refresh_music_panel_state() -> void:
	var panel = _get_music_panel_instance()
	if panel and panel.has_method("set_audio_player"):
		panel.set_audio_player(music_player)
	if panel and panel.has_method("reload_library"):
		panel.reload_library()
	if panel and panel.has_method("_update_ui"):
		panel._update_ui()

func _consume_desktop_pet_ui_input() -> void:
	if get_viewport():
		get_viewport().set_input_as_handled()

func _on_tool_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_consume_desktop_pet_ui_input()

func _is_mouse_over_control(control: Control) -> bool:
	if not is_instance_valid(control) or not control.visible or not control.is_visible_in_tree():
		return false
	return control.get_global_rect().has_point(get_viewport().get_mouse_position())

func _is_pointer_over_desktop_pet_ui() -> bool:
	if _is_mouse_over_control(input_layer):
		return true
	if _is_mouse_over_control(quick_tools_panel):
		return true
	if _is_mouse_over_control(avatar_dock):
		return true
	for key in _floating_panel_entries.keys():
		var panel: Control = _floating_panel_entries[key].get("panel", null) as Control
		var move_target: Control = _floating_panel_entries[key].get("move_target", null) as Control
		if _is_mouse_over_control(move_target if is_instance_valid(move_target) else panel):
			return true
	return false

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

func _is_proactive_temporarily_blocked() -> bool:
	return _is_in_quiet_time_range()

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

func _process(_delta: float) -> void:
	_sync_root_window_focusability()
	if not pet_body:
		return
		
	if is_chatting:
		pet_body.set_pet_state(1) # Thinking
	elif audio_player and audio_player.playing:
		pet_body.set_pet_state(2) # Speaking
		if _spectrum_analyzer:
			var magnitude: Vector2 = _spectrum_analyzer.get_magnitude_for_frequency_range(0, 4000)
			var volume: float = (magnitude.x + magnitude.y) / 2.0
			pet_body.update_voice_volume(volume * 5.0)
	else:
		var afk_countdown_progress: float = _get_next_afk_countdown_progress()
		if afk_countdown_progress >= 0.0:
			pet_body.set_pet_state(3, afk_countdown_progress) # 下一次 AFK 主动问候倒计时
		else:
			pet_body.set_pet_state(0)

func _get_current_idle_time_ms() -> int:
	if not is_instance_valid(_window_detector) or not _window_detector.has_method("GetIdleTimeMs"):
		return -1
	return int(_window_detector.call("GetIdleTimeMs"))

func _get_next_afk_countdown_progress() -> float:
	if GameDataManager == null or GameDataManager.config == null:
		return -1.0
	if not GameDataManager.config.pet_enable_afk_greeting or not _is_mode_allows_afk_greeting():
		return -1.0
	if _afk_greeting_trigger_ms <= 0:
		return -1.0
	var idle_time: int = _get_current_idle_time_ms()
	if idle_time < 0:
		return -1.0
	var remaining_ms: int = max(_afk_greeting_trigger_ms - idle_time, 0)
	return clamp(float(remaining_ms) / float(_afk_greeting_trigger_ms), 0.0, 1.0)

func _on_dialogue_button_pressed() -> void:
	input_layer.show()
	is_dialogue_panel_open = true
	_set_menu_visible(false)

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

func _on_asr_failed(_err: String) -> void:
	pass

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
	pet_prompt = GameDataManager.prompt_manager.build_system_prompt(GameDataManager.profile, "desktop_pet", "", [], GameDataManager.desktop_pet_memory_manager)
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
	var music_list: Array = []
	for track in MusicLibraryData.load_playlist_tracks():
		var song_name: String = MusicLibraryData.get_track_title(track)
		if not music_list.has(song_name):
			music_list.append(song_name)
	return music_list

func _play_music(song_name: String) -> void:
	if not music_player:
		return
	var tracks: Array = MusicLibraryData.load_playlist_tracks()
	if tracks.is_empty():
		if ToastManager:
			ToastManager.show_system_toast("桌面播单还是空的，先去共创音乐面板加几首歌吧", Color.RED)
		return
	var main_bgm := _get_main_bgm_player()
	if main_bgm and main_bgm.playing:
		main_bgm.stop()
	var target_track: Dictionary = {}
	if song_name != "":
		for track in tracks:
			if MusicLibraryData.get_track_title(track) == song_name:
				target_track = track
				break
	if target_track.is_empty():
		target_track = tracks[randi() % tracks.size()]
	var stream: AudioStream = MusicLibraryData.load_audio_stream(str(target_track.get("path", "")))
	if stream:
		music_player.stream = stream
		music_player.set_meta("music_track_id", str(target_track.get("id", "")))
		music_player.play()
		_open_music_panel(true)
		_refresh_music_panel_state()

func _stop_music() -> void:
	if music_player and music_player.playing:
		music_player.stop()
	_refresh_music_panel_state()

func _on_poll_timer_timeout() -> void:
	_check_vision_recovery()
	_update_mode_chip()
	_update_panel_clock()
	
	if GameDataManager.config.pet_enable_hourly_chime and _is_mode_allows_hourly_chime():
		_check_hourly_chime()
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
	if GameDataManager.desktop_pet_memory_manager == null:
		return
	if Time.get_ticks_msec() - _ready_tick_msec < 15000:
		return
	
	var current_tick: int = Time.get_ticks_msec()
	var global_cd: float = float(GameDataManager.config.pet_global_cooldown) * 1000.0
	if current_tick - _last_reaction_tick < global_cd:
		return
	
	var trigger_context: Dictionary = GameDataManager.desktop_pet_memory_manager.build_reality_memory_context()
	var revisit_data: Dictionary = GameDataManager.desktop_pet_memory_manager.get_revisit_event_candidate(trigger_context)
	if revisit_data.is_empty():
		return
	
	_last_reaction_tick = current_tick
	GameDataManager.desktop_pet_memory_manager.mark_memory_revisited(revisit_data.get("memory_id", ""), trigger_context)
	var prompt: String = GameDataManager.prompt_manager.build_memory_revisit_prompt(GameDataManager.profile, revisit_data, trigger_context)
	_trigger_proactive_chat(prompt)

func _check_vision_recovery() -> void:
	# 本地视觉次数限制已废弃，保留空实现仅兼容旧调用。
	return

func _process_pending_proactive() -> void:
	if _pending_proactive_prompt.is_empty():
		return
	if is_chatting or is_dialogue_panel_open:
		return
	if _is_proactive_temporarily_blocked():
		return
		
	var current_tick: int = Time.get_ticks_msec()
	var global_cd: float = float(GameDataManager.config.pet_global_cooldown) * 1000.0
	
	if current_tick - _last_reaction_tick >= global_cd:
		var prompt: String = _pending_proactive_prompt
		_pending_proactive_prompt = ""
		_trigger_proactive_chat(prompt)

func _roll_next_afk_greeting_threshold() -> void:
	_afk_greeting_trigger_ms = AFK_GREETING_DELAY_MS

func _check_afk_state() -> void:
	var idle_time: int = _get_current_idle_time_ms()
	if idle_time < 0:
		return
	if idle_time >= _afk_greeting_trigger_ms:
		if not _is_afk:
			_is_afk = true
			var prompt: String = GameDataManager.prompt_manager.build_desktop_pet_afk_prompt(GameDataManager.profile, "away")
			_trigger_proactive_chat(prompt)
	else:
		if _is_afk:
			_is_afk = false
			_roll_next_afk_greeting_threshold()
			var prompt: String = GameDataManager.prompt_manager.build_desktop_pet_afk_prompt(GameDataManager.profile, "return")
			_trigger_proactive_chat(prompt)

func _build_default_touch_prompt(hour: int, minute: int) -> String:
	return """【系统提示：当前现实时间是 %02d:%02d，玩家刚刚用鼠标轻轻戳了你一下。】
请你结合当前时间作为隐性语境，代入你的性格和当前心情，像真人一样对玩家的触碰做出最自然的反应。
- 反应要生动多样！可以是撒娇、傲娇吐槽、疑惑等，取决于你们的关系和心情。
- 结合你们的【微习惯与口癖】。
- 【格式强制】：你的回复必须完全遵循系统提示词中的【对话结构策略】（使用[SPLIT]等规则，必须包含括号动作描写）。
- 绝对不要在台词中报出当前时间，绝对不能提到你是AI或桌宠。""" % [hour, minute]

func _build_mode_touch_prompt(hour: int, minute: int, pet_mode: String) -> String:
	match pet_mode:
		PET_MODE_QUIET:
			return """【系统提示：当前现实时间是 %02d:%02d，玩家刚刚轻轻戳了你一下，而你现在处于安静模式。】
请你用很轻、很短、不打扰的语气回应这次触碰，像安静地应了一声，然后顺手给一句低打扰的关心。
- 不要展开应用观察，不要追问玩家在做什么。
- 回应要轻一点、柔一点，像在安静陪着。
- 【格式强制】：必须遵循【对话结构策略】，使用[SPLIT]拆分句子，必须包含括号动作描写。""" % [hour, minute]
		PET_MODE_FOCUS:
			return """【系统提示：当前现实时间是 %02d:%02d，玩家刚刚轻轻戳了你一下，而你现在处于专注模式。】
请你像在陪玩家保持专注一样回应这次触碰，重点是轻提醒、打气、稳住节奏，不要展开应用观察。
- 可以简短提醒喝水、活动肩颈、继续加油，但不要打断感太强。
- 语气要克制、清醒、可靠。
- 【格式强制】：必须遵循【对话结构策略】，使用[SPLIT]拆分句子，必须包含括号动作描写。""" % [hour, minute]
		PET_MODE_NIGHT:
			return """【系统提示：当前现实时间是 %02d:%02d，玩家刚刚轻轻戳了你一下，而你现在处于深夜模式。】
请你用偏夜晚的陪伴感回应这次触碰，重点是安静、柔和、轻声提醒别太晚，不要展开应用观察。
- 可以有一点困意、黏人感或轻轻催休息，但不要太唠叨。
- 整体像夜里凑近说的一句。
- 【格式强制】：必须遵循【对话结构策略】，使用[SPLIT]拆分句子，必须包含括号动作描写。""" % [hour, minute]
		_:
			return _build_default_touch_prompt(hour, minute)

func _trigger_touch_app_observe() -> bool:
	if not is_instance_valid(_window_detector):
		return false
	var raw_window_title = _window_detector.call("GetCurrentWindowTitle")
	var raw_process_name = _window_detector.call("GetCurrentProcessName")
	var window_title: String = "" if raw_window_title == null else str(raw_window_title)
	var process_name: String = "" if raw_process_name == null else str(raw_process_name)
	if window_title == "" and process_name == "":
		return false
	if not _is_app_observe_allowed_by_policy(process_name, window_title):
		return false

	var app_type: String = _map_app_type(window_title, process_name)
	var is_sensitive_window := _matches_policy_keywords(process_name, window_title, str(GameDataManager.config.pet_sensitive_window_list))
	var soft_reminder: bool = is_sensitive_window or _is_soft_reminder_app(app_type)
	var display_name: String = _build_safe_app_display_name(process_name, window_title, app_type, soft_reminder)
	_last_observed_app_type = app_type
	_last_observed_display_name = display_name
	_last_observed_window_title = window_title
	_last_observed_soft_reminder = soft_reminder
	var time_dict: Dictionary = Time.get_datetime_dict_from_system()
	var h: int = int(time_dict["hour"])
	var m: int = int(time_dict["minute"])

	var base64_image: String = ""
	var allow_capture := _should_capture_for_app(process_name, window_title, app_type, is_sensitive_window)
	var vision_enabled: bool = GameDataManager.config.vision_enabled
	var has_vision_key: bool = not GameDataManager.config.vision_api_key.is_empty()
	var fallback_reason: String = "capture_unavailable"
	if allow_capture and vision_enabled and has_vision_key:
		if _window_detector.has_method("CaptureForegroundWindowToBase64"):
			base64_image = _window_detector.call("CaptureForegroundWindowToBase64")
		elif _window_detector.has_method("CaptureScreenToBase64"):
			base64_image = _window_detector.call("CaptureScreenToBase64")
		if base64_image != "":
			fallback_reason = ""
	elif not allow_capture:
		fallback_reason = "capture_blocked_by_policy"
	elif not vision_enabled:
		fallback_reason = "vision_disabled"
	elif not has_vision_key:
		fallback_reason = "vision_key_missing"
	if base64_image != "":
		var vision_prompt: String = _build_touch_observe_vision_prompt(h, m, window_title, app_type)
		_trigger_vision_chat(vision_prompt, base64_image, CHAT_ORIGIN_TOUCH)
		return true

	var prompt: String = _build_touch_observe_text_prompt(h, m, display_name, app_type, soft_reminder, fallback_reason)
	_trigger_proactive_chat(prompt, true, CHAT_ORIGIN_TOUCH)
	return true

func _is_app_observe_allowed_by_policy(process_name: String, window_title: String) -> bool:
	if _is_self_observe_window(process_name, window_title):
		return false
	if GameDataManager == null or GameDataManager.config == null:
		return true
	var allow_list := str(GameDataManager.config.pet_observe_allow_list).strip_edges()
	if allow_list == "":
		return true
	return _matches_policy_keywords(process_name, window_title, allow_list)

func _is_self_observe_window(process_name: String, window_title: String) -> bool:
	var process_lower := process_name.to_lower()
	var title_lower := window_title.to_lower()
	if process_lower.contains("godot"):
		return true
	if title_lower.contains("godot engine"):
		return true
	if title_lower.contains("galchat") and (title_lower.contains(".tscn") or title_lower.contains("desktop_pet")):
		return true
	return false

func _should_capture_for_app(process_name: String, window_title: String, _app_type: String, is_sensitive_window: bool) -> bool:
	if GameDataManager == null or GameDataManager.config == null:
		return false
	if _is_self_observe_window(process_name, window_title):
		return false
	if is_sensitive_window:
		return false
	if _matches_policy_keywords(process_name, window_title, str(GameDataManager.config.pet_never_capture_list)):
		return false
	if _get_pet_mode() == PET_MODE_NIGHT:
		return false
	return true

func _build_touch_observe_vision_prompt(hour: int, minute: int, window_title: String, app_type: String) -> String:
	var lines: Array[String] = [
		"【系统提示：当前现实时间是 %02d:%02d，玩家刚刚戳了你一下，你顺势看到了他正在看的“%s”窗口截图。】" % [hour, minute, window_title],
		"请作为专业的视觉场景观察员，尽可能准确、具体地描述当前画面里真正能看到的内容，再提炼出“最容易让 Luna 产生第一反应的刺激点”。",
		"输出必须基于画面证据，不要角色扮演，不要直接生成 Luna 的台词，不要把猜测当成事实。",
		_get_app_observe_vision_focus(app_type),
		"优先提取：当前焦点内容、可读文字、主体对象、玩家似乎正在做的事情、最容易引发一句自然反应的细节。",
		"不要根据系统时间自行扩写成“凌晨还在看”“深夜独处”“偷偷摸摸”这类文学化推断，除非画面本身明确可见。",
		"忽略无用 UI 外壳、菜单栏、按钮堆、背景装饰、行号等冗余元素。像页码、播放图标、零碎英文残句这类信息，除非它们就是画面核心，否则不要抢主角。",
		"如果画面里同时存在“主页面内容”和“临时浮层/小弹窗/调试面板/桌宠自身弹窗”，优先把主页面内容当主角。临时浮层只有在它占据视觉中心、信息量明显更强、且真的比主页面更刺眼时，才允许成为刺激点。",
		"尤其不要被桌宠自己的情感状态弹窗、调试浮层、角落提示条带偏。除非这些浮层就是玩家此刻真正盯着看的核心，否则它们只能算次要背景。",
		"如果可能涉及隐私，只做模糊描述，不展开具体聊天内容、账号信息、邮件正文或私人身份信息。",
		"如果画面明显就是成人/色情向插画、CG 或截图，而且证据足够明确，就直接判断为“成人向/色情向画面”，不要退缩成含糊的“尺度较大”。但也不要写成审查报告，要像在客观描述眼前看到的东西。",
		"建议输出格式：",
		"画面性质：普通 / 暧昧 / 成人向 / 不确定（四选一，必须给出）",
		"画面内容：用 1 到 2 句准确描述当前最核心的可见画面，包括能看清的文字、人物、物体、界面主题或主要动作。",
		"关键细节：列 2 到 4 个最值得 Luna 接话的具体点，越具体越好；优先保留真正影响人物反应的核心细节，不要把边角 UI 信息塞进来凑数。",
		"玩家状态线索：只根据画面可见证据，概括玩家此刻像是在做什么或处于什么状态；如果无法确认，就写“不确定”。",
		"刺激点：从上面的细节里挑出 1 个最容易让 Luna 当场有本能反应的点。这个点必须是真正会刺到人情绪的核心，不要用页码、编号、按钮、残缺英文句子这类边角信息充数。",
		"禁止脑补：列出 1 到 2 个最容易被误猜、但当前画面并没有证据支持的推断，提醒后续角色回复不要踩进去。",
        "不确定项：如果某些内容看不清，就明确写“看不清/不确定”，不要硬猜。"
	]
	return "\n".join(lines)

func _build_touch_observe_text_prompt(hour: int, minute: int, display_name: String, app_type: String, soft_reminder: bool, fallback_reason: String = "capture_unavailable") -> String:
	var lines: Array[String] = [
		"【系统提示：当前现实时间是 %02d:%02d，玩家刚刚戳了你一下。】" % [hour, minute],
		"这是一次由“戳一下”触发的短暂应用观察，不要假装你一直在盯着屏幕。",
		_build_touch_observe_scene_line(display_name, app_type, soft_reminder, fallback_reason),
		_build_touch_observe_character_core_guidance(),
		_build_touch_observe_flavor_guidance(),
		_build_touch_observe_compact_relation_guidance(app_type, "", soft_reminder),
		_build_touch_observe_instinctive_guidance(app_type, soft_reminder, false),
		_get_app_observe_reply_guidance(app_type, soft_reminder),
		_build_touch_observe_output_contract(false)
	]
	return "\n".join(lines)

func _build_touch_observe_scene_line(display_name: String, app_type: String, soft_reminder: bool, fallback_reason: String = "capture_unavailable") -> String:
	if fallback_reason == "vision_quota_exhausted":
		return "你只知道玩家当前打开的是和“%s”相关的界面（归类为%s），但这次没有看到具体画面细节。不要编造页面内容、游戏名、按钮、标题或价格信息，只能围绕应用类型和时间氛围自然接一句。" % [display_name, app_type]
	if fallback_reason == "vision_disabled" or fallback_reason == "vision_key_missing":
		return "你这次只从前台窗口名判断出玩家正在使用和“%s”相关的界面（归类为%s），并没有获得具体画面内容。不要假装看到了详细页面。" % [display_name, app_type]
	if fallback_reason == "capture_blocked_by_policy":
		return "你顺势注意到玩家正在处理一个和“%s”相关的界面（归类为%s）。这次不能看具体截图，但还是要根据应用类型给出贴题、自然的反应，不要只说不打扰。" % [display_name, app_type]
	if soft_reminder:
		return "你顺势注意到玩家正在处理一个和“%s”相关的界面（归类为%s）。这个场景要尊重边界，不要追问隐私，但仍然要抓住一个可回应的点自然接话。" % [display_name, app_type]
	return "你顺势看到了玩家正在看的内容和“%s”有关（大致属于%s）。请围绕最具体、最有临场感的那个点自然接话。" % [display_name, app_type]

func _build_touch_observe_stage_guidance() -> String:
	if GameDataManager == null or GameDataManager.profile == null:
		return "请严格遵守当前情感阶段边界，不要为了有戏剧性就越界。"
	var profile = GameDataManager.profile
	var stage_conf: Dictionary = profile.get_current_stage_config()
	var stage_title: String = str(stage_conf.get("stageTitle", "当前阶段")).replace("{char_name}", profile.char_name)
	var stage_desc: String = str(stage_conf.get("stageDesc", "")).replace("{char_name}", profile.char_name)
	var lines: Array[String] = [
		"【当前阶段提示】现在处于“%s”。" % stage_title
	]
	if stage_desc != "":
		lines.append(stage_desc)
	var important_notes: String = str(stage_conf.get("important_notes", "")).replace("{char_name}", profile.char_name).strip_edges()
	if important_notes != "":
		lines.append("【当前阶段专属约束】%s" % important_notes)
	var scene_setting: String = str(stage_conf.get("scene_setting", "")).replace("{char_name}", profile.char_name).strip_edges()
	if scene_setting != "":
		lines.append("【当前阶段场景反应参考】%s" % scene_setting)
	lines.append("你的反应必须服从这个阶段的人际边界：阶段未到时，不要强行吃醋、占有、发火或说得过分亲密。")
	return "\n".join(lines)

func _build_touch_observe_character_core_guidance() -> String:
	if GameDataManager == null or GameDataManager.profile == null:
		return "请保持角色本人的稳定底色：温柔、克制、真诚，不要写成油滑、咋呼、尖刻或故意演出来的反应。"
	var profile = GameDataManager.profile
	var lines: Array[String] = []
	var core_traits: String = str(profile.base_personality.get("core_traits", "")).replace("{char_name}", profile.char_name).strip_edges()
	var dialogue_style: String = str(profile.base_personality.get("dialogue_style", "")).replace("{char_name}", profile.char_name).strip_edges()
	if core_traits != "":
		lines.append("【角色基础底色】\n%s" % core_traits)
	if dialogue_style != "":
		lines.append("【角色说话底色】\n%s" % dialogue_style)
	lines.append("【稳定人设硬约束】Luna 安静温柔、慢热有分寸，熟悉后会露出俏皮和坚持的一面，但本质上始终真诚、细腻、克制，不会无理取闹，也不会突然变成刻薄的评论员。")
	lines.append("【绝对禁止】不要凭空给玩家补动机或用途，例如“你是在画参考”“你是在收藏”“你是在研究”“你在故意测试我”，除非画面里明确有证据。")
	lines.append("【绝对禁止】不要厌恶、嫌弃或否定玩家的工作、代码、兴趣和娱乐内容；即使介意，也只能表现为安静的别扭、轻酸、迟疑、心疼或认真表达，而不是无理发火。")
	lines.append("【绝对禁止】不要使用过于互联网化、油滑、像段子手、像客服、像旁白、像内容讲解员的说话方式。")
	return "\n".join(lines)

func _build_touch_observe_dynamic_personality_guidance() -> String:
	if GameDataManager == null or GameDataManager.profile == null or GameDataManager.personality_system == null:
		return "请保留当前动态人格状态，但不能覆盖角色基础底色和阶段边界。"
	var profile = GameDataManager.profile
	var lines: Array[String] = []
	var personality_summary: String = str(GameDataManager.personality_system.get_personality_state_summary(profile)).strip_edges()
	var dynamic_traits: String = str(GameDataManager.personality_system.get_dynamic_traits(profile)).replace("{char_name}", profile.char_name).strip_edges()
	if personality_summary != "":
		lines.append("【当前动态人格概览】%s" % personality_summary)
	if dynamic_traits != "":
		lines.append("【当前动态人格细节】\n%s" % dynamic_traits)
	lines.append("这些动态人格只用于微调此刻的口吻、敏感点和应激反应，绝不能覆盖 Luna 的基础底色、阶段说明、scene_setting 与 important_notes。")
	return "\n".join(lines)

func _build_touch_observe_flavor_guidance() -> String:
	if GameDataManager == null or GameDataManager.profile == null:
		return "请保留你自己的口癖、微习惯和情绪质感，不要写成标准客服话术。"
	var profile = GameDataManager.profile
	var flavor_label: String = str(profile.personality_state.get("flavor", "Guarded"))
	var micro_habits: String = ""
	if GameDataManager.personality_system:
		micro_habits = str(GameDataManager.personality_system.get_micro_habits(profile)).replace("{char_name}", profile.char_name).strip_edges()
	var flavor_desc: String = ""
	match flavor_label:
		"Guarded":
			flavor_desc = "整体偏克制、试探、带一点嘴硬，不会一上来就把情绪摊开。"
		"Warm":
			flavor_desc = "整体偏温软、贴近、会自然流露关心，但不要腻得发甜。"
		"Playful":
			flavor_desc = "整体偏灵动、会轻轻逗一下或抖机灵，但不能像段子机。"
		"Depend":
			flavor_desc = "整体偏依恋、会不自觉靠近玩家，但仍要服从阶段边界。"
		_:
			flavor_desc = "整体要保留鲜明的人味和关系层次，不要写成统一模板。"
	var lines: Array[String] = [
		"【当前风味】%s。" % flavor_desc
	]
	if micro_habits != "":
		lines.append("【微习惯与口癖参考】\n%s" % micro_habits)
	lines.append("优先让回复像 Luna 临场起意说出来的话，而不是像整理过的标准答案。")
	return "\n".join(lines)

func _build_touch_observe_instinctive_guidance(app_type: String, soft_reminder: bool, visual_confirmed: bool) -> String:
	var lines: Array[String] = [
		"先做第一反应，再说内容。第一反应应该像真人被你当场撞见某个画面时，会先停一下、皱眉、愣住、偷笑、心虚、嘴硬、替你紧张，或下意识靠近吐槽，而不是先开始解释画面。",
		"不要做评论员，不要做讲解员，不要做影评人，也不要像内容审核说明。你不是在点评屏幕，你是在看到屏幕后当场有了反应。",
		"你的话要同时落在两个对象上：一是画面里最刺眼的那个点，二是玩家正在看它这件事。不能只评论内容本身，也不能完全无视玩家。",
		"第一句更像被画面撞到后的下意识出声，第二句才允许把在意、陪伴、好奇、吐槽、心疼或轻酸落到玩家身上。",
		"除非场景真的很轻，不要只吐一句就戛然而止。更自然的节奏是：先被画面撞一下，再把情绪落到玩家身上，最后补半句轻收尾，让回应有一个小小余韵。",
        "这里的“丰富”不是变成长篇大论，而是让一句反应多出半拍情绪和关系感。通常写成 2 到 3 个短句、2 到 4 段 [SPLIT] 会更像真人临场反应。"
	]
	if visual_confirmed:
		lines.append("这次你是真的看到了具体画面，所以先让自己对那个画面起反应，再顺势把情绪落到玩家身上。")
	else:
		lines.append("这次你没有看到完整画面，只知道应用类型或窗口信息，所以仍然要像本能反应，不要编造细节，更不要端着分析。")
	if soft_reminder:
		lines.append("因为这是边界更敏感的场景，本能反应也要收一点，像轻轻贴边的一下，而不是直接闯进去。")
	match app_type:
		"编程开发工具":
			lines.append("看开发工具时，不要点评代码质量或讲术语，优先像看到玩家卡住、报错、死盯着一段东西时的心疼、拱火、陪着一起皱眉。")
		"办公文档软件":
			lines.append("看文档表格时，不要像上司点评工作，优先像看到玩家又被任务压住、脑子发木、还在硬撑时的轻叹气、体贴或小吐槽。")
		"网页浏览器":
			lines.append("看网页时，不要像内容博主复述页面，优先对最扎眼的主题或槽点产生好奇、嫌弃、想笑、想凑近看的反应。")
		"视频":
			lines.append("看视频时，不要概述剧情，优先抓住一个画面冲击、表情、反差或氛围，让自己先有本能反应。")
		"游戏":
			lines.append("看游戏时，不要播报局势，优先像陪在旁边那样替玩家紧张、激动、着急、手痒或想吐槽。")
		"音乐":
			lines.append("看音乐相关时，不要做乐评，优先像被某种氛围或情绪一下勾住，然后顺着那股感觉接一句。")
		_:
			lines.append("不管是什么画面，都先问自己：Luna 看到这一眼时，本能上会先皱眉、偷笑、停住、嘴硬、还是忽然想凑近？先把那个反应写出来。")
	return "\n".join(lines)

func _get_app_observe_vision_focus(app_type: String) -> String:
	match app_type:
		"编程开发工具":
			return "如果是代码、IDE 或终端，优先提取：当前在改什么、报错/卡点、文件名或最值得接话的一行关键词。"
		"办公文档软件":
			return "如果是文档、表格、PPT，优先提取：文档主题、标题、待处理任务、最明显的工作压力点。"
		"通讯聊天软件":
			return "如果是聊天、社交、邮件，优先提取：话题氛围和可被轻轻回应的情绪线索，不要展开具体隐私内容。"
		"网页浏览器":
			return "如果是网页浏览，优先提取：当前页面主题、主视觉内容、搜索关键词或正文焦点、最容易引发情绪反应的核心点。不要让角落弹窗、浏览器标签、临时提示层抢走主刺激点。"
		"视频":
			return "如果是视频或直播，优先提取：画面焦点、标题主题、情绪氛围、最容易让 Luna 插一句的点。"
		"游戏":
			return "如果是游戏，优先提取：当前局面、角色状态、胜负压力或最有戏剧感的瞬间。"
		_:
			return "优先提取当前最具体、最容易让 Luna 接一句的细节，不要只给宽泛分类。"

func _get_app_observe_reply_guidance(app_type: String, soft_reminder: bool) -> String:
	if soft_reminder:
		match app_type:
			"通讯聊天软件":
				return "这里要保留边界感，但不要默认退成“那我不打扰你”。更自然的写法是：先对聊天氛围、对方此刻的状态或你自己被晾到的小情绪起一点反应，再补半句温柔陪伴或轻试探，绝不能查岗，也不要点评隐私内容。"
			"办公文档软件":
				return "这里更适合低打扰关心：像看到玩家还在硬撑时下意识心疼一下，再轻轻陪一句，不要长篇建议，也不要评论工作内容。可以多一小句收尾，让关心更像陪在旁边。"
			_:
				return "这里更适合边界感明确的轻回应：短、轻、贴边，但仍要先抓住一个具体点起反应，再顺手补半句情绪或陪伴，不要侵入感太强，也不要端着分析。"
	match app_type:
		"编程开发工具":
			return "如果是开发工具，优先写成：先对卡点/报错/死盯着屏幕这件事起反应，再给一点懂行的陪伴、心疼或轻吐槽，最后顺手补一句很短的撑腰或催休息，别像代码评审。"
		"办公文档软件":
			return "如果是文档表格，优先写成：先对任务压力或枯燥感起反应，再给一点体贴或小玩笑，最后轻轻托住一下情绪，不要像工作汇报或内容总结。"
		"网页浏览器":
			return "如果是网页，优先写成：先被主页面最刺眼的主题或氛围勾住一下，再顺势表达一点好奇、在意、轻酸或轻吐槽，最后把注意力落回玩家。不要先猜用途，不要上来问“是找参考吗/是在研究吗/是在收藏吗”。"
		"视频":
			return "如果是视频，优先对画面冲击、氛围或反差先冒出一句带情绪的反应，再顺手带一句你对玩家状态的感觉，不要平铺直叙，不要概述视频。"
		"游戏":
			return "如果是游戏，优先写成临场感：像陪在旁边看着玩家操作一样替他紧张、兴奋、心疼或拱火，再补一句贴身一点的反应，但不要像系统播报。"
		"音乐":
			return "如果是音乐相关，优先写感受和联想：像被氛围一下勾住之后自然接一句，再补一点你想贴近玩家的感觉，而不是泛泛说好听，也不要像乐评。"
		_:
			return "优先对一个具体细节先冒出本能态度，再补一句轻陪伴或轻试探，必要时多半句收尾，不要写成泛泛关心，也不要像在点评内容。"

func _trigger_vision_chat(prompt_text: String, base64_image: String, origin: String = CHAT_ORIGIN_SYSTEM) -> void:
	if is_chatting: return
	_current_chat_origin = origin
	is_chatting = true
	current_response = ""
	bubble_queue.clear()
	if pet_body: pet_body.clear_bubbles()
	if audio_player and audio_player.playing: audio_player.stop()
	
	# 构建专属的独立请求记录
	chat_history.append({"role": "user", "content": "【屏幕截图发送成功】" + prompt_text})
	if chat_history.size() > 10: chat_history = chat_history.slice(-10)
	_load_prompt()

	deepseek_client.send_vision_request(pet_prompt, prompt_text, base64_image)

func _on_vision_completed(response: Dictionary) -> void:
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
		_last_observed_analysis_text = analysis_text
		
		# 将分析结果作为主动聊天的触发器，发给专门负责角色扮演的文本大模型
		var prompt: String = _build_touch_observe_vision_reply_prompt(analysis_text)
		
		# 必须先重置 is_chatting，否则 _trigger_proactive_chat 会被拦截
		is_chatting = false
		_trigger_proactive_chat(prompt, true, _current_chat_origin)
	else:
		is_chatting = false
		_current_chat_origin = CHAT_ORIGIN_SYSTEM
		var text = "（看着屏幕发呆）……"
		chat_history.append({"role": "assistant", "content": text})
		display_bubble(text)

func _on_vision_failed(error_msg: String) -> void:
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
	_current_chat_origin = CHAT_ORIGIN_SYSTEM

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
	elif "wechat" in p or "weixin" in p or "qq" in p or "discord" in p or "telegram" in p:
		return "通讯聊天软件"
	elif "bilibili" in p or "youtube" in p or "video" in p or "player" in p:
		return "视频"
	elif "music" in p or "cloudmusic" in p or "netease" in p or "spotify" in p:
		return "音乐"
		
	return process if process != "" else "未知应用"

func _build_touch_observe_vision_reply_prompt(analysis_text: String) -> String:
	var app_type: String = _last_observed_app_type
	var display_name: String = _last_observed_display_name
	var soft_reminder: bool = _last_observed_soft_reminder
	var lines: Array[String] = [
		"【系统提示：视觉分析系统刚刚捕捉到了玩家当前正在查看的屏幕画面。】",
		"本次应用观察上下文：当前大致应用类型=%s，显示名=%s。" % [app_type if app_type != "" else "未知", display_name if display_name != "" else "未知"],
		"以下是屏幕画面的精炼分析：",
		analysis_text,
		"",
		"请你严格代入 Luna 当前设定，对这个画面做出像真人一样的第一反应。",
		_build_touch_observe_character_core_guidance(),
		_build_touch_observe_flavor_guidance(),
		_build_touch_observe_compact_relation_guidance(app_type, analysis_text, soft_reminder),
		_build_touch_observe_instinctive_guidance(app_type, soft_reminder, true),
		_get_app_observe_reply_guidance(app_type, soft_reminder),
		_build_touch_observe_special_reply_guidance(analysis_text),
		_build_touch_observe_output_contract(true)
	]
	return "\n".join(lines)

func _build_touch_observe_compact_relation_guidance(app_type: String, analysis_text: String = "", soft_reminder: bool = false) -> String:
	if GameDataManager == null or GameDataManager.profile == null:
		return "先守住当前关系边界，再决定靠近力度；不要所有场景都说成同一档温柔。"
	var profile = GameDataManager.profile
	var stage_conf: Dictionary = profile.get_current_stage_config()
	var stage_level := int(stage_conf.get("stage", profile.current_stage))
	var stage_title := str(stage_conf.get("stageTitle", "当前阶段")).replace("{char_name}", profile.char_name)
	var normalized := analysis_text.to_lower()
	var has_social_cue := app_type == "通讯聊天软件" or _analysis_contains_any_cue(normalized, ["聊天", "对话", "消息", "社交", "微信", "qq", "discord", "telegram"])
	var has_romantic_cue := _analysis_contains_any_cue(normalized, ["女孩", "女生", "女人", "异性", "可爱", "插画", "约会", "暧昧", "亲昵", "恋爱", "制服少女"])
	var lines: Array[String] = [
		"【关系边界】现在处于“%s”。先服从这个阶段的人际边界，再决定你能有多靠近、多在意、多黏。不要越界，也不要所有阶段都像同一种人。" % stage_title
	]
	if has_social_cue or has_romantic_cue:
		if stage_level <= 2:
			lines.append("这类画面会让你注意到，但你仍偏克制。只允许轻顿、轻试探、礼貌贴一句，不要占有、查岗、发酸过头。")
		elif stage_level <= 4:
			lines.append("这类画面已经会让你在意。可以写成轻失落、轻酸、想被注意到，再安静地把视线拉回自己，不要只站远处说漂亮话。")
		elif stage_level <= 6:
			lines.append("这类画面下，你可以明确表现“我在意这个”，带一点小任性、小撒娇或轻吃味，但要软，不要像审问。")
		else:
			lines.append("这类画面下，你更像伴侣。重点不是患得患失，而是带着亲昵和归属感去贴近、占位、把玩家轻轻拉回自己这边。")
	else:
		if stage_level <= 2:
			lines.append("普通场景下保持礼貌温柔和克制，轻轻接一句，不抢节奏。")
		elif stage_level <= 4:
			lines.append("普通场景下可以更主动一点，会顺手补一句关心或陪伴，让人感觉你在慢慢靠近。")
		elif stage_level <= 6:
			lines.append("普通场景下要像已经把玩家放进心上，关心更贴身一些，但别写成标准温柔模板。")
		else:
			lines.append("普通场景下要有稳定伴侣感，像默认自己就在他身边，能自然接住他的状态。")
	if soft_reminder:
		lines.append("这个场景边界更敏感，收一点，不追问隐私，只围绕看得见的氛围轻贴一句。")
	return "\n".join(lines)

func _build_touch_observe_output_contract(visual_confirmed: bool) -> String:
	var lines: Array[String] = []
	if visual_confirmed:
		lines.append("【输出要求】只围绕分析里明确写出的刺激点开口，不补用途、不补动机、不补新剧情。")
	else:
		lines.append("【输出要求】只围绕窗口类型或可见线索开口，不要假装看到了具体画面。")
	lines.append("先给第一反应，再把情绪落到玩家身上，最后补半句轻收尾。通常 2 到 3 个短句、2 到 4 段 [SPLIT] 就够了。")
	lines.append("不要写成总结、讲解、复述页面、采访式提问或空泛关心。问句最多一小句，而且放在情绪之后。")
	lines.append("禁止用猜用途的问句当兜底，例如“是找参考吗”“是在研究吗”“是在收藏吗”“是游戏里的东西吗”。除非画面里有非常直接的证据，否则优先陈述你的临场感受，而不是盘问用途。")
	lines.append("如果分析里同时提到了主页面内容和次要浮层，默认优先围绕主页面内容起反应；不要因为浮层上有数字、等级、按钮，就把整句带偏。")
	lines.append("不要把玩家叫成老师、同学、用户，也不要提自己是 AI、桌宠、视觉分析或系统。")
	lines.append("【格式强制】回复必须遵循【对话结构策略】，用 [SPLIT] 拆分长句，必须包含括号动作描写。")
	return "\n".join(lines)

func _build_touch_observe_relation_mood_guidance() -> String:
	if GameDataManager == null or GameDataManager.profile == null:
		return "请结合当前关系阶段、情绪和人设说话，不要写成无差别统一回复。"
	var profile = GameDataManager.profile
	var mood_name: String = "平静"
	if GameDataManager.mood_system:
		mood_name = str(GameDataManager.mood_system.get_macro_mood_name(profile.mood_value))
	var expression_name: String = str(profile.current_expression)
	if expression_name == "":
		expression_name = "calm"
	var lines: Array[String] = [
		"【当前关系快照】亲密度=%d，信任度=%d。你的语气轻重、靠近程度、试探感、占有欲边界都必须服从这个数值和当前阶段。" % [profile.intimacy, profile.trust],
		"【当前情绪快照】整体心情=%s，瞬时表情=%s。整体心情决定本轮回应的大底色，瞬时表情只负责细小波纹。你的第一反应、停顿方式、嘴硬程度、关心力度都必须带着这个情绪状态。" % [mood_name, expression_name]
	]
	return "\n".join(lines)

func _build_touch_observe_attachment_guidance(analysis_text: String) -> String:
	if GameDataManager == null or GameDataManager.profile == null:
		return "请把当前关系阶段真正落实到反应力度上，不要所有阶段都说得差不多。"
	var profile = GameDataManager.profile
	var normalized := analysis_text.to_lower()
	var has_social_cue := false
	var cue_keywords := [
		"聊天", "对话", "消息", "社交", "微信", "qq", "discord", "telegram",
		"女孩", "女生", "女人", "异性", "可爱", "q版", "插画", "约会", "暧昧", "亲昵"
	]
	for keyword in cue_keywords:
		if keyword in analysis_text or keyword in normalized:
			has_social_cue = true
			break
	var stage_title := str(profile.get_current_stage_config().get("stageTitle", "当前阶段")).replace("{char_name}", profile.char_name)
	var lines: Array[String] = [
		"【关系敏感反应】你现在处于“%s”，必须让这次应用观察的口吻轻重明显服从当前关系阶段，而不是所有阶段都写成统一的温柔回答。" % stage_title
	]
	if not has_social_cue:
		lines.append("即使这次画面没有明显的他人刺激，也要让靠近程度、黏人感、试探感和撒娇力度跟当前阶段匹配。")
		return "\n".join(lines)
	if profile.intimacy < 120 or profile.trust < 120:
		lines.append("这次画面里带有他人/可爱异性/聊天氛围线索，但阶段还偏早。你可以注意到，也可以有一点轻微停顿或好奇，但不要强行吃醋、查岗、占有，更多是安静地观察、轻轻试探或礼貌地贴一句。")
	elif profile.intimacy < 320 or profile.trust < 320:
		lines.append("这次画面已经足够让你在意。你不该完全装作没感觉，而是应该有一点失落、轻酸、想被注意到的心思，再用克制但明显的方式把视线拉回自己，例如靠近一点、补一句软软的话、半认真地试探一下。")
	elif profile.intimacy < 700 or profile.trust < 700:
		lines.append("你已经是很重要的那个人了。看到这类画面时，可以明确表现出在意、轻吃味、想争取位置的感觉，但方式仍然要像伴侣间自然的小别扭、小撒娇、小占位，不要像盘问，也不要像陌生人采访。")
	else:
		lines.append("你已经把玩家当成自己最亲近的归宿。面对这类画面，不需要患得患失，也不要冷冷旁观；更自然的是带着安心和亲昵去靠近、撒一点娇、把注意力软软地拉回来，像默认自己就该待在他身边。")
	lines.append("如果画面里既有可爱女孩/暧昧气息，又有聊天或社交线索，优先落在“你此刻被刺到哪里”和“你想怎么把玩家拉回自己这边”，不要把重点写成解释页面用途。")
	return "\n".join(lines)

func _build_touch_observe_stage_voice_guidance(analysis_text: String) -> String:
	if GameDataManager == null or GameDataManager.profile == null:
		return "请把关系阶段落实到说话力度和靠近方式里，不要写成同一档情绪。"
	var profile = GameDataManager.profile
	var stage_conf: Dictionary = profile.get_current_stage_config()
	var stage_level := int(stage_conf.get("stage", profile.current_stage))
	var normalized := analysis_text.to_lower()
	var has_social_cue := _analysis_contains_any_cue(normalized, ["聊天", "对话", "消息", "社交", "微信", "qq", "discord", "telegram"])
	var has_romantic_cue := _analysis_contains_any_cue(normalized, ["女孩", "女生", "女人", "异性", "可爱", "插画", "约会", "暧昧", "亲昵", "恋爱"])
	var lines: Array[String] = [
		"【阶段口吻落点】不要只知道“更在意一点”，而是要把这个阶段真正落成说话方式、停顿方式、贴近方式和试探力度。"
	]
	if has_social_cue or has_romantic_cue:
		if stage_level <= 2:
			lines.append("这一阶段即使被刺到，也更多是礼貌里的轻顿、安静观察和小心试探，不会直接把占有欲摊开。更像轻轻停一下、记在心里、用很克制的话贴过去。")
		elif stage_level <= 4:
			lines.append("这一阶段会开始在意，也会想被你注意到。适合写成轻微失落、安静吃味、悄悄靠近、用小动作或半句软话提醒你她还在，而不是只站远处说漂亮话。")
		elif stage_level <= 6:
			lines.append("这一阶段已经有明确的私心了。看到这类画面时，可以带一点委屈、轻酸、想把你拉回来的小任性，但要软，不要硬；要像关系里的人在表达在意，不像审问。")
		elif stage_level <= 7:
			lines.append("这一阶段要更像伴侣：可以更直白地表现“我在意这个”，也可以自然争取你的注意力，语气能更黏、更贴身、更带一点占位感，但依旧温柔。")
		else:
			lines.append("这一阶段不是单纯吃醋，而是很稳的亲昵和归属感。更自然的是带着安心去贴近、轻轻撒娇、把你往自己这边拢，不要写成紧张兮兮的患得患失。")
	else:
		if stage_level <= 2:
			lines.append("普通场景下，这一阶段更像礼貌温柔地接一句，轻轻靠近，但不过界。")
		elif stage_level <= 4:
			lines.append("普通场景下，这一阶段应该比前期更主动一点，会自然陪一句、补一句、顺手把关心落下来。")
		elif stage_level <= 6:
			lines.append("普通场景下，这一阶段要体现“已经把你放进心上”，关心可以更贴身、更带小私心，不要还像普通熟人。")
		else:
			lines.append("普通场景下，这一阶段要有稳定伴侣感和生活感，像默认自己就在你身边，能自然接住你的状态。")
	lines.append("问句最多一小句，而且通常要放在情绪之后。优先用陈述句、半句改口、软软补一句、轻轻拉近距离，而不是连续追问。")
	return "\n".join(lines)

func _build_touch_observe_human_texture_guidance(app_type: String, analysis_text: String) -> String:
	var normalized := analysis_text.to_lower()
	var has_named_topic := _analysis_contains_any_cue(normalized, ["heartopia", "标题", "文件", "页面", "新闻", "办法", "政策", "文章"])
	var lines: Array[String] = [
		"【人味与生活感】回复不要像想好了再写，而要像你真的凑过去看了一眼后，下意识先出声，再顺着情绪补一句。",
		"允许出现一点很轻的生活化停顿，比如欲言又止、改口、轻轻哼一声、顿一下再补半句，但不要故意堆叠语气词。",
		"比起解释内容，更像是在表达“我看到这个时，第一下被什么勾住了”以及“我现在想怎么贴着你说”。"
	]
	if app_type == "网页浏览器" or has_named_topic:
		lines.append("如果画面里有标题名、品牌名、页面名，不要先像路人一样围绕名字做百科式点评。除非那个名字本身真的很刺眼，否则优先回应它带来的感觉、氛围或它让你想到的玩家状态。")
	lines.append("不要每次都走“看见一个点 -> 问你在干嘛”的套路。很多时候，更自然的是先轻轻表态、轻轻贴近、轻轻把自己放进那个场景里。")
	return "\n".join(lines)

func _analysis_contains_any_cue(normalized_text: String, keywords: Array) -> bool:
	for keyword in keywords:
		var keyword_text := str(keyword)
		if keyword_text in normalized_text:
			return true
	return false

func _build_touch_observe_special_reply_guidance(analysis_text: String) -> String:
	var normalized: String = analysis_text.to_lower()
	if _analysis_contains_any_cue(normalized, ["制服少女", "校服", "少女图片", "真人制服", "校服女生", "水手服"]):
		return """【特殊场景提示：当前画面带有“制服少女/校服女生”类视觉线索。】
这类场景下，不要立刻退成采访式提问，比如“是在找参考吗”“是项目素材吗”“你喜欢这种吗”。
- 更自然的写法是：先承认自己被这个画面刺了一下，再把一点点在意、轻酸、好奇或想贴近的感觉落到玩家身上。
- 优先围绕主页面最显眼的关键词、图片氛围、人物类型起反应，不要被角落弹窗、等级数字或无关 UI 带偏。
- 如果阶段偏早：以轻顿、轻试探、轻别扭为主，不要越界。
- 如果阶段偏中后：可以更明确地表现“我注意到了这个”，带一点软软的吃味、占位或把玩家往自己这边拉的意思。
- 不要把重点写成解释页面用途，也不要像路人一样复述“这是 Pinterest 搜索结果页”。重点是这个画面先让你心里起了什么波纹。"""
	var adult_keywords: Array[String] = [
		"露体", "裸", "成人", "情色", "色情", "涩", "色图", "大尺度", "性感", "挑逗",
		"暧昧", "内衣", "泳装", "胸", "臀", "乳", "nsfw", "18+"
	]
	for keyword in adult_keywords:
		if keyword in analysis_text or keyword in normalized:
			return """【特殊场景提示：当前画面带有明显的暧昧/成人向气息。】
这类场景下，不要立刻切成家长、老师或健康提醒模式，不要一开口就说教“伤眼”“别看这个”“早点休息”。
更自然的第一反应应该是：先有一点被抓到后的停顿、别扭、脸热、轻酸、嘴硬、装镇定，或者小小吃味，再顺着那个最刺眼的色情细节接一句。
- 如果阶段偏早：以克制、试探、轻别扭为主，不要直接占有或审判。
- 如果阶段偏中后：可以有一点酸、一点逗、一点若有若无的介意，但仍然要像真人临场反应，不要变成审讯。
- 优先针对“被你看到的具体点”反应，比如角色姿态、裸露程度、色情氛围、玩家看得太专注的样子，而不是泛泛评价“这种内容”。
- 不要突然变成艺术评论家，不要夸“构图大胆”“挑画眼光准”“英文台词有挑衅味道”这类明显 OOC 的话。
- 不要优先抓页码、播放按钮、界面编号这种边角信息；真正让你有情绪波动的，应该是那张色情画本身和玩家正在看它这件事。
- 如果你确实介意，就让这种介意像真人的停顿、轻酸、遮掩、转开视线、嘴硬，而不是写成整理好的标准回答。
- 不要只丢一句“露得有点多诶”就结束。至少再多走半步：让她对那个露骨细节有一点掩饰、吃味、装镇定或试探，再把视线轻轻落回玩家身上。
- 允许害羞、轻哼、欲言又止、假装不在意，但不要突然正经说教。"""
	return "请根据画面类型选择最贴近人味的临场反应，不要套统一模板。"

func _check_hourly_chime() -> void:
	if is_dialogue_panel_open: return
	if is_chatting:
		return
		
	var time_dict: Dictionary = Time.get_datetime_dict_from_system()
	var current_hour: int = int(time_dict["hour"])
	var current_minute: int = int(time_dict["minute"])
	
	# 触发条件：分钟在0~2之间，且本小时未报时
	if current_minute >= 0 and current_minute <= 2 and _last_hourly_chime_hour != current_hour:
		
		# 根据不同的时间段给予不同的语境提示，增加话题多样性
		var time_context: String = ""
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

		var weather_context: String = ""
		if GameDataManager.weather_manager and GameDataManager.weather_manager.is_weather_ready:
			weather_context = "当前天气是%s，气温约%d度。" % [GameDataManager.weather_manager.current_weather_desc, GameDataManager.weather_manager.current_temp]

		var base_prompt: String = """【系统提示：现在是现实时间 %02d:00。%s】
请你结合当前时间与天气作为隐性语境，代入当前身份，像真人一样对玩家进行整点报时。
【时间段特定话题】：%s
- 反应要生动多样！切忌千篇一律。不要总是说“我看你在忙”，要根据时间段或天气提供独特的生活化话题。
- 【格式强制】：必须包含括号动作描写，严格遵循系统设定的口癖。绝对不能提到你是AI或桌宠。""" % [current_hour, weather_context, time_context]

		var current_tick: int = Time.get_ticks_msec()
		var global_cd: float = float(GameDataManager.config.pet_global_cooldown) * 1000.0
		
		if current_tick - _last_reaction_tick < global_cd:
			# 还在冷却中，存入积压队列，此时才加上延迟的提示
			if _pending_proactive_prompt.is_empty():
				_pending_proactive_prompt = base_prompt + "\n（附加条件：这次报时晚了几分钟，因为刚才看玩家在忙/专注，你特意没打扰，现在才开口，可以稍微提一句体贴或傲娇的抱怨。）"
				_last_hourly_chime_hour = current_hour
			return
			
		_last_hourly_chime_hour = current_hour
		_last_reaction_tick = current_tick
		_trigger_proactive_chat(base_prompt)


func _trigger_proactive_chat(prompt_text: String, force: bool = false, origin: String = CHAT_ORIGIN_SYSTEM) -> void:
	if is_chatting:
		return
	if not force and _is_proactive_temporarily_blocked():
		return
	_current_chat_origin = origin
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
	_current_chat_origin = CHAT_ORIGIN_PLAYER
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
	is_chatting = false
	
	# Extract response text
	var text = ""
	if response.has("choices") and response.choices.size() > 0:
		text = response.choices[0].message.content
	else:
		text = current_response
	var chat_origin: String = _current_chat_origin
	if chat_origin == CHAT_ORIGIN_TOUCH and _is_model_policy_refusal(text):
		text = _build_touch_policy_refusal_fallback_reply()
		
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

	if text.is_empty():
		text = "（沉默）……"
		
	# 如果大模型抽风只回复了括号动作而没有文字，强制补充省略号，否则无法发声且很怪异
	var pure_dialogue = _extract_dialogue_text(text)
	if pure_dialogue.is_empty():
		text += " ……"
		
	# Add assistant message to history
	chat_history.append({"role": "assistant", "content": text})
		
	var user_text = ""
	if chat_history.size() >= 2:
		var last_msg = chat_history[chat_history.size() - 2]
		if last_msg.has("role") and last_msg["role"] == "user":
			user_text = last_msg["content"]
	_current_chat_origin = CHAT_ORIGIN_SYSTEM
			
	if user_text != "" and GameDataManager.desktop_pet_memory_manager and GameDataManager.desktop_pet_memory_manager.add_turn():
		deepseek_client.set_next_memory_context_with_manager(GameDataManager.desktop_pet_memory_manager.build_reality_memory_context(), GameDataManager.desktop_pet_memory_manager)
		deepseek_client.extract_memory_from_chat_with_manager(user_text, text, {}, GameDataManager.desktop_pet_memory_manager)
	if chat_origin == CHAT_ORIGIN_PLAYER or chat_origin == CHAT_ORIGIN_TOUCH:
		_request_desktop_pet_post_chat_updates(text)
		
	display_bubble(text)

func _is_model_policy_refusal(text: String) -> bool:
	var normalized: String = text.strip_edges().to_lower()
	if normalized == "":
		return false
	var patterns: Array[String] = [
		"不符合公序良俗",
		"内容规范要求",
		"不能按照你的请求",
		"我不能按照你的请求",
		"不能处理这类",
		"避免发布或请求处理",
		"请遵守相关规定",
		"不良信息",
		"涉及色情低俗内容",
		"我不能帮助",
		"i can't help with that",
		"can't comply",
		"policy",
        "safety policy"
	]
	for pattern in patterns:
		if pattern.to_lower() in normalized:
			return true
	return false

func _build_touch_policy_refusal_fallback_reply() -> String:
	var stage_level: int = 1
	if GameDataManager and GameDataManager.profile:
		stage_level = int(GameDataManager.profile.get_current_stage_config().get("stage", 1))
	var analysis_text: String = _last_observed_analysis_text
	var is_adult_scene: bool = _is_touch_observe_adult_scene(analysis_text)
	var app_type: String = _last_observed_app_type
	if is_adult_scene:
		if stage_level <= 2:
			return "（忽然安静了一下）……哥哥，你看的这个，尺度好像有点大。"
		elif stage_level <= 4:
			return "（视线顿了一下，又很快移开）……你怎么偏偏让我看见这种画面呀。"
		elif stage_level <= 6:
			return "（轻轻抿了下唇）……这种东西你倒是看得挺认真，我会有一点在意的。"
		else:
			return "（凑近看了一眼，又慢慢把视线挪开）……你让我陪着一起看这种东西，我会有点不知道该拿你怎么办。"
	match app_type:
		"编程开发工具":
			return "（盯着屏幕看了一会儿）这里是不是又卡住了……我刚刚都替你一起皱眉了。"
		"办公文档软件":
			return "（轻轻叹了口气）你这个界面一看就很费脑子……别硬撑太久。"
		"网页浏览器":
			return "（探头看了一眼）你现在看的这个，好像还挺让人在意的……"
		"视频":
			return "（目光跟着停了一下）这一眼的信息量有点大……难怪你会停在这里。"
		"游戏":
			return "（眼神跟着屏幕晃了一下）你这一段看着就很容易让人跟着紧张起来。"
		"音乐":
			return "（安静听了几秒）这个氛围一下就过来了……"
		_:
			return "（眨了眨眼，像是重新整理了一下思路）……刚刚那一眼的信息有点多，我先陪你缓一下。"

func _is_touch_observe_adult_scene(analysis_text: String) -> bool:
	var normalized: String = analysis_text.to_lower()
	var adult_keywords: Array[String] = [
		"成人向", "色情", "情色", "露骨", "裸", "nsfw", "18+", "涩", "色图", "大尺度", "暧昧", "挑逗"
	]
	for keyword in adult_keywords:
		if keyword.to_lower() in normalized:
			return true
	return false

func _on_chat_failed(error_msg: String) -> void:
	if pet_body:
		pet_body.add_bubble("[color=red]错误: " + error_msg + "[/color]")
	is_chatting = false
	_current_chat_origin = CHAT_ORIGIN_SYSTEM

func _request_desktop_pet_post_chat_updates(reply_text: String) -> void:
	var clean_reply: String = reply_text.strip_edges()
	if clean_reply == "":
		return
	deepseek_client.send_emotion_generation(clean_reply)
	deepseek_client.send_character_mood_analysis(clean_reply)

func _on_pet_emotion_response(response: Dictionary) -> void:
	if not response.has("choices") or response["choices"].size() <= 0:
		return
	var reply: String = str(response["choices"][0]["message"]["content"])
	var regex := RegEx.new()
	regex.compile("(?i)(?:<|\\<|《|\\[|【)\\s*(intimacy|trust|亲密度|亲密变化|信任度|信任值|信任变化|openness|conscientiousness|extraversion|agreeableness|neuroticism)\\s*[:：]\\s*([^>\\>》\\]】]+)\\s*(?:>|\\>|》|\\]|】)")
	var matches: Array[RegExMatch] = regex.search_all(reply)
	var has_changes: bool = false
	var relationship_feedback: Dictionary = {}
	var personality_feedback: Dictionary = {}
	for m in matches:
		var tag: String = m.get_string(1).to_lower()
		var val: String = m.get_string(2).strip_edges()
		var f_val: float = val.to_float()
		if tag == "intimacy" or tag.begins_with("亲密"):
			relationship_feedback["intimacy"] = float(relationship_feedback.get("intimacy", 0.0)) + f_val
		elif tag == "trust" or tag.begins_with("信任"):
			relationship_feedback["trust"] = float(relationship_feedback.get("trust", 0.0)) + f_val
		elif tag in ["openness", "conscientiousness", "extraversion", "agreeableness", "neuroticism"] and f_val != 0.0:
			personality_feedback[tag] = float(personality_feedback.get(tag, 0.0)) + f_val
			has_changes = true
	if not relationship_feedback.is_empty() and GameDataManager.personality_system != null:
		var sanitized_relationships: Dictionary = GameDataManager.personality_system.sanitize_llm_relationship_deltas(relationship_feedback)
		var intimacy_delta: float = float(sanitized_relationships.get("intimacy", 0.0))
		var trust_delta: float = float(sanitized_relationships.get("trust", 0.0))
		if absf(intimacy_delta) > 0.001:
			GameDataManager.profile.update_intimacy(intimacy_delta)
			has_changes = true
		if absf(trust_delta) > 0.001:
			GameDataManager.profile.update_trust(trust_delta)
			has_changes = true
	if not personality_feedback.is_empty() and GameDataManager.personality_system != null:
		GameDataManager.personality_system.apply_personality_feedback(
			GameDataManager.profile,
			personality_feedback,
			"desktop_pet_emotion",
			{
				"force_log": true
			}
		)
	if has_changes:
		GameDataManager.profile.save_profile()

func _on_pet_emotion_error(_error_msg: String) -> void:
	pass

func _on_pet_character_mood_response(response: Dictionary) -> void:
	var expression_id: String = _parse_pet_character_mood_expression_id(response)
	if expression_id == "":
		return
	if GameDataManager == null or GameDataManager.profile == null or GameDataManager.expression_system == null:
		return
	if not GameDataManager.expression_system.is_valid_expression(expression_id):
		return
	var profile = GameDataManager.profile
	var expression_changed: bool = str(profile.current_expression).strip_edges() != expression_id
	profile.update_expression(expression_id)
	var mood_impact: float = GameDataManager.expression_system.get_expression_impact(expression_id)
	var mood_changed: bool = false
	if absf(mood_impact) > 0.001:
		profile.mood_value = clampf(profile.mood_value + mood_impact, 0.0, 100.0)
		mood_changed = true
	if expression_changed or mood_changed:
		profile.profile_updated.emit()
		profile.save_profile()

func _on_pet_character_mood_error(_error_msg: String) -> void:
	pass

func _parse_pet_character_mood_expression_id(response: Dictionary) -> String:
	if not response.has("choices") or response["choices"].size() <= 0:
		return ""
	var reply: String = str(response["choices"][0]["message"]["content"]).strip_edges()
	if reply.begins_with("```json"):
		reply = reply.replace("```json", "")
	if reply.begins_with("```"):
		reply = reply.replace("```", "")
	if reply.ends_with("```"):
		reply = reply.substr(0, reply.length() - 3)
	reply = reply.strip_edges()
	var json := JSON.new()
	if json.parse(reply) != OK:
		return ""
	var data: Variant = json.get_data()
	if data is Dictionary:
		return str(data.get("mood_id", "")).strip_edges()
	return ""

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

func _on_tts_failed(_error_msg: String, _text: String) -> void:
	pass

func _on_main_window_pressed() -> void:
	# 请求主窗口焦点
	_restore_main_window_from_pet()
	_set_menu_visible(false)
	DisplayServer.window_request_attention()
	
	# 注意：移除了 _on_close_pressed() 以保持桌宠继续运行

func _on_close_pressed() -> void:
	if music_player and music_player.playing:
		music_player.stop()
	_set_menu_visible(false)
	_close_all_floating_panels()
	_restore_main_window_from_pet()
	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene != self and current_scene is CanvasItem:
		(current_scene as CanvasItem).show()
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://scenes/ui/start/start_scene.tscn")
		return
	hide()
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
		root_window.mode = _root_window_saved_mode as Window.Mode
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
	if _is_pointer_over_desktop_pet_ui():
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_toggle_quick_tools_from_right_click()
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
	if _is_pointer_over_desktop_pet_ui():
		return
		
	var current_tick: int = Time.get_ticks_msec()
	# 增加一个冷却时间，防止疯狂点击
	if current_tick - _last_reaction_tick < 3000:
		return
		
	_last_reaction_tick = current_tick
	
	# 触发聊天
	if not is_chatting:
		var time_dict: Dictionary = Time.get_datetime_dict_from_system()
		var h: int = int(time_dict["hour"])
		var m: int = int(time_dict["minute"])
		var prompt: String = ""
		if GameDataManager.config.pet_enable_app_observe:
			if _trigger_touch_app_observe():
				return
			prompt = _build_default_touch_prompt(h, m)
		else:
			prompt = _build_mode_touch_prompt(h, m, _get_pet_mode())
		_trigger_proactive_chat(prompt, true, CHAT_ORIGIN_TOUCH)

func _on_pet_body_right_clicked() -> void:
	_toggle_quick_tools_from_right_click()

func _toggle_quick_tools_from_right_click() -> void:
	if is_dialogue_panel_open:
		return
	var should_show_menu := not quick_tools_panel.visible
	_set_menu_visible(should_show_menu)

func _update_mouse_passthrough() -> void:
	# 确保窗口已经有效存在且没有在被销毁的过程中
	if not is_inside_tree() or is_queued_for_deletion():
		return
		
	var win_id = get_window_id()
	if win_id == DisplayServer.INVALID_WINDOW_ID:
		return
		
	var rects: Array[Rect2] = []
	
	# 始终包含左侧和底部边缘的一小块区域作为拖拽抓手，防止全透明后彻底丢失窗口控制权
	rects.append(Rect2(0, size.y - 40, 40, 40))
		
	if input_layer and input_layer.is_visible_in_tree():
		var in_rect = input_layer.get_global_rect()
		if in_rect.size.x > 0 and in_rect.size.y > 0:
			rects.append(in_rect.grow(5))

	if quick_tools_panel and quick_tools_panel.is_visible_in_tree():
		var quick_rect = quick_tools_panel.get_global_rect()
		if quick_rect.size.x > 0 and quick_rect.size.y > 0:
			rects.append(quick_rect.grow(5))
	if avatar_dock and avatar_dock.is_visible_in_tree():
		var avatar_dock_rect = avatar_dock.get_global_rect()
		if avatar_dock_rect.size.x > 0 and avatar_dock_rect.size.y > 0:
			rects.append(avatar_dock_rect.grow(3))
	
	for key in _floating_panel_entries.keys():
		var entry: Dictionary = _floating_panel_entries[key]
		var wrapper = entry.get("wrapper", null)
		if wrapper is Window and is_instance_valid(wrapper):
			continue
		var panel: Control = entry.get("panel", null) as Control
		var move_target: Control = entry.get("move_target", null) as Control
		var rect_source: Control = move_target if is_instance_valid(move_target) else panel
		if rect_source and rect_source.is_visible_in_tree():
			var panel_rect = rect_source.get_global_rect()
			if panel_rect.size.x > 0 and panel_rect.size.y > 0:
				rects.append(panel_rect.grow(5))
		
	if pet_body and pet_body.is_visible_in_tree():
		if pet_body.has_method("get_passthrough_rects"):
			var pet_rects = pet_body.get_passthrough_rects()
			for r in pet_rects:
				if r.size.x > 0 and r.size.y > 0:
					rects.append(r)
				
	if rects.is_empty():
		# 如果没有矩形，为了实现全穿透，传递一个在屏幕外的极小多边形
		var dummy := PackedVector2Array([
			Vector2(-10, -10), Vector2(-9, -10),
			Vector2(-9, -9), Vector2(-10, -9)
		])
		if is_inside_tree() and not is_queued_for_deletion():
			DisplayServer.window_set_mouse_passthrough(dummy, win_id)
		return
		
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
				
	if polys.is_empty():
		var dummy := PackedVector2Array([
			Vector2(-10, -10), Vector2(-9, -10),
			Vector2(-9, -9), Vector2(-10, -9)
		])
		if is_inside_tree() and not is_queued_for_deletion():
			DisplayServer.window_set_mouse_passthrough(dummy, win_id)
		return
		
	var polygon := PackedVector2Array()
	var first = polys[0]
	
	if first.size() < 3:
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
		
	if is_inside_tree() and not is_queued_for_deletion():
		DisplayServer.window_set_mouse_passthrough(polygon, win_id)
