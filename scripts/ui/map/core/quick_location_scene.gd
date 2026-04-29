extends Control

@onready var bg_texture: TextureRect = $Background
@onready var name_label: Label = $MapInfoPanel/VBox/NameLabel
@onready var desc_label: Label = $MapInfoPanel/VBox/DescLabel
@onready var npc_container: HBoxContainer = $NPCContainer
@onready var back_button: Button = $BackButton

@onready var interaction_menu = $InteractionMenu
@onready var info_and_options = $InteractionMenu/InfoAndOptions

@onready var menu_title_label = $InteractionMenu/InfoAndOptions/NPCInfoVBox/TitleLabel
@onready var menu_name_label = $InteractionMenu/InfoAndOptions/NPCInfoVBox/NameLabel
@onready var menu_stage_label = $InteractionMenu/InfoAndOptions/NPCInfoVBox/StageHBox/StageLabel
@onready var menu_hearts_label = $InteractionMenu/InfoAndOptions/NPCInfoVBox/HeartsLabel

@onready var character_layer = $InteractionMenu/CharacterLayer
@onready var menu_options_vbox = $InteractionMenu/InfoAndOptions/OptionsVBox

@onready var dialogue_panel = $DialoguePanel

var location_id: String = ""

var current_interacting_npc_id: String = ""

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	
	# 隐藏选项菜单和角色
	interaction_menu.hide()
	
	if dialogue_panel:
		dialogue_panel.hide()
		# 监听对话结束信号，以便恢复互动选项
		if dialogue_panel.has_signal("dialogue_finished"):
			dialogue_panel.dialogue_finished.connect(func():
				if current_interacting_npc_id != "":
					info_and_options.show()
			)
	
	if location_id != "":
		_load_location_data()

func _load_location_data():
	var loc_data = MapDataManager.get_location(location_id)
	if loc_data.is_empty():
		return
		
	name_label.text = loc_data.get("name", "未知地点")
	desc_label.text = loc_data.get("description", "没有描述")
	
	# 设置背景图
	var bg_path = loc_data.get("bg_path", "")
	if not bg_path.is_empty() and ResourceLoader.exists(bg_path):
		bg_texture.texture = load(bg_path)
	else:
		bg_texture.texture = null
	
	# Clear existing NPCs
	for child in npc_container.get_children():
		child.queue_free()
		
	var npcs = MapDataManager.generate_location_npcs(location_id)
	for npc_id in npcs:
		var portrait_scene = load("res://scenes/ui/map/npc/quick_npc_portrait.tscn")
		if portrait_scene:
			var npc_node = portrait_scene.instantiate()
			npc_container.add_child(npc_node)
			npc_node.setup(npc_id)
			npc_node.npc_clicked.connect(_on_npc_clicked)

