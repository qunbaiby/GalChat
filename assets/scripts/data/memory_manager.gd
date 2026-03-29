class_name MemoryManager
extends Node

const MEMORY_FILE_PATH = "user://player_memory.json"

# 四级记忆分层架构
var memories: Dictionary = {
    "core": [],     # 核心记忆层：用户姓名、禁忌、核心价值观、人生大事、不可逆选择
    "emotion": [],  # 情绪记忆层：用户的情绪触发点、雷区、情感偏好
    "habit": [],    # 习惯记忆层：用户作息、饮食喜好、兴趣、日常习惯
    "bond": []      # 羁绊记忆层：专属约定、共同经历、纪念日、一起完成的事
}

func _init() -> void:
    load_memory()

func load_memory() -> void:
    if FileAccess.file_exists(MEMORY_FILE_PATH):
        var file = FileAccess.open(MEMORY_FILE_PATH, FileAccess.READ)
        var content = file.get_as_text()
        file.close()
        
        var json = JSON.new()
        if json.parse(content) == OK:
            var data = json.get_data()
            if data is Dictionary:
                for key in memories.keys():
                    if data.has(key) and data[key] is Array:
                        memories[key] = data[key]

func save_memory() -> void:
    var file = FileAccess.open(MEMORY_FILE_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(memories, "\t"))
        file.close()

func add_memory(layer: String, content: String) -> void:
    if memories.has(layer):
        # 防止重复添加
        if not memories[layer].has(content):
            memories[layer].append(content)
            save_memory()
            print("【记忆管理器】新增 %s 记忆: %s" % [layer, content])

func get_memory_prompt() -> String:
    var prompt_lines = []
    
    if memories["core"].size() > 0:
        prompt_lines.append("- 核心记忆（永不覆盖，严格遵守）：" + "；".join(memories["core"]))
    if memories["emotion"].size() > 0:
        prompt_lines.append("- 情绪记忆（据此调整沟通方式）：" + "；".join(memories["emotion"]))
    if memories["habit"].size() > 0:
        prompt_lines.append("- 习惯记忆（主动贴合用户日常）：" + "；".join(memories["habit"]))
    if memories["bond"].size() > 0:
        prompt_lines.append("- 羁绊记忆（专属情感锚点，可主动提起）：" + "；".join(memories["bond"]))
        
    if prompt_lines.size() > 0:
        return "【玩家专属长记忆档案】\n" + "\n".join(prompt_lines)
    return ""
