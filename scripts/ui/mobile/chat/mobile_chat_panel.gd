extends Control

signal back_requested
signal incoming_call_ended

@onready var back_btn: Button = $Panel/VBox/TopBar/BackBtn
@onready var title_label: Label = $Panel/VBox/TopBar/Title
@onready var voice_call_btn: TextureButton = $Panel/VBox/BottomArea/ActionRow/VoiceCallBtn/Btn
@onready var video_call_btn: TextureRect = $Panel/VBox/BottomArea/ActionRow/VideoBtn/Icon
@onready var image_btn: TextureButton = $Panel/VBox/BottomArea/ActionRow/ImageBtn/Btn
@onready var red_packet_btn: TextureButton = $Panel/VBox/BottomArea/ActionRow/RedPacketBtn/Btn
@onready var message_list: VBoxContainer = $Panel/VBox/ScrollContainer/Margin/MessageList
@onready var input_edit: LineEdit = $Panel/VBox/BottomArea/InputRow/InputEdit
@onready var send_btn: Button = $Panel/VBox/BottomArea/InputRow/SendBtn
@onready var scroll_container: ScrollContainer = $Panel/VBox/ScrollContainer
@onready var deepseek_client = $DeepSeekClient

@onready var image_overlay: Control = $ImageOverlay
@onready var full_image: TextureRect = $ImageOverlay/FullImage
@onready var close_viewer_btn: Button = $ImageOverlay/CloseViewerBtn
@onready var save_to_album_btn: Button = $ImageOverlay/SaveToAlbumBtn

@onready var red_packet_overlay: Control = $RedPacketOverlay
@onready var rp_close_btn: Button = $RedPacketOverlay/VBox/TopBar/CloseBtn
@onready var rp_amount_input: LineEdit = $RedPacketOverlay/VBox/Margin/FormVBox/AmountPanel/HBox/AmountInput
@onready var rp_text_input: LineEdit = $RedPacketOverlay/VBox/Margin/FormVBox/TextPanel/TextInput
@onready var rp_display_amount: Label = $RedPacketOverlay/VBox/Margin/FormVBox/DisplayAmount
@onready var rp_send_btn: Button = $RedPacketOverlay/VBox/Margin/FormVBox/SendRPBtn

var doubao_tts = null
var audio_player: AudioStreamPlayer = null

var current_char_id: String = ""
var char_profile: CharacterProfile = null
var chat_history: Array = []
var current_call_history: Array = [] # 专门用于通话上下文的独立历史记录
var voice_call_panel_instance = null
var is_voice_call_mode: bool = false
var video_call_panel_instance = null
var _current_call_is_incoming: bool = false
var _current_viewing_image_path: String = ""

func _ready() -> void:
	back_btn.pressed.connect(_on_back_pressed)
	send_btn.pressed.connect(_on_send_pressed)
	input_edit.text_submitted.connect(_on_input_submitted)
	voice_call_btn.pressed.connect(_on_voice_call_pressed)
	image_btn.pressed.connect(_on_image_btn_pressed)
	red_packet_btn.pressed.connect(_on_red_packet_pressed)
	
	close_viewer_btn.pressed.connect(_on_close_viewer_pressed)
	save_to_album_btn.pressed.connect(_on_save_to_album_pressed)
	
	rp_close_btn.pressed.connect(_on_rp_close_pressed)
	rp_amount_input.text_changed.connect(_on_rp_amount_changed)
	rp_send_btn.pressed.connect(_on_rp_send_pressed)
	
	video_call_btn.mouse_filter = Control.MOUSE_FILTER_PASS
	video_call_btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_video_call_pressed()
	)
	
	if deepseek_client:
		deepseek_client.chat_request_completed.connect(_on_ai_response)
		deepseek_client.chat_request_failed.connect(_on_ai_error)
		
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	var tts_script = load("res://scripts/api/doubao_TTS_Service.gd")
	if tts_script:
		doubao_tts = tts_script.new()
		add_child(doubao_tts)
		
		# Load API keys from config
		if GameDataManager.config:
			doubao_tts.setup_auth(
				GameDataManager.config.doubao_app_id,
				GameDataManager.config.doubao_token,
				GameDataManager.config.doubao_cluster
			)
			
		doubao_tts.tts_success.connect(_on_tts_success)
		doubao_tts.tts_failed.connect(_on_tts_failed)
		
