extends Control

signal chat_closed

@onready var ui_panel: Panel = $UIPanel
@onready var hide_ui_btn: Button = $UIPanel/UIOverlay/HideUIButton
@onready var camera_btn: Button = $UIPanel/UIOverlay/CameraButton

@onready var dialogue_panel: Control = $UIPanel/DialoguePanel
@onready var name_label: Label = $UIPanel/DialoguePanel/DialogueLayer/VBox/NameLabel
@onready var dialogue_text: RichTextLabel = $UIPanel/DialoguePanel/DialogueLayer/VBox/RichTextLabel
@onready var input_layer: Panel = $UIPanel/DialoguePanel/InputLayer
@onready var input_field: TextEdit = $UIPanel/DialoguePanel/InputLayer/HBoxContainer/InputField
@onready var send_btn: Button = $UIPanel/DialoguePanel/InputLayer/HBoxContainer/SendButton
@onready var voice_record_btn: Button = $UIPanel/DialoguePanel/InputLayer/HBoxContainer/VoiceRecordButton
@onready var quick_options_container = $UIPanel/DialoguePanel/QuickOptionLayer/ScrollContainer/QuickOptions
@onready var end_chat_btn: Button = $UIPanel/DialoguePanel/EndChatButton
@onready var history_btn: Button = $UIPanel/DialoguePanel/HistoryButton

@onready var character_layer: Node2D = $CharacterLayer

@onready var deepseek_client: DeepSeekClient = $DeepSeekClient
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var mic_capture: AudioStreamPlayer = $MicCapture
var qwen_asr_client = null

@onready var click_blocker: Control = $ClickBlocker

var _ui_tween: Tween = null
var _typewriter_tween: Tween = null
var camera_panel_instance = null
var mobile_interface_instance = null
var _intro_playing: bool = false
var _intro_waiting_for_click: bool = false
var _waiting_for_chat_click: bool = false

# Free Chat states
var is_free_chat_mode: bool = false
var free_chat_strategy: String = ""
var free_chat_max_rounds: int = 0
var free_chat_current_round: int = 0

var _accumulated_stats: Dictionary = {
    "intimacy": 0.0,
    "trust": 0.0,
    "openness": 0.0,
    "conscientiousness": 0.0,
    "extraversion": 0.0,
    "agreeableness": 0.0,
    "neuroticism": 0.0
}

@onready var free_chat_info_layer: Control = $UIPanel/FreeChatInfoLayer
@onready var free_chat_round_label: Label = $UIPanel/FreeChatInfoLayer/Panel/Margin/VBox/RoundLabel
@onready var free_chat_strategy_label: RichTextLabel = $UIPanel/FreeChatInfoLayer/Panel/Margin/VBox/StrategyLabel

var history_panel = null
var affection_panel = null
var gift_panel = null
var debug_panel = null

var incoming_call_notification_instance = null

var script_engine: ScriptEngineManager = null

signal _intro_click_proceed
signal _chat_click_proceed

const HISTORY_ITEM_SCENE = preload("res://scenes/ui/history/history_item.tscn")
const QUICK_OPTION_ITEM_SCENE = preload("res://scenes/ui/story/quick_option_item.tscn")

func _ready() -> void:
    dialogue_panel.show()
    
    # 故事场景中，我们现在使用结束按钮退出
    if end_chat_btn:
        end_chat_btn.show()
        # 断开面板自带的结束事件
        if end_chat_btn.pressed.is_connected(dialogue_panel._on_end_chat_pressed):
            end_chat_btn.pressed.disconnect(dialogue_panel._on_end_chat_pressed)
        end_chat_btn.pressed.connect(_on_end_chat_pressed)
        
    click_blocker.gui_input.connect(_on_click_blocker_input)
    if dialogue_panel.has_signal("panel_clicked"):
        dialogue_panel.panel_clicked.connect(_on_click_blocker_input)
    
    if GameDataManager.config:
        GameDataManager.config.apply_settings()
        
    if hide_ui_btn: hide_ui_btn.pressed.connect(_on_hide_ui_pressed)
    if camera_btn: camera_btn.pressed.connect(_on_camera_pressed)
        
    if history_btn: history_btn.pressed.connect(_on_history_pressed)
    if voice_record_btn:
        voice_record_btn.button_down.connect(_on_voice_record_down)
        voice_record_btn.button_up.connect(_on_voice_record_up)
    if send_btn: send_btn.pressed.connect(_on_send_pressed)
    if input_field: input_field.text_changed.connect(_on_input_text_changed)
    
    GameDataManager.profile.stage_upgraded.connect(_on_stage_upgraded)
    GameDataManager.character_switched.connect(_on_character_switched)
    
    deepseek_client.chat_request_completed.connect(_on_chat_response)
    deepseek_client.chat_request_failed.connect(_on_chat_error)
    deepseek_client.chat_stream_started.connect(_on_chat_stream_started)
    deepseek_client.chat_stream_delta.connect(_on_chat_stream_delta)
    
    deepseek_client.emotion_request_completed.connect(_on_emotion_response)
    deepseek_client.emotion_request_failed.connect(_on_emotion_error)
    
    deepseek_client.memory_request_completed.connect(_on_memory_response)
    deepseek_client.memory_request_failed.connect(_on_memory_error)
    
    deepseek_client.options_request_completed.connect(_on_options_response)
    deepseek_client.options_request_failed.connect(_on_options_error)
    
    deepseek_client.narrator_request_completed.connect(_on_narrator_response)
    deepseek_client.narrator_request_failed.connect(_on_narrator_error)
    
    TTSManager.tts_success.connect(_on_tts_success)
    TTSManager.tts_failed.connect(_on_tts_failed)
    
    if GameDataManager.config.qwen_asr_enabled:
        var QwenASRClient = load("res://scripts/api/qwen_asr_client.gd")
        if QwenASRClient:
            qwen_asr_client = QwenASRClient.new()
            qwen_asr_client.name = "QwenASRClient"
            add_child(qwen_asr_client)
            qwen_asr_client.transcribe_completed.connect(_on_asr_success)
            qwen_asr_client.transcribe_failed.connect(_on_asr_failed)
            print("[DialogueManager] 已启用千问 ASR")
    
    # 初始化并挂载 ScriptEngineManager
    script_engine = ScriptEngineManager.new()
    add_child(script_engine)
    script_engine.on_dialogue_requested.connect(_on_script_dialogue_requested)
    script_engine.on_character_show_requested.connect(_on_script_show_character)
    script_engine.on_character_hide_requested.connect(_on_script_hide_character)
    script_engine.on_player_info_requested.connect(_on_script_player_info)
    script_engine.on_voice_call_requested.connect(_on_script_voice_call)
    script_engine.on_start_free_chat_requested.connect(_on_script_start_free_chat)
    script_engine.on_background_requested.connect(_on_script_background_requested)
    script_engine.on_bgm_requested.connect(_on_script_bgm_requested)
    script_engine.on_audio_requested.connect(_on_script_audio_requested)
    script_engine.on_variable_set.connect(_on_script_variable_set)
    script_engine.on_ai_chat_requested.connect(_on_script_ai_chat_requested)
    script_engine.script_finished.connect(_on_script_finished)
    
    _update_ui()
    
    # Check if we should play the intro story
    if GameDataManager.has_meta("play_intro_story") and GameDataManager.get_meta("play_intro_story"):
        GameDataManager.remove_meta("play_intro_story")
        _play_intro_story()
        return
    
    # 初始问候
    var messages = GameDataManager.history.messages
    if messages.size() == 0:
        var char_name = GameDataManager.profile.char_name
        _show_message("你好...今天想聊点什么？", char_name, false)
    else:
        # 有历史记录时，生成旁白并续写话题
        _generate_narrator_and_continue()

func _play_intro_story() -> void:
    _intro_playing = true
    send_btn.disabled = true
    input_field.editable = false
    ui_panel.visible = true
    input_layer.hide()
    
    modulate.a = 0.0
    var fade_tween = create_tween()
    fade_tween.tween_property(self, "modulate:a", 1.0, 1.0)
    
    if character_layer.has_method("hide_character"):
        character_layer.hide()
    
    var path = "res://assets/data/story/intro_story.json"
    if script_engine.load_script(path):
        script_engine.start_script("start")
    else:
        _intro_playing = false
        send_btn.disabled = false
        input_field.editable = true
        input_layer.show()

