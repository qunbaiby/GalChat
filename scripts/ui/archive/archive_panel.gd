extends Control

@onready var close_btn: Button = $Panel/VBoxContainer/TopBar/CloseButton
@onready var char_option: OptionButton = $Panel/VBoxContainer/TopBar/CharOption
@onready var tab_container: TabContainer = $Panel/VBoxContainer/TabContainer
@onready var memory_text: RichTextLabel = $"Panel/VBoxContainer/TabContainer/记忆库/ScrollContainer/MemoryText"
@onready var base_personality_text: RichTextLabel = $"Panel/VBoxContainer/TabContainer/性格演化/ScrollContainer/VBox/BasePersonalityText"
@onready var dynamic_personality_text: RichTextLabel = $"Panel/VBoxContainer/TabContainer/性格演化/ScrollContainer/VBox/DynamicPersonalityText"
@onready var deepseek_client = $DeepSeekClient

@onready var trait_o_bar: ProgressBar = $"Panel/VBoxContainer/TabContainer/性格演化/ScrollContainer/VBox/TraitsVBox/开放性容器/ProgressBar"
@onready var trait_o_val: RichTextLabel = $"Panel/VBoxContainer/TabContainer/性格演化/ScrollContainer/VBox/TraitsVBox/开放性容器/Value"

@onready var trait_c_bar: ProgressBar = $"Panel/VBoxContainer/TabContainer/性格演化/ScrollContainer/VBox/TraitsVBox/尽责性容器/ProgressBar"
@onready var trait_c_val: RichTextLabel = $"Panel/VBoxContainer/TabContainer/性格演化/ScrollContainer/VBox/TraitsVBox/尽责性容器/Value"

@onready var trait_e_bar: ProgressBar = $"Panel/VBoxContainer/TabContainer/性格演化/ScrollContainer/VBox/TraitsVBox/外倾性容器/ProgressBar"
@onready var trait_e_val: RichTextLabel = $"Panel/VBoxContainer/TabContainer/性格演化/ScrollContainer/VBox/TraitsVBox/外倾性容器/Value"

@onready var trait_a_bar: ProgressBar = $"Panel/VBoxContainer/TabContainer/性格演化/ScrollContainer/VBox/TraitsVBox/宜人性容器/ProgressBar"
@onready var trait_a_val: RichTextLabel = $"Panel/VBoxContainer/TabContainer/性格演化/ScrollContainer/VBox/TraitsVBox/宜人性容器/Value"

@onready var trait_n_bar: ProgressBar = $"Panel/VBoxContainer/TabContainer/性格演化/ScrollContainer/VBox/TraitsVBox/神经质容器/ProgressBar"
@onready var trait_n_val: RichTextLabel = $"Panel/VBoxContainer/TabContainer/性格演化/ScrollContainer/VBox/TraitsVBox/神经质容器/Value"

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
	
	# 打开动画：从右侧滑入并淡入
	position.x = size.x
	modulate.a = 0.0
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

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
	var base_o = profile.base_personality.get("openness", 50.0)
	var base_c = profile.base_personality.get("conscientiousness", 50.0)
	var base_e = profile.base_personality.get("extraversion", 50.0)
	var base_a = profile.base_personality.get("agreeableness", 50.0)
	var base_n = profile.base_personality.get("neuroticism", 50.0)
	
	_set_trait_ui(trait_o_bar, trait_o_val, profile.openness, base_o)
	_set_trait_ui(trait_c_bar, trait_c_val, profile.conscientiousness, base_c)
	_set_trait_ui(trait_e_bar, trait_e_val, profile.extraversion, base_e)
	_set_trait_ui(trait_a_bar, trait_a_val, profile.agreeableness, base_a)
	_set_trait_ui(trait_n_bar, trait_n_val, profile.neuroticism, base_n)
	
	var base_traits_str = GameDataManager.personality_system.get_base_traits(profile)
	if base_traits_str == "":
		base_personality_text.text = "暂无初始底色配置"
	else:
		base_personality_text.text = base_traits_str
		
	var dynamic_traits_str = GameDataManager.personality_system.get_dynamic_traits(profile)
	dynamic_personality_text.text = "AI 正在分析性格演化，请稍候..."
	
	_request_ai_personality_summary(profile, base_traits_str, dynamic_traits_str)

