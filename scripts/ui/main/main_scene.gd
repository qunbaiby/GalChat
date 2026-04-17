extends Window

@onready var galchat_button: Button = $GalChatButton
@onready var activity_button: Button = $ActivityButton
@onready var desktop_pet_button: Button = $DesktopPetButton
@onready var settings_button: Button = $TopBar/SettingsButton
@onready var switch_char_button: Button = $TopBar/SwitchCharButton
@onready var stats_panel = $StatsPanel
@onready var bgm: AudioStreamPlayer = $BGM

var activity_panel_instance = null
var settings_panel_instance = null
var desktop_pet_instance: Window = null
var chat_scene_instance = null

func _ready() -> void:
	if GameDataManager.config:
		GameDataManager.config.apply_settings()
		
	if self is Window:
		if GameDataManager.has_meta("last_window_pos"):
			var last_pos = GameDataManager.get_meta("last_window_pos")
			if typeof(last_pos) == TYPE_VECTOR2I or typeof(last_pos) == TYPE_VECTOR2:
				self.position = last_pos
			else:
				self.move_to_center()
		else:
			self.move_to_center()
			
	close_requested.connect(_on_close_requested)
	
	galchat_button.pressed.connect(_on_galchat_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	switch_char_button.pressed.connect(_on_switch_char_pressed)
	activity_button.pressed.connect(_on_activity_pressed)
	desktop_pet_button.pressed.connect(_on_desktop_pet_pressed)
	
	GameDataManager.character_switched.connect(_on_character_switched)
	
	# 动画：按钮点击弹性反馈
	galchat_button.pivot_offset = galchat_button.size / 2
	settings_button.pivot_offset = settings_button.size / 2
	switch_char_button.pivot_offset = switch_char_button.size / 2
	activity_button.pivot_offset = activity_button.size / 2
	desktop_pet_button.pivot_offset = desktop_pet_button.size / 2
	
	# Update StatsPanel explicitly when returning to main scene
	if stats_panel and stats_panel.has_method("_update_ui"):
		stats_panel._update_ui()
		
	# 尝试找回已存在的桌宠实例
	if get_tree().root.has_node("DesktopPet"):
		desktop_pet_instance = get_tree().root.get_node("DesktopPet")
		
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
	var desktop_pet = get_tree().root.get_node_or_null("DesktopPet")
	if is_instance_valid(desktop_pet) and desktop_pet.visible:
		self.hide()
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

func _on_switch_char_pressed() -> void:
	_animate_button(switch_char_button)
	
	# 简单的切换逻辑：如果有更多角色可以弹出一个面板，这里先做二切一
	var current_id = GameDataManager.config.current_character_id
	var target_id = "ya" if current_id == "luna" else "luna"
	
	# 调用 GameDataManager 统一接口切换
	GameDataManager.switch_character(target_id)

func _on_character_switched(char_id: String) -> void:
	# 角色切换后更新主界面的面板（特别是数值显示）
	if stats_panel and stats_panel.has_method("_update_ui"):
		stats_panel._update_ui()
	
	# 更新右上角的 AffectionPanel
	var affection_panel = $AffectionPanel
	if affection_panel and affection_panel.has_method("update_ui"):
		affection_panel.update_ui()
		
	# 注意：ChatScene 的更新由它自己内部监听信号处理

func _animate_button(btn: Button) -> void:
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(0.9, 0.9), 0.05)
	tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.05)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.05)