func _on_script_dialogue_requested(speaker: String, content: String, mood: String) -> void:
    var char_name = speaker
    if speaker == "旁白":
        char_name = " "
    elif speaker == "player":
        char_name = "我"
    elif speaker == "char":
        char_name = GameDataManager.profile.char_name
    else:
        char_name = speaker.capitalize()
        
    var actual_content = content
    if GameDataManager.profile:
        actual_content = actual_content.replace("{player_name}", GameDataManager.profile.player_name)
        var p_title = GameDataManager.profile.player_title
        if p_title == "":
            p_title = "老师"
        actual_content = actual_content.replace("{player_title}", p_title)
        
    await _show_message_async(actual_content, char_name, true)
    script_engine.resume()

func _on_script_show_character(animation: String) -> void:
    if character_layer.has_method("show_character"):
        character_layer.show_character(animation)
    else:
        character_layer.show()
    script_engine.resume()

func _on_script_hide_character(animation: String) -> void:
    if character_layer.has_method("hide_character"):
        character_layer.hide_character(animation)
    else:
        character_layer.hide()
    script_engine.resume()

func _on_script_player_info() -> void:
    var popup_scene = load("res://scenes/ui/story/player_info_popup.tscn")
    if popup_scene:
        var popup = popup_scene.instantiate()
        add_child(popup)
        popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        await popup.info_submitted
        
        if popup.player_info.has("name"):
            GameDataManager.profile.player_name = popup.player_info["name"]
        if popup.player_info.has("preferred_title"):
            GameDataManager.profile.player_title = popup.player_info["preferred_title"]
            
        GameDataManager.profile.save_profile()
        popup.queue_free()
    script_engine.resume()

func _on_script_voice_call(call_id: String) -> void:
    var fixed_calls_path = "res://assets/data/story/fixed_calls.json"
    var call_data = []
    if FileAccess.file_exists(fixed_calls_path):
        var file = FileAccess.open(fixed_calls_path, FileAccess.READ)
        var json = JSON.new()
        if json.parse(file.get_as_text()) == OK:
            call_data = json.data
            
    var target_call_id = call_id
    var call_lines = []
    var char_id = "ya"
    for call in call_data:
        if call.get("id") == target_call_id:
            call_lines = call.get("lines", [])
            char_id = call.get("char_id", "ya")
            break
            
    GameDataManager.set_meta("pending_fixed_call_data", call_lines)
    
    if is_instance_valid(incoming_call_notification_instance):
        incoming_call_notification_instance.queue_free()
        
    var NotificationObj = load("res://scenes/ui/main/incoming_call_notification.tscn")
    var notification = NotificationObj.instantiate()
    incoming_call_notification_instance = notification
    add_child(notification)
    notification.show_incoming_call(char_id, false, true)
    
    var original_ui_visible = ui_panel.visible
    ui_panel.visible = false
    
    await notification.call_accepted
    notification.queue_free()
    
    if mobile_interface_instance == null:
        var MobileInterfaceObj = load("res://scenes/ui/mobile/mobile_interface.tscn")
        mobile_interface_instance = MobileInterfaceObj.instantiate()
        add_child(mobile_interface_instance)
        mobile_interface_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        
    mobile_interface_instance.show_phone()
    mobile_interface_instance.open_call_directly(char_id, false, true)
    
    await get_tree().process_frame
    await get_tree().process_frame
    
    if mobile_interface_instance.chat_panel_instance:
        await mobile_interface_instance.chat_panel_instance.incoming_call_ended
    
    # If we created it just for this, we might want to hide it
    if is_instance_valid(mobile_interface_instance):
        mobile_interface_instance.hide_phone()
    
    ui_panel.visible = original_ui_visible
    script_engine.resume()

func _on_script_start_free_chat(strategy: String, max_rounds: int) -> void:
    is_free_chat_mode = true
    free_chat_strategy = strategy
    free_chat_max_rounds = max_rounds
    free_chat_current_round = 0
    _update_free_chat_info()
    free_chat_info_layer.show()
    
    _intro_playing = false
    input_layer.show()
    input_field.editable = true
    send_btn.disabled = false
    
    var char_name = GameDataManager.profile.char_name
    await _show_message_async("我们聊聊吧...", char_name, false)
    script_engine.resume()

func _on_script_background_requested(bg_path: String, duration: float, transition_type: String) -> void:
    var tex = load(bg_path)
    if tex:
        # 尝试寻找所有可能的背景节点，优先寻找故事场景的 BackgroundLayer
        var bg_node = null
        if get_parent() and get_parent().has_node("BackgroundLayer"):
            bg_node = get_parent().get_node("BackgroundLayer")
        
        # 兼容旧逻辑和自身内部的节点
        if not bg_node:
            bg_node = get_node_or_null("BackgroundLayer")
        
        # 兼容 main_scene.gd 的结构
        if not bg_node and get_parent() and get_parent().has_node("MainBg"):
            bg_node = get_parent().get_node("MainBg")
        
        if bg_node and bg_node is TextureRect:
            if duration > 0:
                BackgroundTransitionHelper.execute_transition(bg_node, tex, duration, transition_type, func(): script_engine.resume())
            else:
                bg_node.texture = tex
                script_engine.resume()
        else:
            print("[ScriptEngine] 警告：找到了背景资源，但未找到对应的 TextureRect 背景节点！", bg_node)
            script_engine.resume()
    else:
        print("[ScriptEngine] 警告：无法加载背景图片 -> ", bg_path)
        script_engine.resume()

func _on_script_bgm_requested(audio_path: String, fade_time: float) -> void:
    # 如果有全局 AudioManager，最好调用它；这里演示使用自带的或全局逻辑
    # 假设 AudioManager 存在且支持 crossfade
    if has_node("/root/AudioManager"):
        var am = get_node("/root/AudioManager")
        if am.has_method("play_bgm"):
            am.play_bgm(audio_path, fade_time)
    else:
        print("[ScriptEngine] Warning: AudioManager not found, BGM skipped.")
    script_engine.resume()

func _on_script_audio_requested(audio_type: String, action: String, audio_id: String, fade_time: float, loop: bool) -> void:
    if action == "play":
        if audio_type == "bgm":
            AudioManager.play_bgm(audio_id, fade_time)
        elif audio_type == "bgs":
            AudioManager.play_bgs(audio_id, fade_time)
        elif audio_type == "se":
            AudioManager.play_se(audio_id, loop)
    elif action == "stop":
        if audio_type == "bgm":
            AudioManager.stop_bgm(fade_time)
        elif audio_type == "bgs":
            AudioManager.stop_bgs(fade_time)
        elif audio_type == "se":
            AudioManager.stop_se(audio_id)
    script_engine.resume()

func _on_script_variable_set(var_name: String, var_value: Variant) -> void:
    GameDataManager.set_meta(var_name, var_value)
    script_engine.resume()

func _on_script_ai_chat_requested(prompt_override: String) -> void:
    # 暂停脚本，进入临时 AI 自由对话（等待玩家点击结束对话后再恢复）
    # 此处作为简单实现，发送 prompt 给 AI，并允许一次问答
    print("[ScriptEngine] 触发临时 AI Chat: ", prompt_override)
    is_free_chat_mode = true
    free_chat_strategy = prompt_override
    free_chat_max_rounds = 1
    free_chat_current_round = 0
    
    _intro_playing = false
    input_layer.show()
    input_field.editable = true
    send_btn.disabled = false
    
    # 这里只允许一轮对话，AI回答后可以在 _on_chat_response 或其他地方判断轮次并调用 script_engine.resume()
    # 如果要做到完美阻塞，应该在这个特定状态结束后由发送或接收逻辑调用 script_engine.resume()
    # 目前为了避免死锁，如果没实现完美对接，先立刻放行。
    # 在真实项目中，应该等待对话完成的信号。
    # 我们在此先挂起，需要在 AI 聊天结束时（比如到达 max_rounds 退出时）调用 script_engine.resume()
    pass

