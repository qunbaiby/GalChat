extends Control

@onready var bg_texture: TextureRect = $Background
@onready var name_label: Label = $MapInfoPanel/VBox/NameLabel
@onready var desc_label: Label = $MapInfoPanel/VBox/DescLabel
@onready var npc_container: HBoxContainer = $NPCContainer
@onready var back_button: Button = $BackButton

@onready var interaction_menu = $InteractionMenu
@onready var options_panel = $InteractionMenu/OptionsPanel
@onready var portrait_center = $InteractionMenu/PortraitCenter
@onready var menu_portrait_bg = $InteractionMenu/PortraitCenter/Portrait/PlaceholderBG
@onready var menu_name_label = $InteractionMenu/PortraitCenter/Portrait/NameLabel
@onready var character_layer = $InteractionMenu/CharacterLayer
@onready var menu_options_vbox = $InteractionMenu/OptionsPanel/VBoxContainer

@onready var dialogue_panel = $DialoguePanel
@onready var portrait_tex = $InteractionMenu/PortraitCenter/Portrait

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
					options_panel.show()
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
	
	var file = FileAccess.open(char_file_path, FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.get_data()
			if data is Dictionary:
				npc_name = data.get("char_name", npc_name)
				spine_path = data.get("spine_path", "")
				static_portrait_path = data.get("static_portrait", data.get("avatar", ""))
				
	menu_name_label.text = npc_name
	
	# 重置显示状态
	portrait_tex.texture = null
	portrait_tex.hide()
	menu_portrait_bg.show()
	if character_layer:
		character_layer.hide_character("none")
		
	var loaded_spine = false
	if not spine_path.is_empty() and ResourceLoader.exists(spine_path) and character_layer:
		character_layer.load_spine_by_path(spine_path)
		character_layer.show_character("none")
		loaded_spine = true
		menu_portrait_bg.hide()
			
	if not loaded_spine:
		portrait_tex.show()
		if not static_portrait_path.is_empty() and ResourceLoader.exists(static_portrait_path):
			portrait_tex.texture = load(static_portrait_path)
			menu_portrait_bg.hide()
		else:
			var npc_type = npc_data.get("type", "random")
			if npc_type == "resident":
				menu_portrait_bg.color = Color(0.4, 0.8, 0.4)
			else:
				if npc_id == "luna": menu_portrait_bg.color = Color(1.0, 0.5, 0.5)
				elif npc_id == "ya": menu_portrait_bg.color = Color(0.5, 0.5, 1.0)
				else: menu_portrait_bg.color = Color(0.8, 0.8, 0.8)

	# Clear existing buttons
	for child in menu_options_vbox.get_children():
		child.queue_free()

	# Generate dynamic interaction buttons based on NPC data
	var interactions = npc_data.get("interactions", [])
	if interactions.is_empty():
		interactions = [{"id": "chat", "label": "聊天"}, {"id": "leave", "label": "离开"}]

	for action in interactions:
		var btn = Button.new()
		btn.text = action.get("label", "未知操作")
		btn.add_theme_font_size_override("font_size", 20)
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
				options_panel.hide() # 仅隐藏右侧选项，保留角色和姓名
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
								options_panel.show()
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
		options_panel.show()

func _on_back_pressed():
	var world_map_scene = load("res://scenes/ui/map/core/world_map_scene.tscn")
	get_tree().change_scene_to_packed(world_map_scene)
