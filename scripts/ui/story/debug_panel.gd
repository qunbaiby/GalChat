extends Control

signal stage_changed(new_stage: int)

@onready var close_btn: Button = $CenterContainer/Panel/VBoxContainer/CloseButton
@onready var stage_option: OptionButton = $"CenterContainer/Panel/VBoxContainer/TabContainer/情感控制/HBoxContainer/StageOption"
@onready var macro_mood_option: OptionButton = $"CenterContainer/Panel/VBoxContainer/TabContainer/状态与表情/HBoxContainer2/MacroMoodOption"

@onready var switch_char_btn: Button = $"CenterContainer/Panel/VBoxContainer/TabContainer/工具与测试/HBoxContainer/SwitchCharButton"
@onready var test_call_btn: Button = $"CenterContainer/Panel/VBoxContainer/TabContainer/工具与测试/HBoxContainer/TestCallButton"
@onready var generate_diary_btn: Button = $"CenterContainer/Panel/VBoxContainer/TabContainer/工具与测试/HBoxContainer/GenerateDiaryButton"

@onready var send_moment_btn: Button = $"CenterContainer/Panel/VBoxContainer/TabContainer/工具与测试/MomentsBtnBox/SendMomentBtn"
@onready var ai_generate_moment_btn: Button = $"CenterContainer/Panel/VBoxContainer/TabContainer/工具与测试/MomentsBtnBox/AIGenerateMomentBtn"
@onready var moment_author_input: LineEdit = $"CenterContainer/Panel/VBoxContainer/TabContainer/工具与测试/MomentsAuthorBox/MomentAuthor"
@onready var moment_mode_option: OptionButton = $"CenterContainer/Panel/VBoxContainer/TabContainer/工具与测试/MomentsAuthorBox/MomentMode"
@onready var moment_content_input: TextEdit = $"CenterContainer/Panel/VBoxContainer/TabContainer/工具与测试/MomentsContentBox/MomentContent"

@onready var personality_text: RichTextLabel = $"CenterContainer/Panel/VBoxContainer/TabContainer/大五人格/ScrollContainer/PersonalityText"
@onready var tab_container: TabContainer = $"CenterContainer/Panel/VBoxContainer/TabContainer"

@onready var trait_option: OptionButton = $"CenterContainer/Panel/VBoxContainer/TabContainer/大五人格/ModifyHBox/TraitOption"
@onready var trait_value_input: SpinBox = $"CenterContainer/Panel/VBoxContainer/TabContainer/大五人格/ModifyHBox/TraitValueInput"
@onready var set_trait_btn: Button = $"CenterContainer/Panel/VBoxContainer/TabContainer/大五人格/ModifyHBox/SetTraitBtn"
@onready var refresh_personality_btn: Button = $"CenterContainer/Panel/VBoxContainer/TabContainer/大五人格/HBoxContainer/RefreshPersonalityBtn"

var is_from_title: bool = false

func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	stage_option.item_selected.connect(_on_stage_selected)
	macro_mood_option.item_selected.connect(_on_macro_mood_selected)
	
	switch_char_btn.pressed.connect(_on_switch_char_pressed)
	test_call_btn.pressed.connect(_on_test_call_pressed)
	generate_diary_btn.pressed.connect(_on_generate_diary_pressed)
	
	send_moment_btn.pressed.connect(_on_send_moment_pressed)
	ai_generate_moment_btn.pressed.connect(_on_ai_generate_moment_pressed)
	
	set_trait_btn.pressed.connect(_on_set_trait_pressed)
	refresh_personality_btn.pressed.connect(_on_refresh_personality_pressed)
	
	_init_stage_options()
	_init_macro_mood_options()
	
	var llm_manager = get_node_or_null("/root/LLMManager")
	var client = null
	if llm_manager and llm_manager.has("deepseek_client"):
		client = llm_manager.deepseek_client
	elif get_tree().current_scene.has_node("DeepseekClient"):
		client = get_tree().current_scene.get_node("DeepseekClient")
	elif get_node_or_null("/root/DeepseekClient"):
		client = get_node("/root/DeepseekClient")
		
	if client:
		if not client.is_connected("diary_generated", _on_diary_generated):
			client.diary_generated.connect(_on_diary_generated)
		if not client.is_connected("diary_error", _on_diary_error):
			client.diary_error.connect(_on_diary_error)

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

