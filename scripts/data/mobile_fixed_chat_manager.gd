extends Node

signal unread_count_changed(chat_id: String, unread_count: int)
signal message_unlocked(chat_id: String, message_index: int)
signal character_typing_state_changed(char_id: String, is_typing: bool)

const SCRIPT_DIR = "res://assets/data/mobile/fixed_chats/"
const DEFAULT_ADDED_CONTACT_IDS: Array[String] = ["luna", "jing", "ya", "luna_father"]

# 存储聊天脚本数据
# { "script_id": { "id": "...", "character_id": "...", "messages": [...] } }
var _chat_scripts: Dictionary = {}

# 存储聊天状态
# { "script_id": { "current_step": int, "is_active": bool, "is_completed": bool } }
var _chat_states: Dictionary = {}

# 按 character_id 统计未读
# { "character_id": int }
var _unread_counts: Dictionary = {}
var _added_contacts: Array = []

func _ready() -> void:
	_ensure_save_dir()
	_load_all_scripts()
	_load_states()

func _get_state_path() -> String:
	return GameDataManager.get_archive_state_path("mobile_fixed_chat_state.json")

func _get_mobile_history_path(char_id: String) -> String:
	return GameDataManager.get_character_save_path("mobile_chat_history.json", char_id)

func _ensure_save_dir() -> void:
	var path = _get_state_path()
	var dir_path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

