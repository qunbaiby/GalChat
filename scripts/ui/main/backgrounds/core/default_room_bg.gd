extends "res://scripts/ui/main/backgrounds/core/bg_scene_base.gd"

@onready var bg_rect: TextureRect = $background
@onready var story_button: Button = $StoryButton
@onready var mood_bubble: PanelContainer = $MoodBubble
@onready var mood_emoji_label: Label = $MoodBubble/Margin/HBox/EmojiLabel
@onready var mood_value_label: Label = $MoodBubble/Margin/HBox/ValueLabel
@onready var mood_name_tag: PanelContainer = $MoodNameTag
@onready var mood_name_label: Label = $MoodNameTag/Margin/NameLabel
@onready var interact_trigger_button: Button = $InteractTriggerButton

var _base_bubble_pos := Vector2.ZERO
var _bubble_tween: Tween
var _base_mood_bubble_pos := Vector2.ZERO
var _mood_bubble_tween: Tween
var _base_interact_pos := Vector2.ZERO
var _interact_bubble_tween: Tween
var _ui_tween: Tween
var _is_ui_hidden := false
var _mood_tag_hovering := false

func _ready() -> void:
	super._ready()
	
	if interact_trigger_button:
		_base_interact_pos = interact_trigger_button.position

	if mood_bubble:
		_base_mood_bubble_pos = mood_bubble.position
		if not mood_bubble.mouse_entered.is_connected(_on_mood_bubble_mouse_entered):
			mood_bubble.mouse_entered.connect(_on_mood_bubble_mouse_entered)
		if not mood_bubble.mouse_exited.is_connected(_on_mood_bubble_mouse_exited):
			mood_bubble.mouse_exited.connect(_on_mood_bubble_mouse_exited)
		
	if story_button:
		_base_bubble_pos = story_button.position
		_check_story_button_visibility()
		if GameDataManager.story_time_manager:
			GameDataManager.story_time_manager.time_advanced.connect(_on_time_advanced)

	if GameDataManager.profile and not GameDataManager.profile.is_connected("profile_updated", _update_mood_bubble):
		GameDataManager.profile.profile_updated.connect(_update_mood_bubble)
			
	_update_mood_bubble()
	_play_bubble_anim()
	
	# Initial UI state check
	var main_scene = get_tree().root.get_node_or_null("MainScene")
	if main_scene and main_scene.get("chat_scene_instance") and main_scene.chat_scene_instance.visible:
		set_ui_hidden(true)
	elif main_scene and main_scene.get("_story_mode_active"):
		set_ui_hidden(true)

func _on_time_advanced(_days: int, _current_period: String) -> void:
	_check_story_button_visibility()
	
	# After time advance, check if we need to hide buttons (e.g. story triggered immediately)
	var main_scene = get_tree().root.get_node_or_null("MainScene")
	if main_scene and main_scene.get("_story_mode_active"):
		set_ui_hidden(true)

func _check_story_button_visibility() -> void:
	if not is_instance_valid(story_button): return
	if not GameDataManager.story_time_manager: return

	if _is_ui_hidden:
		story_button.visible = false
		if _bubble_tween and _bubble_tween.is_valid():
			_bubble_tween.kill()
		return
	
	var date_dict = GameDataManager.story_time_manager.get_current_date_dict()
	var weekday = date_dict.weekday
	var current_hour = GameDataManager.story_time_manager.current_hour
	
	var should_show = false
	# 周末（0, 6）或者周五晚（20点及以后）才有概率出现心事
	if weekday == 0 or weekday == 6 or (weekday == 5 and current_hour >= 20):
		var current_day_offset = GameDataManager.story_time_manager.current_day_offset
		var rng = RandomNumberGenerator.new()
		rng.seed = hash(str(current_day_offset) + "_story_button")
		# 60%概率出现
		if rng.randf() < 0.6:
			should_show = true
			
	story_button.visible = should_show
	if should_show:
		story_button.modulate.a = 1.0
	
	if should_show:
		if not _bubble_tween or not _bubble_tween.is_valid():
			_play_bubble_anim()
	else:
		if _bubble_tween and _bubble_tween.is_valid():
			_bubble_tween.kill()
	
	if should_show and GameDataManager.profile:
		var mood_val = GameDataManager.profile.mood_value
		var mood_name = "心事"
		if GameDataManager.mood_system:
			var config_name = GameDataManager.mood_system.get_macro_mood_name(mood_val)
			if config_name != "" and config_name != "平静" and config_name != "寻常":
				mood_name = config_name + "的心事"
		story_button.text = mood_name

