extends Control

@onready var background_panel: Panel = $Background
@onready var panel_root: PanelContainer = $CenterContainer/PanelRoot
@onready var title_label: Label = $CenterContainer/PanelRoot/MainMargin/RootVBox/TopBar/TitleLabel
@onready var mode_hint_label: Label = $CenterContainer/PanelRoot/MainMargin/RootVBox/TopBar/ModeHintLabel
@onready var mode_badge_label: Label = $CenterContainer/PanelRoot/MainMargin/RootVBox/BodyMargin/BodyVBox/ModeCard/ModeMargin/ModeHBox/ModeBadgePanel/ModeBadgeLabel
@onready var section_desc_label: Label = $CenterContainer/PanelRoot/MainMargin/RootVBox/BodyMargin/BodyVBox/ModeCard/ModeMargin/ModeHBox/ModeTextVBox/SectionDesc
@onready var close_btn: Button = $CenterContainer/PanelRoot/MainMargin/RootVBox/TopBar/BackButton
@onready var slot_count_label: Label = $CenterContainer/PanelRoot/MainMargin/RootVBox/BodyMargin/BodyVBox/ListCard/ListMargin/ListVBox/ListHeader/CountLabel
@onready var list_title_label: Label = $CenterContainer/PanelRoot/MainMargin/RootVBox/BodyMargin/BodyVBox/ListCard/ListMargin/ListVBox/ListHeader/ListTitle
@onready var list_hint_label: Label = $CenterContainer/PanelRoot/MainMargin/RootVBox/BodyMargin/BodyVBox/ListCard/ListMargin/ListVBox/ListHint
@onready var list_container: VBoxContainer = $CenterContainer/PanelRoot/MainMargin/RootVBox/BodyMargin/BodyVBox/ListCard/ListMargin/ListVBox/ScrollContainer/ListContainer

const SLOT_ITEM_SCENE: PackedScene = preload("res://scenes/ui/save_load/save_slot_item.tscn")
const POPUP_MIN_SIZE: Vector2 = Vector2(980, 620)

var _panel_tween: Tween = null
signal archive_slot_selected(slot_id: String, is_empty: bool)

func _ready() -> void:
    hide()
    close_btn.pressed.connect(_on_close_pressed)
    background_panel.gui_input.connect(_on_background_gui_input)
    resized.connect(_on_panel_resized)

func show_panel(_unused_mode: bool = false) -> void:
    title_label.text = "选择存档"
    mode_badge_label.text = "ARCHIVE"
    mode_hint_label.text = "每个档案都是独立世界线，自动存档会持续写入当前档案。"
    section_desc_label.text = "点击已有档案继续陪伴，点击空槽位新建档案。"
    list_title_label.text = "档案列表"
    list_hint_label.text = "第一行显示相处天数，第二行显示玩家与 Luna 当前阶段，第三行显示最后游玩时间。"
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

    var archive_slots: Array = GameDataManager.save_manager.get_save_slots()
    for i in range(archive_slots.size()):
        var slot_meta: Dictionary = archive_slots[i]
        var slot_id: String = str(slot_meta.get("slot_id", "slot_%d" % (i + 1)))
        var item = SLOT_ITEM_SCENE.instantiate()
        list_container.add_child(item)
        item.setup(i + 1, slot_id, slot_meta)
        item.slot_selected.connect(_on_slot_selected)
        if item.has_signal("delete_requested"):
            item.delete_requested.connect(_on_delete_requested)

    slot_count_label.text = "%d 个档案位" % archive_slots.size()

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
    archive_slot_selected.emit(slot_id, is_empty)

func _on_delete_requested(slot_id: String) -> void:
    var confirm_scene = load("res://scenes/ui/common/confirm_dialog.tscn")
    if confirm_scene == null:
        return
    var dialog = confirm_scene.instantiate()
    get_tree().root.add_child(dialog)
    dialog.setup_advanced(
        "清除记忆",
        "确认要清除这段记忆么？",
        "清除之后将无法再找回！！",
        "请输入指定文字后才能继续。",
        "清除记忆",
        "取消",
        "确认清除"
    )
    dialog.confirmed.connect(func() -> void:
        GameDataManager.save_manager.delete_save(slot_id)
        if is_instance_valid(dialog):
            dialog.queue_free()
        refresh_list()
    )
    dialog.canceled.connect(func() -> void:
        if is_instance_valid(dialog):
            dialog.queue_free()
    )

func refresh_after_archive_change() -> void:
    refresh_list()
