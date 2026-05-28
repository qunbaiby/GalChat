extends CanvasLayer

var npc_id: String = "ya"

@onready var currency_label = %CurrencyLabel
@onready var list_vbox = %ListVBox
@onready var detail_vbox = %DetailVBox
@onready var empty_label = %EmptyLabel
@onready var name_label = %NameLabel
@onready var desc_label = %DescLabel
@onready var preview_rect = %PreviewRect
@onready var tag_label = %TagLabel
@onready var price_value = %PriceValue
@onready var buy_button = %BuyButton
@onready var close_button = $MainPanel/TopBar/CloseButton

var _selected_item: Dictionary = {}
var _item_nodes: Array = []

func _ready():
	detail_vbox.hide()
	empty_label.show()
	
	$MainPanel.modulate.a = 0.0
	create_tween().tween_property($MainPanel, "modulate:a", 1.0, 0.3)
	
	close_button.pressed.connect(_on_close_button_pressed)
	buy_button.pressed.connect(_on_buy_pressed)
	
	_update_currency_label()
	_load_menu_data()

func _update_currency_label():
	var gold = GameDataManager.profile.gold
	currency_label.text = "当前银币：%d" % gold

func _load_menu_data():
	var file = FileAccess.open("res://assets/data/map/cafe/cafe_menu.json", FileAccess.READ)
	if file:
		var data = JSON.parse_string(file.get_as_text())
		file.close()
		if data:
			if data.has("coffee"):
				_add_category_separator("咖 啡")
				_populate_grid(data.get("coffee", []))
			
			if data.has("dessert"):
				_add_category_separator("甜 点")
				_populate_grid(data.get("dessert", []))

func _add_category_separator(title: String):
	var hbox = HBoxContainer.new()
	var sep_style = StyleBoxLine.new()
	sep_style.color = Color(0.8, 0.8, 0.8, 1)
	sep_style.thickness = 2
	
	var sep1 = HSeparator.new()
	sep1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sep1.add_theme_stylebox_override("separator", sep_style)
	
	var lbl = Label.new()
	lbl.text = title
	lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	lbl.add_theme_font_size_override("font_size", 18)
	
	var sep2 = HSeparator.new()
	sep2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sep2.add_theme_stylebox_override("separator", sep_style)
	
	hbox.add_child(sep1)
	hbox.add_child(lbl)
	hbox.add_child(sep2)
	list_vbox.add_child(hbox)

func _populate_grid(items: Array):
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 15)
	grid.add_theme_constant_override("v_separation", 15)
	list_vbox.add_child(grid)
	
	for item in items:
		var card = _create_item_card(item)
		grid.add_child(card)
		_item_nodes.append({"node": card, "data": item})