func _update_mood_bubble() -> void:
	if not is_instance_valid(mood_bubble):
		return
	if not GameDataManager.profile:
		mood_bubble.visible = false
		if is_instance_valid(mood_name_tag):
			mood_name_tag.visible = false
		return

	var mood_val := int(round(GameDataManager.profile.mood_value))
	var mood_name := "心情"
	var mood_emoji := ""
	if GameDataManager.mood_system:
		var mood_info: Dictionary = GameDataManager.mood_system.get_macro_mood(mood_val)
		mood_name = str(mood_info.get("name", "心情"))
		mood_emoji = str(mood_info.get("emoji", ""))
	if is_instance_valid(mood_emoji_label):
		mood_emoji_label.text = mood_emoji
	if is_instance_valid(mood_value_label):
		mood_value_label.text = str(mood_val)
	if is_instance_valid(mood_name_label):
		mood_name_label.text = mood_name

	mood_bubble.visible = not _is_ui_hidden
	if not _is_ui_hidden:
		mood_bubble.modulate.a = 1.0
	if _is_ui_hidden and is_instance_valid(mood_name_tag):
		mood_name_tag.visible = false

func _on_mood_bubble_mouse_entered() -> void:
	if not is_instance_valid(mood_bubble) or not mood_bubble.visible:
		return
	if _is_ui_hidden:
		return
	_mood_tag_hovering = true
	if is_instance_valid(mood_name_tag):
		mood_name_tag.visible = true
		_update_mood_name_tag_position()

func _on_mood_bubble_mouse_exited() -> void:
	_mood_tag_hovering = false
	if is_instance_valid(mood_name_tag):
		mood_name_tag.visible = false

func _process(_delta: float) -> void:
	if _mood_tag_hovering and is_instance_valid(mood_name_tag) and mood_name_tag.visible:
		_update_mood_name_tag_position()

func _update_mood_name_tag_position() -> void:
	if not is_instance_valid(mood_name_tag):
		return
	var mouse_pos := get_local_mouse_position()
	var desired_pos := mouse_pos + Vector2(16.0, -42.0)
	var viewport_rect := get_viewport_rect()
	var tag_size := mood_name_tag.size
	if tag_size == Vector2.ZERO:
		tag_size = mood_name_tag.get_combined_minimum_size()
	desired_pos.x = clampf(desired_pos.x, 8.0, viewport_rect.size.x - tag_size.x - 8.0)
	desired_pos.y = clampf(desired_pos.y, 8.0, viewport_rect.size.y - tag_size.y - 8.0)
	mood_name_tag.position = desired_pos

