extends Node
class_name SaveManager

const SafeFileAccess = preload("res://scripts/utils/safe_file_access.gd")
const SLOTS_DIR_FORMAT = "user://saves/%s/slots/"

# Metadata keys: slot_id, timestamp, playtime, stage, screenshot_path
var current_slot_id: String = ""

func _ready() -> void:
	pass

func get_slots_dir() -> String:
	var char_id = "default"
	if GameDataManager.config and GameDataManager.config.current_character_id != "":
		char_id = GameDataManager.config.current_character_id
	return SLOTS_DIR_FORMAT % char_id

func get_active_dir() -> String:
	var char_id = "default"
	if GameDataManager.config and GameDataManager.config.current_character_id != "":
		char_id = GameDataManager.config.current_character_id
	return "user://saves/%s/" % char_id

func _replace_directory(source_dir: String, target_dir: String) -> void:
	_remove_directory_recursive(target_dir)
	if DirAccess.dir_exists_absolute(source_dir):
		_copy_directory_recursive(source_dir, target_dir)

func _copy_directory_recursive(source_dir: String, target_dir: String) -> void:
	if not DirAccess.dir_exists_absolute(source_dir):
		return
	if not DirAccess.dir_exists_absolute(target_dir):
		DirAccess.make_dir_recursive_absolute(target_dir)
	var dir = DirAccess.open(source_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var source_path = source_dir.path_join(entry)
		var target_path = target_dir.path_join(entry)
		if dir.current_is_dir():
			_copy_directory_recursive(source_path, target_path)
		else:
			var copy_result = dir.copy(source_path, target_path)
			if copy_result != OK:
				printerr("[SaveManager] Failed to copy directory file: ", source_path, " -> ", target_path, ", error code: ", copy_result)
		entry = dir.get_next()

func _remove_directory_recursive(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var child_path = dir_path.path_join(entry)
		if dir.current_is_dir():
			_remove_directory_recursive(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
		entry = dir.get_next()
	DirAccess.remove_absolute(dir_path)

func get_save_slots() -> Array:
	var slots_dir = get_slots_dir()
	if not DirAccess.dir_exists_absolute(slots_dir):
		return []
		
	var slots = []
	var dir = DirAccess.open(slots_dir)
	if dir:
		dir.list_dir_begin()
		var slot_name = dir.get_next()
		while slot_name != "":
			if dir.current_is_dir() and not slot_name.begins_with("."):
				var meta_path = slots_dir + slot_name + "/meta.json"
				if FileAccess.file_exists(meta_path):
					var file = FileAccess.open(meta_path, FileAccess.READ)
					if file:
						var content = file.get_as_text()
						file.close()
						var json = JSON.new()
						if json.parse(content) == OK:
							var meta = json.get_data()
							meta["slot_id"] = slot_name
							slots.append(meta)
			slot_name = dir.get_next()
			
	# 按时间降序排序
	slots.sort_custom(func(a, b):
		var t_a = a.get("timestamp", "").replace("T", " ")
		var t_b = b.get("timestamp", "").replace("T", " ")
		return t_a > t_b
	)
	return slots

func save_game(slot_id: String, custom_image: Image = null):
	var image: Image
	if custom_image != null:
		image = custom_image
	else:
		await RenderingServer.frame_post_draw
		image = get_viewport().get_texture().get_image()
		
	image.resize(320, 180, Image.INTERPOLATE_BILINEAR)
	
	# 1. 强制各模块把当前数据保存到活动目录
	if GameDataManager.profile != null:
		GameDataManager.profile.save_profile()
	if GameDataManager.history != null:
		GameDataManager.history.save_history()
	if GameDataManager.npc_relationship_manager != null:
		GameDataManager.npc_relationship_manager.save_relationships()
	if GameDataManager.memory_manager != null:
		GameDataManager.memory_manager.save_memory()
	if GameDataManager.story_time_manager != null:
		GameDataManager.story_time_manager.save_data()
		
	# 2. 准备槽位目录
	var slots_dir = get_slots_dir()
	var slot_dir = slots_dir + slot_id + "/"
	if not DirAccess.dir_exists_absolute(slot_dir):
		DirAccess.make_dir_recursive_absolute(slot_dir)
		
	var active_dir = get_active_dir()
	
	# 3. 拷贝文件
	var files_to_copy = [
		"character_profile.json",
		"chat_history.json",
		"player_memory.json",
		"story_time_save.json",
		"mobile_chat_history.json",
		"npc_relationships.json",
		"triggered_events.json",
		"memory_album_state.json",
		"moments_data.json"
	]
	
	var dir = DirAccess.open(active_dir)
	if dir:
		for f in files_to_copy:
			if FileAccess.file_exists(active_dir + f):
				var copy_result = dir.copy(active_dir + f, slot_dir + f)
				if copy_result != OK:
					printerr("[SaveManager] Failed to copy file: ", f, ", error code: ", copy_result)
					return false
	_replace_directory(active_dir + "photos", slot_dir + "photos")
				
	var img_filename = "screenshot.jpg"
	image.save_jpg(slot_dir + img_filename, 0.8)
				
	# 4. 生成 meta.json
	var profile = GameDataManager.profile
	var stage_title = "未知"
	if profile:
		var s_conf = profile.get_stage_config(profile.current_stage)
		if not s_conf.is_empty():
			stage_title = s_conf.get("stageTitle", "未知")
			
	var meta = {
		"slot_id": slot_id,
		"timestamp": Time.get_datetime_string_from_system().replace("T", " "),
		"stage": profile.current_stage if profile else 1,
		"stage_title": stage_title,
		"intimacy": profile.intimacy if profile else 0,
		"trust": profile.trust if profile else 0,
		"screenshot_path": slot_dir + img_filename
	}
	
	var meta_content = JSON.stringify(meta, "\t")
	SafeFileAccess.store_string(slot_dir + "meta.json", meta_content)
	
	print("[SaveManager] Game saved to slot: ", slot_id)
	return true

func load_game(slot_id: String) -> bool:
	var slot_dir = get_slots_dir() + slot_id + "/"
	if not DirAccess.dir_exists_absolute(slot_dir):
		printerr("[SaveManager] Slot directory not found: ", slot_dir)
		return false
		
	var active_dir = get_active_dir()
	
	# 1. 将槽位文件拷贝回活动目录
	var files_to_copy = [
		"character_profile.json",
		"chat_history.json",
		"player_memory.json",
		"story_time_save.json",
		"mobile_chat_history.json",
		"npc_relationships.json",
		"triggered_events.json",
		"memory_album_state.json",
		"moments_data.json"
	]
	
	var dir = DirAccess.open(slot_dir)
	if dir:
		for f in files_to_copy:
			if FileAccess.file_exists(slot_dir + f):
				dir.copy(slot_dir + f, active_dir + f)
	_replace_directory(slot_dir + "photos", active_dir + "photos")
				
	# 2. 强制各模块重新加载数据
	if GameDataManager.profile:
		GameDataManager.profile.load_profile()
	if GameDataManager.history:
		GameDataManager.history.load_history()
	if GameDataManager.npc_relationship_manager:
		GameDataManager.npc_relationship_manager.load_relationships()
	if GameDataManager.memory_manager:
		GameDataManager.memory_manager.load_memory()
	if GameDataManager.story_time_manager:
		GameDataManager.story_time_manager.load_data()
	var event_manager = get_node_or_null("/root/EventManager")
	if event_manager and event_manager.has_method("reload_for_current_character"):
		event_manager.reload_for_current_character()
		
	print("[SaveManager] Game loaded from slot: ", slot_id)
	return true

func delete_save(slot_id: String) -> bool:
	var slot_dir = get_slots_dir() + slot_id + "/"
	if DirAccess.dir_exists_absolute(slot_dir):
		var dir = DirAccess.open(slot_dir)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir():
					dir.remove(file_name)
				file_name = dir.get_next()
			DirAccess.remove_absolute(slot_dir)
			print("[SaveManager] Deleted slot: ", slot_id)
			return true
	return false

func auto_save():
	await save_game("auto")
