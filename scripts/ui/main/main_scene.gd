extends Control

@onready var ui_panel: Panel = $UIPanel
@onready var galchat_button: Button = $UIPanel/StoryButton
@onready var activity_button: Button = $UIPanel/ActivityButton
@onready var desktop_pet_button: Button = $UIPanel/BottomButton/DesktopPetButton
@onready var test_call_button: Button = $UIPanel/BottomButton/TestCallButton
@onready var hide_ui_button: Button = $UIPanel/SystemButton/HideUIButton
@onready var settings_button: Button = $UIPanel/SystemButton/SettingsButton
@onready var affection_button: Button = $UIPanel/AffectionButton
@onready var phone_button: Button = $UIPanel/BottomButton/PhoneButton
@onready var switch_char_button: Button = $UIPanel/BottomButton/SwitchCharButton
@onready var stats_panel = $UIPanel/StatsPanel
@onready var bgm: AudioStreamPlayer = $BGM
@onready var music_player: Panel = $UIPanel/BottomButton/MusicPlayer
@onready var incoming_call_notification: Panel = $IncomingCallNotification

var activity_panel_instance = null
var settings_panel_instance = null
var desktop_pet_instance: Window = null
var chat_scene_instance = null
var archive_panel_instance = null
var affection_panel_instance = null
var mobile_interface_instance = null

var _window_detector: Node = null
var _is_afk: bool = false
var _afk_timer: Timer = null
var _ui_tween: Tween = null

func _ready() -> void:
	if GameDataManager.config:
		GameDataManager.config.apply_settings()
		
	var window = get_window()
	if GameDataManager.has_meta("last_window_pos"):
		var last_pos = GameDataManager.get_meta("last_window_pos")
		if typeof(last_pos) == TYPE_VECTOR2I or typeof(last_pos) == TYPE_VECTOR2:
			window.position = last_pos
		else:
			window.move_to_center()
	else:
		window.move_to_center()
		
	window.close_requested.connect(_on_close_requested)
	
	galchat_button.pressed.connect(_on_galchat_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	hide_ui_button.pressed.connect(_on_hide_ui_pressed)
	affection_button.pressed.connect(_on_affection_pressed)
	phone_button.pressed.connect(_on_phone_pressed)
	switch_char_button.pressed.connect(_on_switch_char_pressed)
	activity_button.pressed.connect(_on_activity_pressed)
	desktop_pet_button.pressed.connect(_on_desktop_pet_pressed)
	test_call_button.pressed.connect(_on_test_call_pressed)
	
	incoming_call_notification.call_accepted.connect(_on_incoming_call_accepted)
	
	GameDataManager.character_switched.connect(_on_character_switched)
	
	# 动画：按钮点击弹性反馈
	galchat_button.pivot_offset = galchat_button.size / 2
	settings_button.pivot_offset = settings_button.size / 2
	phone_button.pivot_offset = phone_button.size / 2
	switch_char_button.pivot_offset = switch_char_button.size / 2
	activity_button.pivot_offset = activity_button.size / 2
	desktop_pet_button.pivot_offset = desktop_pet_button.size / 2
	test_call_button.pivot_offset = test_call_button.size / 2
	hide_ui_button.pivot_offset = hide_ui_button.size / 2
	settings_button.pivot_offset = settings_button.size / 2
	affection_button.pivot_offset = affection_button.size / 2
	
	# 恢复整个主窗口的鼠标输入响应，清除可能因为之前透明测试遗留的 passthrough 多边形
	if not is_queued_for_deletion():
		DisplayServer.window_set_mouse_passthrough(PackedVector2Array(), get_window().get_window_id())
	
	# Update StatsPanel explicitly when returning to main scene
	if stats_panel and stats_panel.has_method("_update_ui"):
		stats_panel._update_ui()
		
	# 尝试找回已存在的桌宠实例
	if get_tree().root.has_node("DesktopPet"):
		desktop_pet_instance = get_tree().root.get_node("DesktopPet")
		
	# 关联音乐播放器
	if is_instance_valid(music_player) and is_instance_valid(bgm):
		music_player.set_audio_player(bgm)
		
	# 初始化挂机检测
	var window_detector_path = "res://scripts/csharp/WindowDetector.cs"
	if FileAccess.file_exists(window_detector_path):
		var WindowDetectorObj = load(window_detector_path)
		if WindowDetectorObj:
			_window_detector = WindowDetectorObj.new()
			add_child(_window_detector)
			# 把当前主窗口的真实 HWND 传给 C# 层，用于精准判断
			var win_id = get_window().get_window_id()
			var hwnd = DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, win_id)
			if hwnd:
				_window_detector.call("SetMainHwnd", hwnd)
			
	_afk_timer = Timer.new()
	_afk_timer.wait_time = 1.0
	_afk_timer.autostart = true
	_afk_timer.timeout.connect(_check_afk_status)
	add_child(_afk_timer)

