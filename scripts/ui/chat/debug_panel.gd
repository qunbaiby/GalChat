extends Control

signal stage_changed(new_stage: int)
signal mood_changed(new_mood: String)

@onready var close_btn: Button = $CenterContainer/Panel/VBoxContainer/CloseButton
@onready var stage_option: OptionButton = $"CenterContainer/Panel/VBoxContainer/TabContainer/情感控制/HBoxContainer/StageOption"
@onready var mood_option: OptionButton = $"CenterContainer/Panel/VBoxContainer/TabContainer/心情/HBoxContainer/MoodOption"

func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	stage_option.item_selected.connect(_on_stage_selected)
	mood_option.item_selected.connect(_on_mood_selected)
	
	_init_stage_options()
	_init_mood_options()

func _init_stage_options() -> void:
	stage_option.clear()
	var profile = GameDataManager.profile
	for i in range(profile.stages_config.size()):
		var config = profile.stages_config[i]
		var stage_num = config.get("stage", i + 1)
		var title = config.get("stageTitle", "未知阶段")
		
		var zh_title = ""
		var title_parts = title.split(" ")
		if title_parts.size() > 1:
			zh_title = title_parts[1]
		else:
			zh_title = title
			
		var display_text = "Stage %d: %s" % [stage_num, zh_title]
		stage_option.add_item(display_text, i)

func _init_mood_options() -> void:
	mood_option.clear()
	var index = 0
	for mood_id in GameDataManager.mood_system.all_mood_ids:
		var config = GameDataManager.mood_system.mood_configs[mood_id]
		var display_text = "%s (%s)" % [config.get("name", mood_id), mood_id]
		mood_option.add_item(display_text, index)
		index += 1

func show_panel() -> void:
	# 同步当前状态
	var profile = GameDataManager.profile
	stage_option.select(profile.current_stage - 1)
	
	var mood_id = profile.current_mood
	var idx = GameDataManager.mood_system.all_mood_ids.find(mood_id)
	if idx >= 0:
		mood_option.select(idx)
		
	show()

func _on_close_pressed() -> void:
	hide()

func _on_stage_selected(index: int) -> void:
	var stage = index + 1
	GameDataManager.profile.force_set_stage(stage)
	stage_changed.emit(stage)

func _on_mood_selected(index: int) -> void:
	if index >= 0 and index < GameDataManager.mood_system.all_mood_ids.size():
		var mood_id = GameDataManager.mood_system.all_mood_ids[index]
		GameDataManager.profile.update_mood(mood_id)
		mood_changed.emit(mood_id)
