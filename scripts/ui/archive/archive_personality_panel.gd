extends Control

@onready var background_panel: ColorRect = $Background
@onready var panel_root: Panel = $CenterContainer/Panel
@onready var close_btn: Button = $CenterContainer/Panel/VBoxContainer/TopBar/CloseButton
@onready var radar_chart: Control = $CenterContainer/Panel/VBoxContainer/BodyMargin/MainHBox/ChartCard/ChartMargin/ContentVBox/ChartsVBox/RadarCard/RadarMargin/RadarVBox/RadarChart
@onready var line_chart: Control = $CenterContainer/Panel/VBoxContainer/BodyMargin/MainHBox/ChartCard/ChartMargin/ContentVBox/ChartsVBox/TrendCard/TrendMargin/TrendVBox/LineChart
@onready var base_personality_text: RichTextLabel = $CenterContainer/Panel/VBoxContainer/BodyMargin/MainHBox/TextScroll/TextVBox/BaseTraitsCard/BaseTraitsMargin/ContentVBox/AnalysisVBox/ContentScroll/BasePersonalityText
@onready var status_text: RichTextLabel = $CenterContainer/Panel/VBoxContainer/BodyMargin/MainHBox/TextScroll/TextVBox/AnalysisCard/AnalysisMargin/AnalysisVBox/ContentScroll/ContentVBox/StatusVBox/Text
@onready var behavior_text: RichTextLabel = $CenterContainer/Panel/VBoxContainer/BodyMargin/MainHBox/TextScroll/TextVBox/AnalysisCard/AnalysisMargin/AnalysisVBox/ContentScroll/ContentVBox/BehaviorVBox/Text
@onready var advice_text: RichTextLabel = $CenterContainer/Panel/VBoxContainer/BodyMargin/MainHBox/TextScroll/TextVBox/AnalysisCard/AnalysisMargin/AnalysisVBox/ContentScroll/ContentVBox/AdviceVBox/Text
@onready var deepseek_client = $DeepSeekClient

const POPUP_PADDING: float = 72.0

var _popup_min_size: Vector2 = Vector2(850, 600)

var _panel_tween: Tween = null

func _ready() -> void:
	_popup_min_size = panel_root.custom_minimum_size
	if _popup_min_size == Vector2.ZERO:
		_popup_min_size = panel_root.size
	if _popup_min_size == Vector2.ZERO:
		_popup_min_size = Vector2(850, 600)
	close_btn.pressed.connect(_on_close_pressed)
	background_panel.gui_input.connect(_on_background_gui_input)
	resized.connect(_on_panel_resized)
	hide()


func show_panel(char_id: String = "") -> void:
	var target_char_id: String = char_id
	if target_char_id == "" and GameDataManager.config and GameDataManager.config.current_character_id != "":
		target_char_id = GameDataManager.config.current_character_id
	if target_char_id == "":
		target_char_id = "luna"

	_load_char_archive(target_char_id)
	_update_popup_layout()
	show()
	background_panel.modulate.a = 0.0
	panel_root.modulate.a = 0.0
	panel_root.scale = Vector2(0.97, 0.97)
	_kill_panel_tween()
	_panel_tween = create_tween()
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(background_panel, "modulate:a", 1.0, 0.18)
	_panel_tween.tween_property(panel_root, "modulate:a", 1.0, 0.22)
	_panel_tween.tween_property(panel_root, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _load_char_archive(char_id: String) -> void:
	var temp_profile: CharacterProfile = CharacterProfile.new()
	temp_profile.load_profile(char_id)
	_update_personality_display(temp_profile)


func _get_story_day_offset_for_char(char_id: String) -> int:
	var path: String = "user://saves/%s/story_time_save.json" % char_id
	if not FileAccess.file_exists(path):
		return 0
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var json: JSON = JSON.new()
	var result: int = json.parse(file.get_as_text())
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

	var history: Array = profile.personality_history.duplicate()
	var current_day_offset: int = _get_story_day_offset_for_char(profile.current_character_id)
	history.append({
		"day_offset": current_day_offset,
		"openness": float(profile.openness),
		"conscientiousness": float(profile.conscientiousness),
		"extraversion": float(profile.extraversion),
		"agreeableness": float(profile.agreeableness),
		"neuroticism": float(profile.neuroticism)
	})
	line_chart.set_data(history)

	var base_traits_str: String = GameDataManager.personality_system.get_base_traits(profile)
	base_personality_text.text = "暂无初始底色配置" if base_traits_str == "" else base_traits_str

	var dynamic_traits_parts: Array = [
		GameDataManager.personality_system.get_personality_state_summary(profile),
		GameDataManager.personality_system.get_recent_event_summary(profile),
		GameDataManager.personality_system.get_tension_summary(profile),
		GameDataManager.personality_system.get_mood_summary(profile),
		GameDataManager.personality_system.get_pattern_summary(profile),
		GameDataManager.personality_system.get_last_settlement_summary(profile),
		"",
		GameDataManager.personality_system.get_dynamic_traits(profile)
	]
	var dynamic_traits_str: String = "\n".join(dynamic_traits_parts)
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
		var content: String = str(response["choices"][0].get("message", {}).get("content", ""))
		var json: JSON = JSON.new()
		var err: int = json.parse(content)
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
	hide_panel()

func hide_panel() -> void:
	if not visible:
		return
	_kill_panel_tween()
	_panel_tween = create_tween()
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(background_panel, "modulate:a", 0.0, 0.16)
	_panel_tween.tween_property(panel_root, "modulate:a", 0.0, 0.16)
	_panel_tween.tween_property(panel_root, "scale", Vector2(0.97, 0.97), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_panel_tween.set_parallel(false)
	_panel_tween.tween_callback(hide)

func _on_background_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		hide_panel()

func _on_panel_resized() -> void:
	if visible:
		_update_popup_layout()

func _update_popup_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var target_size: Vector2 = _popup_min_size
	target_size.x = minf(target_size.x, viewport_size.x - POPUP_PADDING)
	target_size.y = minf(target_size.y, viewport_size.y - POPUP_PADDING)
	panel_root.custom_minimum_size = target_size
	panel_root.size = target_size
	panel_root.pivot_offset = target_size * 0.5

func _kill_panel_tween() -> void:
	if _panel_tween != null:
		_panel_tween.kill()
		_panel_tween = null