func _check_afk_status() -> void:
	var window = get_window()
	var is_minimized = window.mode == Window.MODE_MINIMIZED
	
	var is_covered_fullscreen = false
	if is_instance_valid(_window_detector):
		is_covered_fullscreen = _window_detector.call("IsAnyFullScreenWindowCovering")
		
	var should_be_afk = is_minimized or is_covered_fullscreen
	
	if should_be_afk != _is_afk:
		_is_afk = should_be_afk
		if _is_afk:
			_on_enter_afk()
		else:
			_on_exit_afk()

func _on_enter_afk() -> void:
	print("[MainScene] 视为主场景后台挂机，暂停音乐与进度")
	if bgm:
		bgm.stream_paused = true
		
func _on_exit_afk() -> void:
	print("[MainScene] 退出后台挂机模式，恢复音乐与进度")
	if bgm:
		bgm.stream_paused = false

func _on_desktop_pet_pressed() -> void:
	_animate_button(desktop_pet_button)
	if is_instance_valid(desktop_pet_instance):
		# 桌宠已存在，关闭它。先隐藏以防止输入系统报错
		desktop_pet_instance.hide()
		desktop_pet_instance.queue_free()
		desktop_pet_instance = null
	else:
		# 创建桌宠，直接挂载在 root 下，这样切换场景也不会被销毁
		var DesktopPetObj = load("res://scenes/ui/desktop_pet/desktop_pet.tscn")
		desktop_pet_instance = DesktopPetObj.instantiate()
		get_tree().root.add_child(desktop_pet_instance)

func _on_test_call_pressed() -> void:
	_animate_button(test_call_button)
	# 模拟来电，随机语音或视频
	var char_id = GameDataManager.config.current_character_id
	var is_video = randf() > 0.5
	incoming_call_notification.show_incoming_call(char_id, is_video)

func _on_incoming_call_accepted(char_id: String, is_video: bool) -> void:
	# 接听电话：打开手机面板
	if mobile_interface_instance == null:
		_on_phone_pressed()
	else:
		mobile_interface_instance.show_phone()
		
	# 告诉手机面板直接跳转到通话界面
	mobile_interface_instance.open_call_directly(char_id, is_video)

func _on_phone_pressed() -> void:
	_animate_button(phone_button)
	if mobile_interface_instance == null:
		var MobileInterfaceObj = load("res://scenes/ui/mobile/mobile_interface.tscn")
		mobile_interface_instance = MobileInterfaceObj.instantiate()
		ui_panel.add_child(mobile_interface_instance)
		mobile_interface_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mobile_interface_instance.app_opened.connect(_on_mobile_app_opened)
	mobile_interface_instance.show_phone()

func _on_mobile_app_opened(app_name: String) -> void:
	pass # 目前 archive 由 mobile_interface 自己处理，如果有其他 app 可以加在这里

func _on_activity_pressed() -> void:
	_animate_button(activity_button)
	if activity_panel_instance == null:
		var ActivityPanelObj = load("res://scenes/ui/activity/activity_panel.tscn")
		activity_panel_instance = ActivityPanelObj.instantiate()
		add_child(activity_panel_instance)
		# 确保它盖在最上面
		activity_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	activity_panel_instance.show_panel()

