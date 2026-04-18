extends Control

@onready var close_btn: Button = $Panel/VBoxContainer/TopBar/CloseButton
@onready var char_option: OptionButton = $Panel/VBoxContainer/TopBar/CharOption
@onready var tab_container: TabContainer = $Panel/VBoxContainer/TabContainer
@onready var memory_text: RichTextLabel = $"Panel/VBoxContainer/TabContainer/记忆库/ScrollContainer/MemoryText"
@onready var personality_text: RichTextLabel = $"Panel/VBoxContainer/TabContainer/性格演化/ScrollContainer/PersonalityText"

var available_characters: Array = []

func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	char_option.item_selected.connect(_on_char_selected)
	_load_available_characters()

func show_panel() -> void:
	# 每次打开时，如果有关联当前角色，默认选中当前角色
	var current_id = GameDataManager.config.current_character_id
	var idx = available_characters.find(current_id)
	if idx >= 0:
		char_option.select(idx)
		_on_char_selected(idx)
	elif available_characters.size() > 0:
		char_option.select(0)
		_on_char_selected(0)
	show()

func _load_available_characters() -> void:
	char_option.clear()
	available_characters.clear()
	
	var dir = DirAccess.open("res://assets/data/characters")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var index = 0
		while file_name != "":
			if file_name.ends_with(".json") and not file_name.ends_with("_stages.json"):
				var char_id = file_name.replace(".json", "")
				available_characters.append(char_id)
				# 可以读取名字，这里简单起见直接用 char_id
				var char_name = _get_char_name(char_id)
				char_option.add_item(char_name, index)
				index += 1
			file_name = dir.get_next()

func _get_char_name(char_id: String) -> String:
	var path = "res://assets/data/characters/%s.json" % char_id
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var content = file.get_as_text()
		var json = JSON.new()
		if json.parse(content) == OK and json.data is Dictionary:
			return json.data.get("char_name", char_id)
	return char_id

func _on_char_selected(index: int) -> void:
	if index < 0 or index >= available_characters.size(): return
	var char_id = available_characters[index]
	_load_char_archive(char_id)

func _load_char_archive(char_id: String) -> void:
	# 临时加载该角色的 Profile 和 Memory
	var temp_profile = CharacterProfile.new()
	temp_profile.load_profile(char_id)
	
	# 读取记忆
	var mem_path = "user://saves/%s/player_memory.json" % char_id
	var mems = { "core": [], "emotion": [], "habit": [], "bond": [] }
	if FileAccess.file_exists(mem_path):
		var file = FileAccess.open(mem_path, FileAccess.READ)
		var content = file.get_as_text()
		var json = JSON.new()
		if json.parse(content) == OK and json.data is Dictionary:
			var data = json.data
			for key in mems.keys():
				if data.has(key) and data[key] is Array:
					mems[key] = data[key]
					
	_update_personality_display(temp_profile)
	_update_memory_display(mems)

func _update_personality_display(profile: CharacterProfile) -> void:
	var text = ""
	text += "[b]【大五人格实时分值与底色对比】[/b]\n\n"
	text += "当前查看角色: " + profile.char_name + "\n\n"
	
	var base_o = profile.base_personality.get("openness", 50.0)
	var base_c = profile.base_personality.get("conscientiousness", 50.0)
	var base_e = profile.base_personality.get("extraversion", 50.0)
	var base_a = profile.base_personality.get("agreeableness", 50.0)
	var base_n = profile.base_personality.get("neuroticism", 50.0)
	
	text += _format_trait("开放性 (Openness)", profile.openness, base_o)
	text += _format_trait("尽责性 (Conscientiousness)", profile.conscientiousness, base_c)
	text += _format_trait("外倾性 (Extraversion)", profile.extraversion, base_e)
	text += _format_trait("宜人性 (Agreeableness)", profile.agreeableness, base_a)
	text += _format_trait("神经质 (Neuroticism)", profile.neuroticism, base_n)
	
	text += "\n[b]【当前激活的人格描述】[/b]\n"
	var dynamic_traits = GameDataManager.personality_system.get_dynamic_traits(profile)
	if dynamic_traits == "":
		text += "暂无激活特征"
	else:
		text += dynamic_traits
		
	personality_text.text = text

func _format_trait(name: String, current: float, base: float) -> String:
	var diff = current - base
	var diff_str = ""
	if diff > 0:
		diff_str = "[color=green]+%.1f[/color]" % diff
	elif diff < 0:
		diff_str = "[color=red]%.1f[/color]" % diff
	else:
		diff_str = "[color=gray]0.0[/color]"
	return "%s: 当前 %.1f (底色 %.1f) %s\n" % [name, current, base, diff_str]

func _update_memory_display(mems: Dictionary) -> void:
	var text = ""
	
	var format_mems = func(layer_mems):
		if layer_mems.size() == 0:
			return "无"
		var lines = []
		for m in layer_mems:
			if m is Dictionary:
				lines.append(" - %s" % m.get("content", ""))
			elif m is String:
				lines.append(" - %s" % m)
		return "\n".join(lines)
		
	text += "[b]核心记忆:[/b]\n" + format_mems.call(mems.get("core", [])) + "\n\n"
	text += "[b]情绪记忆:[/b]\n" + format_mems.call(mems.get("emotion", [])) + "\n\n"
	text += "[b]习惯记忆:[/b]\n" + format_mems.call(mems.get("habit", [])) + "\n\n"
	text += "[b]羁绊记忆:[/b]\n" + format_mems.call(mems.get("bond", []))
	
	memory_text.text = text

func _on_close_pressed() -> void:
	hide()