func _on_npc_clicked(npc_id: String):
	current_interacting_npc_id = npc_id
	npc_container.hide()
	interaction_menu.show()
	back_button.hide() # 隐藏返回地图按钮
	
	var npc_data = MapDataManager.get_npc_data(npc_id)
	var npc_name = npc_data.get("name", npc_id)
	
	var char_file_path = "res://assets/data/characters/npc/" + npc_id + ".json"
	if npc_id == "luna":
		char_file_path = "res://assets/data/characters/luna.json"
		
	var spine_path = ""
	var static_portrait_path = ""
	var npc_title = "未知"
	
	var file = FileAccess.open(char_file_path, FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.get_data()
			if data is Dictionary:
				npc_name = data.get("char_name", npc_name)
				spine_path = data.get("spine_path", "")
				static_portrait_path = data.get("static_portrait", data.get("avatar", ""))
				npc_title = data.get("title", npc_title)
				
	menu_name_label.text = npc_name
	if npc_id == "luna":
		menu_title_label.text = "魔法少女" # 或从配置读取
	else:
		menu_title_label.text = npc_title
		
	# 好感度及情感阶段展示逻辑
	if npc_id == "luna":
		var profile = GameDataManager.profile
		var current_stage = profile.current_stage
		var conf = profile.get_current_stage_config()
		menu_stage_label.text = conf.get("stageTitle", "陌生人")
		
		# 构建爱心字符串 (根据当前阶段显示实心心，总共10颗心)
		var max_hearts = 10
		var filled_hearts = min(current_stage, max_hearts)
		var hearts_str = ""
		for i in range(max_hearts):
			if i < filled_hearts:
				hearts_str += "♥"
			else:
				hearts_str += "♡"
		menu_hearts_label.text = hearts_str
	else:
		# 默认非主角NPC的好感度展示
		menu_stage_label.text = "普通朋友"
		menu_hearts_label.text = "♥♡♡♡♡♡♡♡♡♡"
	
	# 重置显示状态
	if character_layer:
		character_layer.hide_character("none")
		
	var loaded_spine = false
	if not spine_path.is_empty() and ResourceLoader.exists(spine_path) and character_layer:
		character_layer.load_spine_by_path(spine_path)
		character_layer.show_character("none")
		loaded_spine = true
			
	if not loaded_spine:
		# Fallback: 如果没有 Spine，暂时不显示任何立绘
		pass

	# Clear existing buttons
	for child in menu_options_vbox.get_children():
		child.queue_free()

	# Generate dynamic interaction buttons based on NPC data
	var interactions = npc_data.get("interactions", [])
	if interactions.is_empty():
		interactions = [{"id": "chat", "label": "聊天"}, {"id": "leave", "label": "离开"}]

	for action in interactions:
		var btn = Button.new()
		var action_label = action.get("label", "未知操作")
		
		# 添加对应的图标前缀 (根据ID简单匹配)
		var icon_str = "💬 "
		match action.get("id", ""):
			"chat": icon_str = "💬 "
			"order": icon_str = "☕ "
			"gift": icon_str = "🎁 "
			"leave": icon_str = "🏃 "
			"interact": icon_str = "✨ "
			"invite", "date": icon_str = "💕 "
		
		btn.text = icon_str + action_label
		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85, 1))
		btn.add_theme_color_override("font_hover_color", Color(1, 0.9, 0.6, 1))
		
		# 样式设计
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.15, 0.2, 0.3, 0.8)
		style_normal.corner_radius_top_left = 25
		style_normal.corner_radius_top_right = 25
		style_normal.corner_radius_bottom_left = 25
		style_normal.corner_radius_bottom_right = 25
		style_normal.border_width_bottom = 2
		style_normal.border_width_top = 2
		style_normal.border_width_left = 2
		style_normal.border_width_right = 2
		style_normal.border_color = Color(0.8, 0.7, 0.4, 0.5) # 淡淡的金边
		style_normal.content_margin_left = 30
		style_normal.content_margin_right = 30
		style_normal.content_margin_top = 15
		style_normal.content_margin_bottom = 15
		
		var style_hover = style_normal.duplicate()
		style_hover.bg_color = Color(0.2, 0.25, 0.35, 0.9)
		style_hover.border_color = Color(1.0, 0.9, 0.5, 0.8) # 高亮的金边
		
		var style_pressed = style_normal.duplicate()
		style_pressed.bg_color = Color(0.1, 0.15, 0.25, 0.9)
		style_pressed.border_color = Color(0.6, 0.5, 0.3, 0.8)
		
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_pressed)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		btn.pressed.connect(_on_menu_action_pressed.bind(action.get("id", "")))
		menu_options_vbox.add_child(btn)

func _on_menu_action_pressed(action_id: String):
	match action_id:
		"chat":
			print("快捷模式 - 与 NPC: ", current_interacting_npc_id, " 聊天")
			interaction_menu.hide() # 隐藏互动选项
			# TODO: 触发聊天对话系统
		"order":
			print("快捷模式 - 与 NPC: ", current_interacting_npc_id, " 点单/服务")
			if current_interacting_npc_id == "ya":
				info_and_options.hide() # 仅隐藏右侧选项，保留角色和姓名
				var order_menu_scene = load("res://scenes/ui/map/cafe/cafe_order_menu.tscn")
				if order_menu_scene:
					var order_menu = order_menu_scene.instantiate()
					# 监听点单菜单的退出信号
					if order_menu.has_signal("tree_exited"):
						order_menu.tree_exited.connect(func(): 
							# 延迟一帧检测，防止 CafeMakingPopup 还没来得及加到场景树里
							await get_tree().process_frame
							
							# 1. 对话面板没有在显示
							# 2. 还在跟 NPC 互动
							# 3. 当前场景树中不存在 CafeMakingPopup (制作弹窗)
							var is_making = false
							for child in get_tree().root.get_children():
								if child.name == "CafeMakingPopup":
									is_making = true
									break
									
							if dialogue_panel and not dialogue_panel.visible and current_interacting_npc_id != "" and not is_making: 
								info_and_options.show()
						)
					get_tree().root.add_child(order_menu)
			else:
				# TODO: 其他 NPC 的互动
				pass
		"interact":
			print("快捷模式 - 与 NPC: ", current_interacting_npc_id, " 互动")
			interaction_menu.hide() # 隐藏互动选项
			# TODO: 触发特殊互动
		"gift":
			print("快捷模式 - 给 NPC: ", current_interacting_npc_id, " 送礼")
			interaction_menu.hide() # 隐藏互动选项
			# TODO: 打开送礼界面
		"leave":
			current_interacting_npc_id = ""
			interaction_menu.hide()
			npc_container.show()
			back_button.show() # 显示返回地图按钮
		_:
			print("快捷模式 - 未知操作: ", action_id)

func _on_dialogue_finished():
	# 当打字机专属台词结束后，恢复互动菜单显示
	if current_interacting_npc_id != "":
		info_and_options.show()

func _on_back_pressed():
	var world_map_scene = load("res://scenes/ui/map/core/world_map_scene.tscn")
	get_tree().change_scene_to_packed(world_map_scene)
