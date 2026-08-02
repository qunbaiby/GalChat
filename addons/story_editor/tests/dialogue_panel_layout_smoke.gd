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
	var free_chat_info_layer := panel.get_node("FreeChatInfoLayer") as Control
	var free_chat_panel := panel.get_node("FreeChatInfoLayer/Panel") as PanelContainer
	var free_chat_round_label := panel.get_node("FreeChatInfoLayer/Panel/Margin/VBox/RoundLabel") as Label
	var toolbar := panel.get_node("ToolBarContainer") as PanelContainer
	var quick_option_layer := panel.get_node("QuickOptionLayer") as Control
	var quick_options_container := panel.get_node("QuickOptionLayer/ScrollContainer/QuickOptions") as VBoxContainer
	var ai_option_layer := panel.get_node("AiPlayerOptionLayer") as Control
	var ai_options_container := panel.get_node("AiPlayerOptionLayer/Margin/Content/OptionsGrid") as GridContainer
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
	var free_chat_style := free_chat_panel.get_theme_stylebox("panel") as StyleBoxFlat
	var toolbar_style := toolbar.get_theme_stylebox("panel") as StyleBoxFlat
	_expect(dialogue_vbox.get_child(0) == name_label, "角色名不是对话内容的第一层。")
	_expect(dialogue_vbox.get_child(1) == divider, "角色名下方缺少分割线。")
	_expect(dialogue_vbox.get_child(2) == dialogue_text, "对话正文没有放在分割线下方。")
	_expect(not divider.visible, "没有角色名时仍然显示分割线。")
	_expect(free_chat_info_layer.size.is_equal_approx(toolbar.size), "回合面板尺寸与 ToolBarContainer 不一致：回合面板=%s，工具栏=%s。" % [str(free_chat_info_layer.size), str(toolbar.size)])
	_expect(free_chat_style.bg_color == toolbar_style.bg_color and free_chat_style.shadow_color == toolbar_style.shadow_color and free_chat_style.shadow_size == toolbar_style.shadow_size and free_chat_style.shadow_offset == toolbar_style.shadow_offset, "回合面板的颜色或阴影与 ToolBarContainer 不一致。")
	_expect(free_chat_style.corner_radius_top_left == 30 and free_chat_style.corner_radius_top_right == 30 and free_chat_style.corner_radius_bottom_right == 30 and free_chat_style.corner_radius_bottom_left == 30, "回合面板没有使用四个一致的圆角。")
	_expect(free_chat_round_label.text == "对话轮次0/4", "回合面板没有使用单行紧凑文案。")
	_expect((free_chat_round_label.get_parent() as Control).get_child_count() == 1, "回合面板仍包含额外说明文字。")
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
	_expect((rendered_option.get_node("HBox/IconPanel") as Control).visible, "顶部话题选项错误隐藏了识别图标。")
	option_helper.populate_ai_reply_items_with_index(
		ai_options_container,
		[{"text": "我想再听你多说一点", "kind": "intimacy"}, {"text": "这件事可以相信我", "kind": "trust"}],
		func(_text: String, _index: int) -> void: pass
	)
	await process_frame
	var ai_reply_option := ai_options_container.get_child(0) as Button
	_expect(ai_reply_option.custom_minimum_size.is_equal_approx(Vector2(0.0, 54.0)), "AI 玩家选项没有使用紧凑的双列尺寸。")
	_expect(absf(ai_reply_option.get_global_rect().get_center().y - ai_option_layer.get_global_rect().get_center().y) <= 1.0, "AI 玩家选项没有在 AiPlayerOptionLayer 中垂直居中。")
	_expect(not (ai_reply_option.get_node("HBox/IconPanel") as Control).visible, "AI 玩家选项仍显示厚重图标块。")
	_expect(not (ai_reply_option.get_node("HBox/Divider") as Control).visible, "AI 玩家选项仍显示菜单式分割线。")
	_expect((ai_reply_option.get_node("HBox/AccentBar") as Control).visible, "AI 玩家选项缺少轻量语义色条。")
	_expect(ai_reply_option.get_presentation_mode() == "ai_reply", "AI 玩家选项没有进入专属展示模式。")
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
	var main_scene_resource := load("res://scenes/ui/main/main_scene.tscn") as PackedScene
	_expect(main_scene_resource != null, "无法加载主场景以验证回合面板引导高亮。")
	if main_scene_resource != null:
		var main_scene := main_scene_resource.instantiate()
		root.add_child(main_scene)
		await process_frame
		await process_frame
		var main_round_info := main_scene.dialogue_panel.get_node("FreeChatInfoLayer") as Control
		main_scene.dialogue_panel.show()
		main_round_info.show()
		await process_frame
		var round_focus_entry: Dictionary = main_scene.get_ai_round_info_focus_entry()
		var round_focus_rect: Rect2 = round_focus_entry.get("rect", Rect2())
		var round_shape_params: Dictionary = round_focus_entry.get("shape_params", {})
		_expect(round_focus_rect.is_equal_approx(main_round_info.get_global_rect()), "AI 主线回合引导高亮没有跟随新回合面板的实时尺寸。")
		_expect(str(round_focus_entry.get("shape", "")) == "rect" and is_equal_approx(float(round_shape_params.get("corner_radius", 0.0)), 20.0), "AI 主线回合引导高亮没有使用匹配面板的圆角矩形。")
		main_scene.queue_free()
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
