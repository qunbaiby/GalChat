extends Panel

signal back_requested
signal play_voice_requested(cache_key: String)

const HISTORY_ITEM_SCENE: PackedScene = preload("res://scenes/ui/history/history_item.tscn")
const MODULE_ID := "desktop_pet"
const PANEL_TITLE := "桌宠陪伴记录"
const EMPTY_STATE_TEXT := "这里还没有新的桌宠陪伴记录\n继续聊天、戳一戳或触发观察后，这里会在这里整理你和 Luna 的日常互动。"

@onready var title_label: Label = $RootMargin/RootVBox/TopBar/TopBarMargin/TopBar/TitleVBox/Title
@onready var close_btn: Button = $RootMargin/RootVBox/TopBar/TopBarMargin/TopBar/CloseButton
@onready var scroll_container: ScrollContainer = $RootMargin/RootVBox/ContentPanel/ContentMargin/ContentRoot/ScrollContainer
@onready var history_list: VBoxContainer = $RootMargin/RootVBox/ContentPanel/ContentMargin/ContentRoot/ScrollContainer/Margin/HistoryList
@onready var empty_state_label: Label = $RootMargin/RootVBox/ContentPanel/ContentMargin/ContentRoot/EmptyStateLabel

func _ready() -> void:
	hide()
	if is_instance_valid(title_label):
		title_label.text = PANEL_TITLE
	if is_instance_valid(empty_state_label):
		empty_state_label.text = EMPTY_STATE_TEXT
	if is_instance_valid(close_btn) and not close_btn.pressed.is_connected(_on_back_pressed):
		close_btn.pressed.connect(_on_back_pressed)

func show_panel() -> void:
	refresh()
	show()

func hide_panel() -> void:
	hide()

func refresh() -> void:
	_populate_history()

func _populate_history() -> void:
	if not is_instance_valid(history_list):
		return
	for child in history_list.get_children():
		child.queue_free()

	var messages: Array = []
	if GameDataManager != null and GameDataManager.history != null:
		messages = GameDataManager.history.get_messages_by_module(MODULE_ID)

	if is_instance_valid(empty_state_label):
		empty_state_label.visible = messages.is_empty()
		empty_state_label.text = EMPTY_STATE_TEXT

	for msg in messages:
		var item = HISTORY_ITEM_SCENE.instantiate()
		history_list.add_child(item)
		item.setup(msg)
		item.play_voice_requested.connect(_on_item_play_voice_requested)

	call_deferred("_scroll_to_bottom")

func _scroll_to_bottom() -> void:
	if not is_instance_valid(scroll_container):
		return
	var bar := scroll_container.get_v_scroll_bar()
	if bar != null:
		bar.value = bar.max_value

func _on_item_play_voice_requested(cache_key: String) -> void:
	play_voice_requested.emit(cache_key)

func _on_back_pressed() -> void:
	back_requested.emit()