func _on_galchat_pressed() -> void:
	_animate_button(galchat_button)
	
	if chat_scene_instance == null:
		var ChatSceneObj = load("res://scenes/ui/chat/chat_scene.tscn")
		chat_scene_instance = ChatSceneObj.instantiate()
		add_child(chat_scene_instance)
		chat_scene_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		chat_scene_instance.chat_closed.connect(_on_chat_closed)
		
	chat_scene_instance.show_panel()
	if bgm.playing:
		bgm.stop()

func _on_chat_closed() -> void:
	if not bgm.playing:
		bgm.play()

func _on_close_requested() -> void:
	pass

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var desktop_pet = get_tree().root.get_node_or_null("DesktopPet")
		if is_instance_valid(desktop_pet) and desktop_pet.visible:
			# Godot 4 中，主场景是 Control 时，我们应该隐藏对应的 Window
			get_tree().root.hide()
		else:
			get_tree().quit()

func _on_settings_pressed() -> void:
	_animate_button(settings_button)
	if settings_panel_instance == null:
		var SettingsPanelObj = load("res://scenes/ui/settings/settings_scene.tscn")
		settings_panel_instance = SettingsPanelObj.instantiate()
		add_child(settings_panel_instance)
		settings_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_panel_instance.show_panel()

func _on_affection_pressed() -> void:
	_animate_button(affection_button)
	var was_visible = false
	if affection_panel_instance == null:
		var AffectionPanelObj = load("res://scenes/ui/chat/affection_panel.tscn")
		affection_panel_instance = AffectionPanelObj.instantiate()
		ui_panel.add_child(affection_panel_instance)
		was_visible = false # 初次实例化，视为原本是隐藏的
	else:
		was_visible = affection_panel_instance.visible
		
	if not was_visible:
		# 根据按钮当前位置动态计算面板位置，显示在按钮右侧，并与按钮顶部对齐
		var button_width = affection_button.size.x
			
		affection_panel_instance.position = Vector2(
			affection_button.position.x + button_width + 10, # 10 为间距
			affection_button.position.y
		)
		affection_panel_instance.show()
	else:
		affection_panel_instance.hide()

func _on_switch_char_pressed() -> void:
	_animate_button(switch_char_button)
	
	# 简单的切换逻辑：如果有更多角色可以弹出一个面板，这里先做二切一
	var current_id = GameDataManager.config.current_character_id
	var target_id = "ya" if current_id == "luna" else "luna"
	
	# 调用 GameDataManager 统一接口切换
	GameDataManager.switch_character(target_id)

func _on_hide_ui_pressed() -> void:
	_animate_button(hide_ui_button)
	if _ui_tween:
		_ui_tween.kill()
	_ui_tween = create_tween()
	_ui_tween.tween_property(ui_panel, "modulate:a", 0.0, 0.3)
	_ui_tween.tween_callback(func(): ui_panel.visible = false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# 如果手机界面存在且正在显示相机，不要显示UI
		if mobile_interface_instance and mobile_interface_instance.camera_panel_instance and mobile_interface_instance.camera_panel_instance.visible:
			return
			
		if not ui_panel.visible or ui_panel.modulate.a < 0.99:
			get_viewport().set_input_as_handled()
			if _ui_tween:
				_ui_tween.kill()
			ui_panel.visible = true
			_ui_tween = create_tween()
			_ui_tween.tween_property(ui_panel, "modulate:a", 1.0, 0.3)

func _on_character_switched(char_id: String) -> void:
	# 角色切换后更新主界面的面板（特别是数值显示）
	if stats_panel and stats_panel.has_method("_update_ui"):
		stats_panel._update_ui()
	
	# 更新右上角的 AffectionPanel
	if is_instance_valid(affection_panel_instance) and affection_panel_instance.has_method("update_ui"):
		affection_panel_instance.update_ui()
		
	# 注意：ChatScene 的更新由它自己内部监听信号处理

func _animate_button(btn: Button) -> void:
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(0.9, 0.9), 0.05)
	tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.05)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.05)
