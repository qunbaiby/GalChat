extends CanvasLayer

signal enter_pressed(location_id: String, npc_id: String)
signal closed

@onready var main_panel = $MainPanel
@onready var thumbnail_rect = %ThumbnailRect
@onready var name_label = %NameLabel
@onready var desc_label = %DescLabel
@onready var npc_container = %NPCContainer
@onready var enter_button = %EnterButton
@onready var empty_npc_label = %EmptyNPCLabel

var location_id: String = ""
var selected_npc_id: String = ""

func _ready():
	$ColorRect.modulate.a = 0.0
	main_panel.position.x = 1280
	var tween = create_tween().set_parallel(true)
	tween.tween_property($ColorRect, "modulate:a", 1.0, 0.3)
	tween.tween_property(main_panel, "position:x", 1280 - 450, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	$ColorRect.gui_input.connect(_on_bg_gui_input)
	$MainPanel/TopBar/CloseButton.pressed.connect(close)
	enter_button.pressed.connect(_on_enter_pressed)

func setup(loc_id: String):
	location_id = loc_id
	var loc_data = MapDataManager.get_location(loc_id)
	if loc_data.is_empty(): return
	
	name_label.text = loc_data.get("name", "未知地点")
	desc_label.text = loc_data.get("description", "没有描述")
	
	var bg_id = loc_data.get("bg_id", loc_data.get("bg_path", ""))
	var real_path = ""
	if not bg_id.is_empty():
		real_path = ImageManager.get_image_path(bg_id)
		if real_path.is_empty():
			real_path = bg_id
			
	if not real_path.is_empty() and ResourceLoader.exists(real_path):
		thumbnail_rect.texture = load(real_path)
	
	_load_npcs()

func _load_npcs():
	for child in npc_container.get_children():
		child.queue_free()
		
	var npcs = MapDataManager.generate_location_npcs(location_id)
	if npcs.is_empty():
		empty_npc_label.show()
		npc_container.hide()
		selected_npc_id = ""
	else:
		empty_npc_label.hide()
		npc_container.show()
		
		var default_npc = null
		for i in range(npcs.size()):
			var n_id = npcs[i]
			var npc_btn = preload("res://scenes/ui/map/npc/quick_npc_portrait.tscn").instantiate()
			npc_container.add_child(npc_btn)
			
			# Scale down the portrait for this panel
			npc_btn.custom_minimum_size = Vector2(100, 130)
			var avatar_container = npc_btn.get_node("AvatarContainer")
			if avatar_container:
				avatar_container.custom_minimum_size = Vector2(100, 100)
			var name_lbl = npc_btn.get_node("NameLabel")
			if name_lbl:
				name_lbl.add_theme_font_size_override("font_size", 16)
			
			npc_btn.setup(n_id)
			npc_btn.npc_clicked.connect(_on_npc_selected.bind(npc_btn))
			
			if default_npc == null or MapDataManager.get_npc_data(n_id).get("type") == "resident":
				default_npc = {"id": n_id, "node": npc_btn}
				
		if default_npc:
			_on_npc_selected(default_npc.id, default_npc.node)

func _on_npc_selected(n_id: String, btn_node: Control):
	selected_npc_id = n_id
	for child in npc_container.get_children():
		if child.has_method("set_selected"):
			child.set_selected(child == btn_node)

func _on_enter_pressed():
	enter_pressed.emit(location_id, selected_npc_id)
	close()

func close():
	var tween = create_tween().set_parallel(true)
	tween.tween_property($ColorRect, "modulate:a", 0.0, 0.25)
	tween.tween_property(main_panel, "position:x", 1280, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.chain().tween_callback(queue_free)
	closed.emit()

func _on_bg_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()
