@tool
extends Window

const WINDOW_LAYOUT_PATH := "res://addons/story_editor/core/editor_window_layout.gd"

var debug_store: RefCounted
var selected_session_id := -1

@onready var event_tree: Tree = %EventTree


func _ready() -> void:
	close_requested.connect(hide)
	%SessionSelect.item_selected.connect(_on_session_selected)
	%FilterEdit.text_changed.connect(_refresh_events)
	%ClearButton.pressed.connect(_clear_selected_session)
	event_tree.item_selected.connect(_show_selected_event)
	for column in 5:
		event_tree.set_column_title(column, ["序号", "事件", "来源", "剧情", "位置"][column])


func set_debug_store(value: RefCounted) -> void:
	if debug_store == value:
		return
	if debug_store != null:
		if debug_store.runtime_event_received.is_connected(_on_runtime_event):
			debug_store.runtime_event_received.disconnect(_on_runtime_event)
		if debug_store.runtime_session_changed.is_connected(_on_session_changed):
			debug_store.runtime_session_changed.disconnect(_on_session_changed)
	debug_store = value
	if debug_store != null:
		debug_store.runtime_event_received.connect(_on_runtime_event)
		debug_store.runtime_session_changed.connect(_on_session_changed)
	_refresh_sessions()


func open_monitor() -> void:
	(load(WINDOW_LAYOUT_PATH) as GDScript).new().open_window(self, Vector2i(1180, 720), Vector2i(780, 520))
	_refresh_sessions()


func _refresh_sessions() -> void:
	%SessionSelect.clear()
	if debug_store == null:
		selected_session_id = -1
		%Status.text = "调试接收器未连接"
		_refresh_events()
		return
	var session_ids: Array[int] = debug_store.get_session_ids()
	for session_id in session_ids:
		%SessionSelect.add_item("Session %d%s" % [session_id, " · 运行中" if debug_store.is_session_active(session_id) else " · 已停止"])
		%SessionSelect.set_item_metadata(%SessionSelect.item_count - 1, session_id)
	if not session_ids.is_empty():
		selected_session_id = session_ids[-1]
		%SessionSelect.select(session_ids.size() - 1)
	else:
		selected_session_id = -1
	%Status.text = "等待游戏调试进程发送剧情事件" if selected_session_id < 0 else "已接收 Session %d" % selected_session_id
	_refresh_events()


func _refresh_events(_unused: String = "") -> void:
	event_tree.clear()
	var root := event_tree.create_item()
	if debug_store == null or selected_session_id < 0:
		return
	var filter_text: String = %FilterEdit.text.strip_edges().to_lower()
	for event in debug_store.get_events(selected_session_id):
		var searchable := JSON.stringify(event).to_lower()
		if not filter_text.is_empty() and not searchable.contains(filter_text):
			continue
		var item := event_tree.create_item(root)
		item.set_text(0, str(event.get("sequence", "")))
		item.set_text(1, str(event.get("event", "")))
		var source := event.get("source", {}) as Dictionary
		item.set_text(2, "%s / %s" % [str(source.get("type", "")), str(source.get("id", ""))])
		var story := event.get("story", {}) as Dictionary
		item.set_text(3, str(story.get("script_id", story.get("script_path", ""))))
		var cursor := event.get("cursor", {}) as Dictionary
		item.set_text(4, "%s #%s %s" % [str(cursor.get("chapter_id", "")), str(cursor.get("event_index", "")), str(story.get("event_type", ""))])
		item.set_metadata(0, event)
	%Status.text = "Session %d · %d 条事件" % [selected_session_id, (event_tree.get_root().get_children() as Array).size()]


func _show_selected_event() -> void:
	var item := event_tree.get_selected()
	if item != null:
		%DetailText.text = JSON.stringify(item.get_metadata(0), "    ", false)


func _on_runtime_event(session_id: int, _event: Dictionary) -> void:
	if selected_session_id < 0:
		_refresh_sessions()
	elif session_id == selected_session_id:
		_refresh_events()


func _on_session_changed(_session_id: int, _active: bool) -> void:
	_refresh_sessions()


func _on_session_selected(index: int) -> void:
	selected_session_id = int(%SessionSelect.get_item_metadata(index))
	_refresh_events()


func _clear_selected_session() -> void:
	if debug_store != null and selected_session_id >= 0:
		debug_store.clear_session(selected_session_id)
		%DetailText.clear()
		_refresh_events()