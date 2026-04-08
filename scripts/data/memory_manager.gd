class_name MemoryManager
extends Node

const MEMORY_FILE_PATH = "user://player_memory.json"

# 四级记忆分层架构，每层存储字典列表 [{"id": String, "content": String, "timestamp": String}]
var memories: Dictionary = {
    "core": [],     # 核心记忆层：用户姓名、禁忌、核心价值观、人生大事、不可逆选择
    "emotion": [],  # 情绪记忆层：用户的情绪触发点、雷区、情感偏好
    "habit": [],    # 习惯记忆层：用户作息、饮食喜好、兴趣、日常习惯
    "bond": []      # 羁绊记忆层：专属约定、共同经历、纪念日、一起完成的事
}

var turns_since_last_extract: int = 0

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
                        var layer_mems = []
                        for item in data[key]:
                            # 兼容旧版本纯字符串记忆
                            if item is String:
                                layer_mems.append({
                                    "id": _generate_id(),
                                    "content": item,
                                    "timestamp": Time.get_datetime_string_from_system()
                                })
                            elif item is Dictionary and item.has("id") and item.has("content"):
                                layer_mems.append(item)
                        memories[key] = layer_mems
                turns_since_last_extract = int(data.get("_turns_since_last_extract", turns_since_last_extract))

func save_memory() -> void:
    var file = FileAccess.open(MEMORY_FILE_PATH, FileAccess.WRITE)
    if file:
        var data = memories.duplicate(true)
        data["_turns_since_last_extract"] = turns_since_last_extract
        file.store_string(JSON.stringify(data, "\t"))
        file.close()

func _generate_id() -> String:
    return str(Time.get_unix_time_from_system() * 1000 + randi() % 1000)

func add_memory(layer: String, content: String) -> void:
    if memories.has(layer):
        # 防止重复内容添加
        for mem in memories[layer]:
            if mem["content"] == content:
                return
                
        var embedding = await DoubaoEmbeddingClient.get_embedding(content)
                
        var new_mem = {
            "id": _generate_id(),
            "content": content,
            "timestamp": Time.get_datetime_string_from_system(),
            "embedding": embedding
        }
        memories[layer].append(new_mem)
        save_memory()
        print("【记忆管理器】新增 %s 记忆: [%s] %s" % [layer, new_mem["id"], content])

func update_memory(layer: String, id: String, new_content: String) -> bool:
    if memories.has(layer):
        for i in range(memories[layer].size()):
            if memories[layer][i]["id"] == id:
                memories[layer][i]["content"] = new_content
                memories[layer][i]["timestamp"] = Time.get_datetime_string_from_system()
                
                var embedding = await DoubaoEmbeddingClient.get_embedding(new_content)
                memories[layer][i]["embedding"] = embedding
                
                save_memory()
                print("【记忆管理器】更新 %s 记忆 [%s]: %s" % [layer, id, new_content])
                return true
    return false

func delete_memory(layer: String, id: String) -> bool:
    if memories.has(layer):
        for i in range(memories[layer].size()):
            if memories[layer][i]["id"] == id:
                var content = memories[layer][i]["content"]
                memories[layer].remove_at(i)
                save_memory()
                print("【记忆管理器】删除 %s 记忆 [%s]: %s" % [layer, id, content])
                return true
    return false

func add_turn() -> bool:
    turns_since_last_extract += 1
    save_memory()
    # 将原本的10回合触发一次，改为每3回合触发一次，或者根据需要调整为更频繁
    return turns_since_last_extract % 3 == 0

func reset_turn_counter() -> void:
    turns_since_last_extract = 0
    save_memory()

func get_memory_prompt(query_embedding: Array = []) -> String:
    var prompt_lines = []
    
    if memories["core"].size() > 0:
        var contents = []
        for m in memories["core"]: contents.append(m["content"])
        prompt_lines.append("- 核心记忆（永不覆盖，严格遵守）：" + "；".join(contents))
        
    var layers = {
        "emotion": "- 情绪记忆（据此调整沟通方式）：",
        "habit": "- 习惯记忆（主动贴合用户日常）：",
        "bond": "- 羁绊记忆（专属情感锚点，可主动提起）："
    }
    
    for layer in layers.keys():
        if memories[layer].size() > 0:
            var relevant_mems = []
            
            if query_embedding.size() > 0:
                var scored_mems = []
                for m in memories[layer]:
                    var emb = m.get("embedding", [])
                    var score = 0.0
                    if emb is Array and emb.size() > 0 and query_embedding.size() == emb.size():
                        score = _cosine_similarity(query_embedding, emb)
                    else:
                        score = -1.0 # 没嵌入或维度不匹配时
                    scored_mems.append({"content": m["content"], "score": score})
                
                # 按分数降序
                scored_mems.sort_custom(func(a, b): return a["score"] > b["score"])
                
                # 选取前3条相关记忆，阈值设为0.4（或无嵌入的直接包含）
                for i in range(min(3, scored_mems.size())):
                    var score = scored_mems[i]["score"]
                    if score >= 0.4 or score == -1.0:
                        relevant_mems.append(scored_mems[i]["content"])
            else:
                for m in memories[layer]: relevant_mems.append(m["content"])
                
            if relevant_mems.size() > 0:
                prompt_lines.append(layers[layer] + "；".join(relevant_mems))
        
    if prompt_lines.size() > 0:
        return "【玩家专属长记忆档案】\n" + "\n".join(prompt_lines)
    return ""

func _cosine_similarity(vec1: Array, vec2: Array) -> float:
    if vec1.size() != vec2.size() or vec1.size() == 0:
        return 0.0
        
    var dot_product = 0.0
    var norm1 = 0.0
    var norm2 = 0.0
    
    for i in range(vec1.size()):
        var v1 = float(vec1[i])
        var v2 = float(vec2[i])
        dot_product += v1 * v2
        norm1 += v1 * v1
        norm2 += v2 * v2
        
    if norm1 == 0.0 or norm2 == 0.0:
        return 0.0
        
    return dot_product / (sqrt(norm1) * sqrt(norm2))
