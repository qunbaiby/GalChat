extends Control

signal back_requested
signal character_selected(char_id: String)

const CONTACT_ITEM_SCENE = preload("res://scenes/ui/mobile/chat/mobile_contact_list_item.tscn")

@onready var back_btn: Button = $Panel/VBox/TopBar/BackBtn
@onready var contact_list: VBoxContainer = $Panel/VBox/ScrollContainer/ContactList

var _item_map: Dictionary = {}
var _selected_char_id: String = ""

func _ready() -> void:
	back_btn.pressed.connect(_on_back_pressed)
	_load_contacts()

func _load_contacts() -> void:
	# 清空列表
	for child in contact_list.get_children():
		child.queue_free()
	_item_map.clear()
		
	var contacts = []
	
	# Load main characters
	var dir = DirAccess.open("res://assets/data/characters")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json") and not file_name.ends_with("_stages.json"):
				var char_id = file_name.replace(".json", "")
				contacts.append(_get_char_info(char_id, "res://assets/data/characters/" + file_name))
			file_name = dir.get_next()
			
	# Load NPCs
	var npc_dir = DirAccess.open("res://assets/data/characters/npc")
	if npc_dir:
		npc_dir.list_dir_begin()
		var file_name = npc_dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json") and not file_name.ends_with("_stages.json"):
				var char_id = file_name.replace(".json", "")
				contacts.append(_get_char_info(char_id, "res://assets/data/characters/npc/" + file_name))
			file_name = npc_dir.get_next()
			
	# Sort contacts by last message time (newest first)
	contacts.sort_custom(func(a, b):
		return a.raw_time > b.raw_time
	)
	
	for c in contacts:
		_create_contact_item(c)

	_apply_selected_state()

func _get_char_info(char_id: String, file_path: String) -> Dictionary:
	var info = {
		"id": char_id,
		"name": char_id,
		"avatar": "",
		"last_msg": "暂无消息",
		"last_time": "",
		"raw_time": "",
		"unread_count": 0
	}
	
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
			info.name = json.data.get("char_name", char_id)
			info.avatar = json.data.get("avatar", "")
			
	# Get last message from mobile chat history
	var history_path = "user://saves/%s/mobile_chat_history.json" % char_id
	if FileAccess.file_exists(history_path):
		var file = FileAccess.open(history_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Array:
			var mobile_msgs = json.data
			if mobile_msgs.size() > 0:
				var last = mobile_msgs[-1]
				var raw_text = last.get("text", "...")
				
				# If it's an image
				if raw_text.begins_with("[img]") and raw_text.ends_with("[/img]"):
					raw_text = "[图片]"
				
				# Strip BBCode tags (like [color=green]...[/color])
				var regex = RegEx.new()
				regex.compile("\\[.*?\\]")
				raw_text = regex.sub(raw_text, "", true)
				
				info.last_msg = raw_text
				info.raw_time = last.get("time", "")
				info.last_time = _format_time(info.raw_time)
				for msg in mobile_msgs:
					var speaker = msg.get("speaker", "")
					if speaker != "player" and not msg.get("is_read", false):
						info.unread_count += 1
				
	return info

func _format_time(time_str: String) -> String:
	if time_str == "":
		return ""
	var parts = time_str.split(" ")
	if parts.size() < 2:
		parts = time_str.split("T")
	if parts.size() >= 2:
		var date_part = parts[0]
		var time_part = parts[1]
		var today = Time.get_date_string_from_system()
		var time_short = time_part.substr(0, 5) # HH:MM
		if date_part == today:
			return time_short
		else:
			var date_split = date_part.split("-")
			if date_split.size() >= 3:
				return date_split[1] + "-" + date_split[2] # MM-DD
	return time_str.substr(0, 10)

func _create_contact_item(info: Dictionary) -> void:
	var item = CONTACT_ITEM_SCENE.instantiate()
	contact_list.add_child(item)
	item.setup(info)
	item.selected.connect(_on_contact_selected)
	_item_map[str(info.get("id", ""))] = item

func _on_contact_selected(char_id: String) -> void:
	_selected_char_id = char_id
	_apply_selected_state()
	character_selected.emit(char_id)

func select_character(char_id: String, emit_signal: bool = true) -> bool:
	if char_id == "":
		return false
	if _item_map.is_empty():
		_load_contacts()
	if not _item_map.has(char_id):
		return false

	_selected_char_id = char_id
	_apply_selected_state()
	if emit_signal:
		character_selected.emit(char_id)
	return true

func clear_selection() -> void:
	_selected_char_id = ""
	_apply_selected_state()

func _apply_selected_state() -> void:
	for item_id in _item_map.keys():
		var item = _item_map[item_id]
		if is_instance_valid(item) and item.has_method("set_selected"):
			item.set_selected(item_id == _selected_char_id)

func _on_back_pressed() -> void:
	back_requested.emit()
	
func show_panel() -> void:
	show()
	_load_contacts() # 每次显示时重新加载，更新最新消息
	# 滑入动画
	position.x = size.x
	modulate.a = 0.0
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

func hide_panel() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:x", size.x, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(self.hide)
