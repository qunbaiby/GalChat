extends PanelContainer

signal slot_selected(slot_id: String, is_empty: bool)

@onready var screenshot_rect: TextureRect = $MarginContainer/HBoxContainer/ScreenshotRect
@onready var id_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/IdLabel
@onready var time_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/TimeLabel
@onready var info_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/InfoLabel
@onready var action_button: Button = $MarginContainer/HBoxContainer/ActionButton
@onready var delete_button: Button = $MarginContainer/HBoxContainer/DeleteButton

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
        id_label.text = "存档 " + slot_id.replace("manual_", "").pad_zeros(2) if slot_id.begins_with("manual_") else "自动存档"
        time_label.text = "空白存档"
        info_label.text = ""
        screenshot_rect.texture = null
        action_button.text = "存档" if is_save_mode else "不可用"
        action_button.disabled = not is_save_mode
        action_button.show()
        if delete_button:
            delete_button.hide()
    else:
        is_empty = false
        var s_id = meta.get("slot_id", slot_id)
        if s_id == "auto":
            id_label.text = "自动存档"
        else:
            id_label.text = "存档 " + s_id.replace("manual_", "").pad_zeros(2)
            
        time_label.text = meta.get("timestamp", "未知时间").replace("T", " ")
        
        var stage_title = meta.get("stage_title", "未知")
        if stage_title == "未知" and meta.has("stage"):
            stage_title = "阶段 " + str(meta.get("stage"))
            
        info_label.text = "%s | 亲密: %d | 信任: %d" % [
            stage_title,
            int(meta.get("intimacy", 0)),
            int(meta.get("trust", 0))
        ]
        
        var img_path = meta.get("screenshot_path", "")
        if img_path != "" and FileAccess.file_exists(img_path):
            var img = Image.load_from_file(img_path)
            if img:
                screenshot_rect.texture = ImageTexture.create_from_image(img)
        else:
            screenshot_rect.texture = null
        
        if is_save_mode:
            action_button.text = "覆盖"
            if s_id == "auto":
                action_button.disabled = true
                action_button.hide() # 不要显示不可覆盖
            else:
                action_button.disabled = false
                action_button.show()
        else:
            action_button.text = "读取"
            action_button.disabled = false
            action_button.show()
            
        if delete_button:
            if s_id == "auto":
                delete_button.hide()
            else:
                delete_button.show()

func _on_action_pressed() -> void:
    slot_selected.emit(current_slot_id, is_empty)

func _on_delete_pressed() -> void:
    if not is_empty:
        var confirm_scene = load("res://scenes/ui/common/confirm_dialog.tscn")
        if confirm_scene:
            var dialog = confirm_scene.instantiate()
            # Find a suitable parent to add the dialog to (usually the root UI or the save panel)
            var root = get_tree().get_root()
            root.add_child(dialog)
            dialog.setup("确定要删除这个存档吗？\n此操作不可撤销。", "删除", "取消")
            
            dialog.confirmed.connect(func():
                GameDataManager.save_manager.delete_save(current_slot_id)
                # 通知上层刷新
                get_parent().get_parent().get_parent().get_parent().refresh_list()
            )
