extends Control

@onready var close_btn: Button = $Panel/VBoxContainer/TopBar/CloseButton
@onready var radar_chart: Control = $Panel/VBoxContainer/ScrollContainer/VBox/ChartCard/ContentVBox/ChartsVBox/RadarChart
@onready var line_chart: Control = $Panel/VBoxContainer/ScrollContainer/VBox/ChartCard/ContentVBox/ChartsVBox/LineChart
@onready var base_personality_text: RichTextLabel = $Panel/VBoxContainer/ScrollContainer/VBox/BaseTraitsCard/ContentVBox/AnalysisVBox/BasePersonalityText
@onready var status_text: RichTextLabel = $Panel/VBoxContainer/ScrollContainer/VBox/ChartCard/ContentVBox/AnalysisVBox/StatusVBox/Text
@onready var behavior_text: RichTextLabel = $Panel/VBoxContainer/ScrollContainer/VBox/ChartCard/ContentVBox/AnalysisVBox/BehaviorVBox/Text
@onready var advice_text: RichTextLabel = $Panel/VBoxContainer/ScrollContainer/VBox/ChartCard/ContentVBox/AnalysisVBox/AdviceVBox/Text
@onready var deepseek_client = $DeepSeekClient


func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)


func show_panel(char_id: String = "") -> void:
	var target_char_id := char_id
	if target_char_id == "" and GameDataManager.config and GameDataManager.config.current_character_id != "":
		target_char_id = GameDataManager.config.current_character_id
	if target_char_id == "":
		target_char_id = "luna"

	_load_char_archive(target_char_id)
	show()

	position.x = size.x
	modulate.a = 0.0
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


func _load_char_archive(char_id: String) -> void:
	var temp_profile := CharacterProfile.new()
	temp_profile.load_profile(char_id)
	_update_personality_display(temp_profile)


func _get_story_day_offset_for_char(char_id: String) -> int:
	var path = "user://saves/%s/story_time_save.json" % char_id
	if not FileAccess.file_exists(path):
		return 0
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var json = JSON.new()
	var result = json.parse(file.get_as_text())
	file.close()
	if result != OK or not json.data is Dictionary:
		return 0
	return int(json.data.get("current_day_offset", 0))


func _update_personality_display(profile: CharacterProfile) -> void:
	var base_values: Array[float] = [
		float(profile.base_personality.get("openness", 50.0)),
		float(profile.base_personality.get("conscientiousness", 50.0)),
		float(profile.base_personality.get("extraversion", 50.0)),
		float(profile.base_personality.get("agreeableness", 50.0)),
		float(profile.base_personality.get("neuroticism", 50.0))
	]
	var dynamic_values: Array[float] = [
		float(profile.openness),
		float(profile.conscientiousness),
		float(profile.extraversion),
		float(profile.agreeableness),
		float(profile.neuroticism)
	]
	radar_chart.set_values(base_values, dynamic_values)

	var history = profile.personality_history.duplicate()
	var current_day_offset = _get_story_day_offset_for_char(profile.current_character_id)
	history.append({
		"day_offset": current_day_offset,
		"openness": float(profile.openness),
		"conscientiousness": float(profile.conscientiousness),
		"extraversion": float(profile.extraversion),
		"agreeableness": float(profile.agreeableness),
		"neuroticism": float(profile.neuroticism)
	})
	line_chart.set_data(history)

	var base_traits_str = GameDataManager.personality_system.get_base_traits(profile)
	base_personality_text.text = "暂无初始底色配置" if base_traits_str == "" else base_traits_str

	var dynamic_traits_parts: Array = [
		GameDataManager.personality_system.get_personality_state_summary(profile),
		GameDataManager.personality_system.get_recent_event_summary(profile),
		GameDataManager.personality_system.get_pressure_summary(profile),
		GameDataManager.personality_system.get_pattern_summary(profile),
		GameDataManager.personality_system.get_last_settlement_summary(profile),
		"",
		GameDataManager.personality_system.get_dynamic_traits(profile)
	]
	var dynamic_traits_str = "\n".join(dynamic_traits_parts)
	status_text.text = "AI 正在分析性格演化..."
	behavior_text.text = "等待分析..."
	advice_text.text = "等待分析..."
	_request_ai_personality_summary(profile, base_traits_str, dynamic_traits_str)


func _request_ai_personality_summary(profile: CharacterProfile, base_traits: String, dynamic_traits: String) -> void:
	if not is_instance_valid(deepseek_client):
		status_text.text = "AI 分析服务未就绪"
		return

	var system_prompt = "你是一位专业的心理学与人物性格分析师。请根据以下角色的【初始底色】和【当前因为属性变化而激活的动态性格特征】，分析该角色目前的性格状态、可能的行为倾向，以及给玩家的相处建议。\n请必须返回严格的JSON格式数据，不要包含任何Markdown代码块(如```json)，直接返回如下结构：\n{\"status\": \"性格状态描述(50-100字)\", \"behavior\": \"行为倾向描述(50-100字)\", \"advice\": \"相处建议(50-100字)\"}"
	var user_prompt = "角色名称：" + profile.char_name + "\n\n" + base_traits + "\n\n【当前激活的动态特征】\n" + dynamic_traits

	if deepseek_client.chat_request_completed.is_connected(_on_ai_summary_completed):
		deepseek_client.chat_request_completed.disconnect(_on_ai_summary_completed)
	if deepseek_client.chat_request_failed.is_connected(_on_ai_summary_failed):
		deepseek_client.chat_request_failed.disconnect(_on_ai_summary_failed)

	deepseek_client.chat_request_completed.connect(_on_ai_summary_completed, CONNECT_ONE_SHOT)
	deepseek_client.chat_request_failed.connect(_on_ai_summary_failed, CONNECT_ONE_SHOT)
	deepseek_client.call_chat_api_non_stream([
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": user_prompt}
	])


func _on_ai_summary_completed(response: Dictionary) -> void:
	if not is_instance_valid(status_text):
		return
	if response.has("choices") and response["choices"].size() > 0:
		var content = response["choices"][0].get("message", {}).get("content", "")
		var json = JSON.new()
		var err = json.parse(content)
		if err == OK and typeof(json.data) == TYPE_DICTIONARY:
			status_text.text = json.data.get("status", "分析失败")
			behavior_text.text = json.data.get("behavior", "分析失败")
			advice_text.text = json.data.get("advice", "分析失败")
		else:
			status_text.text = "[color=red]AI 返回格式无法解析[/color]\n" + content
			behavior_text.text = "等待分析..."
			advice_text.text = "等待分析..."
	else:
		status_text.text = "[color=red]AI 返回格式错误[/color]"


func _on_ai_summary_failed(err_msg: String) -> void:
	if is_instance_valid(status_text):
		status_text.text = "[color=red]AI 分析失败: " + err_msg + "[/color]"
		behavior_text.text = "分析失败"
		advice_text.text = "分析失败"


func _on_close_pressed() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:x", size.x, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(hide)