func set_ui_hidden(is_hidden: bool) -> void:
	_is_ui_hidden = is_hidden
	var story_button = get_node_or_null("StoryButton")
	var mood_bubble_node = get_node_or_null("MoodBubble")
	var mood_name_tag_node = get_node_or_null("MoodNameTag")
	var interact_button = get_node_or_null("InteractTriggerButton")
	
	if _ui_tween:
		_ui_tween.kill()
	_ui_tween = create_tween()
	
	var target_a = 0.0 if is_hidden else 1.0
	
	if story_button:
		_ui_tween.parallel().tween_property(story_button, "modulate:a", target_a, 0.3)
	if mood_bubble_node:
		_ui_tween.parallel().tween_property(mood_bubble_node, "modulate:a", target_a, 0.3)
	if mood_name_tag_node:
		_ui_tween.parallel().tween_property(mood_name_tag_node, "modulate:a", target_a, 0.2)
	if interact_button:
		_ui_tween.parallel().tween_property(interact_button, "modulate:a", target_a, 0.3)
		
	if is_hidden:
		_mood_tag_hovering = false
		_ui_tween.tween_callback(func():
			if story_button: story_button.visible = false
			if mood_bubble_node: mood_bubble_node.visible = false
			if mood_name_tag_node: mood_name_tag_node.visible = false
			if interact_button: interact_button.visible = false
		)
	else:
		if story_button:
			story_button.visible = false
			story_button.modulate.a = 1.0
		if mood_bubble_node:
			mood_bubble_node.visible = true
			mood_bubble_node.modulate.a = 1.0
		if mood_name_tag_node:
			mood_name_tag_node.visible = false
			mood_name_tag_node.modulate.a = 1.0
		if interact_button:
			interact_button.visible = true
			interact_button.modulate.a = 1.0
		_check_story_button_visibility()
		_update_mood_bubble()

# 如果有特殊的环境切换需求可以在这里实现
func play_environment_anim(anim_name: String) -> void:
	# 例如根据白天黑夜改变颜色
	if anim_name == "night":
		bg_rect.modulate = Color(0.5, 0.5, 0.7)
	elif anim_name == "day":
		bg_rect.modulate = Color(1, 1, 1)

func _play_bubble_anim() -> void:
	if _bubble_tween:
		_bubble_tween.kill()

	if is_instance_valid(story_button):
		story_button.pivot_offset = story_button.size / 2.0

	_bubble_tween = create_tween().set_loops()

	if is_instance_valid(story_button):
		# 上浮与放大
		_bubble_tween.tween_property(story_button, "position:y", _base_bubble_pos.y - 12.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_bubble_tween.parallel().tween_property(story_button, "scale", Vector2(1.05, 1.05), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# 下落与缩小还原
		_bubble_tween.tween_property(story_button, "position:y", _base_bubble_pos.y, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_bubble_tween.parallel().tween_property(story_button, "scale", Vector2(1.0, 1.0), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
	if _interact_bubble_tween:
		_interact_bubble_tween.kill()
		
	if is_instance_valid(interact_trigger_button):
		interact_trigger_button.pivot_offset = interact_trigger_button.size / 2.0
		
		_interact_bubble_tween = create_tween().set_loops()
		# 错开动画时间，使用不同的初始延迟或者不同的周期
		_interact_bubble_tween.tween_property(interact_trigger_button, "position:y", _base_interact_pos.y - 10.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_interact_bubble_tween.parallel().tween_property(interact_trigger_button, "scale", Vector2(1.03, 1.03), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
		_interact_bubble_tween.tween_property(interact_trigger_button, "position:y", _base_interact_pos.y, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_interact_bubble_tween.parallel().tween_property(interact_trigger_button, "scale", Vector2(1.0, 1.0), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if _mood_bubble_tween:
		_mood_bubble_tween.kill()

	if is_instance_valid(mood_bubble):
		mood_bubble.pivot_offset = mood_bubble.size / 2.0
		_mood_bubble_tween = create_tween().set_loops()
		_mood_bubble_tween.tween_property(mood_bubble, "position:y", _base_mood_bubble_pos.y - 8.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_mood_bubble_tween.parallel().tween_property(mood_bubble, "scale", Vector2(1.02, 1.02), 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_mood_bubble_tween.tween_property(mood_bubble, "position:y", _base_mood_bubble_pos.y, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_mood_bubble_tween.parallel().tween_property(mood_bubble, "scale", Vector2(1.0, 1.0), 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