func _request_ai_personality_summary(profile: CharacterProfile, base_traits: String, dynamic_traits: String) -> void:
	if not is_instance_valid(deepseek_client):
		dynamic_personality_text.text = "AI 分析服务未就绪"
		return
		
	var system_prompt = "你是一位专业的心理学与人物性格分析师。请根据以下角色的【初始底色】和【当前因为属性变化而激活的动态性格特征】，用一段自然、生动且富有洞察力的语言（150-300字），总结该角色目前的性格状态、可能的行为倾向，以及给玩家的相处建议。不要输出Markdown代码块，直接输出分析文本。"
	var user_prompt = "角色名称：" + profile.char_name + "\n\n" + base_traits + "\n\n【当前激活的动态特征】\n" + dynamic_traits
	
	if deepseek_client.chat_request_completed.is_connected(_on_ai_summary_completed):
		deepseek_client.chat_request_completed.disconnect(_on_ai_summary_completed)
	if deepseek_client.chat_request_failed.is_connected(_on_ai_summary_failed):
		deepseek_client.chat_request_failed.disconnect(_on_ai_summary_failed)
		
	deepseek_client.chat_request_completed.connect(_on_ai_summary_completed, CONNECT_ONE_SHOT)
	deepseek_client.chat_request_failed.connect(_on_ai_summary_failed, CONNECT_ONE_SHOT)
	
	var messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": user_prompt}
	]
	
	deepseek_client.call_chat_api_non_stream(messages)

func _on_ai_summary_completed(response: Dictionary) -> void:
	if is_instance_valid(dynamic_personality_text):
		if response.has("choices") and response["choices"].size() > 0:
			var content = response["choices"][0].get("message", {}).get("content", "")
			dynamic_personality_text.text = content
		else:
			dynamic_personality_text.text = "[color=red]AI 返回格式错误[/color]"

func _on_ai_summary_failed(err_msg: String) -> void:
	if is_instance_valid(dynamic_personality_text):
		dynamic_personality_text.text = "[color=red]AI 分析失败: " + err_msg + "[/color]"

func _set_trait_ui(bar: ProgressBar, val_label: RichTextLabel, current: float, base: float) -> void:
	bar.value = current
	var diff = current - base
	var diff_str = ""
	if diff > 0:
		diff_str = "[color=green]+%.1f[/color]" % diff
	elif diff < 0:
		diff_str = "[color=red]%.1f[/color]" % diff
	else:
		diff_str = "[color=gray]0.0[/color]"
	val_label.text = "%.1f (初始: %.1f)\n%s" % [current, base, diff_str]

func _update_memory_display(mems: Dictionary) -> void:
	var text = ""
	
	var format_mems = func(title, layer_mems, icon_color):
		var sec = "[color=%s][b]■ %s[/b][/color]\n" % [icon_color, title]
		if layer_mems.size() == 0:
			sec += "[color=gray]  暂无记录[/color]\n\n"
			return sec
			
		for m in layer_mems:
			if m is Dictionary:
				sec += "  • %s\n" % m.get("content", "")
			elif m is String:
				sec += "  • %s\n" % m
		sec += "\n"
		return sec
		
	text += format_mems.call("核心记忆 (Core)", mems.get("core", []), "#ff6b81")
	text += format_mems.call("情绪记忆 (Emotion)", mems.get("emotion", []), "#1e90ff")
	text += format_mems.call("习惯记忆 (Habit)", mems.get("habit", []), "#ff4757")
	text += format_mems.call("羁绊记忆 (Bond)", mems.get("bond", []), "#fbc531")
	
	memory_text.text = text

func _on_close_pressed() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:x", size.x, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(self.hide)
