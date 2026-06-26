extends CanvasLayer

signal enter_pressed(location_id: String, npc_id: String)
signal closed

@onready var main_panel: Panel = $MainPanel
@onready var thumbnail_rect: TextureRect = $MainPanel/ThumbnailPanel/Mask/ThumbnailRect
@onready var name_label: Label = $MainPanel/ThumbnailPanel/Mask/Margin/NameLabel
@onready var desc_label: Label = $MainPanel/Margin/VBox/DescLabel
@onready var npc_container: HBoxContainer = $MainPanel/Margin/VBox/ScrollContainer/NPCContainer
@onready var enter_button: Button = $MainPanel/Margin/VBox/EnterButton
@onready var empty_npc_label: Label = $MainPanel/Margin/VBox/EmptyNPCLabel
@onready var color_rect: ColorRect = $ColorRect
@onready var close_button: Button = $MainPanel/TopBar/CloseButton
@onready var content_vbox: VBoxContainer = $MainPanel/Margin/VBox

var location_id: String = ""
var selected_npc_id: String = ""
var story_hint_label: Label = null

func _ready():
	color_rect.modulate.a = 0.0
	main_panel.position.x = 1280
	var tween = create_tween()
	tween.tween_property(main_panel, "position:x", get_viewport().get_visible_rect().size.x - 450, 0.3).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(color_rect, "modulate:a", 1.0, 0.3)

	if is_instance_valid(color_rect):
		color_rect.gui_input.connect(_on_bg_gui_input)
	if is_instance_valid(close_button):
		close_button.pressed.connect(close)
	else:
		push_error("[LocationDetailPanel] CloseButton 节点不存在")
	if is_instance_valid(enter_button):
		enter_button.pressed.connect(_on_enter_pressed)
	else:
		push_error("[LocationDetailPanel] EnterButton 节点不存在")
	_ensure_story_hint_label()

func _ensure_story_hint_label() -> void:
	if story_hint_label and is_instance_valid(story_hint_label):
		return
	if not is_instance_valid(content_vbox) or not is_instance_valid(enter_button):
		return
	story_hint_label = Label.new()
	story_hint_label.name = "StoryHintLabel"
	story_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_hint_label.visible = false
	story_hint_label.add_theme_color_override("font_color", Color(0.32, 0.62, 0.58, 1))
	story_hint_label.add_theme_font_size_override("font_size", 14)
	content_vbox.add_child(story_hint_label)
	content_vbox.move_child(story_hint_label, enter_button.get_index())

func setup(loc_id: String):
	location_id = loc_id
	var loc_data = MapDataManager.get_location(loc_id)
	if loc_data.is_empty(): return
	
	name_label.text = loc_data.get("name", "未知地点")
	desc_label.text = loc_data.get("description", "没有描述")
	
	var bg_id = loc_data.get("bg_id", "")
	var real_path = ""
	if not bg_id.is_empty():
		real_path = ImageManager.get_image_path(bg_id)
		if real_path.is_empty():
			real_path = bg_id
			
	if not real_path.is_empty() and ResourceLoader.exists(real_path):
		thumbnail_rect.texture = load(real_path)
	_refresh_entry_state()
	
	_load_npcs()

func _refresh_entry_state() -> void:
	var active_story := _resolve_location_story_trigger()
	if is_instance_valid(enter_button):
		enter_button.text = "进入该地点"
		enter_button.tooltip_text = "直接进入地点"
		if not active_story.is_empty():
			enter_button.text = "进入剧情"
			enter_button.tooltip_text = "当前有可触发的地点剧情，完成后今日不再重复触发"
	if not story_hint_label or not is_instance_valid(story_hint_label):
		return
	if active_story.is_empty():
		story_hint_label.hide()
		story_hint_label.text = ""
		return
	var story_title := str(active_story.get("badge_text", "")).strip_edges()
	if story_title == "":
		story_title = str(active_story.get("name", "")).strip_edges()
	if story_title == "":
		story_title = "当前时段有可触发剧情"
	story_hint_label.text = "今日事件：%s。完成后今天再次进入将直接进入地点。" % story_title
	story_hint_label.show()

func _resolve_location_story_trigger() -> Dictionary:
	if MapDataManager and MapDataManager.has_method("get_active_location_story_trigger"):
		return MapDataManager.get_active_location_story_trigger(location_id)
	return MapDataManager.get_location_entry_story(location_id)

func _load_npcs():
	for child in npc_container.get_children():
		child.queue_free()
		
	var npcs = MapDataManager.generate_location_npcs(location_id)
	var story_badges: Dictionary = MapDataManager.get_location_story_badges(location_id)
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
			if npc_btn.has_method("set_story_badge"):
				npc_btn.set_story_badge(str(story_badges.get(n_id, "")))
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
	tween.tween_property(color_rect, "modulate:a", 0.0, 0.25)
	tween.tween_property(main_panel, "position:x", 1280, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.chain().tween_callback(queue_free)
	closed.emit()

func _on_bg_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()