func _on_tts_success(stream: AudioStream, _text: String) -> void:
	if audio_player:
		audio_player.stream = stream
		audio_player.play()

func _on_tts_failed(err_msg: String, _text: String) -> void:
	print("Mobile Chat TTS Failed: ", err_msg)

func setup(char_id: String) -> void:
	current_char_id = char_id
	
	# Load profile
	char_profile = CharacterProfile.new()
	char_profile.load_profile(char_id)
	
	title_label.text = char_profile.char_name
	
	# Load history
	_load_mobile_history()
	_render_history()

func _on_back_pressed() -> void:
	back_requested.emit()

func _on_red_packet_pressed() -> void:
	red_packet_overlay.show()
	rp_amount_input.text = ""
	rp_text_input.text = ""
	rp_display_amount.text = "¥ 0.00"

func _on_rp_close_pressed() -> void:
	red_packet_overlay.hide()

func _on_rp_amount_changed(new_text: String) -> void:
	var amount = new_text.to_int()
	rp_display_amount.text = "¥ " + str(amount) + ".00"

func _on_rp_send_pressed() -> void:
	var amount = rp_amount_input.text.to_int()
	if amount <= 0:
		return
	if GameDataManager.profile.gold < amount:
		# 钱不够
		return
	
	GameDataManager.profile.gold -= amount
	GameDataManager.profile.save_profile()
	
	var top_panel = get_tree().get_root().find_child("TopStatusPanel", true, false)
	if top_panel and top_panel.has_method("_update_ui"):
		top_panel._update_ui()
	
	red_packet_overlay.hide()
	
	var text = rp_text_input.text
	if text == "":
		text = "恭喜发财，大吉大利"
		
	# 发送红包消息
	var msg_data = {
		"role": "user",
		"type": "red_packet",
		"content": text,
		"amount": amount,
		"status": "unclaimed" # unclaimed, claimed, expired
	}
	_add_message_to_ui(msg_data)
	chat_history.append(msg_data)
	_save_mobile_history()
	
	# 模拟AI领取红包
	await get_tree().create_timer(1.5).timeout
	if msg_data["status"] == "unclaimed":
		msg_data["status"] = "claimed"
		var sys_msg = {
			"role": "system",
			"type": "system",
			"content": current_char_id.capitalize() + "领取了你的红包"
		}
		chat_history.append(sys_msg)
		_save_mobile_history()
		_load_mobile_history()
		_render_history()
		
		# 发起AI回复请求，由于上一步修改了chat_history，这里把刚发的红包和系统消息作为上下文带进去
		var sys_prompt_text = "【系统提示：玩家给你发了一个%dG的红包: %s，并且你已经自动领取了。请你根据当前好感度、心情和你们的聊天语境，给玩家发送一段感谢或反应消息。如果好感度低可能表现得傲娇或惊讶。】" % [amount, text]
		var fake_msg = {"role": "system", "content": sys_prompt_text}
		chat_history.append(fake_msg)
		
		var messages = [{"role": "system", "content": GameDataManager.prompt_manager.build_system_prompt(char_profile, "mobile_chat", "", [])}]
		var recent = chat_history.slice(-10)
		for msg in recent:
			var msg_speaker = msg.get("speaker", msg.get("role", ""))
			var msg_text = msg.get("text", msg.get("content", ""))
			var role = "user" if msg_speaker == "player" or msg_speaker == "user" or msg_speaker == "system" else "assistant"
			var msg_content = str(msg_text)
			
			if msg.get("type", "") == "system":
				msg_content = "【系统提示：%s】" % msg_content
			elif msg.get("type", "") == "red_packet":
				msg_content = "【系统提示：[%s发了一个红包: %s]】" % [
					"玩家" if msg_speaker == "player" or msg_speaker == "user" else "你", 
					msg_content
				]
			elif msg_content.begins_with("[img]") and msg_content.ends_with("[/img]"):
				msg_content = "【系统提示：[%s发送了一张照片]】" % ("玩家" if msg_speaker == "player" or msg_speaker == "user" else "你")
				
			messages.append({"role": role, "content": msg_content})
			
		chat_history.erase(fake_msg) # 移出伪造的系统提示
		
		input_edit.editable = false
		send_btn.disabled = true
		deepseek_client.call_chat_api_non_stream(messages)

