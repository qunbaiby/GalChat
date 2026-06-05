extends Control

@onready var background_panel: Panel = $Background
@onready var panel_root: PanelContainer = $CenterContainer/PanelRoot
@onready var title_label: Label = $CenterContainer/PanelRoot/MainMargin/RootVBox/TopBar/TitleLabel
@onready var mode_hint_label: Label = $CenterContainer/PanelRoot/MainMargin/RootVBox/TopBar/ModeHintLabel
@onready var mode_badge_label: Label = $CenterContainer/PanelRoot/MainMargin/RootVBox/BodyMargin/BodyVBox/ModeCard/ModeMargin/ModeHBox/ModeBadgePanel/ModeBadgeLabel
@onready var section_desc_label: Label = $CenterContainer/PanelRoot/MainMargin/RootVBox/BodyMargin/BodyVBox/ModeCard/ModeMargin/ModeHBox/ModeTextVBox/SectionDesc
@onready var close_btn: Button = $CenterContainer/PanelRoot/MainMargin/RootVBox/TopBar/BackButton
@onready var slot_count_label: Label = $CenterContainer/PanelRoot/MainMargin/RootVBox/BodyMargin/BodyVBox/ListCard/ListMargin/ListVBox/ListHeader/CountLabel
@onready var list_container: VBoxContainer = $CenterContainer/PanelRoot/MainMargin/RootVBox/BodyMargin/BodyVBox/ListCard/ListMargin/ListVBox/ScrollContainer/ListContainer

const SLOT_ITEM_SCENE: PackedScene = preload("res://scenes/ui/save_load/save_slot_item.tscn")
const MAX_MANUAL_SLOTS: int = 20
const POPUP_MIN_SIZE: Vector2 = Vector2(980, 620)

var is_save_mode: bool = false
var pre_captured_image: Image = null
var _panel_tween: Tween = null

func _ready() -> void:
    hide()
    close_btn.pressed.connect(_on_close_pressed)
    background_panel.gui_input.connect(_on_background_gui_input)
    resized.connect(_on_panel_resized)

func show_panel(save_mode: bool) -> void:
    is_save_mode = save_mode
    title_label.text = "保存游戏" if is_save_mode else "读取游戏"
    mode_badge_label.text = "SAVE" if is_save_mode else "LOAD"
    mode_hint_label.text = "整理你的关键进度，随时回到重要时刻。" if is_save_mode else "从已记录的节点继续游戏，快速回到想要的剧情。"
    section_desc_label.text = "保存当前画面、剧情阶段与关键数值。" if is_save_mode else "选择一个已有存档，恢复当时的推进状态。"

    if is_save_mode:
        # 在显示弹窗前捕获当前画面，确保缩略图就是点击时的内容
        pre_captured_image = get_viewport().get_texture().get_image()
    else:
        pre_captured_image = null

    _update_popup_layout()
    refresh_list()
    show()

    background_panel.modulate.a = 0.0
    panel_root.modulate.a = 0.0
    panel_root.scale = Vector2(0.97, 0.97)
    _kill_panel_tween()
    _panel_tween = create_tween()
    _panel_tween.set_parallel(true)
    _panel_tween.tween_property(background_panel, "modulate:a", 1.0, 0.18)
    _panel_tween.tween_property(panel_root, "modulate:a", 1.0, 0.22)
    _panel_tween.tween_property(panel_root, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func hide_panel() -> void:
    if not visible:
        return

    _kill_panel_tween()
    _panel_tween = create_tween()
    _panel_tween.set_parallel(true)
    _panel_tween.tween_property(background_panel, "modulate:a", 0.0, 0.16)
    _panel_tween.tween_property(panel_root, "modulate:a", 0.0, 0.16)
    _panel_tween.tween_property(panel_root, "scale", Vector2(0.97, 0.97), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    _panel_tween.set_parallel(false)
    _panel_tween.tween_callback(hide)

func refresh_list() -> void:
    for child: Node in list_container.get_children():
        child.queue_free()

    var existing_slots: Array = GameDataManager.save_manager.get_save_slots()
    var slots_dict: Dictionary = {}
    for slot_data in existing_slots:
        slots_dict[slot_data.get("slot_id")] = slot_data

    var item_count: int = 0

    # 自动存档在读档模式下优先展示，保存模式下仅展示已有自动存档记录。
    var auto_meta: Dictionary = slots_dict.get("auto", {})
    if not auto_meta.is_empty() or not is_save_mode:
        var auto_item = SLOT_ITEM_SCENE.instantiate()
        list_container.add_child(auto_item)
        auto_item.setup("auto", auto_meta, is_save_mode)
        auto_item.slot_selected.connect(_on_slot_selected)
        if auto_item.has_signal("delete_requested"):
            auto_item.delete_requested.connect(refresh_list)
        item_count += 1

    for i in range(1, MAX_MANUAL_SLOTS + 1):
        var slot_id: String = "manual_" + str(i)
        var meta: Dictionary = slots_dict.get(slot_id, {})
        if not is_save_mode and meta.is_empty():
            continue

        var item = SLOT_ITEM_SCENE.instantiate()
        list_container.add_child(item)
        item.setup(slot_id, meta, is_save_mode)
        item.slot_selected.connect(_on_slot_selected)
        if item.has_signal("delete_requested"):
            item.delete_requested.connect(refresh_list)
        item_count += 1

    slot_count_label.text = "%d 个槽位" % item_count

func _on_close_pressed() -> void:
    hide_panel()

func _on_background_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        hide_panel()

func _on_panel_resized() -> void:
    if visible:
        _update_popup_layout()

func _update_popup_layout() -> void:
    var viewport_size: Vector2 = get_viewport_rect().size
    var target_size: Vector2 = POPUP_MIN_SIZE
    target_size.x = minf(target_size.x, viewport_size.x - 72.0)
    target_size.y = minf(target_size.y, viewport_size.y - 72.0)
    panel_root.custom_minimum_size = target_size
    panel_root.size = target_size
    panel_root.pivot_offset = target_size * 0.5

func _kill_panel_tween() -> void:
    if _panel_tween != null:
        _panel_tween.kill()
        _panel_tween = null

func _on_slot_selected(slot_id: String, is_empty: bool) -> void:
    if is_save_mode:
        if not is_empty:
            var confirm_scene = load("res://scenes/ui/common/confirm_dialog.tscn")
            if confirm_scene:
                var dialog = confirm_scene.instantiate()
                get_tree().get_root().add_child(dialog)
                dialog.setup("确定要覆盖这个存档吗？", "覆盖", "取消")
                dialog.confirmed.connect(func() -> void:
                    _execute_save(slot_id)
                )
        else:
            _execute_save(slot_id)
    else:
        var success: bool = GameDataManager.save_manager.load_game(slot_id)
        if success:
            hide_panel()
            get_tree().change_scene_to_file("res://scenes/ui/main/main_scene.tscn")

func _execute_save(slot_id: String) -> void:
    await GameDataManager.save_manager.save_game(slot_id, pre_captured_image)
    refresh_list()
    if ToastManager:
        ToastManager.show_system_toast("保存成功")
