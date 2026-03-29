extends Control

@onready var stage_option: OptionButton = $"CenterContainer/Panel/VBoxContainer/TabContainer/情感控制/HBoxContainer/StageOption"
@onready var mood_option: OptionButton = $"CenterContainer/Panel/VBoxContainer/TabContainer/心情/HBoxContainer/MoodOption"
@onready var close_btn: Button = $CenterContainer/Panel/VBoxContainer/CloseButton

@onready var memory_text: RichTextLabel = $"CenterContainer/Panel/VBoxContainer/TabContainer/记忆管理/ScrollContainer/MemoryText"
@onready var clear_memory_btn: Button = $"CenterContainer/Panel/VBoxContainer/TabContainer/记忆管理/ClearMemoryBtn"

signal stage_changed(new_stage: int)
signal mood_changed(new_mood: String)

func _ready() -> void:
    close_btn.pressed.connect(_on_close_pressed)
    stage_option.item_selected.connect(_on_stage_selected)
    mood_option.item_selected.connect(_on_mood_selected)
    clear_memory_btn.pressed.connect(_on_clear_memory_pressed)
    
    _init_mood_options()

func _init_mood_options() -> void:
    mood_option.clear()
    var index = 0
    for mood_name in GameDataManager.mood_system.all_mood_names:
        var config = GameDataManager.mood_system.mood_configs[mood_name]
        var display_text = "%s (%s)" % [mood_name, config["id"]]
        mood_option.add_item(display_text, index)
        index += 1

func show_panel() -> void:
    # 同步当前状态
    var profile = GameDataManager.profile
    stage_option.select(profile.current_stage - 1)
    
    var mood = profile.current_mood
    var idx = GameDataManager.mood_system.all_mood_names.find(mood)
    if idx >= 0:
        mood_option.select(idx)
        
    _update_memory_text()
    
    show()

func _update_memory_text() -> void:
    var mems = GameDataManager.memory_manager.memories
    var text = ""
    text += "[b]核心记忆:[/b]\n" + ("\n".join(mems["core"]) if mems["core"].size() > 0 else "无") + "\n\n"
    text += "[b]情绪记忆:[/b]\n" + ("\n".join(mems["emotion"]) if mems["emotion"].size() > 0 else "无") + "\n\n"
    text += "[b]习惯记忆:[/b]\n" + ("\n".join(mems["habit"]) if mems["habit"].size() > 0 else "无") + "\n\n"
    text += "[b]羁绊记忆:[/b]\n" + ("\n".join(mems["bond"]) if mems["bond"].size() > 0 else "无")
    memory_text.text = text

func _on_clear_memory_pressed() -> void:
    GameDataManager.memory_manager.memories = {
        "core": [], "emotion": [], "habit": [], "bond": []
    }
    GameDataManager.memory_manager.save_memory()
    _update_memory_text()
    print("记忆已清空")

func _on_close_pressed() -> void:
    hide()

func _on_stage_selected(index: int) -> void:
    var stage = index + 1
    GameDataManager.profile.force_set_stage(stage)
    stage_changed.emit(stage)

func _on_mood_selected(index: int) -> void:
    if index >= 0 and index < GameDataManager.mood_system.all_mood_names.size():
        var mood = GameDataManager.mood_system.all_mood_names[index]
        GameDataManager.profile.update_mood(mood)
        mood_changed.emit(mood)
