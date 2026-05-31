extends Control

const HISTORY_ITEM_SCENE = preload("res://scenes/ui/history/history_item.tscn")

@onready var history_title: Label = $MainPanel/HistoryTopBar/Margin/HBox/HistoryTitle
@onready var close_button: Button = $MainPanel/HistoryTopBar/Margin/HBox/HistoryCloseButton
@onready var scroll_container: ScrollContainer = $MainPanel/ScrollContainer
@onready var history_vbox: VBoxContainer = $MainPanel/ScrollContainer/Margin/VBoxContainer

signal play_voice_requested(cache_key: String)
signal panel_closed

var history_module: String = "daily"

func _ready() -> void:
    if close_button and not close_button.pressed.is_connected(_on_close_button_pressed):
        close_button.pressed.connect(_on_close_button_pressed)

func show_module(module_id: String) -> void:
    history_module = module_id
    _refresh_title()
    _populate_history()
    show()

func refresh() -> void:
    _refresh_title()
    _populate_history()

func _refresh_title() -> void:
    if history_title:
        history_title.text = GameDataManager.history.get_module_title(history_module)

func _populate_history() -> void:
    if not history_vbox:
        return

    for child in history_vbox.get_children():
        child.queue_free()

    var messages = GameDataManager.history.get_messages_by_module(history_module)
    for msg in messages:
        var item = HISTORY_ITEM_SCENE.instantiate()
        history_vbox.add_child(item)
        item.setup(msg)
        item.play_voice_requested.connect(_on_item_play_voice_requested)

    call_deferred("_scroll_to_bottom")

func _scroll_to_bottom() -> void:
    if not is_instance_valid(scroll_container):
        return
    var v_scroll = scroll_container.get_v_scroll_bar()
    if v_scroll:
        v_scroll.value = v_scroll.max_value

func _on_item_play_voice_requested(cache_key: String) -> void:
    play_voice_requested.emit(cache_key)

func _on_close_button_pressed() -> void:
    hide()
    panel_closed.emit()
