extends Control

signal gift_sent(gift_id: String)

@onready var close_button: Button = $Panel/VBoxContainer/CloseButton
@onready var send_button: Button = $Panel/VBoxContainer/SendButton
@onready var grid_container: GridContainer = $Panel/VBoxContainer/ScrollContainer/GridContainer
@onready var detail_label: RichTextLabel = $Panel/VBoxContainer/DetailLabel
@onready var energy_label: Label = $Panel/VBoxContainer/EnergyLabel

var selected_gift_id: String = ""

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	send_button.pressed.connect(_on_send_pressed)
	_init_gift_list()

func show_panel() -> void:
	_update_ui()
	show()

func _update_ui() -> void:
	var profile = GameDataManager.profile
	energy_label.text = "当前精力：%.1f / %.1f" % [profile.current_energy, profile.max_energy]
	
	if selected_gift_id == "":
		detail_label.text = "请选择一件礼物..."
		send_button.disabled = true
	else:
		var gift = GameDataManager.gift_manager.get_gift_by_id(selected_gift_id)
		var text = "[b]%s[/b]\n" % gift.name
		text += "消耗精力：%d\n" % gift.get("cost", 0)
		text += "基础亲密：+%d | 基础信任：+%d\n" % [gift.get("base_intimacy", 0), gift.get("base_trust", 0)]
		text += "[color=#aaaaaa]%s[/color]" % gift.desc
		detail_label.text = text
		
		if profile.current_energy >= gift.get("cost", 0):
			send_button.disabled = false
		else:
			send_button.disabled = true
			detail_label.text += "\n[color=#ff4444](精力不足)[/color]"

func _init_gift_list() -> void:
	for child in grid_container.get_children():
		child.queue_free()
		
	var gifts = GameDataManager.gift_manager.get_all_gifts()
	for gift in gifts:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(120, 150)
		
		if gift.has("icon_path"):
			var icon_res = load(gift.icon_path)
			if icon_res:
				btn.icon = icon_res
				btn.expand_icon = true
				btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		
		btn.text = gift.name
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(_on_gift_pressed.bind(gift.id))
		grid_container.add_child(btn)

func _on_gift_pressed(gift_id: String) -> void:
	selected_gift_id = gift_id
	_update_ui()
	
	# 更新按钮高亮
	for child in grid_container.get_children():
		if child is Button:
			if child.text == GameDataManager.gift_manager.get_gift_by_id(gift_id).name:
				child.modulate = Color(1.2, 1.2, 1.2)
			else:
				child.modulate = Color(0.8, 0.8, 0.8)

func _on_send_pressed() -> void:
	if selected_gift_id != "":
		hide()
		gift_sent.emit(selected_gift_id)
		selected_gift_id = ""

func _on_close_pressed() -> void:
	hide()
