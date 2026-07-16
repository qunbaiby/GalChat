@tool
extends RefCounted

const STORY_ROOTS := [
	"res://assets/data/story/scripts/main",
	"res://assets/data/story/scripts/events"
]


static func scan() -> Array[Dictionary]:
	var stories: Array[Dictionary] = []
	for root in STORY_ROOTS:
		_scan_directory(root, stories)
	stories.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("path", "")) < str(right.get("path", ""))
	)
	return stories


static func _scan_directory(path: String, stories: Array[Dictionary]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if not entry.begins_with("."):
			var child_path := path.path_join(entry)
			if directory.current_is_dir():
				_scan_directory(child_path, stories)
			elif entry.get_extension().to_lower() == "json":
				stories.append({"path": child_path, "name": entry.get_basename(), "category": path.get_file()})
		entry = directory.get_next()
	directory.list_dir_end()