func _create_item_card(item: Dictionary) -> Control:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(160, 200)
	btn.flat = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(1, 1, 1, 1)
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_right = 8
	normal_style.corner_radius_bottom_left = 8
	normal_style.shadow_color = Color(0, 0, 0, 0.05)
	normal_style.shadow_size = 5
	panel.add_theme_stylebox_override("panel", normal_style)
	
	btn.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)
	
	var top_margin = MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 10)
	top_margin.add_theme_constant_override("margin_top", 20)
	top_margin.add_theme_constant_override("margin_right", 10)
	top_margin.add_theme_constant_override("margin_bottom", 10)
	top_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(top_margin)
	
	var img_panel = PanelContainer.new()
	var img_style = StyleBoxFlat.new()
	img_style.bg_color = Color(0.95, 0.95, 0.95, 1)
	img_style.border_width_left = 2
	img_style.border_width_top = 2
	img_style.border_width_right = 2
	img_style.border_width_bottom = 2
	img_style.border_color = Color(0.4, 0.7, 0.4, 1)
	img_panel.add_theme_stylebox_override("panel", img_style)
	top_margin.add_child(img_panel)
	
	var img = TextureRect.new()
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.custom_minimum_size = Vector2(0, 100)
	if item.has("icon") and FileAccess.file_exists(item.icon):
		img.texture = load(item.icon)
	else:
		img.texture = load("res://assets/images/activities/cafe_break.png")
	img_panel.add_child(img)
	
	var qty_lbl = Label.new()
	qty_lbl.text = "x1"
	qty_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	qty_lbl.add_theme_font_size_override("font_size", 14)
	var qty_bg = ColorRect.new()
	qty_bg.color = Color(0, 0, 0, 0.5)
	qty_bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	qty_bg.custom_minimum_size = Vector2(30, 20)
	qty_bg.offset_left = -30
	qty_bg.offset_top = -20
	qty_bg.add_child(qty_lbl)
	qty_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	img_panel.add_child(qty_bg)
	
	var name_lbl = Label.new()
	name_lbl.text = item.name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.custom_minimum_size = Vector2(0, 30)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)
	
	var price_panel = PanelContainer.new()
	price_panel.custom_minimum_size = Vector2(0, 40)
	var price_style = StyleBoxFlat.new()
	price_style.bg_color = Color(0.3, 0.3, 0.3, 1)
	price_style.corner_radius_bottom_right = 8
	price_style.corner_radius_bottom_left = 8
	price_panel.add_theme_stylebox_override("panel", price_style)
	vbox.add_child(price_panel)
	
	var price_hbox = HBoxContainer.new()
	price_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	price_panel.add_child(price_hbox)
	
	var coin_lbl = Label.new()
	coin_lbl.text = "◎"
	coin_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	price_hbox.add_child(coin_lbl)
	
	var price_lbl = Label.new()
	price_lbl.text = str(item.price)
	price_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	price_lbl.add_theme_font_size_override("font_size", 18)
	price_hbox.add_child(price_lbl)
	
	btn.pressed.connect(_on_item_selected.bind(item, btn))
	return btn

func _on_item_selected(item: Dictionary, btn_node: Control):
	_selected_item = item
	
	var selected_style = StyleBoxFlat.new()
	selected_style.bg_color = Color(0.9, 0.95, 1, 1)
	selected_style.border_width_left = 2
	selected_style.border_width_top = 2
	selected_style.border_width_right = 2
	selected_style.border_width_bottom = 2
	selected_style.border_color = Color(0.3, 0.7, 1, 1)
	selected_style.corner_radius_top_left = 8
	selected_style.corner_radius_top_right = 8
	selected_style.corner_radius_bottom_right = 8
	selected_style.corner_radius_bottom_left = 8
	
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(1, 1, 1, 1)
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_right = 8
	normal_style.corner_radius_bottom_left = 8
	normal_style.shadow_color = Color(0, 0, 0, 0.05)
	normal_style.shadow_size = 5
	
	for entry in _item_nodes:
		var node = entry["node"]
		var panel = node.get_child(0) as PanelContainer
		if node == btn_node:
			panel.add_theme_stylebox_override("panel", selected_style)
		else:
			panel.add_theme_stylebox_override("panel", normal_style)
			
	empty_label.hide()
	detail_vbox.show()
	
	name_label.text = "▪ " + item.name
	desc_label.text = item.desc
	
	if item.has("icon") and FileAccess.file_exists(item.icon):
		preview_rect.texture = load(item.icon)
	else:
		preview_rect.texture = load("res://assets/images/activities/cafe_break.png")
		
	if item.has("buff") and item.buff != "":
		tag_label.text = " ☺ " + item.buff + " "
		tag_label.show()
	else:
		tag_label.hide()
		
	price_value.text = str(item.price)
	
	var can_afford = GameDataManager.profile.gold >= item.price
	buy_button.disabled = not can_afford
	if can_afford:
		buy_button.text = "购 买"
	else:
		buy_button.text = "余额不足"

func _on_buy_pressed():
	if _selected_item.is_empty(): return
	
	var price = int(_selected_item.get("price", 0))
	if GameDataManager.profile.gold < price:
		return
		
	GameDataManager.profile.gold -= price
	GameDataManager.profile.save_profile()
	_update_currency_label()
	
	var popup_scene = load("res://scenes/ui/map/cafe/cafe_making_popup.tscn")
	if popup_scene:
		var popup = popup_scene.instantiate()
		popup.setup(_selected_item)
		get_tree().root.add_child(popup)
		
	var tween = create_tween()
	tween.tween_property($MainPanel, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)

func _on_close_button_pressed():
	var tween = create_tween()
	tween.tween_property($MainPanel, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)
