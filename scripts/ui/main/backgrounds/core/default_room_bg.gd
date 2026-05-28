extends "res://scripts/ui/main/backgrounds/core/bg_scene_base.gd"

@onready var bg_rect: TextureRect = $background
@onready var story_button: Button = $StoryButton
@onready var interact_trigger_button: Button = $InteractTriggerButton

var _base_bubble_pos := Vector2.ZERO
var _bubble_tween: Tween
var _base_interact_pos := Vector2.ZERO
var _interact_bubble_tween: Tween

func _ready() -> void:
	super._ready()
	
	if interact_trigger_button:
		_base_interact_pos = interact_trigger_button.position
		
	if story_button:
		_base_bubble_pos = story_button.position
		_check_story_button_visibility()
		if GameDataManager.story_time_manager:
			GameDataManager.story_time_manager.time_advanced.connect(_on_time_advanced)
			
	_play_bubble_anim()

func _on_time_advanced(_days: int, _current_period: String) -> void:
	_check_story_button_visibility()

func _check_story_button_visibility() -> void:
	if not is_instance_valid(story_button): return
	if not GameDataManager.story_time_manager: return
	
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

func set_ui_hidden(is_hidden: bool) -> void:
	if is_instance_valid(story_button):
		if is_hidden:
			story_button.hide()
		else:
			_check_story_button_visibility()
			
	if is_instance_valid(interact_trigger_button):
		if is_hidden:
			interact_trigger_button.hide()
		else:
			# Only show if not in interact group mode
			var main_scene = get_tree().root.get_node_or_null("MainScene")
			if main_scene and main_scene.has_node("UIPanel/InteractGroup"):
				var interact_group = main_scene.get_node("UIPanel/InteractGroup")
				if not interact_group.visible:
					# Let main_scene _update_button_states_by_time decide if it should be visible
					pass
			
			if main_scene and main_scene.has_method("_update_button_states_by_time"):
				main_scene._update_button_states_by_time()

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
