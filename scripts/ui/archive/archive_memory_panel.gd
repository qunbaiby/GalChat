extends Control

@onready var close_btn: Button = $Panel/VBoxContainer/TopBar/CloseButton
@onready var memory_list_container: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/MemoryListContainer


func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)


func show_panel(char_id: String = "") -> void:
	var target_char_id := char_id
	if target_char_id == "" and GameDataManager.config and GameDataManager.config.current_character_id != "":
		target_char_id = GameDataManager.config.current_character_id
	if target_char_id == "":
		target_char_id = "luna"

	_load_memory_archive(target_char_id)
	show()

	position.x = size.x
	modulate.a = 0.0
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


func _load_memory_archive(char_id: String) -> void:
	var mem_path = "user://saves/%s/player_memory.json" % char_id
	var mems = {"core": [], "emotion": [], "habit": [], "bond": []}
	if FileAccess.file_exists(mem_path):
		var file = FileAccess.open(mem_path, FileAccess.READ)
		var content = file.get_as_text()
		var json = JSON.new()
		if json.parse(content) == OK and json.data is Dictionary:
			var data = json.data
			for key in mems.keys():
				if data.has(key) and data[key] is Array:
					mems[key] = data[key]
	_update_memory_display(mems)


func _update_memory_display(mems: Dictionary) -> void:
	for child in memory_list_container.get_children():
		child.queue_free()

	_add_memory_category("核心记忆 (Core)", mems.get("core", []), Color("#ff6b81"))
	_add_memory_category("情绪记忆 (Emotion)", mems.get("emotion", []), Color("#1e90ff"))
	_add_memory_category("习惯记忆 (Habit)", mems.get("habit", []), Color("#ff4757"))
	_add_memory_category("羁绊记忆 (Bond)", mems.get("bond", []), Color("#fbc531"))


func _add_memory_category(title: String, items: Array, color: Color) -> void:
	if items.is_empty():
		return

	var header_panel = PanelContainer.new()
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = Color(0.12, 0.13, 0.15, 0.9)
	header_style.corner_radius_top_left = 8
	header_style.corner_radius_top_right = 8
	header_style.corner_radius_bottom_left = 8
	header_style.corner_radius_bottom_right = 8
	header_panel.add_theme_stylebox_override("panel", header_style)

	var header_margin = MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 15)
	header_margin.add_theme_constant_override("margin_top", 10)
	header_margin.add_theme_constant_override("margin_right", 15)
	header_margin.add_theme_constant_override("margin_bottom", 10)
	header_panel.add_child(header_margin)

	var header_vbox = VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 10)
	header_margin.add_child(header_vbox)

	var title_label = Label.new()
	title_label.text = "◆ " + title
	title_label.add_theme_color_override("font_color", color)
	title_label.add_theme_font_size_override("font_size", 16)
	header_vbox.add_child(title_label)

	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(1, 1, 1, 0.1)
	header_vbox.add_child(sep)

	var items_vbox = VBoxContainer.new()
	items_vbox.add_theme_constant_override("separation", 8)
	header_vbox.add_child(items_vbox)

	for item in items:
		var text := ""
		var timestamp := ""
		var is_bond := false
		var decay := 0.0

		if item is Dictionary:
			text = item.get("content", "")
			timestamp = item.get("story_time", "")
			if timestamp == "":
				timestamp = item.get("timestamp", "").split("T")[0]
			is_bond = item.get("is_bond_mark", false)
			decay = item.get("decay", 0.0)
		elif item is String:
			text = item

		var item_card = PanelContainer.new()
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color(0.18, 0.20, 0.23, 0.8)
		card_style.corner_radius_top_left = 6
		card_style.corner_radius_top_right = 6
		card_style.corner_radius_bottom_left = 6
		card_style.corner_radius_bottom_right = 6
		if is_bond:
			card_style.border_width_left = 2
			card_style.border_width_top = 2
			card_style.border_width_right = 2
			card_style.border_width_bottom = 2
			card_style.border_color = Color("#fbc531")
		item_card.add_theme_stylebox_override("panel", card_style)

		var card_margin = MarginContainer.new()
		card_margin.add_theme_constant_override("margin_left", 15)
		card_margin.add_theme_constant_override("margin_top", 10)
		card_margin.add_theme_constant_override("margin_right", 15)
		card_margin.add_theme_constant_override("margin_bottom", 10)
		item_card.add_child(card_margin)

		var card_hbox = HBoxContainer.new()
		card_hbox.add_theme_constant_override("separation", 15)
		card_margin.add_child(card_hbox)

		var time_vbox = VBoxContainer.new()
		card_hbox.add_child(time_vbox)

		var time_dot = Label.new()
		time_dot.text = "◆"
		time_dot.add_theme_color_override("font_color", Color("#7bed9f"))
		time_dot.add_theme_font_size_override("font_size", 12)
		time_dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		time_vbox.add_child(time_dot)

		var time_label = Label.new()
		time_label.text = timestamp.split(" ")[0] if " " in timestamp else timestamp
		time_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		time_label.add_theme_font_size_override("font_size", 14)
		time_vbox.add_child(time_label)

		var content_label = RichTextLabel.new()
		content_label.bbcode_enabled = true
		content_label.text = text
		content_label.fit_content = true
		content_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_label.add_theme_font_size_override("normal_font_size", 15)
		card_hbox.add_child(content_label)

		if is_bond:
			var bond_label = Label.new()
			bond_label.text = "✨羁绊印记"
			bond_label.add_theme_color_override("font_color", Color("#fbc531"))
			bond_label.add_theme_font_size_override("font_size", 12)
			card_hbox.add_child(bond_label)
		elif decay > 0.0:
			var decay_label = Label.new()
			decay_label.text = "遗忘: %d%%" % int(decay)
			decay_label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.4))
			decay_label.add_theme_font_size_override("font_size", 12)
			card_hbox.add_child(decay_label)

		items_vbox.add_child(item_card)

	memory_list_container.add_child(header_panel)


func _on_close_pressed() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:x", size.x, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(hide)
