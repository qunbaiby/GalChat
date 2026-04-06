extends Control

@onready var stage_option: OptionButton = $"CenterContainer/Panel/VBoxContainer/TabContainer/情感控制/HBoxContainer/StageOption"
@onready var mood_option: OptionButton = $"CenterContainer/Panel/VBoxContainer/TabContainer/心情/HBoxContainer/MoodOption"
@onready var close_btn: Button = $CenterContainer/Panel/VBoxContainer/CloseButton

@onready var memory_text: RichTextLabel = $"CenterContainer/Panel/VBoxContainer/TabContainer/记忆管理/ScrollContainer/MemoryText"
@onready var clear_memory_btn: Button = $"CenterContainer/Panel/VBoxContainer/TabContainer/记忆管理/ClearMemoryBtn"

signal stage_changed(new_stage: int)
signal mood_changed(new_mood: String)

func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	stage_option.item_selected.connect(_on_stage_selected)
	mood_option.item_selected.connect(_on_mood_selected)
	clear_memory_btn.pressed.connect(_on_clear_memory_pressed)
	
	_init_stage_options()
	_init_mood_options()

func _init_stage_options() -> void:
	stage_option.clear()
	var profile = GameDataManager.profile
	# Load stages from JSON to get dynamic titles
	var json_path = "res://assets/data/characters/" + profile.char_name + ".json"
	var file = FileAccess.open(json_path, FileAccess.READ)
	var stages = []
	if file:
		var text = file.get_as_text()
		var json = JSON.new()
		if json.parse(text) == OK:
			var data = json.get_data()
			if data.has("stages"):
				stages = data["stages"]
		file.close()
		
	for i in range(stages.size()):
		var st = stages[i]
		var stage_num = int(st.get("stage", i + 1))
		var title = st.get("stageTitle", "")
		# Extract Chinese part from title e.g. "initial (初始)" -> "初始"
		var zh_title = title
		var regex = RegEx.new()
		regex.compile("\\((.*?)\\)|（(.*?)）")
		var match = regex.search(title)
		if match:
			zh_title = match.get_string(1) if match.get_string(1) != "" else match.get_string(2)
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
		
	_update_memory_text()
	
	show()

func _update_memory_text() -> void:
	var mems = GameDataManager.memory_manager.memories
	var text = ""
	
	var format_mems = func(layer_mems):
		if layer_mems.size() == 0:
			return "无"
		var lines = []
		for m in layer_mems:
			lines.append("[%s] %s" % [m.get("id", ""), m.get("content", "")])
		return "\n".join(lines)
		
	text += "[b]核心记忆:[/b]\n" + format_mems.call(mems["core"]) + "\n\n"
	text += "[b]情绪记忆:[/b]\n" + format_mems.call(mems["emotion"]) + "\n\n"
	text += "[b]习惯记忆:[/b]\n" + format_mems.call(mems["habit"]) + "\n\n"
	text += "[b]羁绊记忆:[/b]\n" + format_mems.call(mems["bond"])
	memory_text.text = text

func _on_clear_memory_pressed() -> void:
	GameDataManager.memory_manager.memories = {
		"core": [], "emotion": [], "habit": [], "bond": []
	}
	GameDataManager.memory_manager.save_memory()
	_update_memory_text()
	print("记忆已清空")

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