func _init_macro_mood_options() -> void:
	macro_mood_option.clear()
	var index = 0
	for config in GameDataManager.mood_system.macro_mood_configs:
		var name = config.get("name", "未知")
		var min_val = config.get("min_value", 0)
		var max_val = config.get("max_value", 100)
		var display_text = "%s (%d-%d)" % [name, min_val, max_val]
		macro_mood_option.add_item(display_text, index)
		index += 1

func show_panel() -> void:
	if is_from_title and tab_container:
		# 隐藏“状态与表情”(索引 1) 和 “工具与测试”(索引 2)
		tab_container.set_tab_hidden(1, true)
		tab_container.set_tab_hidden(2, true)
		# 确保选中未被隐藏的第一个可用 Tab (情感控制)
		if tab_container.current_tab == 1 or tab_container.current_tab == 2:
			tab_container.current_tab = 0
	elif tab_container:
		# 恢复显示
		tab_container.set_tab_hidden(1, false)
		tab_container.set_tab_hidden(2, false)

	# 初始化 GameDataManager 的必要组件（如果在标题界面）
	if GameDataManager.profile == null:
		GameDataManager.profile = CharacterProfile.new()
		GameDataManager.profile.load_profile()

	# 同步当前状态
	var profile = GameDataManager.profile
	stage_option.select(profile.current_stage - 1)
		
	var mood_val = profile.mood_value
	for i in range(GameDataManager.mood_system.macro_mood_configs.size()):
		var config = GameDataManager.mood_system.macro_mood_configs[i]
		if mood_val >= config.get("min_value", 0) and mood_val <= config.get("max_value", 100):
			macro_mood_option.select(i)
			break
			
	# 同步大五人格数据
	_update_personality_display(profile)
		
	show()

func _update_personality_display(profile) -> void:
	if not is_instance_valid(personality_text):
		return
		
	var base_o = profile.base_personality.get("openness", 50.0)
	var base_c = profile.base_personality.get("conscientiousness", 50.0)
	var base_e = profile.base_personality.get("extraversion", 50.0)
	var base_a = profile.base_personality.get("agreeableness", 50.0)
	var base_n = profile.base_personality.get("neuroticism", 50.0)

	var curr_o = profile.openness
	var curr_c = profile.conscientiousness
	var curr_e = profile.extraversion
	var curr_a = profile.agreeableness
	var curr_n = profile.neuroticism
	
	var text = "[b]基础分值 -> 实时分值[/b]\n\n"
	text += "经验开放性 (O): %.1f -> [color=#4a90e2]%.1f[/color]\n" % [base_o, curr_o]
	text += "尽责严谨性 (C): %.1f -> [color=#4a90e2]%.1f[/color]\n" % [base_c, curr_c]
	text += "外向活跃性 (E): %.1f -> [color=#4a90e2]%.1f[/color]\n" % [base_e, curr_e]
	text += "亲和共情性 (A): %.1f -> [color=#4a90e2]%.1f[/color]\n" % [base_a, curr_a]
	text += "神经敏感性 (N): %.1f -> [color=#4a90e2]%.1f[/color]\n" % [base_n, curr_n]
	
	text += "\n[b]人格状态:[/b]\n"
	text += GameDataManager.personality_system.get_personality_state_summary(profile) + "\n"
	text += GameDataManager.personality_system.get_recent_event_summary(profile) + "\n"
	text += GameDataManager.personality_system.get_pressure_summary(profile) + "\n"
	text += GameDataManager.personality_system.get_pattern_summary(profile) + "\n"
	text += GameDataManager.personality_system.get_last_settlement_summary(profile) + "\n"
	
	text += "\n[b]动态特征描述:[/b]\n"
	text += GameDataManager.personality_system.get_dynamic_traits(profile)
	
	personality_text.text = text