func _on_image_btn_pressed() -> void:
	print("Image button pressed!")
	var mobile_interface = get_parent().get_parent() # Assuming it's inside PhonePanel
	print("mobile_interface: ", mobile_interface, ", has method: ", mobile_interface.has_method("_on_album_app_pressed") if mobile_interface else "null")
	if mobile_interface and mobile_interface.has_method("_on_album_app_pressed"):
		mobile_interface._on_album_app_pressed()
		
		# Set picker mode for album
		if mobile_interface.album_panel_instance:
			mobile_interface.album_panel_instance.set_picker_mode(true)
			# We need to connect once
			if not mobile_interface.album_panel_instance.is_connected("photo_picked", _on_photo_picked):
				mobile_interface.album_panel_instance.photo_picked.connect(_on_photo_picked)

func _on_photo_picked(path: String) -> void:
	var msg_text = "[img]%s[/img]" % path
	_send_player_message(msg_text)
	
	# After picking, we should return to chat
	var mobile_interface = get_parent().get_parent()
	if mobile_interface and mobile_interface.album_panel_instance:
		mobile_interface.album_panel_instance.hide_panel()
		mobile_interface.album_panel_instance.set_picker_mode(false)

func _on_voice_call_pressed() -> void:
	start_voice_call(false)

func start_voice_call(is_incoming: bool, is_fixed: bool = false) -> void:
	current_call_history.clear()
	_current_call_is_incoming = is_incoming
	if voice_call_panel_instance == null:
		var VoiceCallObj = load("res://scenes/ui/mobile/chat/voice_call_panel.tscn")
		voice_call_panel_instance = VoiceCallObj.instantiate()
		add_child(voice_call_panel_instance)
		voice_call_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		voice_call_panel_instance.call_ended.connect(_on_voice_call_ended)
		voice_call_panel_instance.message_sent.connect(_on_voice_call_message_sent)
		
	voice_call_panel_instance.setup(current_char_id, char_profile, is_incoming, is_fixed)
	voice_call_panel_instance.show()
	is_voice_call_mode = true
	
	if not is_fixed:
		_request_proactive_call_message(is_incoming, false)

func _on_voice_call_ended() -> void:
	if not _current_call_is_incoming:
		if voice_call_panel_instance:
			voice_call_panel_instance.hide()
			
	is_voice_call_mode = false
	
	if deepseek_client and deepseek_client.chat_http:
		deepseek_client.chat_http.cancel_request()
		
	input_edit.editable = true
	send_btn.disabled = false
		
	# 把当前通话历史同步到全局聊天记录（作为 fixed_call 或 normal_call，此处假设我们统称为 fixed_call 或者根据 is_fixed 判断）
	# 因为这里 mobile_chat_panel 自身并不知道 is_fixed 状态，我们可以统一保存为普通对话，或者把 is_fixed 存起来。
	# 为简单起见，既然需求提到固定剧情音视频通话，我们就直接追加到 GameDataManager.history 中：
	var is_fixed = voice_call_panel_instance.is_fixed_mode if voice_call_panel_instance else false
	var type_str = "fixed_call" if is_fixed else "normal"
	for msg in current_call_history:
		var msg_speaker = msg.get("speaker", msg.get("role", ""))
		var msg_text = msg.get("text", msg.get("content", ""))
		var s_name = "我" if msg_speaker == "player" or msg_speaker == "user" else current_char_id.capitalize()
		GameDataManager.history.add_message(s_name, "【语音通话】" + msg_text, "", type_str)
		
	if _current_call_is_incoming:
		incoming_call_ended.emit()

