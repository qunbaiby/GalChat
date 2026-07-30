extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/ui/mobile/chat/mobile_contact_list.tscn") as PackedScene
	_expect(scene != null, "无法加载微聊联系人列表场景。")
	if scene == null:
		_finish()
		return

	var contact_list := scene.instantiate()
	root.add_child(contact_list)
	await process_frame
	_expect(not contact_list._item_map.is_empty(), "微聊联系人列表没有可测试的联系人。")
	if contact_list._item_map.is_empty():
		contact_list.queue_free()
		_finish()
		return

	var first_char_id := str(contact_list._item_map.keys()[0])
	var first_item: Button = contact_list._item_map[first_char_id]
	var first_instance_id := first_item.get_instance_id()
	contact_list.select_character(first_char_id, false)
	contact_list._load_contacts()

	_expect(contact_list._item_map.has(first_char_id), "刷新后联系人从列表消失。")
	if contact_list._item_map.has(first_char_id):
		var refreshed_item: Button = contact_list._item_map[first_char_id]
		_expect(refreshed_item.get_instance_id() == first_instance_id, "刷新未读状态时替换了联系人节点，会导致左侧列表跳闪。")
	_expect(contact_list._selected_char_id == first_char_id, "刷新后丢失了当前联系人选中状态。")

	contact_list.queue_free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("MOBILE_CONTACT_LIST_REFRESH_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)