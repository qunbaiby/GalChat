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
        return a.get("timestamp", "") > b.get("timestamp", "")
    )
    return slots

func save_game(slot_id: String) -> bool:
    # 1. 强制各模块把当前数据保存到活动目录
    if GameDataManager.profile and not GameDataManager.profile.save_profile():
        printerr("[SaveManager] Failed to save profile, aborting save_game.")
        return false
    if GameDataManager.history and not GameDataManager.history.save_history():
        printerr("[SaveManager] Failed to save history, aborting save_game.")
        return false
    if GameDataManager.memory_manager and not GameDataManager.memory_manager.save_memory():
        printerr("[SaveManager] Failed to save memory, aborting save_game.")
        return false
        
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
        "player_memory.json"
    ]
    
    var dir = DirAccess.open(active_dir)
    if dir:
        for f in files_to_copy:
            if FileAccess.file_exists(active_dir + f):
                var copy_result = dir.copy(active_dir + f, slot_dir + f)
                if copy_result != OK:
                    printerr("[SaveManager] Failed to copy file: ", f, ", error code: ", copy_result)
                    return false
                
    # 4. 生成 meta.json
    var meta = {
        "slot_id": slot_id,
        "timestamp": Time.get_datetime_string_from_system(),
        "stage": GameDataManager.profile.current_stage if GameDataManager.profile else 1,
        "intimacy": GameDataManager.profile.intimacy if GameDataManager.profile else 0,
        "screenshot_path": "" # 未来可以接截图
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
        "player_memory.json"
    ]
    
    var dir = DirAccess.open(slot_dir)
    if dir:
        for f in files_to_copy:
            if FileAccess.file_exists(slot_dir + f):
                dir.copy(slot_dir + f, active_dir + f)
                
    # 2. 强制各模块重新加载数据
    if GameDataManager.profile:
        GameDataManager.profile.load_profile()
    if GameDataManager.history:
        GameDataManager.history.load_history()
    if GameDataManager.memory_manager:
        GameDataManager.memory_manager.load_memory()
        
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

func auto_save() -> void:
    save_game("auto")