func _on_video_call_pressed() -> void:
	start_video_call(false)

func start_video_call(is_incoming: bool, is_fixed: bool = false) -> void:
	current_call_history.clear()
	_current_call_is_incoming = is_incoming
	if video_call_panel_instance == null:
		var VideoCallObj = load("res://scenes/ui/mobile/chat/video_call_panel.tscn")
		video_call_panel_instance = VideoCallObj.instantiate()
		add_child(video_call_panel_instance)
		video_call_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		video_call_panel_instance.call_ended.connect(_on_video_call_ended)
		video_call_panel_instance.message_sent.connect(_on_voice_call_message_sent)
		
	video_call_panel_instance.setup(current_char_id, char_profile, is_incoming, is_fixed)
	
	# 可以根据场景设置不同的背景
	# video_call_panel_instance.set_background("res://assets/images/backgrounds/room_night.png")
	
	video_call_panel_instance.show()
	is_voice_call_mode = true
	
	if not is_fixed:
		_request_proactive_call_message(is_incoming, true)

func _on_video_call_ended() -> void:
	if not _current_call_is_incoming:
		if video_call_panel_instance:
			video_call_panel_instance.hide()
			
	is_voice_call_mode = false
	
	if deepseek_client and deepseek_client.chat_http:
		deepseek_client.chat_http.cancel_request()
		
	input_edit.editable = true
	send_btn.disabled = false
		
	var is_fixed = video_call_panel_instance.is_fixed_mode if video_call_panel_instance else false
	var type_str = "fixed_call" if is_fixed else "normal"
	for msg in current_call_history:
		var msg_speaker = msg.get("speaker", msg.get("role", ""))
		var msg_text = msg.get("text", msg.get("content", ""))
		var s_name = "我" if msg_speaker == "player" or msg_speaker == "user" else current_char_id.capitalize()
		GameDataManager.history.add_message(s_name, "【视频通话】" + msg_text, "", type_str)
		
	if _current_call_is_incoming:
		incoming_call_ended.emit()

func _on_voice_call_message_sent(text: String) -> void:
	current_call_history.append({"speaker": "player", "text": text})
	
	# Disable input while waiting
	input_edit.editable = false
	send_btn.disabled = true
	
	if voice_call_panel_instance and voice_call_panel_instance.visible:
		voice_call_panel_instance.set_loading_state()
	elif video_call_panel_instance and video_call_panel_instance.visible:
		video_call_panel_instance.set_loading_state()
		
	_request_ai_call_response(text)

func _on_send_pressed() -> void:
	var text = input_edit.text.strip_edges()
	if text == "": return
	
	input_edit.text = ""
	_send_player_message(text)

func _on_input_submitted(text: String) -> void:
	_on_send_pressed()

func _send_player_message(text: String) -> void:
	_add_message_bubble("player", text)
	_save_message_to_history("player", text)
	
	# Disable input while waiting
	input_edit.editable = false
	send_btn.disabled = true
	
	_request_ai_response(text)