func _on_script_finished(script_id: String) -> void:
    print("Script finished: ", script_id)
    GameDataManager.profile.mark_story_finished(script_id)
    if script_id == "intro_story":
        GameDataManager.set_meta("just_finished_intro_story", true)
        # 如果当前是根场景（例如初次进入的开场剧情），剧情结束应该切换到主场景
        if get_parent() == get_tree().root:
            if get_tree().root.has_node("SceneTransitionManager"):
                get_tree().root.get_node("SceneTransitionManager").transition_to_scene("res://scenes/ui/main/main_scene.tscn")
            else:
                get_tree().change_scene_to_file("res://scenes/ui/main/main_scene.tscn")
        else:
            # 如果 dialogue_manager 不是作为单独的 root 场景运行，
            # 说明它是嵌套在 main_scene 中的，我们直接触发跳转即可
            if get_tree().root.has_node("SceneTransitionManager"):
                get_tree().root.get_node("SceneTransitionManager").transition_to_scene("res://scenes/ui/main/main_scene.tscn")
            else:
                get_tree().change_scene_to_file("res://scenes/ui/main/main_scene.tscn")

func _update_free_chat_info() -> void:
    if free_chat_max_rounds > 0:
        free_chat_round_label.text = "自由对话轮次: %d / %d" % [free_chat_current_round, free_chat_max_rounds]
    else:
        free_chat_round_label.text = "自由对话"
        
    if free_chat_strategy != "":
        free_chat_strategy_label.text = "策略: " + free_chat_strategy
    else:
        free_chat_strategy_label.text = ""

func _send_player_message(text: String, is_system_event: bool = false) -> void:
    if not is_system_event:
        input_field.text = ""
        
        if is_free_chat_mode:
            free_chat_current_round += 1
            _update_free_chat_info()
            
    send_btn.disabled = true
    input_field.editable = false
    
    # 发起请求前清除之前的选项
    pending_options_data.clear()
    for child in quick_options_container.get_children():
        child.queue_free()
        
    if not is_system_event:
        # Wait for the typewriter effect of the player's message to finish before requesting AI response
		await _show_message_async(text, "我")
	
	_request_ai_response(text, is_system_event)
	
	# 检查是否达到最大轮次，在发送请求后关闭模式，这样本次请求还能带上策略
	if is_free_chat_mode and free_chat_max_rounds > 0 and free_chat_current_round >= free_chat_max_rounds:
		is_free_chat_mode = false
		free_chat_info_layer.hide()
		ToastManager.show_system_toast("自由对话阶段结束", Color(0.8, 0.4, 0.1, 0.9))
		
		# 如果是作为独立剧情执行的最后一个事件，手动调用恢复以触发 _on_script_finished
		if script_engine.is_running:
			script_engine.resume()

func _generate_narrator_and_continue() -> void:
	send_btn.disabled = true
	input_field.editable = false
	print("正在生成场景旁白...")
	# 清空对话框内容，保持干净
	dialogue_text.text = ""
	name_label.text = ""
	deepseek_client.send_narrator_generation()

func _on_narrator_response(response: Dictionary) -> void:
	if response.has("choices") and response["choices"].size() > 0:
		var narrator_text = response["choices"][0]["message"]["content"].strip_edges()
		
		# 显示旁白，无角色名，不发声，不记录到历史
		await _show_message_async(narrator_text, " ", true)
		
		# 旁白显示完后等待一小段时间
		if is_inside_tree():
			await get_tree().create_timer(1.5).timeout
			
		# 触发角色续写话题
		_trigger_character_continue()
	else:
		_on_narrator_error("旁白生成为空")

func _on_narrator_error(error_msg: String) -> void:
	print("旁白生成失败: ", error_msg)
	# 兜底：如果旁白失败，直接恢复最后一条消息或让角色直接说话
	_restore_last_message()
	send_btn.disabled = false
	input_field.editable = true

func _trigger_character_continue() -> void:
	print("旁白生成完毕，正在思考后续对话...")
	var char_name = GameDataManager.profile.char_name
	
	is_text_playback_finished = false
	pending_options_data.clear()
	
	# 计算玩家离线时间
	var offline_seconds = 0
	var last_time = GameDataManager.profile.last_online_time
	if last_time > 0:
		offline_seconds = Time.get_unix_time_from_system() - last_time
	
	# 获取性格系统动态生成的重逢问候策略
	var greeting_strategy = GameDataManager.personality_system.get_offline_greeting_strategy(GameDataManager.profile, offline_seconds)
	
	# 构造一条系统级的隐式 prompt，让 LLM 知道它需要主动续写话题
	var continue_prompt = "【系统提示：%s。注意：绝对不要输出这段系统提示，直接以%s的口吻说话。】" % [greeting_strategy, char_name]
	
	if GameDataManager.config.ai_mode_enabled:
		var query_embedding = []
		var messages = GameDataManager.history.messages
		if messages.size() > 0:
			var last_msg = messages[messages.size() - 1]["text"]
			query_embedding = await DoubaoEmbeddingClient.get_embedding(last_msg)
			
		var system_prompt = GameDataManager.prompt_manager.build_chat_prompt(GameDataManager.profile, continue_prompt, query_embedding)
		var api_messages = [{"role": "system", "content": system_prompt}]
		api_messages.append_array(deepseek_client._get_history_messages(10))
		api_messages.append({"role": "user", "content": continue_prompt})
		
		var body = {
			"model": GameDataManager.config.model,
			"messages": api_messages,
			"temperature": GameDataManager.config.temperature,
			"max_tokens": GameDataManager.config.max_tokens
		}
		deepseek_client.chat_http.request(deepseek_client._get_url(), deepseek_client._get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	else:
		_show_message("（离线模式）你回来了，我们刚才聊到哪了？", char_name)
		send_btn.disabled = false
		input_field.editable = true

func _restore_last_message() -> void:
	var messages = GameDataManager.history.messages
	if messages.size() > 0:
		var last_msg = messages[messages.size() - 1]
		# 直接静默显示最后一条，不触发打字机和语音
		dialogue_text.text = last_msg["text"]
		dialogue_text.visible_characters = -1
		name_label.text = last_msg["speaker"]
		
		# 恢复对应立绘
		if last_msg["speaker"] == GameDataManager.profile.char_name:
			var current_expression = GameDataManager.profile.current_expression
			_update_character_sprite(current_expression)
	else:
		var char_name = GameDataManager.profile.char_name
		# 如果没有历史记录，静默显示初始问候
		dialogue_text.text = "你好...今天想聊点什么？"
		dialogue_text.visible_characters = -1
		name_label.text = char_name

func _on_input_text_changed() -> void:
	if input_field.text.length() > 120:
		input_field.text = input_field.text.substr(0, 120)
		input_field.set_caret_column(120)

func _update_ui() -> void:
	pass

func _on_character_switched(char_id: String) -> void:
	ToastManager.show_system_toast("已切换到角色：" + char_id, Color.CYAN)
	
	# 清空现有对话UI
	dialogue_text.text = ""
	name_label.text = ""
	
	_update_ui()
	
	# 初始问候或恢复历史记录
	var messages = GameDataManager.history.messages
	if messages.size() == 0:
		var char_name = GameDataManager.profile.char_name
		_show_message("你好...今天想聊点什么？", char_name, false)
	else:
		_restore_last_message()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F10:
			GameDataManager.switch_character("luna")
		elif event.keycode == KEY_F11:
			GameDataManager.switch_character("ya")
		elif event.keycode == KEY_F12:
			if debug_panel == null:
				var DebugPanelObj = load("res://scenes/ui/story/debug_panel.tscn")
				debug_panel = DebugPanelObj.instantiate()
				add_child(debug_panel)
				debug_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				debug_panel.stage_changed.connect(_on_debug_stage_changed)
				debug_panel.mood_changed.connect(_on_debug_mood_changed)
				debug_panel.show_panel() # Instantiate and show directly
			elif debug_panel.visible:
				debug_panel.hide()
			else:
				debug_panel.show_panel()

func show_panel() -> void:
	show()
	modulate.a = 0.0
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	scale = Vector2(0.95, 0.95)
	pivot_offset = get_viewport_rect().size / 2.0
	var scale_tween = create_tween()
	scale_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	scale_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3)

