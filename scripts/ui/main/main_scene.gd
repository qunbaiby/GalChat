extends Window

@onready var galchat_button: Button = $VBoxContainer/GalChatButton
@onready var activity_button: Button = $VBoxContainer/ActivityButton
@onready var desktop_pet_button: Button = $VBoxContainer/DesktopPetButton
@onready var settings_button: Button = $TopBar/SettingsButton
@onready var stats_panel = $StatsPanel

var activity_panel_instance = null
var desktop_pet_instance: Window = null

func _ready() -> void:
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
	activity_button.pressed.connect(_on_activity_pressed)
	desktop_pet_button.pressed.connect(_on_desktop_pet_pressed)
	
	# 动画：按钮点击弹性反馈
	galchat_button.pivot_offset = galchat_button.size / 2
	settings_button.pivot_offset = settings_button.size / 2
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
		# 桌宠已存在，关闭它
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
	if self is Window:
		GameDataManager.set_meta("last_window_pos", self.position)
	await get_tree().create_timer(0.2).timeout
	
	GameDataManager.change_scene("res://scenes/ui/chat/chat_scene.tscn")

func _on_close_requested() -> void:
	var desktop_pet = get_tree().root.get_node_or_null("DesktopPet")
	if is_instance_valid(desktop_pet) and desktop_pet.visible:
		self.hide()
	else:
		get_tree().quit()

func _on_settings_pressed() -> void:
	_animate_button(settings_button)
	if self is Window:
		GameDataManager.set_meta("last_window_pos", self.position)
	await get_tree().create_timer(0.2).timeout
	GameDataManager.previous_scene_path = "res://scenes/ui/main/main_scene.tscn"
	get_tree().change_scene_to_file("res://scenes/ui/settings/settings_scene.tscn")

func _animate_button(btn: Button) -> void:
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(0.9, 0.9), 0.05)
	tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.05)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.05)