func _request_proactive_call_message(is_incoming: bool, is_video: bool) -> void:
	if not deepseek_client: return
	
	var call_type_str = "视频通话" if is_video else "语音通话"
	var scenario = ""
	if is_incoming:
		scenario = "【系统提示：你刚刚主动给玩家打了一个%s，玩家刚刚接通了。请你先开口说第一句话，不要发表情或动作，直接用自然口吻开始聊天。结合你当前的性格、阶段和心情来回应。】" % call_type_str
	else:
		scenario = "【系统提示：玩家刚刚给你打了一个%s，你接通了。请你先开口说第一句话，不要发表情或动作，直接用自然口吻回应。结合你当前的性格、阶段和心情来回应。】" % call_type_str
		
	# 不保存这段 prompt 到历史记录，只是作为一次性的 system/user 引导
	var system_prompt = GameDataManager.prompt_manager.build_system_prompt(char_profile, "mobile_chat", "", [])
	
	var messages = [{"role": "system", "content": system_prompt}]
	
	messages.append({"role": "user", "content": scenario})
	
	# 禁用按钮
	input_edit.editable = false
	send_btn.disabled = true
	if voice_call_panel_instance and voice_call_panel_instance.visible:
		voice_call_panel_instance.set_loading_state()
	elif video_call_panel_instance and video_call_panel_instance.visible:
		video_call_panel_instance.set_loading_state()
		
	deepseek_client.call_chat_api_non_stream(messages)

func _request_ai_call_response(player_text: String) -> void:
	if not deepseek_client: return
	
	var system_prompt = GameDataManager.prompt_manager.build_system_prompt(char_profile, "mobile_chat", player_text, [])
	
	var messages = [{"role": "system", "content": system_prompt}]
	
	# Add recent call history (last 10 messages)
	var recent = current_call_history.slice(-10)
	for msg in recent:
		var msg_speaker = msg.get("speaker", msg.get("role", ""))
		var msg_text = msg.get("text", msg.get("content", ""))
		var role = "user" if msg_speaker == "player" or msg_speaker == "user" else "assistant"
		messages.append({"role": role, "content": msg_text})
		
	deepseek_client.call_chat_api_non_stream(messages)

func _request_ai_response(player_text: String) -> void:
	if not deepseek_client: return
	
	var processed_text = player_text
	if player_text.begins_with("[img]") and player_text.ends_with("[/img]"):
		processed_text = "【系统动作：玩家向你发送了一张刚刚拍摄的照片。】"
		
	var system_prompt = GameDataManager.prompt_manager.build_system_prompt(char_profile, "mobile_chat", processed_text, [])
	
	var messages = [{"role": "system", "content": system_prompt}]
	
	# Add recent history (last 10 messages)
	var recent = chat_history.slice(-10)
	for msg in recent:
		var msg_speaker = msg.get("speaker", msg.get("role", ""))
		var msg_text = msg.get("text", msg.get("content", ""))
		var role = "user" if msg_speaker == "player" or msg_speaker == "user" or msg_speaker == "system" else "assistant"
		var msg_content = str(msg_text)
		
		if msg.get("type", "") == "system":
			msg_content = "【系统提示：%s】" % msg_content
		elif msg.get("type", "") == "red_packet":
			msg_content = "【系统提示：[%s发了一个红包: %s]】" % [
				"玩家" if msg_speaker == "player" or msg_speaker == "user" else "你", 
				msg_content
			]
		elif msg_content.begins_with("[img]") and msg_content.ends_with("[/img]"):
			msg_content = "【系统提示：[%s发送了一张照片]】" % ("玩家" if msg_speaker == "player" or msg_speaker == "user" else "你")
			
		messages.append({"role": role, "content": msg_content})
		
	deepseek_client.call_chat_api_non_stream(messages)

