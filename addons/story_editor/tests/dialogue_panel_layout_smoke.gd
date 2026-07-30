extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var panel_scene := load("res://scenes/ui/common/dialogue_panel.tscn") as PackedScene
	_expect(panel_scene != null, "无法加载共用对话面板。")
	if panel_scene == null:
		_finish()
		return
	var panel := panel_scene.instantiate() as Control
	root.add_child(panel)
	root.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	var dialogue_vbox := panel.get_node("DialogueLayer/VBox") as VBoxContainer
	var dialogue_layer := panel.get_node("DialogueLayer") as Control
	var name_label := panel.get_node("DialogueLayer/VBox/NameLabel") as Label
	var divider := panel.get_node("DialogueLayer/VBox/NameDivider") as ColorRect
	var dialogue_text := panel.get_node("DialogueLayer/VBox/RichTextLabel") as RichTextLabel
	var quick_option_layer := panel.get_node("QuickOptionLayer") as Control
	var quick_options_container := panel.get_node("QuickOptionLayer/ScrollContainer/QuickOptions") as VBoxContainer
	var ai_option_layer := panel.get_node("AiPlayerOptionLayer") as Control
	var input_layer := panel.get_node("InputLayer") as Control
	var input_row := panel.get_node("InputLayer/HBoxContainer") as HBoxContainer
	var end_chat_button := panel.get_node("InputLayer/HBoxContainer/EndChatButton") as Button
	var input_field := panel.get_node("InputLayer/HBoxContainer/InputField") as TextEdit
	var continue_indicator := panel.get_node("DialogueLayer/ContinueIndicator") as Control
	var default_continue_indicator_position := continue_indicator.position
	var default_continue_indicator_size := continue_indicator.size
	var default_dialogue_offsets := Vector2(dialogue_layer.offset_top, dialogue_layer.offset_bottom)
	var default_dialogue_size := dialogue_layer.size
	var default_quick_option_size := quick_option_layer.size
	var default_ai_option_size := ai_option_layer.size
	var default_input_size := input_layer.size
	var default_name_font_size := name_label.get_theme_font_size("font_size")
	var default_dialogue_font_size := dialogue_text.get_theme_font_size("normal_font_size")
	_expect(dialogue_vbox.get_child(0) == name_label, "角色名不是对话内容的第一层。")
	_expect(dialogue_vbox.get_child(1) == divider, "角色名下方缺少分割线。")
	_expect(dialogue_vbox.get_child(2) == dialogue_text, "对话正文没有放在分割线下方。")
	_expect(not divider.visible, "没有角色名时仍然显示分割线。")
	name_label.text = "Luna"
	await process_frame
	_expect(divider.visible, "显示角色名时分割线没有出现。")
	name_label.text = " "
	await process_frame
	_expect(not divider.visible, "旁白空白角色名仍然显示分割线。")
	_expect(dialogue_text.global_position.y + dialogue_text.size.y <= ai_option_layer.global_position.y, "对话正文与 AI 玩家选项面板发生重叠。")
	panel.set_continue_indicator_visible(true)
	_expect(continue_indicator.visible, "下一句指示器无法显示。")
	_expect(panel._continue_indicator_tween != null and panel._continue_indicator_tween.is_valid(), "下一句指示器没有启动浮动动画。")
	panel.set_continue_indicator_visible(false)
	_expect(not continue_indicator.visible, "下一句指示器无法隐藏。")
	_expect(continue_indicator.position.is_equal_approx(default_continue_indicator_position), "下一句指示器动画没有恢复场景默认位置。")
	_expect(continue_indicator.size.is_equal_approx(default_continue_indicator_size), "下一句指示器动画改变了场景默认尺寸。")
	_expect(is_equal_approx(quick_option_layer.anchor_left, 0.5) and is_equal_approx(quick_option_layer.anchor_right, 0.5), "剧情与话题选项没有在屏幕中线居中。")
	_expect(ai_option_layer.position.y + ai_option_layer.size.y <= input_layer.position.y, "AI 玩家选项面板没有位于输入面板上方。")
	_expect(panel.ai_player_options_container.columns == 2, "AI 玩家选项面板不是单行双列。")
	_expect(input_row.get_child(0) == end_chat_button and input_row.get_child(1) == input_field, "结束对话按钮没有放在玩家输入框左侧。")
	var option_scene := load("res://scenes/ui/story/quick_option_item.tscn") as PackedScene
	var default_option := option_scene.instantiate() as Button
	var expected_option_minimum_size := default_option.custom_minimum_size
	var expected_option_font_size := (default_option.get_node("HBox/TextVBox/PrimaryLabel") as Label).get_theme_font_size("font_size")
	default_option.queue_free()
	var option_helper = load("res://scripts/ui/story/quick_option_list_helper.gd")
	option_helper.populate_option_items(quick_options_container, [{"text": "测试选项", "kind": "life"}], func(_text: String) -> void: pass)
	await process_frame
	var rendered_option := quick_options_container.get_child(0) as Button
	_expect(rendered_option.custom_minimum_size.is_equal_approx(expected_option_minimum_size), "选项渲染代码覆盖了场景默认尺寸。")
	_expect((rendered_option.get_node("HBox/TextVBox/PrimaryLabel") as Label).get_theme_font_size("font_size") == expected_option_font_size, "选项渲染代码覆盖了场景默认字号。")
	panel.set_story_mode(false)
	_expect(end_chat_button.visible, "日常对话模式没有显示输入框左侧的结束按钮。")
	_expect(Vector2(dialogue_layer.offset_top, dialogue_layer.offset_bottom).is_equal_approx(default_dialogue_offsets), "AI 对话模式覆盖了场景默认对话框位置。")
	panel.set_story_mode(true)
	_expect(not end_chat_button.visible, "剧情模式错误显示了结束对话按钮。")
	_expect(Vector2(dialogue_layer.offset_top, dialogue_layer.offset_bottom).is_equal_approx(default_dialogue_offsets + Vector2(60.0, 60.0)), "固定剧情模式没有基于场景默认位置等量下移对话框。")
	_expect(dialogue_layer.size.is_equal_approx(default_dialogue_size), "固定剧情模式改变了场景默认对话框尺寸。")
	_expect(quick_option_layer.size.is_equal_approx(default_quick_option_size), "模式切换改变了场景默认剧情选项层尺寸。")
	_expect(ai_option_layer.size.is_equal_approx(default_ai_option_size), "模式切换改变了场景默认 AI 选项层尺寸。")
	_expect(input_layer.size.is_equal_approx(default_input_size), "模式切换改变了场景默认输入层尺寸。")
	_expect(name_label.get_theme_font_size("font_size") == default_name_font_size, "模式切换改变了场景默认角色名字号。")
	_expect(dialogue_text.get_theme_font_size("normal_font_size") == default_dialogue_font_size, "模式切换改变了场景默认对话字号。")
	panel.set_story_mode(false)
	_expect(Vector2(dialogue_layer.offset_top, dialogue_layer.offset_bottom).is_equal_approx(default_dialogue_offsets), "退出固定剧情后没有恢复场景默认对话框位置。")
	panel.queue_free()
	await process_frame
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("DIALOGUE_PANEL_LAYOUT_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("DIALOGUE_PANEL_LAYOUT_SMOKE: %s" % failure)
	quit(1)
