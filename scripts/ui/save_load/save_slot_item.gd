extends PanelContainer

signal slot_selected(slot_id: String)

@onready var id_label: Label = $HBoxContainer/VBoxContainer/IdLabel
@onready var time_label: Label = $HBoxContainer/VBoxContainer/TimeLabel
@onready var info_label: Label = $HBoxContainer/VBoxContainer/InfoLabel
@onready var action_button: Button = $HBoxContainer/ActionButton
@onready var delete_button: Button = $HBoxContainer/DeleteButton

var current_slot_id: String = ""
var is_empty: bool = true

func _ready() -> void:
    action_button.pressed.connect(_on_action_pressed)
    if delete_button:
        delete_button.pressed.connect(_on_delete_pressed)

func setup(slot_id: String, meta: Dictionary, is_save_mode: bool) -> void:
    current_slot_id = slot_id
    
    if meta.is_empty():
        is_empty = true
        id_label.text = "Slot: " + slot_id
        time_label.text = "空槽位"
        info_label.text = ""
        action_button.text = "存档" if is_save_mode else "不可用"
        action_button.disabled = not is_save_mode
        if delete_button:
            delete_button.hide()
    else:
        is_empty = false
        var s_id = meta.get("slot_id", slot_id)
        if s_id == "auto":
            id_label.text = "自动存档"
        else:
            id_label.text = "手动存档: " + s_id.replace("manual_", "")
            
        time_label.text = meta.get("timestamp", "未知时间")
        info_label.text = "阶段: %d | 亲密: %d" % [int(meta.get("stage", 1)), int(meta.get("intimacy", 0))]
        
        if is_save_mode:
            action_button.text = "覆盖"
            if s_id == "auto":
                action_button.disabled = true
                action_button.text = "不可覆盖"
            else:
                action_button.disabled = false
        else:
            action_button.text = "读取"
            action_button.disabled = false
            
        if delete_button:
            if s_id == "auto":
                delete_button.hide()
            else:
                delete_button.show()

func _on_action_pressed() -> void:
    slot_selected.emit(current_slot_id)

func _on_delete_pressed() -> void:
    if not is_empty:
        GameDataManager.save_manager.delete_save(current_slot_id)
        # 通知上层刷新
        get_parent().get_parent().get_parent().get_parent().refresh_list()