func _on_ai_response(response: Dictionary) -> void:
	input_edit.editable = true
	send_btn.disabled = false
	
	if response.has("choices") and response["choices"].size() > 0:
		var content = response["choices"][0].get("message", {}).get("content", "")
		
		# 强制过滤所有的括号及其内部内容，确保只剩下纯文本
		var regex = RegEx.new()
		# 匹配各种中英文括号及其内部的任意字符（包括动作、神态等）
		regex.compile("(\\(.*?\\)|\\（.*?\\）|\\[.*?\\]|\\【.*?\\】|\\<.*?\\>|\\《.*?\\》|\\{.*?\\}|\\*.*?\\*)")
		var clean_content = regex.sub(content, "", true).strip_edges()
		
		# 如果全被过滤掉了，说明AI只发了括号动作（虽然概率极低），我们给个默认值
		if clean_content == "":
			clean_content = "..."
			
		# Split by [SPLIT] if any (注意，如果AI依然输出了 [SPLIT]，上面的正则可能会把它当成括号过滤掉。所以我们需要先把 [SPLIT] 替换成安全字符，过滤完再替换回来，或者修改正则不要过滤大写的SPLIT)
		# 更好的做法是，先按照 [SPLIT] 拆分，然后对每部分分别过滤
		
		var parts = content.split("[SPLIT]")
		
		if is_voice_call_mode:
			if voice_call_panel_instance and voice_call_panel_instance.visible:
				# 此时把原始内容传给通话面板，那边可能也会过滤，或者我们在这里先过滤
				# 这里我们统一先过滤
				for i in range(parts.size()):
					parts[i] = regex.sub(parts[i], "", true).strip_edges()
					if parts[i] == "": parts[i] = "..."
				
				voice_call_panel_instance.add_character_message("[SPLIT]".join(parts))
			elif video_call_panel_instance and video_call_panel_instance.visible:
				for i in range(parts.size()):
					parts[i] = regex.sub(parts[i], "", true).strip_edges()
					if parts[i] == "": parts[i] = "..."
					
				video_call_panel_instance.add_character_message("[SPLIT]".join(parts))
			
			# 将其记录在通话历史中，而不是聊天历史
			for part in parts:
				if part != "":
					current_call_history.append({"speaker": "char", "text": part})
		else:
			for part in parts:
				var clean_part = regex.sub(part, "", true).strip_edges()
				if clean_part != "":
					# 随机触发角色发红包 (例如文本包含特定词汇)
					if clean_part.find("红包") != -1 and clean_part.find("给") != -1 and randf() < 0.6:
						var rp_amount = randi_range(50, 200)
						var rp_msg = {
							"role": "char",
							"type": "red_packet",
							"content": "给你的红包！",
							"amount": rp_amount,
							"status": "unclaimed"
						}
						_add_message_to_ui(rp_msg)
						chat_history.append(rp_msg)
						_save_mobile_history()
						
					# 20% chance to be a voice message
					var is_voice = randf() < 0.2
					var duration = max(1, int(clean_part.length() / 4.0)) if is_voice else 0
					
					_add_message_bubble("char", clean_part, is_voice, duration)
					_save_message_to_history("char", clean_part, is_voice, duration)
					
			# Scroll to bottom
			await get_tree().create_timer(0.1).timeout
			scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value
	else:
		var sys_msg = {
			"role": "system",
			"type": "system",
			"content": "消息发送失败..."
		}
		_add_message_to_ui(sys_msg)
		chat_history.append(sys_msg)
		_save_mobile_history()

func _on_ai_error(err_msg: String) -> void:
	input_edit.editable = true
	send_btn.disabled = false
	
	if is_voice_call_mode:
		if voice_call_panel_instance and voice_call_panel_instance.visible:
			voice_call_panel_instance.status_label.text = "网络错误: " + err_msg
			voice_call_panel_instance.record_btn.disabled = false
		elif video_call_panel_instance and video_call_panel_instance.visible:
			video_call_panel_instance.status_label.text = "网络错误: " + err_msg
			video_call_panel_instance.record_btn.disabled = false
	else:
		var sys_msg = {
			"role": "system",
			"type": "system",
			"content": "网络错误: " + err_msg
		}
		_add_message_to_ui(sys_msg)
		chat_history.append(sys_msg)
		_save_mobile_history()

