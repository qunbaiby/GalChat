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
	var gift_button := main_scene.get_node("UIPanel/BottomBarHBox/BtnHBox/MainGiftButton") as Button
	var wardrobe_button := main_scene.get_node("UIPanel/BottomBarHBox/ActionHBox/WardrobeButton") as Button
	var date_button := main_scene.get_node("UIPanel/DateButton") as Button
	var current_background := main_scene.get("current_bg_scene") as Control
	var rest_button := current_background.get_node("RestButton") as Button
	var outing_button := main_scene.get_node("UIPanel/BottomBarHBox/ActionHBox/MainActionButton") as Button
	var gift_overlay := main_scene.get_node("UIPanel/GiftOverlay") as Control
	var affection_overlay := main_scene.get_node("UIPanel/AffectionOverlay") as Control
	var gift_frame := main_scene.get_node("UIPanel/GiftOverlay/PopupCenter/GiftPopupFrame") as Control
	var affection_frame := main_scene.get_node("UIPanel/AffectionOverlay/PopupCenter/AffectionPopupFrame") as Control
	var gift_dimmer := main_scene.get_node("UIPanel/GiftOverlay/Dimmer") as ColorRect
	var affection_dimmer := main_scene.get_node("UIPanel/AffectionOverlay/Dimmer") as ColorRect
	var guide_manager_source := FileAccess.get_file_as_string("res://scripts/data/guide_manager.gd")
	var guide_flow_source := FileAccess.get_file_as_string("res://assets/data/guide/guide_flows.json")
	var main_scene_source := FileAccess.get_file_as_string("res://scripts/ui/main/main_scene.gd")
	_expect(not guide_manager_source.contains('"main.gift": "UIPanel/'), "礼物按钮仍注册在引导高亮路径中。")
	_expect(not guide_flow_source.contains('"highlight_feature": "main.gift"'), "礼物按钮引导步骤仍未移除。")
	_expect(guide_manager_source.contains('"main.wardrobe": "UIPanel/BottomBarHBox/ActionHBox/WardrobeButton"'), "服装引导没有迁移到原休息按钮槽位。")
	_expect(guide_manager_source.contains('"main.gift": true'), "礼物按钮没有配置为初始锁定。")
	_expect(main_scene_source.contains('_register_compound_feature_lock_view("main.gift"'), "礼物按钮没有接入主场景功能锁视图。")
	_expect(main_scene.get_node_or_null("UIPanel/BottomBarHBox/BtnHBox/DiaryButton") != null, "主场景日记按钮仍使用混淆名称。")
	_expect(main_scene.get_node_or_null("UIPanel/BottomBarHBox/BtnHBox/CreationButton") != null, "主场景创作按钮仍使用日记按钮名称。")
	_expect(gift_button.get_parent().name == "BtnHBox", "礼物按钮没有移动到底栏原服装槽位。")
	_expect(wardrobe_button.get_parent().name == "ActionHBox", "服装按钮没有放进原休息按钮槽位。")
	_expect(wardrobe_button.size == Vector2(110, 60), "服装按钮没有使用原休息按钮大小。")
	_expect(date_button.position == Vector2(1065, 580) and date_button.size == Vector2(210, 60), "约会按钮没有迁移到原服装按钮位置。")
	_expect(rest_button.get_parent() == current_background and rest_button.get_parent() == current_background.get_node("ChatButton").get_parent(), "休息按钮没有像聊天按钮一样直接放在背景场景根节点。")
	_expect(rest_button.icon != null and rest_button.text == "休息", "背景休息按钮缺少场景配置的图标或文字。")
	var background_paths := [
		"res://scenes/ui/main/backgrounds/locations/default_room_bg.tscn",
		"res://scenes/ui/main/backgrounds/locations/art_studio_bg.tscn",
		"res://scenes/ui/main/backgrounds/locations/class_break_moments_bg.tscn",
		"res://scenes/ui/main/backgrounds/locations/holiday_pool_days_bg.tscn",
		"res://scenes/ui/main/backgrounds/locations/piano_room_bg.tscn"
	]
	for background_path in background_paths:
		var background_scene := load(background_path) as PackedScene
		var background_instance := background_scene.instantiate()
		var scene_rest_button := background_instance.get_node_or_null("RestButton") as Button
		_expect(scene_rest_button != null, "%s 没有直接配置根级休息按钮。" % background_path)
		background_instance.free()
	for content_button in [outing_button, wardrobe_button, date_button]:
		_expect(content_button.icon == null and content_button.text == "", "%s 仍在使用按钮原生图标或文字。" % content_button.name)
		var content := content_button.get_node_or_null("ContentHBox") as HBoxContainer
		var icon_node := content.get_node_or_null("Icon") as TextureRect if content != null else null
		var label_node := content.get_node_or_null("Label") as Label if content != null else null
		_expect(content != null and icon_node != null and label_node != null, "%s 缺少紧凑图标文字子节点。" % content_button.name)
		if label_node != null:
			var initial_text_color := label_node.get_theme_color("font_color")
			_expect(initial_text_color.get_luminance() < 0.25 and initial_text_color.a == 1.0, "%s 的场景初始文字颜色在浅色按钮上不可见。" % content_button.name)
		if icon_node != null:
			_expect(icon_node.self_modulate.get_luminance() < 0.25 and icon_node.self_modulate.a == 1.0, "%s 的场景初始图标颜色在浅色按钮上不可见。" % content_button.name)
		if content != null:
			var local_rect := Rect2(Vector2.ZERO, content_button.size)
			var content_rect := Rect2(content.position, content.size)
			_expect(local_rect.encloses(content_rect), "%s 的图标文字内容跑出了按钮范围。" % content_button.name)
			_expect(content.get_theme_constant("separation") <= 7, "%s 的图标文字间距不够紧凑。" % content_button.name)
	_expect(gift_overlay.get_parent() == affection_overlay.get_parent(), "礼物面板仍依附于情感面板。")
	_expect(gift_frame.custom_minimum_size == affection_frame.custom_minimum_size, "礼物面板尺寸没有与情感面板保持一致。")
	_expect(gift_dimmer.material == null and gift_dimmer.color.a == 0.0, "礼物面板仍有半透明模糊背景。")
	_expect(affection_dimmer.material == null and affection_dimmer.color.a == 0.0, "情感面板仍有半透明模糊背景。")
	main_scene.call("_open_gift_panel")
	await process_frame
	_expect(gift_overlay.visible, "主场景礼物按钮没有打开独立礼物面板。")
	_expect(gift_overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "透明礼物 Overlay 没有拦截主场景输入。")
	_expect(not bool(main_scene.call("_has_fullscreen_main_overlay")), "礼物面板错误触发了主场景音乐暂停判定。")
	var gift_panel = main_scene.get("gift_panel_instance")
	_expect(is_instance_valid(gift_panel) and gift_panel.get_parent() == main_scene.get_node("UIPanel/GiftOverlay/PopupCenter/GiftPopupFrame"), "礼物面板没有挂载到独立 GiftOverlay。")
	var affection_scene := load("res://scenes/ui/main/affection_panel.tscn") as PackedScene
	var affection_panel := affection_scene.instantiate()
	_expect(affection_panel.get_node_or_null("RootMargin/RootVBox/ContentVBox/MainHBox/VisualColumn/GiftButton") == null, "情感面板仍包含礼物按钮。")
	affection_panel.free()
	main_scene.call("_hide_gift_popup")
	await create_timer(0.25).timeout
	var dialogue_panel := main_scene.get_node("DialoguePanel") as Control
	main_scene.call("_on_realize_turn_completed", {
		"segments": [{"speech": "谢谢你送我的礼物，我会好好珍惜。"}]
	}, {"display_mode": "main_bubble", "event_kind": "gift_reaction"})
	await process_frame
	var bubble_label := current_background.get_node_or_null("IdleQuoteBubble/Label") as RichTextLabel if is_instance_valid(current_background) else null
	_expect(not dialogue_panel.visible, "送礼回复错误打开了完整主对话面板。")
	_expect(bubble_label != null and bubble_label.text.contains("谢谢你送我的礼物"), "送礼回复没有显示在主场景人物气泡中。")
	main_scene.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("MAIN_GIFT_PANEL_BUBBLE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("MAIN_GIFT_PANEL_BUBBLE_SMOKE: %s" % failure)
	quit(1)