extends SceneTree

const DESKTOP_PET_PATH := "res://scripts/ui/desktop_pet/desktop_pet.gd"
const PROMPT_PATH := "res://scripts/templates/prompts/desktop_pet.txt"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var desktop_pet_script: GDScript = load(DESKTOP_PET_PATH)
	_expect(desktop_pet_script != null, "无法加载桌宠脚本。")
	if desktop_pet_script == null:
		_finish()
		return

	var desktop_pet = desktop_pet_script.new()
	var first_chunk: Dictionary = desktop_pet.call("_parse_desktop_pet_voice_chunk", "<voice:轻快地说>（挥手）你回来啦。")
	var second_chunk: Dictionary = desktop_pet.call("_parse_desktop_pet_voice_chunk", "【语音指令：稍微压低音量】（靠近）今天别熬太晚。")
	_expect(str(first_chunk.get("text", "")) == "（挥手）你回来啦。", "桌宠气泡没有移除 voice 标签。")
	_expect(str(first_chunk.get("voice_instruction", "")) == "轻快地说", "桌宠没有提取尖括号 voice 指令。")
	_expect(str(second_chunk.get("text", "")) == "（靠近）今天别熬太晚。", "桌宠没有移除中文语音指令标签。")
	_expect(str(second_chunk.get("voice_instruction", "")) == "稍微压低音量", "桌宠没有提取中文语音指令。")
	_expect(str(desktop_pet.call("_extract_dialogue_text", first_chunk.get("text", ""))) == "你回来啦。", "桌宠 TTS 文本仍包含动作或标签。")

	var prompt := FileAccess.get_file_as_string(PROMPT_PATH)
	_expect(prompt.contains("<voice:...>"), "桌宠 prompt 没有声明 TTS 2.0 voice 标签。")
	_expect(prompt.contains("每一条被拆分出来的独立消息"), "桌宠 prompt 没有要求每个分段携带指令。")
	desktop_pet.free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("DESKTOP_PET_VOICE_INSTRUCTION_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("DESKTOP_PET_VOICE_INSTRUCTION_SMOKE: %s" % failure)
	quit(1)