func _add_message_to_ui(msg: Dictionary) -> void:
	_add_message_bubble(msg.get("role", msg.get("speaker", "")), msg.get("content", msg.get("text", "")), msg.get("is_voice", false), msg.get("duration", 0), msg)

func _add_message_bubble(speaker: String, text: String, is_voice: bool = false, duration: int = 0, msg: Dictionary = {}) -> void:
	if speaker == "user":
		speaker = "player"
	elif speaker == "assistant":
		speaker = "char"
		
	var final_msg = msg.duplicate()
	if not final_msg.has("text") and not final_msg.has("content"):
		final_msg["text"] = text
	if not final_msg.has("is_voice"):
		final_msg["is_voice"] = is_voice
	if not final_msg.has("duration"):
		final_msg["duration"] = duration
		
	var msg_type = final_msg.get("type", "text")
	
	if speaker == "system" or msg_type == "system":
		var system_bubble = load("res://scenes/ui/mobile/chat/bubbles/system_bubble.tscn").instantiate()
		message_list.add_child(system_bubble)
		system_bubble.setup(final_msg)
	elif speaker == "player":
		var player_bubble = load("res://scenes/ui/mobile/chat/bubbles/player_bubble.tscn").instantiate()
		message_list.add_child(player_bubble)
		player_bubble.setup(final_msg)
	else:
		var char_bubble = load("res://scenes/ui/mobile/chat/bubbles/character_bubble.tscn").instantiate()
		message_list.add_child(char_bubble)
		var c_profile_dict = {}
		if char_profile:
			c_profile_dict["avatar_path"] = char_profile.avatar
		char_bubble.setup(final_msg, c_profile_dict)
		
	# Scroll down
	await get_tree().process_frame
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

func _on_red_packet_message_clicked(msg: Dictionary) -> void:
	var speaker = msg.get("role", msg.get("speaker", ""))
	var is_sender = (speaker == "player" or speaker == "user")
	var status = msg.get("status", "unclaimed")
	
	var p_avatar = null
	if GameDataManager.profile and GameDataManager.profile.avatar and ResourceLoader.exists(GameDataManager.profile.avatar):
		p_avatar = load(GameDataManager.profile.avatar)
		
	var c_avatar = null
	if char_profile and char_profile.avatar and ResourceLoader.exists(char_profile.avatar):
		c_avatar = load(char_profile.avatar)
	
	var rp_scene = load("res://scenes/ui/mobile/chat/red_packet_interact.tscn")
	var rp_ui = rp_scene.instantiate()
	rp_ui.setup(msg, is_sender, current_char_id, c_avatar, p_avatar)
	add_child(rp_ui)
	rp_ui.opened.connect(func():
		if is_sender or status == "claimed":
			return
			
		msg["status"] = "claimed"
		
		# Find the original message in chat_history and update it
		for i in range(chat_history.size() - 1, -1, -1):
			var h_msg = chat_history[i]
			if h_msg.get("type") == "red_packet" and h_msg.get("content", h_msg.get("text", "")) == msg.get("content", msg.get("text", "")) and h_msg.get("amount", 0) == msg.get("amount", 0):
				if h_msg.get("status", "unclaimed") == "unclaimed":
					h_msg["status"] = "claimed"
					break
		
		var amount = msg.get("amount", 0)
		if amount > 0:
			GameDataManager.profile.gold += amount
			GameDataManager.profile.save_profile()
			
			var top_panel = get_tree().get_root().find_child("TopStatusPanel", true, false)
			if top_panel and top_panel.has_method("_update_ui"):
				top_panel._update_ui()
		
		# 添加系统消息
		var sys_msg = {
			"role": "system",
			"type": "system",
			"content": "你领取了" + current_char_id.capitalize() + "的红包"
		}
		chat_history.append(sys_msg)
		
		_save_mobile_history()
		_load_mobile_history()
		_render_history()
	)

