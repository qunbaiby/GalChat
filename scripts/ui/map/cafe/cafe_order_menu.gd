extends CanvasLayer

signal closing_started

const CAFE_MENU_SECTION_SCENE = preload("res://scenes/ui/map/cafe/cafe_menu_section.tscn")
const CAFE_MENU_ITEM_CARD_SCENE = preload("res://scenes/ui/map/cafe/cafe_menu_item_card.tscn")

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
				_add_category_section("咖 啡", data.get("coffee", []))
			
			if data.has("dessert"):
				_add_category_section("甜 点", data.get("dessert", []))

func _add_category_section(title: String, items: Array) -> void:
	var section = CAFE_MENU_SECTION_SCENE.instantiate()
	var title_label := section.get_node("Header/TitleLabel") as Label
	var item_grid := section.get_node("ItemGrid") as GridContainer
	if title_label:
		title_label.text = title
	list_vbox.add_child(section)
	if item_grid == null:
		return
	for item in items:
		var card = CAFE_MENU_ITEM_CARD_SCENE.instantiate()
		item_grid.add_child(card)
		if card and card.has_method("setup"):
			card.setup(item)
		if card and card.has_signal("card_pressed"):
			card.card_pressed.connect(_on_item_selected)
		_item_nodes.append({"node": card, "data": item})

func _on_item_selected(item: Dictionary, card_node: Control):
	_selected_item = item

	for entry in _item_nodes:
		var node = entry["node"]
		if node and node.has_method("set_selected"):
			node.set_selected(node == card_node)
			
	empty_label.hide()
	detail_vbox.show()
	
	name_label.text = "▪ " + item.name
	desc_label.text = item.desc
	
	if item.has("icon") and FileAccess.file_exists(item.icon):
		preview_rect.texture = load(item.icon)
	else:
		preview_rect.texture = load("res://assets/images/ui/creation/cafe_break.png")
		
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
		
	closing_started.emit()
	var tween = create_tween()
	tween.tween_property($MainPanel, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)

func _on_close_button_pressed():
	closing_started.emit()
	var tween = create_tween()
	tween.tween_property($MainPanel, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)
