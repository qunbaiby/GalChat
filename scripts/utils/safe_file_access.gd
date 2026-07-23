class_name SafeFileAccess
extends RefCounted

## 安全写入文件内容
## @param path: 目标文件路径
## @param content: 要写入的字符串内容
## @return: 是否写入成功
static func store_string(path: String, content: String) -> bool:
    var base_dir = path.get_base_dir()
    if not DirAccess.dir_exists_absolute(base_dir):
        var make_dir_error := DirAccess.make_dir_recursive_absolute(base_dir)
        if make_dir_error != OK:
            printerr("[SafeFileAccess] Failed to create target directory: ", base_dir, " Error: ", make_dir_error)
            return false

    var tmp_path = path + ".tmp"
    var file = FileAccess.open(tmp_path, FileAccess.WRITE)
    if file == null:
        printerr("[SafeFileAccess] Failed to open temp file for writing: ", tmp_path)
        return false
        
    file.store_string(content)
    var write_error := file.get_error()
    file.close()
    if write_error != OK:
        printerr("[SafeFileAccess] Failed to write temp file: ", tmp_path, " Error: ", write_error)
        DirAccess.remove_absolute(tmp_path)
        return false
    
    var dir = DirAccess.open("user://")
    if dir == null:
        printerr("[SafeFileAccess] Failed to open user:// directory")
        return false
        
    # 如果原文件存在，先删除（在某些平台上 rename 可能会失败如果目标存在）
    if FileAccess.file_exists(path):
        var err = DirAccess.remove_absolute(path)
        if err != OK:
            printerr("[SafeFileAccess] Failed to remove existing file: ", path, " Error: ", err)
            return false
            
    # 重命名 tmp 文件为目标文件
    var rename_err = DirAccess.rename_absolute(tmp_path, path)
    if rename_err != OK:
        printerr("[SafeFileAccess] Failed to rename temp file to target: ", tmp_path, " -> ", path, " Error: ", rename_err)
        return false
        
    return true