func _play_voice_message(text: String) -> void:
	if not doubao_tts:
		return
		
	if GameDataManager.config.voice_enabled:
		var v_type = "ICL_zh_female_bingruoshaonv_tob"
		if GameDataManager.config.character_voice_types.has(current_char_id):
			v_type = GameDataManager.config.character_voice_types[current_char_id]
			
		doubao_tts.synthesize(text, {"voice_type": v_type})

func _load_mobile_history() -> void:
	chat_history.clear()
	for child in message_list.get_children():
		child.queue_free()
		
	var path = "user://saves/%s/mobile_chat_history.json" % current_char_id
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var content = file.get_as_text()
		var json = JSON.new()
		if json.parse(content) == OK and json.data is Array:
			chat_history = json.data

func _render_history() -> void:
	for msg in chat_history:
		var is_voice = msg.get("is_voice", false)
		var duration = int(msg.get("duration", 0))
		var msg_speaker = msg.get("speaker", msg.get("role", ""))
		var msg_text = msg.get("text", msg.get("content", ""))
		
		if msg.get("type", "") == "system":
			_add_message_to_ui(msg)
		elif msg.get("type", "") == "red_packet":
			_add_message_to_ui(msg)
		else:
			_add_message_bubble(msg_speaker, msg_text, is_voice, duration, msg)

func _show_image_fullscreen(tex: Texture2D, path: String, is_char: bool) -> void:
	print("Showing image fullscreen: ", path)
	_current_viewing_image_path = path
	full_image.texture = tex
	image_overlay.show()
	image_overlay.move_to_front() # Ensure it's on top of everything in MobileChatPanel
	
	if is_char:
		save_to_album_btn.show()
	else:
		save_to_album_btn.hide()
		
	image_overlay.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(image_overlay, "modulate:a", 1.0, 0.2)

func _on_close_viewer_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(image_overlay, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		image_overlay.hide()
		full_image.texture = null
		_current_viewing_image_path = ""
	)

func _on_save_to_album_pressed() -> void:
	if _current_viewing_image_path != "":
		var save_dir = "user://saves/photos"
		if not DirAccess.dir_exists_absolute(save_dir):
			DirAccess.make_dir_recursive_absolute(save_dir)
			
		var filename = "char_img_" + str(Time.get_unix_time_from_system()) + ".png"
		var new_path = save_dir + "/" + filename
		
		var img = Image.load_from_file(_current_viewing_image_path)
		if img:
			img.save_png(new_path)
			
		# 可以弹个提示或者简单关闭
		_on_close_viewer_pressed()

func _save_mobile_history() -> void:
	var dir_path = "user://saves/%s" % current_char_id
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
		
	var path = "%s/mobile_chat_history.json" % dir_path
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(chat_history, "\t"))

func _mark_message_read(text: String) -> void:
	var has_changed = false
	for msg in chat_history:
		var msg_text = msg.get("text", msg.get("content", ""))
		if msg_text == text and not msg.get("is_read", false):
			msg["is_read"] = true
			has_changed = true
			
	if has_changed:
		_save_mobile_history()

func _save_message_to_history(speaker: String, text: String, is_voice: bool = false, duration: int = 0) -> void:
	var new_msg = {
		"speaker": speaker,
		"text": text,
		"time": Time.get_datetime_string_from_system(),
		"is_voice": is_voice,
		"duration": duration,
		"is_read": false
	}
	chat_history.append(new_msg)
	_save_mobile_history()

func show_panel() -> void:
	show()
	position.x = size.x
	modulate.a = 0.0
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	
	# Scroll to bottom when shown
	await get_tree().create_timer(0.1).timeout
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

func hide_panel(immediate: bool = false) -> void:
	if immediate:
		modulate.a = 0.0
		position.x = size.x
		hide()
		return
		
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:x", size.x, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(self.hide)
