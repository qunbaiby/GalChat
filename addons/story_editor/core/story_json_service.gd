@tool
extends RefCounted


static func load_dictionary(path: String) -> Dictionary:
	var result := _load_json(path)
	if not result.get("ok", false):
		return result
	if not result.get("data") is Dictionary:
		return {"ok": false, "error": "剧情文件根节点必须是对象。"}
	return {"ok": true, "data": (result.get("data") as Dictionary).duplicate(true)}


static func load_array(path: String) -> Dictionary:
	var result := _load_json(path)
	if not result.get("ok", false):
		return result
	if not result.get("data") is Array:
		return {"ok": false, "error": "JSON 文件根节点必须是数组。"}
	return {"ok": true, "data": (result.get("data") as Array).duplicate(true)}


static func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "文件不存在：%s" % path}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "无法读取文件：%s" % path}
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	if parse_error != OK:
		return {"ok": false, "error": "JSON 第 %d 行解析失败：%s" % [parser.get_error_line(), parser.get_error_message()]}
	return {"ok": true, "data": parser.data}


static func save_dictionary(path: String, data: Dictionary) -> Dictionary:
	return _save_json(path, data)


static func save_array(path: String, data: Array) -> Dictionary:
	return _save_json(path, data)


static func _save_json(path: String, data: Variant) -> Dictionary:
	var absolute_path := ProjectSettings.globalize_path(path)
	var temporary_path := absolute_path + ".story_editor.tmp"
	var backup_path := absolute_path + ".story_editor.bak"
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return {"ok": false, "error": "无法创建文件目录，错误码：%d" % directory_error}
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "无法创建临时文件：%s" % temporary_path}
	file.store_string(JSON.stringify(data, "    ", false) + "\n")
	file.close()
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	var had_original := FileAccess.file_exists(absolute_path)
	if had_original:
		var backup_error := DirAccess.rename_absolute(absolute_path, backup_path)
		if backup_error != OK:
			DirAccess.remove_absolute(temporary_path)
			return {"ok": false, "error": "无法备份原文件，错误码：%d" % backup_error}
	var error := DirAccess.rename_absolute(temporary_path, absolute_path)
	if error != OK:
		if had_original:
			DirAccess.rename_absolute(backup_path, absolute_path)
		if FileAccess.file_exists(temporary_path):
			DirAccess.remove_absolute(temporary_path)
		return {"ok": false, "error": "无法写入目标文件，错误码：%d" % error}
	if had_original and FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	return {"ok": true}