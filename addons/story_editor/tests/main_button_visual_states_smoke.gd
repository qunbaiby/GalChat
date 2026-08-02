extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene_resource := load("res://scenes/ui/main/main_scene.tscn") as PackedScene
	_expect(main_scene_resource != null, "主场景无法加载。")
	if main_scene_resource == null:
		_finish()
		return
	var main_scene := main_scene_resource.instantiate() as Control
	root.add_child(main_scene)
	await process_frame
	await process_frame
	var current_background := main_scene.get("current_bg_scene") as Control
	var compact_button_paths := [
		"UIPanel/BottomBarHBox/BtnHBox/DiaryButton",
		"UIPanel/BottomBarHBox/BtnHBox/CreationButton",
		"UIPanel/BottomBarHBox/BtnHBox/WeChatButton",
		"UIPanel/BottomBarHBox/BtnHBox/MainGiftButton"
	]
	var framed_button_paths := [
		"UIPanel/BottomBarHBox/ActionHBox/WardrobeButton",
		"UIPanel/BottomBarHBox/ActionHBox/MainActionButton",
		"UIPanel/DateButton"
	]
	for button_path in compact_button_paths:
		_validate_compact_button(main_scene.get_node(button_path) as Button)
	for button_path in framed_button_paths:
		_validate_framed_button(main_scene.get_node(button_path) as Button)
	for button_name in ["ChatButton", "MealButton", "RestButton"]:
		_validate_scene_button(current_background.get_node(button_name) as Button)
	var chat_button := current_background.get_node("ChatButton") as Button
	var chat_position := chat_button.position
	var chat_scale := chat_button.scale
	await create_timer(0.2).timeout
	_expect(chat_button.position == chat_position, "聊天按钮仍在上下晃动。")
	_expect(chat_button.scale == chat_scale, "聊天按钮仍在缩放浮动。")
	main_scene.queue_free()
	await process_frame
	_finish()


func _validate_compact_button(button: Button) -> void:
	_expect(button != null, "目标按钮不存在。")
	if button == null:
		return
	var content := button.get_node_or_null("ContentVBox") as VBoxContainer
	_expect(content != null, "%s 没有恢复上图标下文字布局。" % button.name)
	if content == null:
		return
	_expect(button.custom_minimum_size == Vector2(55, 55), "%s 没有恢复原按钮尺寸。" % button.name)
	var icon_node := content.get_node_or_null("Icon") as TextureRect
	var label_node := content.get_node_or_null("Label") as Label
	_expect(icon_node != null and icon_node.custom_minimum_size == Vector2(30, 30), "%s 没有恢复原图标尺寸。" % button.name)
	_expect(label_node != null and label_node.get_theme_font_size("font_size") == 12, "%s 没有恢复原文字尺寸。" % button.name)
	_validate_content_states(button, content)


func _validate_framed_button(button: Button) -> void:
	_expect(button != null, "目标按钮不存在。")
	if button == null:
		return
	var content := button.get_node_or_null("ContentHBox") as HBoxContainer
	_expect(content != null, "%s 缺少横排图标文字结构。" % button.name)
	if content == null:
		return
	for state_name in ["normal", "hover", "pressed", "disabled"]:
		_expect(not button.get_theme_stylebox(state_name) is StyleBoxEmpty, "%s 的 %s 平行四边形或梯形背景被移除。" % [button.name, state_name])
	_validate_content_states(button, content)


func _validate_scene_button(button: Button) -> void:
	_expect(button != null, "目标按钮不存在。")
	if button == null:
		return
	var content := button.get_node_or_null("ContentHBox") as HBoxContainer
	_expect(content != null, "%s 没有使用左图标右文字布局。" % button.name)
	if content == null:
		return
	_expect(button.size.is_equal_approx(Vector2(222.0404, 190.0)), "%s 没有在场景中放大到双倍尺寸。" % button.name)
	var icon_node := content.get_node_or_null("Icon") as TextureRect
	var label_node := content.get_node_or_null("Label") as Label
	_expect(icon_node != null and icon_node.custom_minimum_size == Vector2(60, 60), "%s 的图标没有同步放大。" % button.name)
	_expect(label_node != null and label_node.get_theme_font_size("font_size") == 34, "%s 的文字没有同步放大。" % button.name)
	for state_name in ["normal", "hover", "pressed", "disabled"]:
		_expect(button.get_theme_stylebox(state_name) is StyleBoxEmpty, "%s 的 %s 状态仍有背景底框。" % [button.name, state_name])
	_validate_content_states(button, content)


func _validate_content_states(button: Button, content: BoxContainer) -> void:
	var icon_node := content.get_node_or_null("Icon") as TextureRect
	var label_node := content.get_node_or_null("Label") as Label
	var button_rect := Rect2(Vector2.ZERO, button.size)
	var content_rect := Rect2(content.position, content.size)
	_expect(button_rect.encloses(content_rect), "%s 的图标文字超出按钮边界。" % button.name)
	_expect(icon_node != null and icon_node.material is ShaderMaterial, "%s 的图标没有状态描边阴影材质。" % button.name)
	_expect(label_node != null and label_node.get_theme_constant("outline_size") > 0, "%s 的文字没有描边。" % button.name)
	_expect(label_node != null and label_node.get_theme_constant("shadow_offset_x") > 0, "%s 的文字没有阴影。" % button.name)
	var state_script = content.get_script()
	_expect(state_script != null, "%s 没有接入四状态内容样式。" % button.name)
	if state_script != null:
		_expect(content.get("normal_color") != content.get("hover_color"), "%s 的正常与悬停颜色没有区分。" % button.name)
		_expect(content.get("hover_color") != content.get("pressed_color"), "%s 的悬停与点击颜色没有区分。" % button.name)
		_expect(content.get("disabled_color") != content.get("normal_color"), "%s 的禁用颜色没有区分。" % button.name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("MAIN_BUTTON_VISUAL_STATES_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("MAIN_BUTTON_VISUAL_STATES_SMOKE: %s" % failure)
	quit(1)