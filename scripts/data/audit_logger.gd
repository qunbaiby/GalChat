extends Node

const LOG_FILE = "user://audit_logs.txt"

# 记录审计日志：操作人、时间、原因、具体事件
func log_event(action: String, details: String, operator: String = "system") -> void:
    var time_str = Time.get_datetime_string_from_system()
    var entry = "[%s] [Operator: %s] [%s] %s\n" % [time_str, operator, action, details]
    
    # 打印到控制台以供开发调试
    print("【审计日志】", entry.strip_edges())
    
    # 写入本地文件模拟持久化存储
    var file: FileAccess
    if FileAccess.file_exists(LOG_FILE):
        file = FileAccess.open(LOG_FILE, FileAccess.READ_WRITE)
        file.seek_end()
    else:
        file = FileAccess.open(LOG_FILE, FileAccess.WRITE)
        
    if file:
        file.store_string(entry)
        file.close()

# 记录OOC预警
func log_ooc_warning(char_name: String, trigger_text: String) -> void:
    log_event("OOC_WARNING", "Character '%s' triggered potential OOC. Original text: %s" % [char_name, trigger_text])