func _on_close_pressed() -> void:
	hide()

func _on_stage_selected(index: int) -> void:
	var stage = index + 1
	GameDataManager.profile.force_set_stage(stage)
	stage_changed.emit(stage)

func _on_macro_mood_selected(index: int) -> void:
	if index >= 0 and index < GameDataManager.mood_system.macro_mood_configs.size():
		var config = GameDataManager.mood_system.macro_mood_configs[index]
		# 将心情值设置为该阶段的中间值
		var min_val = config.get("min_value", 0)
		var max_val = config.get("max_value", 100)
		var target_val = (min_val + max_val) / 2.0
		GameDataManager.profile.mood_value = target_val
		GameDataManager.profile.save_profile()
		GameDataManager.profile.profile_updated.emit()
		print("[DebugPanel] 强制切换宏观心情至: ", config.get("name", "未知"), " (值: ", target_val, ")")

func _on_switch_char_pressed() -> void:
	var profiles = _get_available_character_ids()
	var current_id = GameDataManager.config.current_character_id
	if current_id == "": current_id = GameDataManager.profile.current_character_id
	
	if profiles.size() <= 1:
		print("[DebugPanel] 只有一个角色，无需切换")
		return
		
	var idx = profiles.find(current_id)
	var next_idx = (idx + 1) % profiles.size()
	var next_id = profiles[next_idx]
	
	print("[DebugPanel] 切换角色从 ", current_id, " 到 ", next_id)
	GameDataManager.switch_character(next_id)
	
	# Update debug panel UI for the new character
	show_panel()

func _get_available_character_ids() -> Array:
	var ids = []
	var dir = DirAccess.open("res://assets/data/characters")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json") and not file_name.ends_with("_stages.json"):
				ids.append(file_name.replace(".json", ""))
			file_name = dir.get_next()
	return ids

func _on_test_call_pressed() -> void:
	var fixed_calls_path = "res://assets/data/story/scripts/calls/fixed_calls.json"
	if not FileAccess.file_exists(fixed_calls_path):
		print("[DebugPanel] 未找到通话数据文件:", fixed_calls_path)
		return
		
	var file = FileAccess.open(fixed_calls_path, FileAccess.READ)
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	if err == OK:
		var calls_data = json.data
		if calls_data is Dictionary and calls_data.keys().size() > 0:
			var first_call_id = calls_data.keys()[0]
			print("[DebugPanel] 测试发起通话:", first_call_id)
			
			var call_event = {
				"type": "video_call",
				"call_id": first_call_id
			}
			
			var call_system = get_node_or_null("/root/CallEventSystem")
			if call_system:
				call_system.trigger_call_event(call_event)
			else:
				var main_scene = get_tree().current_scene
				var chat_scene = preload("res://scenes/ui/mobile/chat/mobile_chat_panel.tscn").instantiate()
				main_scene.add_child(chat_scene)
				chat_scene.hide_panel(false)
				
				await get_tree().process_frame
				
				if chat_scene.has_method("start_video_call"):
					chat_scene.start_video_call(true, false)
		else:
			print("[DebugPanel] 通话数据为空")
	else:
		print("[DebugPanel] 解析通话数据失败")

func _on_generate_diary_pressed() -> void:
	print("[DebugPanel] 测试生成日记")
	generate_diary_btn.disabled = true
	generate_diary_btn.text = "生成中..."
	
	var client = null
	var llm_manager = get_node_or_null("/root/LLMManager")
	if llm_manager and llm_manager.has("deepseek_client"):
		client = llm_manager.deepseek_client
	elif get_tree().current_scene.has_node("DeepSeekClient"):
		client = get_tree().current_scene.get_node("DeepSeekClient")
	elif get_node_or_null("/root/DeepSeekClient"):
		client = get_node("/root/DeepSeekClient")
		
	if client and client.has_method("send_diary_generation"):
		# Make sure we connect to signals if not connected
		if not client.diary_generated.is_connected(_on_diary_generated):
			client.diary_generated.connect(_on_diary_generated)
		if not client.diary_error.is_connected(_on_diary_error):
			client.diary_error.connect(_on_diary_error)
			
		client.send_diary_generation()
	else:
		print("[DebugPanel] 未找到 DeepSeekClient 或缺少 send_diary_generation 方法，执行模拟生成")
		# Simulate diary generation for testing
		await get_tree().create_timer(1.5).timeout
		
		var mock_diary = {
			"date": Time.get_date_string_from_system(),
			"weather": "晴",
			"content": "　　今天天气真不错，心情也跟着好起来了。测试生成了一篇新的日记，感觉这个系统越来越完善了呢。接下来还要继续努力，把剩下的功能都实现！\n　　而且今天和玩家聊天也很开心，希望能一直保持这样的状态。"
		}
		_on_diary_generated(mock_diary)