func _show_accumulated_stats() -> void:
	var display_keys = {
		"intimacy": "亲密",
		"trust": "信任"
	}
	
	for key in _accumulated_stats.keys():
		var val = _accumulated_stats[key]
		if abs(val) > 0.01: # Avoid floating point inaccuracies
			if display_keys.has(key):
				var sign_str = "+" if val > 0 else ""
				var formatted_val = sign_str + ("%.1f" % val)
				ToastManager.show_stat_toast(key, display_keys[key] + " " + formatted_val)
		_accumulated_stats[key] = 0.0 # reset for next time

func hide_panel() -> void:
	_show_accumulated_stats()
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	var scale_tween = create_tween()
	scale_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	scale_tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.2)
	tween.finished.connect(func():
		hide()
		chat_closed.emit()
		
		# 强制检查：如果正在运行剧情且没有因为正常轮次耗尽而结束，玩家手动退出了界面，
		# 我们也视作当前挂起的剧情结束，防止无法保存剧情状态。
		if script_engine.is_running:
			script_engine._end_script()
			
		# 重置等待标志
		_waiting_for_chat_exit = false
		
		# 如果当前是根场景（例如初次进入的开场剧情），返回应该切换到主场景
		if get_parent() == get_tree().root:
			if get_tree().root.has_node("SceneTransitionManager"):
				get_tree().root.get_node("SceneTransitionManager").transition_to_scene("res://scenes/ui/main/main_scene.tscn")
			else:
				get_tree().change_scene_to_file("res://scenes/ui/main/main_scene.tscn")
	)

func _on_hide_ui_pressed() -> void:
	if _ui_tween:
		_ui_tween.kill()
	_ui_tween = create_tween()
	_ui_tween.tween_property(ui_panel, "modulate:a", 0.0, 0.3)
	_ui_tween.tween_callback(func(): ui_panel.visible = false)

func _on_click_blocker_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if camera_panel_instance and camera_panel_instance.visible:
			return
			
		if not ui_panel.visible or ui_panel.modulate.a < 0.99:
			get_viewport().set_input_as_handled()
			if _ui_tween:
				_ui_tween.kill()
			ui_panel.visible = true
			_ui_tween = create_tween()
			_ui_tween.tween_property(ui_panel, "modulate:a", 1.0, 0.3)
		else:
			if dialogue_text.visible_ratio < 1.0:
				get_viewport().set_input_as_handled()
				if _typewriter_tween:
					_typewriter_tween.kill()
				dialogue_text.visible_ratio = 1.0
				dialogue_text.visible_characters = -1
				
                # Make sure we finish the tween's intended outcome immediately if we killed it
                # We don't emit finished here, but we can wait briefly and then if it's intro we wait for next click
                
                # ADDED: If we just finished the text, we should NOT emit proceed immediately,
                # the next click should emit proceed.
            elif _intro_playing and _intro_waiting_for_click:
                get_viewport().set_input_as_handled()
                _intro_waiting_for_click = false
                _intro_click_proceed.emit()
                print("[Debug] _intro_click_proceed signal emitted")
            elif _waiting_for_chat_click:
                get_viewport().set_input_as_handled()
                _waiting_for_chat_click = false
                _chat_click_proceed.emit()
                print("[Debug] _chat_click_proceed signal emitted")

func _gui_input(event: InputEvent) -> void:
    pass

func _unhandled_input(event: InputEvent) -> void:
    pass

func _on_camera_pressed() -> void:
    if camera_panel_instance == null:
        var CameraPanelObj = load("res://scenes/ui/mobile/camera_panel.tscn")
        camera_panel_instance = CameraPanelObj.instantiate()
        get_tree().get_root().add_child(camera_panel_instance)
        camera_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        camera_panel_instance.camera_closed.connect(_on_camera_closed)
        
    camera_panel_instance.show_panel()
    
    if _ui_tween:
        _ui_tween.kill()
    ui_panel.visible = false
    ui_panel.modulate.a = 0.0

func _on_camera_closed() -> void:
    ui_panel.visible = true
    if _ui_tween:
        _ui_tween.kill()
    _ui_tween = create_tween()
    _ui_tween.tween_property(ui_panel, "modulate:a", 1.0, 0.3)

func _on_end_chat_pressed() -> void:
    if not GameDataManager.config.ai_mode_enabled:
        _show_message("（离线模式）下次再见！", GameDataManager.profile.char_name)
        await get_tree().create_timer(1.5).timeout
        hide_panel()
        return
        
    # 隐藏玩家输入框和玩家选项
    input_layer.hide()
    quick_options_container.get_parent().hide() # 隐藏整个 QuickOptionLayer/ScrollContainer
    end_chat_btn.hide()
    
    send_btn.disabled = true
    input_field.editable = false
    
    is_text_playback_finished = false
    pending_options_data.clear()
    
    var char_name = GameDataManager.profile.char_name
    
    # 从历史记录中提取最近的几条对话上下文作为参考
    var recent_history = GameDataManager.profile.get_recent_chat_history_text(3)
    
    var prompt = "【系统提示：玩家想要结束本次对话。请根据你们当前的关系阶段（Stage %d），并结合以下刚才聊天的上下文，给出自然的告别反应。注意：1. 只能回复单句告别语。2. 不要输出这段系统提示，直接以%s的口吻说话。】\n[近期聊天上下文]\n%s" % [GameDataManager.profile.current_stage, char_name, recent_history]
    
    # 发送隐藏系统消息来获取告别回复
    deepseek_client.send_chat_message(prompt, "story_chat")
    
    # 设定一个特殊标记，表示 AI 下一句话结束后应该退出面板
    _waiting_for_chat_exit = true

var _waiting_for_chat_exit: bool = false

func _on_voice_record_down() -> void:
    voice_record_btn.text = "松开发送"
    voice_record_btn.modulate = Color(0.8, 0.2, 0.2)
    if GameDataManager.config.qwen_asr_enabled and qwen_asr_client:
        qwen_asr_client.start_recording()

func _on_voice_record_up() -> void:
    voice_record_btn.text = "按住说话"
    voice_record_btn.modulate = Color(1, 1, 1)
    if GameDataManager.config.qwen_asr_enabled and qwen_asr_client:
        ToastManager.show_system_toast("正在识别语音...", Color.YELLOW)
        qwen_asr_client.stop_recording()

func _on_asr_success(text: String) -> void:
    if not text.is_empty():
        input_field.text = text
        ToastManager.show_system_toast("语音识别成功", Color.GREEN)
    else:
        ToastManager.show_system_toast("未听清你说什么", Color.ORANGE)

func _on_asr_failed(err: String) -> void:
    ToastManager.show_system_toast("语音识别失败: " + err, Color.RED)
    print("ASR Error: ", err)

func _on_affection_pressed() -> void:
    if affection_panel == null:
        var AffectionPanelObj = load("res://scenes/ui/story/affection_panel.tscn")
        affection_panel = AffectionPanelObj.instantiate()
        add_child(affection_panel)
        # Set proper anchor layout programmatically if needed
        affection_panel.anchor_top = 0.5
        affection_panel.anchor_bottom = 0.5
        affection_panel.offset_left = 120.0
        affection_panel.offset_top = -189.0
        affection_panel.offset_right = 400.0
        affection_panel.offset_bottom = 171.0
        
    if affection_panel.visible:
        affection_panel.hide()
    else:
        affection_panel.show_panel()

func _on_gift_pressed() -> void:
    if gift_panel == null:
        var GiftPanelObj = load("res://scenes/ui/gift/gift_panel.tscn")
        gift_panel = GiftPanelObj.instantiate()
        add_child(gift_panel)
        gift_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        gift_panel.gift_sent.connect(_on_gift_sent)
        
    gift_panel.show_panel()

