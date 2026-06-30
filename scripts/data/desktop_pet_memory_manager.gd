class_name DesktopPetMemoryManager
extends MemoryManager

func get_memory_file_path() -> String:
	var char_id = "default"
	if GameDataManager.config and GameDataManager.config.current_character_id != "":
		char_id = GameDataManager.config.current_character_id
	return GameDataManager.get_character_save_path("desktop_pet_memory.json", char_id)