func _on_diary_generated(diary_entry: Dictionary) -> void:
	print("[DebugPanel] 日记生成成功")
	generate_diary_btn.disabled = false
	generate_diary_btn.text = "生成日记"
	
	var profile = GameDataManager.profile
	if profile and profile.has_method("add_diary"):
		profile.add_diary(diary_entry)
		# 强制保存
		if profile.has_method("save_profile"):
			profile.save_profile()
		
		# Trigger notification
		var main_scene = get_tree().current_scene
		if main_scene and main_scene.has_method("show_diary_notification"):
			main_scene.show_diary_notification()
	else:
		print("[DebugPanel] 未找到 profile.add_diary 方法")

func _on_diary_error(error_msg: String) -> void:
	print("[DebugPanel] 日记生成失败: ", error_msg)
	generate_diary_btn.disabled = false
	generate_diary_btn.text = "生成日记"

func _on_send_moment_pressed() -> void:
	var author = moment_author_input.text.strip_edges()
	var content = moment_content_input.text.strip_edges()
	if author == "": author = "AI"
	if content == "": content = "这是一条测试内容"
	
	var images = []
	if moment_mode_option.selected == 0:
		# 图文并茂，放个占位图
		images.append("res://icon.svg")
		
	var moments_manager = get_node_or_null("/root/MomentsManager")
	if moments_manager:
		moments_manager.add_moment(author, Time.get_date_string_from_system(), content, images)
		print("[DebugPanel] 已手动插入一条朋友圈测试数据")
	else:
		print("[DebugPanel] MomentsManager 未找到！")

func _on_ai_generate_moment_pressed() -> void:
	var event_manager = get_node_or_null("/root/EventManager")
	if event_manager and event_manager.has_method("execute_event"):
		event_manager.execute_event("post_moment")
		print("[DebugPanel] 已触发 AI 自动生成朋友圈事件")
	else:
		print("[DebugPanel] EventManager 未找到！")

func _on_set_trait_pressed() -> void:
	var trait_map = ["openness", "conscientiousness", "extraversion", "agreeableness", "neuroticism"]
	var selected_idx = trait_option.selected
	if selected_idx >= 0 and selected_idx < trait_map.size():
		var trait_name = trait_map[selected_idx]
		var target_val = trait_value_input.value
		
		var profile = GameDataManager.profile
		if profile:
			# 直接赋值覆盖
			profile.set(trait_name, target_val)
			profile.save_profile()
			print("[DebugPanel] 强制修改大五人格: %s = %.1f" % [trait_name, target_val])
			
			# 立即写入存档并触发更新信号
			if GameDataManager.save_manager:
				GameDataManager.save_manager.auto_save()
			profile.profile_updated.emit()
			
			# 更新UI显示
			_update_personality_display(profile)
			
			# 如果档案面板开着，也刷新它
			var main_scene = get_tree().current_scene
			if main_scene and main_scene.has_node("UIPanel/MobileInterface"):
				var mobile_interface = main_scene.get_node("UIPanel/MobileInterface")
				var archive = mobile_interface.get("archive_panel_instance")
				if archive and archive.visible and archive.has_method("show_panel"):
					archive.show_panel()

func _on_refresh_personality_pressed() -> void:
	if GameDataManager.profile:
		_update_personality_display(GameDataManager.profile)
		print("[DebugPanel] 手动刷新了大五人格显示")