func _on_gift_sent(gift_id: String) -> void:
    var profile = GameDataManager.profile
    var gift = GameDataManager.gift_manager.get_gift_by_id(gift_id)
    if gift.is_empty():
        return
        
    var res = GameDataManager.gift_manager.send_gift(profile, gift_id)
    if res.success:
        # 显示Toast
        ToastManager.show_toast("送出了 [%s]" % gift.name, Color(0.6, 0.4, 0.8, 0.9))
        if res.gained_intimacy > 0:
            ToastManager.show_stat_toast("intimacy", "亲密 +%.1f" % res.gained_intimacy)
        if res.gained_trust > 0:
            ToastManager.show_stat_toast("trust", "信任 +%.1f" % res.gained_trust)
        
        _update_ui()
        
        # 触发LLM生成对应的感谢/反应
        _trigger_gift_reaction(gift)
    else:
        ToastManager.show_system_toast(res.msg, Color.RED)

func _trigger_gift_reaction(gift: Dictionary) -> void:
    send_btn.disabled = true
    input_field.editable = false
    
    is_text_playback_finished = false
    pending_options_data.clear()
    
    var char_name = GameDataManager.profile.char_name
    var prompt = "【系统动作：玩家刚刚送给了你一份礼物，名称是：“%s”，描述是：“%s”。请根据你们当前的关系阶段（Stage %d）以及礼物的内容，给出自然的反应和台词。注意：不要输出这段系统提示，直接以%s的口吻说话。】" % [gift.name, gift.desc, GameDataManager.profile.current_stage, char_name]
    
    if GameDataManager.config.ai_mode_enabled:
        deepseek_client.send_chat_message(prompt)
    else:
        if is_inside_tree():
            await get_tree().create_timer(1.0).timeout
        _show_message("（离线模式）谢谢你的礼物！我很喜欢。", char_name)
        send_btn.disabled = false
        input_field.editable = true

func _on_debug_stage_changed(stage: int) -> void:
    ToastManager.show_system_toast("【Debug】强制切换情感阶段至：" + str(stage), Color.CYAN)
    GameDataManager.profile.force_set_stage(stage)
    # Clear short term history so the AI doesn't get confused by previous stage's context
    GameDataManager.history.messages.clear()
    GameDataManager.history.save_history()
    _update_ui()
    ToastManager.show_system_toast("已清空上下文历史，以重新适配新阶段", Color.GRAY)

func _on_stage_upgraded(new_stage: int, unlock_dialog: String) -> void:
    ToastManager.show_system_toast("情感阶段提升至: Stage " + str(new_stage), Color.YELLOW)
    
    var stage_conf = GameDataManager.profile.get_current_stage_config()
    if stage_conf.has("mood_switch"):
        var new_mood = stage_conf["mood_switch"]
        if GameDataManager.expression_system.is_valid_expression(new_mood):
            GameDataManager.profile.update_expression(new_mood)
            ToastManager.show_system_toast("表情切换为：" + new_mood, Color.ORANGE)

func _on_debug_mood_changed(expression: String) -> void:
    ToastManager.show_system_toast("【Debug】强制切换表情至：" + expression, Color.CYAN)
    GameDataManager.profile.update_expression(expression)
    _update_ui()

func _update_character_sprite(expression: String) -> void:
    var sprite_path = GameDataManager.expression_system.get_expression_sprite_path(expression)
    if sprite_path != "":
        var tex = load(sprite_path)
        if tex:
            if character_layer.has_method("update_sprite"):
                character_layer.update_sprite(tex)
            else:
                character_layer.texture = tex

func _on_history_pressed() -> void:
    if history_panel == null:
        var HistoryPanelObj = load("res://scenes/ui/history/history_panel.tscn")
        history_panel = HistoryPanelObj.instantiate()
        add_child(history_panel)
        history_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        var close_btn = history_panel.get_node("HistoryTopBar/HistoryCloseButton")
        if close_btn:
            close_btn.pressed.connect(_on_history_close_pressed)
            
    history_panel.show()
    _populate_history_ui()
    
    # 延迟一帧等待容器布局完成，然后滚动到底部
    if is_inside_tree():
        await get_tree().process_frame
    var scroll = history_panel.get_node("ScrollContainer")
    if scroll:
        var v_scroll = scroll.get_v_scroll_bar()
        v_scroll.value = v_scroll.max_value

func _on_history_close_pressed() -> void:
    if history_panel:
        history_panel.hide()

func _populate_history_ui() -> void:
    if not history_panel: return
    var history_vbox = history_panel.get_node("ScrollContainer/VBoxContainer")
    if not history_vbox: return
    
    # 清空现有子节点
    for child in history_vbox.get_children():
        child.queue_free()
        
    var messages = GameDataManager.history.get_messages_by_type("story_chat")
    for msg in messages:
        var item = HISTORY_ITEM_SCENE.instantiate()
        history_vbox.add_child(item)
        item.setup(msg)
        item.play_voice_requested.connect(_play_cached_voice)

func _play_cached_voice(cache_key: String) -> void:
    # 由于我们重构了 TTSManager，原来的本地缓存逻辑直接暴露给外部不太合适
    # 但这里仅仅是播放历史语音，我们可以直接通过 FileAccess 尝试加载 MD5 key 对应的音频文件
    # 或者简单地通过 TTSManager 重新请求（因为它内部有缓存）
    # 为了保持行为一致，我们使用 TTSManager 提供的新接口或者直接重新请求：
    var options = {}
    if GameDataManager.profile and GameDataManager.config:
        var char_id = GameDataManager.config.current_character_id
        if GameDataManager.config.character_voice_types.has(char_id):
            options["voice_type"] = GameDataManager.config.character_voice_types[char_id]
    
    # TODO: 未来需要在 TTSManager 或 Adapter 中公开 get_cache_path 方法以支持直接播放，
    # 暂时我们直接通过 TTSManager 重新发送文本，因为它的内部底层 Adapter 依然会命中缓存文件
    # 注意：历史面板目前只保存了 cache_key 而不是完整文本，我们需要根据设计调整。
    # 在没有公开 _load_audio_from_file 之前，我们可以直接查默认目录：
    var cache_path = "user://tts_cache/" + cache_key + ".mp3"
    if FileAccess.file_exists(cache_path):
        var file = FileAccess.open(cache_path, FileAccess.READ)
        if file:
            var data = file.get_buffer(file.get_length())
            var stream = AudioStreamMP3.new()
            stream.data = data
            audio_player.stream = stream
            audio_player.play()
    else:
        print("未找到语音缓存: ", cache_key)

var pending_status_changes = []


func _request_ai_response(text: String, is_system_event: bool) -> void:
    if not is_system_event:
        # Save player message
        GameDataManager.history.add_message("我", text, "", "story_chat")
        
    # Clear the flag for playback finish
    is_text_playback_finished = false
    
    if GameDataManager.config.ai_mode_enabled:
        deepseek_client.send_chat_message(text, "story_chat")
    else:
        # 本地兜底对话
        if is_inside_tree():
            await get_tree().create_timer(1.0).timeout
        var char_name = GameDataManager.profile.char_name
        _show_message("（离线模式）我...我不知道该说什么...", char_name)
        send_btn.disabled = false
        input_field.editable = true

func _on_send_pressed() -> void:
    var text = input_field.text.strip_edges()
    if text.is_empty():
        return
    
    _send_player_message(text, false)

var pending_reply_lines = []
var stream_live_active: bool = false
var stream_live_done: bool = false
var stream_live_buffer: String = ""
var stream_live_queue: Array = []
var stream_live_worker_running: bool = false

func _on_chat_stream_started() -> void:
    stream_live_active = true
    stream_live_done = false
    stream_live_buffer = ""
    stream_live_queue.clear()
    
    if _waiting_for_chat_click:
        _waiting_for_chat_click = false
        _chat_click_proceed.emit()
        
    _try_start_stream_worker()

func _on_chat_stream_delta(delta_text: String) -> void:
    if not stream_live_active:
        return
    stream_live_buffer += delta_text
    _extract_stream_segments(false)
    _try_start_stream_worker()

