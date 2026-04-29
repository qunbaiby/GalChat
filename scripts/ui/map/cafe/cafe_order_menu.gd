extends CanvasLayer

var npc_id: String = "ya"

@onready var currency_label = $Panel/CurrencyLabel
@onready var coffee_vbox = $"Panel/TabContainer/咖啡/CoffeeVBox"
@onready var dessert_vbox = $"Panel/TabContainer/甜点/DessertVBox"

func _ready():
    _update_currency_label()
    _load_menu_data()

func _update_currency_label():
    var gold = GameDataManager.profile.gold
    currency_label.text = "余额: %d 银币" % gold

func _load_menu_data():
    var file = FileAccess.open("res://assets/data/map/cafe/cafe_menu.json", FileAccess.READ)
    if file:
        var data = JSON.parse_string(file.get_as_text())
        file.close()
        if data:
            _populate_list(coffee_vbox, data.get("coffee", []))
            _populate_list(dessert_vbox, data.get("dessert", []))

func _populate_list(vbox: VBoxContainer, items: Array):
    for item in items:
        var btn = Button.new()
        btn.custom_minimum_size = Vector2(0, 60)
        btn.text = "%s - %s银币\n[%s] %s" % [item.name, item.price, item.buff, item.desc]
        btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
        btn.pressed.connect(_on_item_ordered.bind(item))
        vbox.add_child(btn)

func _on_item_ordered(item: Dictionary):
    var price = int(item.get("price", 0))
    if GameDataManager.profile.gold < price:
        print("余额不足！")
        # 可以考虑弹一个Toast或者提示
        return
        
    print("Ordered: ", item.name)
    # 扣除货币并更新UI
    GameDataManager.profile.gold -= price
    GameDataManager.profile.save_profile()
    _update_currency_label()
    
    var popup_scene = load("res://scenes/ui/map/cafe/cafe_making_popup.tscn")
    if popup_scene:
        var popup = popup_scene.instantiate()
        popup.setup(item)
        get_tree().root.add_child(popup)
        
    queue_free()

func _on_close_button_pressed():
    queue_free()
