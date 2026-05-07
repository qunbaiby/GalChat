extends Control

@onready var title_label: Label = $Panel/VBoxContainer/TopBar/TitleLabel
@onready var close_btn: Button = $Panel/VBoxContainer/TopBar/CloseButton
@onready var list_container: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/ListContainer

const SLOT_ITEM_SCENE = preload("res://scenes/ui/save_load/save_slot_item.tscn")
const MAX_MANUAL_SLOTS = 20

var is_save_mode: bool = false

func _ready() -> void:
    close_btn.pressed.connect(_on_close_pressed)

func show_panel(save_mode: bool) -> void:
    is_save_mode = save_mode
    title_label.text = "保存游戏" if is_save_mode else "读取游戏"
    show()
    refresh_list()
    
    modulate.a = 0.0
    var tween = create_tween()
    tween.tween_property(self, "modulate:a", 1.0, 0.2)

func hide_panel() -> void:
    var tween = create_tween()
    tween.tween_property(self, "modulate:a", 0.0, 0.2)
    tween.tween_callback(hide)

func _on_close_pressed() -> void:
    hide_panel()

func refresh_list() -> void:
    for child in list_container.get_children():
        child.queue_free()
        
    var existing_slots = GameDataManager.save_manager.get_save_slots()
    var slots_dict = {}
    for s in existing_slots:
        slots_dict[s.get("slot_id")] = s
        
    # Auto save slot (only for load, or disabled for save)
    var auto_meta = slots_dict.get("auto", {})
    if not auto_meta.is_empty() or not is_save_mode:
        var auto_item = SLOT_ITEM_SCENE.instantiate()
        list_container.add_child(auto_item)
        auto_item.setup("auto", auto_meta, is_save_mode)
        auto_item.slot_selected.connect(_on_slot_selected)
        
    # Manual slots
    for i in range(1, MAX_MANUAL_SLOTS + 1):
        var slot_id = "manual_" + str(i)
        var meta = slots_dict.get(slot_id, {})
        # 如果是读档模式，且该槽位为空，跳过
        if not is_save_mode and meta.is_empty():
            continue
            
        var item = SLOT_ITEM_SCENE.instantiate()
        list_container.add_child(item)
        item.setup(slot_id, meta, is_save_mode)
        item.slot_selected.connect(_on_slot_selected)

func _on_slot_selected(slot_id: String) -> void:
    if is_save_mode:
        GameDataManager.save_manager.save_game(slot_id)
        refresh_list()
        # Optionally show toast
    else:
        var success = GameDataManager.save_manager.load_game(slot_id)
        if success:
            hide_panel()
            # 读档成功后重启主场景以刷新全部状态
            get_tree().change_scene_to_file("res://scenes/ui/main/main_scene.tscn")