func _on_chat_response(response: Dictionary) -> void:
    var char_name = GameDataManager.profile.char_name
    
    if stream_live_active:
        stream_live_done = true
        _extract_stream_segments(true)
        _try_start_stream_worker()
        
        # 当流式接收彻底完毕时，因为此时历史记录中还没有保存AI刚刚说的这句话，我们需要手动将它传给选项生成器
        if GameDataManager.config.ai_mode_enabled and not _waiting_for_chat_exit:
            var ai_reply = deepseek_client._chat_stream_full_text
            deepseek_client.send_options_generation(ai_reply, free_chat_strategy if is_free_chat_mode else "")
            
            # 触发记忆提取
            var messages = GameDataManager.history.get_messages_by_type("story_chat")
            if messages.size() > 0:
                var last_msg = messages[messages.size() - 1]
                if last_msg["speaker"] == "我" and GameDataManager.memory_manager.add_turn():
                    deepseek_client.extract_memory_from_chat(last_msg["text"], ai_reply)
                    
        return
        
    if response.has("choices") and response["choices"].size() > 0:
        var reply = response["choices"][0]["message"]["content"]
        
        # 非流式模式下，收到完整回复后也立刻提前触发选项生成，并手动传入最新回复
        if GameDataManager.config.ai_mode_enabled and not _waiting_for_chat_exit:
            deepseek_client.send_options_generation(reply, free_chat_strategy if is_free_chat_mode else "")
            
            # 触发记忆提取
            var messages = GameDataManager.history.get_messages_by_type("story_chat")
            if messages.size() > 0:
                var last_msg = messages[messages.size() - 1]
                if last_msg["speaker"] == "我" and GameDataManager.memory_manager.add_turn():
                    deepseek_client.extract_memory_from_chat(last_msg["text"], reply)
            
        # 拦截 reply 进行预处理，提取纯净的消息序列
        var lines = _parse_reply_to_lines(reply)
        if lines.size() == 0:
            _show_message(char_name + " 似乎走神了...", char_name)
            send_btn.disabled = false
            input_field.editable = true
            return
            
        _play_message_sequence(lines, char_name)
    else:
        _show_message(char_name + " 似乎走神了...", char_name)
        send_btn.disabled = false
        input_field.editable = true

# 移除旧的 _on_character_mood_response 和 _on_character_mood_error 回调，
# 因为我们现在改为在 _play_message_sequence 中逐条进行同步等待分析了。

func _parse_reply_to_lines(reply: String) -> Array:
    # Print the raw reply to the console for debugging
    print("\n========== [Chat Agent Output] ==========")
    print(reply)
    print("=========================================\n")
    
    # Try to parse the reply as multiple bubbles using the [SPLIT] token
    var clean_reply = reply.strip_edges()
    
    # Remove any markdown formatting if the LLM still tries to output it
    if clean_reply.begins_with("```"):
        var lines = clean_reply.split("\n")
        if lines.size() > 2:
            lines.remove_at(0)
            if lines[lines.size()-1].begins_with("```"):
                lines.remove_at(lines.size()-1)
            clean_reply = "\n".join(lines).strip_edges()
            
    var message_list = _auto_split_message(clean_reply)
        
    var valid_lines = []
    for line in message_list:
        if typeof(line) == TYPE_STRING:
            var t = line.strip_edges()
            if t != "":
                valid_lines.append(t)
                
    return valid_lines

func _on_emotion_response(response: Dictionary) -> void:
    if response.has("choices") and response["choices"].size() > 0:
        var reply = response["choices"][0]["message"]["content"]
        
        print("\n========== [Emotion Agent Output] ==========")
        print(reply)
        print("============================================\n")
        
        var regex = RegEx.new()
        regex.compile("(?i)(?:<|\\<|《|\\[|【)\\s*(intimacy|trust|亲密度|亲密变化|信任度|信任值|信任变化|openness|conscientiousness|extraversion|agreeableness|neuroticism)\\s*[:：]\\s*([^>\\>》\\]】]+)\\s*(?:>|\\>|》|\\]|】)")
        var matches = regex.search_all(reply)
        var has_changes = false
        
        for m in matches:
            var tag = m.get_string(1).to_lower()
            var val = m.get_string(2).strip_edges()
            var f_val = val.to_float()
            
            if tag == "intimacy" or tag.begins_with("亲密"):
                GameDataManager.profile.update_intimacy(f_val)
                has_changes = true
                _accumulated_stats["intimacy"] += f_val
            elif tag == "trust" or tag.begins_with("信任"):
                GameDataManager.profile.update_trust(f_val)
                has_changes = true
                _accumulated_stats["trust"] += f_val
            elif tag in ["openness", "conscientiousness", "extraversion", "agreeableness", "neuroticism"]:
                if f_val != 0.0:
                    GameDataManager.personality_system.update_trait(GameDataManager.profile, tag, f_val)
                    has_changes = true
                    _accumulated_stats[tag] += f_val
                    
        if has_changes:
            GameDataManager.profile.save_profile()
            _update_ui()

func _on_emotion_error(error_msg: String) -> void:
    print("Emotion Agent Failed: ", error_msg)

func _on_memory_response(response: Dictionary) -> void:
    # 记忆的解析和存储现在已移至 deepseek_client.gd 的 _on_memory_completed 中集中处理。
    pass

func _on_memory_error(error_msg: String) -> void:
    print("Memory Agent Failed: ", error_msg)

var pending_options_data = []
var is_text_playback_finished = true

func _on_options_response(response: Dictionary) -> void:
    if response.has("choices") and response["choices"].size() > 0:
        var reply = response["choices"][0]["message"]["content"]
        
        print("\n========== [Options Agent Output] ==========")
        print(reply)
        print("============================================\n")
        
        var json = JSON.new()
        
        # 提取可能的 JSON 代码块
        var json_str = reply
        var regex = RegEx.new()
        regex.compile("```(?:json)?\\s*(\\{[\\s\\S]*?\\})\\s*```")
        var match = regex.search(reply)
        if match:
            json_str = match.get_string(1).strip_edges()
        else:
            var start_idx = reply.find("{")
            var end_idx = reply.rfind("}")
            if start_idx != -1 and end_idx != -1 and end_idx > start_idx:
                json_str = reply.substr(start_idx, end_idx - start_idx + 1)
                
        if json.parse(json_str.strip_edges()) == OK:
            var data = json.get_data()
            if data is Dictionary and data.has("options") and data["options"] is Array:
                pending_options_data = data["options"]
                _try_show_options()
                return
                
        print("Warning: Options Agent did not return valid JSON.")

func _try_show_options() -> void:
    # 只有当文本演出完全结束，且已经获取到了选项数据时，才将选项渲染到UI
    if is_text_playback_finished and pending_options_data.size() > 0:
        _populate_quick_options(pending_options_data)
        pending_options_data.clear()

func _on_options_error(error_msg: String) -> void:
    print("Options Agent Failed: ", error_msg)

func _populate_quick_options(options: Array) -> void:
    for child in quick_options_container.get_children():
        child.queue_free()
        
    var regex = RegEx.new()
    regex.compile("（.*?）|\\(.*?\\)")
        
    for i in range(options.size()):
        var opt_text = options[i]
        if typeof(opt_text) == TYPE_STRING:
            var clean_text = regex.sub(opt_text, "", true).strip_edges()
            if clean_text == "":
                clean_text = opt_text # fallback if the whole text was bracketed
            var item = QUICK_OPTION_ITEM_SCENE.instantiate()
            quick_options_container.add_child(item)
            item.setup(clean_text)
            item.option_selected.connect(_on_quick_option_selected.bind(i))

func _on_quick_option_selected(text: String, index: int = -1) -> void:
    if index == 0:
        GameDataManager.profile.update_intimacy(5)
        GameDataManager.profile.update_trust(5)
    elif index == 1:
        GameDataManager.profile.update_intimacy(-5)
        GameDataManager.profile.update_trust(-5)
        
    input_field.text = text
    _on_send_pressed()

func _on_chat_error(error_msg: String) -> void:
    var char_name = GameDataManager.profile.char_name
    send_btn.disabled = false
    input_field.editable = true
    stream_live_active = false
    stream_live_done = true
    stream_live_buffer = ""
    stream_live_queue.clear()
    ToastManager.show_system_toast(error_msg, Color.RED)
    # 本地兜底
    if is_inside_tree():
        await get_tree().create_timer(1.0).timeout
    _show_message("你在哪儿？我听不到你的声音了...", char_name)