func _load_all_scripts() -> void:
	var dir = DirAccess.open(SCRIPT_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				_load_script(SCRIPT_DIR + file_name)
			file_name = dir.get_next()

func _load_script(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(content)
		if error == OK:
			var data = json.data
			if typeof(data) == TYPE_DICTIONARY and data.has("id"):
				_chat_scripts[data["id"]] = data
		file.close()

func _load_states() -> void:
	var save_path = _get_state_path()
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		var content = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(content)
		if error == OK:
			var data = json.data
			if typeof(data) == TYPE_DICTIONARY:
				_chat_states = data.get("states", {})
				_unread_counts = data.get("unreads", {})
				_added_contacts = data.get("added_contacts", [])
		file.close()
	_ensure_default_added_contacts()
	
	# 初始化缺失的状态
	var state_changed = false
	for script_id in _chat_scripts.keys():
		if not _chat_states.has(script_id):
			_chat_states[script_id] = {
				"current_step": 0,
				"is_active": false,
				"is_completed": false
			}
			state_changed = true
	
	if state_changed:
		_save_states()

func _save_states() -> void:
	var file = FileAccess.open(_get_state_path(), FileAccess.WRITE)
	if file:
		var data = {
			"states": _chat_states,
			"unreads": _unread_counts,
			"added_contacts": _added_contacts
		}
		var json_string = JSON.stringify(data, "\t")
		file.store_string(json_string)
		file.close()

func _ensure_default_added_contacts() -> void:
	var normalized: Array = []
	for raw_id in _added_contacts:
		var contact_id = str(raw_id).strip_edges().to_lower()
		if contact_id != "" and not normalized.has(contact_id):
			normalized.append(contact_id)
	for contact_id in DEFAULT_ADDED_CONTACT_IDS:
		if not normalized.has(contact_id):
			normalized.append(contact_id)
	_added_contacts = normalized

func get_added_contact_ids() -> Array:
	return _added_contacts.duplicate()

func is_contact_added(char_id: String) -> bool:
	var normalized_id = str(char_id).strip_edges().to_lower()
	if normalized_id == "":
		return false
	return _added_contacts.has(normalized_id)

func add_contact(char_id: String, save_now: bool = true) -> bool:
	var normalized_id = str(char_id).strip_edges().to_lower()
	if normalized_id == "":
		return false
	if _added_contacts.has(normalized_id):
		return false
	_added_contacts.append(normalized_id)
	if save_now:
		_save_states()
	return true

func reload_for_active_archive() -> void:
	_chat_states.clear()
	_unread_counts.clear()
	_added_contacts.clear()
	_load_states()

var _advancing_scripts: Dictionary = {}

# 触发一个固定剧本
func trigger_script(script_id: String) -> bool:
	if not _chat_scripts.has(script_id) or not _chat_states.has(script_id):
		return false
	
	var state = _chat_states[script_id]
	if state["is_completed"] or state["is_active"]:
		return false # 已经完成或正在进行中
		
	state["is_active"] = true
	state["current_step"] = 0
	_save_states()
	
	var script = _chat_scripts[script_id]
	add_contact(str(script.get("character_id", "")))
	unread_count_changed.emit(script["character_id"], _unread_counts.get(script["character_id"], 0))
	
	_advance_script(script_id)
	return true

# 推进剧本
func _advance_script(script_id: String) -> void:
	if _advancing_scripts.get(script_id, false):
		return
	_advancing_scripts[script_id] = true
	
	var script = _chat_scripts[script_id]
	var state = _chat_states[script_id]
	var messages = script["messages"]
	var char_id = script["character_id"]
	
	while state["current_step"] < messages.size():
		var msg_data = messages[state["current_step"]]
		var speaker = msg_data.get("speaker", "")
		
		if speaker == "player_options":
			# 等待玩家选择
			break
			
		var delay = msg_data.get("delay", 0)
		if delay > 0:
			character_typing_state_changed.emit(char_id, true)
			await get_tree().create_timer(delay).timeout
			character_typing_state_changed.emit(char_id, false)
			
			# 如果在等待期间被重置/清除了记录，则退出
			if not _advancing_scripts.get(script_id, false):
				return
			
		# 将消息添加到角色的手机历史中
		_append_to_history(char_id, msg_data)
		
		state["current_step"] += 1
		
		if not _unread_counts.has(char_id):
			_unread_counts[char_id] = 0
		_unread_counts[char_id] += 1
		_save_states()
		unread_count_changed.emit(char_id, _unread_counts[char_id])
		
		# 增加微小停顿，避免新消息和下一条的三点气泡完全在同一帧糊在脸上
		await get_tree().create_timer(0.2).timeout
		if not _advancing_scripts.get(script_id, false):
			return
			
	if state["current_step"] >= messages.size() and not state.get("is_completed", false):
		state["is_completed"] = true
		state["is_active"] = false
		
		# 强制中断正在播放的气泡
		_advancing_scripts[script_id] = false
		
		await get_tree().create_timer(1.0).timeout
		
		# 再次检查状态，如果在等待的这1秒内被清除了记录，则不再发送结束语
		if not _chat_states.has(script_id) or not _chat_states[script_id].get("is_completed", false):
			return
			
		_append_to_history(char_id, {
			"speaker": "system",
			"text": "本轮对话已结束"
		})
		
		if not _unread_counts.has(char_id):
			_unread_counts[char_id] = 0
		_unread_counts[char_id] += 1
		_save_states()
		unread_count_changed.emit(char_id, _unread_counts[char_id])
		
	_advancing_scripts[script_id] = false

# 玩家提交选项
func submit_player_option(script_id: String, option_id: String, option_text: String) -> void:
	var script = _chat_scripts[script_id]
	var state = _chat_states[script_id]
	var messages = script["messages"]
	var char_id = script["character_id"]
	
	var current_msg = messages[state["current_step"]]
	if current_msg.get("speaker") != "player_options":
		return
		
	# 记录玩家的话
	_append_to_history(char_id, {
		"speaker": "player",
		"text": option_text
	})
	
	# 找到 next 跳转
	var next_id = ""
	for opt in current_msg.get("options", []):
		if opt.get("id") == option_id:
			next_id = opt.get("next", "")
			break
			
	if next_id != "":
		# 跳转到 next_id
		var found = false
		for i in range(messages.size()):
			if messages[i].get("id") == next_id:
				state["current_step"] = i
				found = true
				break
		if not found:
			state["current_step"] += 1
	else:
		state["current_step"] += 1
		
	_save_states()
	
	# 通知UI刷新玩家刚发出的消息
	unread_count_changed.emit(char_id, _unread_counts.get(char_id, 0))
	
	_advance_script(script_id)

func _append_to_history(char_id: String, msg_data: Dictionary) -> void:
	add_contact(char_id, false)
	var history_path = _get_mobile_history_path(char_id)
	var dir_path = history_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
		
	var history = []
	if FileAccess.file_exists(history_path):
		var file = FileAccess.open(history_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Array:
			history = json.data
		file.close()
		
	var new_msg = {
		"speaker": msg_data.get("speaker", "system"),
		"time": Time.get_datetime_string_from_system(),
		"is_read": false
	}
	
	if msg_data.has("text"):
		new_msg["text"] = msg_data["text"]
	if msg_data.has("image"):
		var img_val = msg_data["image"]
		if img_val.begins_with("res://") or img_val.begins_with("user://"):
			new_msg["text"] = "[img]" + img_val + "[/img]"
		else:
			# Try resolving ID via ImageManager
			var resolved_path = ImageManager.get_image_path(img_val)
			if resolved_path != "":
				new_msg["text"] = "[img]" + resolved_path + "[/img]"
			else:
				new_msg["text"] = "[img]" + img_val + "[/img]"
				
	if msg_data.has("type"):
		new_msg["type"] = msg_data["type"]
	if new_msg["speaker"] == "system" and not new_msg.has("type"):
		new_msg["type"] = "system"
	
	if msg_data.has("amount"):
		new_msg["amount"] = msg_data["amount"]
	if msg_data.has("status"):
		new_msg["status"] = msg_data["status"]
	else:
		if new_msg.get("type") == "red_packet":
			new_msg["status"] = "unclaimed"
			
	if msg_data.has("is_voice"):
		new_msg["is_voice"] = msg_data["is_voice"]
	if msg_data.has("duration"):
		new_msg["duration"] = msg_data["duration"]
		
	history.append(new_msg)
	
	var file = FileAccess.open(history_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(history, "\t"))
		file.close()

# 清除所有固定对话记录，方便重新测试
func clear_all_records() -> void:
	_chat_states.clear()
	_unread_counts.clear()
	
	# 删除状态存档文件
	var save_path = _get_state_path()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
		
	# 遍历清除各个角色的聊天历史记录
	for script_id in _chat_scripts.keys():
		var char_id = _chat_scripts[script_id]["character_id"]
		var history_path = _get_mobile_history_path(char_id)
		if FileAccess.file_exists(history_path):
			DirAccess.remove_absolute(history_path)
			
	# 重新初始化状态
	var state_changed = false
	for script_id in _chat_scripts.keys():
		_chat_states[script_id] = {
			"current_step": 0,
			"is_active": false,
			"is_completed": false
		}
		_advancing_scripts[script_id] = false
		state_changed = true
		
	if state_changed:
		_save_states()
		
	# 触发红点更新
	for script_id in _chat_scripts.keys():
		var char_id = _chat_scripts[script_id]["character_id"]
		unread_count_changed.emit(char_id, 0)

# 标记角色所有消息为已读 
func mark_as_read(char_id: String) -> void:
	if _unread_counts.has(char_id) and _unread_counts[char_id] > 0:
		_unread_counts[char_id] = 0
		_save_states()
		unread_count_changed.emit(char_id, 0)

# 获取总未读数
func get_total_unread_count() -> int:
	var total = 0
	for count in _unread_counts.values():
		total += count
	return total

# 获取角色当前活跃的剧本
func get_active_script_for_char(char_id: String) -> String:
	for script_id in _chat_states.keys():
		var state = _chat_states[script_id]
		if state["is_active"]:
			var script = _chat_scripts.get(script_id, {})
			if script.get("character_id") == char_id:
				return script_id
	return ""

# 获取当前需要显示的选项
func get_current_options(script_id: String) -> Array:
	if not _chat_scripts.has(script_id) or not _chat_states.has(script_id):
		return []
	var state = _chat_states[script_id]
	var script = _chat_scripts[script_id]
	var messages = script["messages"]
	if state["current_step"] < messages.size():
		var msg = messages[state["current_step"]]
		if msg.get("speaker") == "player_options":
			return msg.get("options", [])
	return []