func _extract_stream_segments(force_flush: bool) -> void:
    var delim = "[SPLIT]"
    while true:
        var idx = stream_live_buffer.find(delim)
        if idx == -1:
            break
        var part = stream_live_buffer.substr(0, idx).strip_edges()
        stream_live_buffer = stream_live_buffer.substr(idx + delim.length())
        if part != "":
            stream_live_queue.append(part)
            
    if force_flush:
        var last_part = stream_live_buffer.strip_edges()
        stream_live_buffer = ""
        if last_part != "":
            var parts = _auto_split_message(last_part)
            for p in parts:
                if typeof(p) == TYPE_STRING:
                    var tp = p.strip_edges()
                    if tp != "":
                        stream_live_queue.append(tp)

func _try_start_stream_worker() -> void:
    if not stream_live_worker_running:
        stream_live_worker_running = true
        call_deferred("_run_stream_worker")

func _run_stream_worker() -> void:
    var char_name = GameDataManager.profile.char_name
    while true:
        while not is_inside_tree():
            if not stream_live_active: break
            await Engine.get_main_loop().process_frame
            
        if not stream_live_active and stream_live_queue.size() == 0:
            break
            
        if stream_live_queue.size() == 0:
            if stream_live_done:
                break
            if is_inside_tree():
                await get_tree().create_timer(0.05).timeout
            continue
            
        var line = stream_live_queue.pop_front()
        if typeof(line) != TYPE_STRING:
            continue
        var t = str(line).strip_edges()
        if t == "":
            continue
            
        if GameDataManager.config.ai_mode_enabled:
            # 异步发起分析，不阻塞当前流程的推进和打字机的显示
            _async_analyze_and_update_mood(t)
                
        await _process_single_message_line_async(t, char_name)
        
        if not stream_live_active:
            break
            
    stream_live_active = false
    stream_live_worker_running = false
    
    GameDataManager.profile.add_interaction_exp()
    GameDataManager.profile.save_profile()
    _update_ui()
    
    # 因为选项生成请求已经提前到流式接收完毕时发送，这里只需要恢复UI交互即可
    is_text_playback_finished = true
    
    if _waiting_for_chat_exit:
        _waiting_for_chat_exit = false
        if is_inside_tree():
            await get_tree().create_timer(1.5).timeout
        hide_panel()
        return
        
    _try_show_options()
    send_btn.disabled = false
    input_field.editable = true

func _auto_split_message(text: String) -> Array:
    # 如果AI主动遵守了提示词，直接使用
    if "[SPLIT]" in text:
        return text.split("[SPLIT]", false)
        
    # 系统级强制干预：根据语境智能切分
    # 提取情绪标签，防止它在切分时被破坏或抛弃
    var mood_tag = ""
    var pure_text = text
    var mood_regex = RegEx.new()
    mood_regex.compile("(?i)(?:<|\\<|《|\\[|【)\\s*(mood|心情)\\s*[:：]\\s*([^>\\>》\\]】]+)\\s*(?:>|\\>|》|\\]|】)")
    var mood_match = mood_regex.search(text)
    if mood_match:
        mood_tag = mood_match.get_string()
        pure_text = text.replace(mood_tag, "")
        
    var modified_text = pure_text
    
    # 新增策略0：优先将大模型输出的换行符视为消息分隔符
    # 很多时候AI会用换行来排版不同的动作和对话
    modified_text = modified_text.replace("\r\n", "\n")
    var nl_regex = RegEx.new()
    nl_regex.compile("\\n+")
    modified_text = nl_regex.sub(modified_text, "[SPLIT]", true)
    
    # 修复：确保连续的 [SPLIT] 被合并为一个
    modified_text = modified_text.replace("[SPLIT][SPLIT]", "[SPLIT]")
    modified_text = modified_text.replace("[SPLIT] [SPLIT]", "[SPLIT]")
    
    if not "[SPLIT]" in modified_text:
        var endings = ["。", "！", "？", "……", "”", "」", "~", "～"]
        var brackets = ["（", "("]
        
        # 策略1：根据“标点+动作括号”完美切分，这样刚好能保证切分后下一句以动作开头，带着后续的对话
        for end_char in endings:
            for bracket in brackets:
                modified_text = modified_text.replace(end_char + bracket, end_char + "[SPLIT]" + bracket)
                modified_text = modified_text.replace(end_char + " " + bracket, end_char + "[SPLIT]" + bracket)
                
        # 策略2：如果文本仍未切分且过长（>80字），强行按标点切分
        if not "[SPLIT]" in modified_text and modified_text.length() > 80:
            modified_text = modified_text.replace("。", "。[SPLIT]")
            modified_text = modified_text.replace("！", "！[SPLIT]")
            modified_text = modified_text.replace("？", "？[SPLIT]")
            # 避免把连续的标点切碎
            modified_text = modified_text.replace("[SPLIT][SPLIT]", "[SPLIT]")
        
    var parts = modified_text.split("[SPLIT]", false)
    var merged_parts = []
    var temp_str = ""
    
    for p in parts:
        var tp = p.strip_edges()
        if tp == "": continue
        
        if temp_str == "":
            temp_str = tp
        else:
            # 优化：判断当前片段(tp)或者暂存片段(temp_str)是否*仅仅*包含动作描写（没有实质对话内容）
            var tp_clean = tp
            var temp_clean = temp_str
            var action_regex = RegEx.new()
            action_regex.compile("（.*?）|\\(.*?\\)")
            tp_clean = action_regex.sub(tp_clean, "", true).strip_edges()
            temp_clean = action_regex.sub(temp_clean, "", true).strip_edges()
            
            # 如果其中一个片段仅仅只有动作描写（去掉括号后无内容），则必须合并
            if tp_clean == "" or temp_clean == "":
                temp_str += " " + tp
            else:
                merged_parts.append(temp_str)
                temp_str = tp
                
    if temp_str != "":
        merged_parts.append(temp_str)
        
    # 新增限制：如果某一条消息长度超过 60，强制进行二次切分
    var final_split_parts = []
    for part in merged_parts:
        if part.length() > 60:
            var split_part = part
            var endings = ["。", "！", "？", "……", "”", "」", "~", "～"]
            var brackets = ["（", "("]
            # 尝试在动作前切分
            for end_char in endings:
                for bracket in brackets:
                    split_part = split_part.replace(end_char + bracket, end_char + "[FORCE_SPLIT]" + bracket)
                    split_part = split_part.replace(end_char + " " + bracket, end_char + "[FORCE_SPLIT]" + bracket)
            
            # 如果依然没有切分开，强行按标点切分
            if not "[FORCE_SPLIT]" in split_part:
                split_part = split_part.replace("。", "。[FORCE_SPLIT]")
                split_part = split_part.replace("！", "！[FORCE_SPLIT]")
                split_part = split_part.replace("？", "？[FORCE_SPLIT]")
                split_part = split_part.replace("[FORCE_SPLIT][FORCE_SPLIT]", "[FORCE_SPLIT]")
                
            var sub_parts = split_part.split("[FORCE_SPLIT]", false)
            for sp in sub_parts:
                if sp.strip_edges() != "":
                    final_split_parts.append(sp.strip_edges())
        else:
            final_split_parts.append(part)
            
    merged_parts = final_split_parts
        
    # 限制最多3条
    if merged_parts.size() > 3:
        # 只保留前3条，或者把后面的内容全部合并到第3条里
        # 这里选择把多余的部分直接丢弃，强制不超过3条
        var truncated_parts = []
        truncated_parts.append(merged_parts[0])
        truncated_parts.append(merged_parts[1])
        truncated_parts.append(merged_parts[2])
        merged_parts = truncated_parts
        
    # 将心情标签加回最后一条消息末尾
    if merged_parts.size() > 0 and mood_tag != "":
        merged_parts[merged_parts.size() - 1] += mood_tag
        
    if merged_parts.size() == 0:
        return [text]
        
    return merged_parts

func _play_message_sequence(lines: Array, char_name: String) -> void:
    for line in lines:
        if GameDataManager.config.ai_mode_enabled:
            _async_analyze_and_update_mood(line)
                
        await _process_single_message_line_async(line, char_name)
        
    GameDataManager.profile.add_interaction_exp()
    GameDataManager.profile.save_profile()
    _update_ui()
    
    if is_inside_tree():
        await get_tree().create_timer(1.0).timeout
        
    is_text_playback_finished = true
    
    if _waiting_for_chat_exit:
        hide_panel()
    else:
        _try_show_options()
        send_btn.disabled = false
        input_field.editable = true

func _async_analyze_and_update_mood(line: String) -> void:
    print("正在异步分析单条消息的心情: ", line)
    var expression_id = await deepseek_client.analyze_mood_sync(line)
    print("【Debug】异步 analyze_mood_sync 返回值: '", expression_id, "'")
    if expression_id != "":
        if GameDataManager.expression_system.is_valid_expression(expression_id):
            print("异步分析结果 -> ", expression_id)
            GameDataManager.profile.update_expression(expression_id)
            print("【心情更新（不弹窗）】表情变为：" + GameDataManager.expression_system.expression_configs[expression_id]["name"])
            _update_ui()
            _update_character_sprite(expression_id)
        else:
            print("【Debug】异步心情分析返回了未知的 expression_id: '", expression_id, "'")
    else:
        print("异步心情分析未匹配或请求失败")

func _process_single_message_line_async(raw_line: String, char_name: String) -> void:
    var regex = RegEx.new()
    regex.compile("(?i)(?:<|\\<|《|\\[|【)\\s*(mood|心情)\\s*[:：]\\s*([^>\\>》\\]】]+)\\s*(?:>|\\>|》|\\]|】)")
    
    var clean_text = raw_line
    var matches = regex.search_all(raw_line)
    for m in matches:
        clean_text = clean_text.replace(m.get_string(0), "")
            
    var any_tag_regex = RegEx.new()
    any_tag_regex.compile("(?i)(?:<|\\<|《|\\[|【)[^>\\>》\\]】]*?[:：][^>\\>》\\]】]*?(?:>|\\>|》|\\]|】)")
    if any_tag_regex.is_valid():
        clean_text = any_tag_regex.sub(clean_text, "", true)
        
    clean_text = clean_text.strip_edges()
    
    # 强制清理：只保留最开头的一个动作描述，移除其余所有动作描述
    var extract_regex = RegEx.new()
    extract_regex.compile("（.*?）|\\(.*?\\)")
    var extract_matches = extract_regex.search_all(clean_text)
    if extract_matches.size() > 0:
        var first_action = extract_matches[0].get_string()
        var no_action_text = extract_regex.sub(clean_text, "", true).strip_edges()
        clean_text = first_action + " " + no_action_text
    
    var tts_text = clean_text
    
    var action_regex1 = RegEx.new()
    action_regex1.compile("\\(.*?\\)")
    tts_text = action_regex1.sub(tts_text, "", true)
    
    var action_regex2 = RegEx.new()
    action_regex2.compile("（.*?）")
    tts_text = action_regex2.sub(tts_text, "", true)
    
    var bracket_regex = RegEx.new()
    bracket_regex.compile("\\[.*?\\]|【.*?】|<.*?>|《.*?》")
    tts_text = bracket_regex.sub(tts_text, "", true)
    tts_text = tts_text.strip_edges()
    
    var display_text = clean_text
    var color_regex_zh = RegEx.new()
    color_regex_zh.compile("（(.*?)）")
    display_text = color_regex_zh.sub(display_text, "[color=green]（$1）[/color]", true)
    var color_regex_en = RegEx.new()
    color_regex_en.compile("\\((.*?)\\)")
    display_text = color_regex_en.sub(display_text, "[color=green]($1)[/color]", true)
    
    await _show_message_async(display_text, char_name, false, tts_text)

func _show_message(text: String, speaker_name: String = "", is_restore: bool = false, tts_text: String = "") -> void:
    _show_message_async(text, speaker_name, is_restore, tts_text)

func _show_message_async(text: String, speaker_name: String = "", is_restore: bool = false, tts_text: String = "") -> void:
    if speaker_name == "":
        speaker_name = GameDataManager.profile.char_name
        
    if speaker_name != "":
        name_label.text = speaker_name
        
    # 根据当前心情更新立绘
    if speaker_name == GameDataManager.profile.char_name:
        var current_expression = GameDataManager.profile.current_expression
        _update_character_sprite(current_expression)
        
    # 开启 BBCode 渲染
    dialogue_text.bbcode_enabled = true
    dialogue_text.text = text
    dialogue_text.visible_ratio = 0.0
    
    # 简单的打字机效果
    if _typewriter_tween:
        _typewriter_tween.kill()
    _typewriter_tween = create_tween()
    var duration = max(0.5, text.length() * 0.05) # 每个字符 0.05 秒，至少0.5秒
    _typewriter_tween.tween_property(dialogue_text, "visible_ratio", 1.0, duration)
    # We will handle visible_characters = -1 after tween finishes or gets killed
    
    var cache_key = ""
    var is_tts_started = false
    
    # 触发TTS语音合成 (仅对 角色 发声)，如果是恢复记录则不发声
    # 在固定剧情模式下，判断 speaker_name 是不是玩家或旁白，都不是的话说明是配音角色，也可以发声
    var is_player_or_narrator = (speaker_name == "我" or speaker_name == "旁白" or speaker_name == " ")
    
    # 如果是固定剧情（_intro_playing），即使 is_restore 为 true，也允许发声
    if GameDataManager.config.voice_enabled and (not is_restore or _intro_playing) and not is_player_or_narrator:
        # 如果提供了专属的 tts_text (过滤了动作描写的纯净文本)，就用它来发声
        var text_to_speak = tts_text if tts_text != "" else text
        
        var regex = RegEx.new()
        regex.compile("[a-zA-Z0-9\u4e00-\u9fa5]")
        if regex.search(text_to_speak) != null:
            is_tts_started = true
            
            # 如果是固定剧情的配音，优先尝试用 speaker_name 作为角色 ID 查找音色
            # 否则使用当前全局角色的音色
            var char_id = GameDataManager.config.current_character_id
            if _intro_playing and speaker_name != GameDataManager.profile.char_name:
                char_id = speaker_name.to_lower()
                
            var options = {}
            if GameDataManager.config.character_voice_types.has(char_id):
                options["voice_type"] = GameDataManager.config.character_voice_types[char_id]
                
            cache_key = (text_to_speak + str(options)).md5_text()
            TTSManager.synthesize(text_to_speak, options)
        
    # 保存记录到历史管理器 (只有在非恢复模式时保存)
    if not is_restore:
        GameDataManager.history.add_message(speaker_name, text, cache_key, "story_chat")
    elif _intro_playing and text != "":
        # 因为 _intro_playing 调用时是 is_restore=true 专门为了避开 normal 的保存
        GameDataManager.history.add_message(speaker_name, text, cache_key, "fixed_story")

    # 等待打字机效果完成
    if is_inside_tree():
        while _typewriter_tween and _typewriter_tween.is_valid() and _typewriter_tween.is_running():
            await get_tree().process_frame
            
    if not is_inside_tree():
        return
        
    # If we killed the tween, make sure the text is fully shown
    dialogue_text.visible_ratio = 1.0
    dialogue_text.visible_characters = -1
    
    # For regular AI chat, disable click to skip and auto-play
    if not _intro_playing:
        _waiting_for_chat_click = false
    else:
        _intro_waiting_for_click = true
    
    # Wait for TTS if playing
    if is_tts_started and is_inside_tree():
        var wait_count = 0
        while not audio_player.playing and wait_count < 10:
            if _intro_playing and not _intro_waiting_for_click:
                break
            await get_tree().create_timer(0.05).timeout
            wait_count += 1
            
        wait_count = 0
        while audio_player.playing and is_inside_tree() and wait_count < 1200:
            if _intro_playing and not _intro_waiting_for_click:
                audio_player.stop()
                break
            await get_tree().create_timer(0.05).timeout
            wait_count += 1
            
    if _intro_playing:
        if is_inside_tree() and _intro_waiting_for_click:
            await _intro_click_proceed
    else:
        if is_inside_tree():
            await get_tree().create_timer(1.0).timeout

func _on_tts_success(audio_stream: AudioStream, text: String) -> void:
    if audio_player:
        audio_player.stream = audio_stream
        audio_player.play()

func _on_tts_failed(error_msg: String, text: String) -> void:
    print("TTS 失败: ", error_msg)
