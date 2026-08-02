extends Control

const QUICK_LOCATION_SCENE = preload("res://scenes/ui/map/core/quick_location_scene.tscn")
const STORY_SCENE = preload("res://scenes/ui/story/story_scene.tscn")
const MAP_BACKGROUND_SCALE := Vector2(0.85, 0.85)
const AREA_FADE_OUT_DURATION := 0.28
const AREA_FADE_IN_DURATION := 0.36

@onready var back_button: Button = $TopBar/TopBarMargin/TopBarHBox/BackButton
@onready var title_label: Label = $TopBar/TopBarMargin/TopBarHBox/TitleCenter/Title

# Sub areas container
@onready var sub_area_container: Control = $SubAreaContainer
@onready var background_shade: ColorRect = $BackgroundShade
@onready var area_transition_input_blocker: ColorRect = $AreaTransitionInputBlocker

# Area list container
@onready var area_list_container: HBoxContainer = $BottomBar/ScrollContainer/MarginContainer/AreaList

var area_item_scene = preload("res://scenes/ui/map/core/area_item.tscn")
var location_button_scene = preload("res://scenes/ui/map/core/location_button.tscn")

signal location_selected(location_id: String)

var _bg_tween: Tween
var _current_area_id: String = ""
var _guide_targets_ready: bool = false
var _debug_label: Label
var _location_entry_transition_busy: bool = false
var _area_transition_busy: bool = false
const QUICK_LOCATION_SKIP_EVENT_META := "skip_quick_location_initial_event_broadcast"

func _ready():
	var background := $Background as TextureRect
	background.pivot_offset = background.size / 2.0
	background.scale = MAP_BACKGROUND_SCALE

	# --- 调试工具：实时显示鼠标相对 SubAreaContainer 的坐标 ---
	_debug_label = Label.new()
	_debug_label.add_theme_font_size_override("font_size", 20)
	_debug_label.add_theme_color_override("font_color", Color(1, 1, 0, 1)) # 黄色
	_debug_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_debug_label.add_theme_constant_override("outline_size", 4)
	_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_label.z_index = 4096
	add_child(_debug_label)
	# --------------------------------------------------------
	
	# Load default world map background
	var world_map_bg = ImageManager.get_image_path("bg_world_map")
	if world_map_bg != "" and ResourceLoader.exists(world_map_bg):
		$Background.texture = load(world_map_bg)
		
	back_button.pressed.connect(_on_back_pressed)
	
	_apply_time_filter()
	if MapDataManager.has_method("sync_story_progress_unlocks"):
		MapDataManager.sync_story_progress_unlocks()
	
	# Clear any previous children (in case of re-initialization)
	for child in area_list_container.get_children():
		child.queue_free()
		
	# Dynamically load area buttons
	var default_area_id = ""
	var first_unlocked_area_id = ""
	var ordered_area_ids: Array = MapDataManager.get_area_order() if MapDataManager.has_method("get_area_order") else MapDataManager.areas.keys()
	for area_id_value in ordered_area_ids:
		var area_id := str(area_id_value)
		if default_area_id == "":
			default_area_id = area_id
		var area_data = MapDataManager.get_area(area_id)
		if area_data.is_empty():
			continue
		var is_unlocked: bool = MapDataManager.is_area_unlocked(area_id)
		if first_unlocked_area_id == "" and is_unlocked:
			first_unlocked_area_id = area_id
		var item = area_item_scene.instantiate()
		area_list_container.add_child(item)
		item.setup(area_id, area_data, is_unlocked, MapDataManager.get_area_lock_reason(area_id))
		item.pressed.connect(_on_area_pressed)
	
	# 世界地图每次打开都从青屿街开始，保持区域入口认知一致。
	var fallback_area_id: String = first_unlocked_area_id if first_unlocked_area_id != "" else default_area_id
	var initial_area_id := "qingyu_street" if MapDataManager.areas.has("qingyu_street") and MapDataManager.is_area_unlocked("qingyu_street") else fallback_area_id
	if initial_area_id != "":
		_on_area_pressed(initial_area_id, true)

	var guide_manager = get_node_or_null("/root/GuideManager")
	if guide_manager and guide_manager.has_method("on_world_map_scene_ready"):
		guide_manager.on_world_map_scene_ready(self)

func _apply_time_filter():
	pass # 交由全局的天气/环境系统处理

func show_map():
	show()
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func hide_map():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(hide)

func _on_back_pressed():
	SceneTransitionManager.transition_to_scene("res://scenes/ui/main/main_scene.tscn")

func _on_area_pressed(area_id: String, force: bool = false):
	if _area_transition_busy and not force:
		return
	if not MapDataManager.is_area_unlocked(area_id):
		if not force:
			var reason: String = MapDataManager.get_area_lock_reason(area_id)
			if reason == "":
				reason = "该区域暂未解锁"
			ToastManager.show_system_toast(reason, Color.RED)
		return
	
	if not force and _current_area_id == area_id:
		return
	_guide_targets_ready = false
	var guide_manager = get_node_or_null("/root/GuideManager")
	if guide_manager and guide_manager.has_method("refresh_current_step_display"):
		guide_manager.refresh_current_step_display()
	if not force:
		if guide_manager and guide_manager.has_method("report_action"):
			guide_manager.report_action("select_map_area", {"area_id": area_id})
		
	_current_area_id = area_id
	
	# Update selected effect for all buttons
	for child in area_list_container.get_children():
		if child.has_method("set_selected"):
			child.set_selected(child.area_id == area_id)

	var area_data = MapDataManager.get_area(area_id)
	if area_data.is_empty():
		return
		
	# Save last area to MapDataManager so we can restore it when returning
	if MapDataManager.has_method("set_last_area"):
		MapDataManager.set_last_area(area_id)
		
	title_label.text = area_data.get("name", "未知区域")
	
	# --- 计算缩放后背景图的区域位置 ---
	var bg := $Background as TextureRect
	var camera_offset := Vector2(0.5, 0.5)

	# 优先读取 JSON 中配置的 camera_offset 比例，让每个区域分散在不同角落
	if area_data.has("camera_offset"):
		var offset = area_data["camera_offset"]
		# Godot JSON 解析后，如果是个对象它通常是个 Dictionary，但如果之前被其他代码强转了，它可能是个 Vector2
		if typeof(offset) == TYPE_DICTIONARY:
			camera_offset = Vector2(float(offset.get("x", 0.5)), float(offset.get("y", 0.5)))
		elif typeof(offset) == TYPE_VECTOR2:
			camera_offset = offset
	var target_pos := _get_background_position_for_camera_offset(bg, camera_offset)
	
	if _bg_tween and _bg_tween.is_valid():
		_bg_tween.kill()
		
	# 地图常态略微拉远，区域切换时不再改变缩放。
	bg.pivot_offset = bg.size / 2.0
	bg.scale = MAP_BACKGROUND_SCALE
	
	if force:
		_clear_sub_area_locations()
		bg.position = target_pos
		self._show_locations_for_area(area_id)
	else:
		_play_area_fade_transition(area_id, target_pos)

func _get_background_position_for_camera_offset(background: TextureRect, camera_offset: Vector2) -> Vector2:
	var displayed_size := background.size * MAP_BACKGROUND_SCALE
	var overflow := Vector2(
		maxf(0.0, displayed_size.x - size.x),
		maxf(0.0, displayed_size.y - size.y)
	)
	var visual_top_left := -overflow * camera_offset.clamp(Vector2.ZERO, Vector2.ONE)
	var pivot_compensation := background.pivot_offset * (Vector2.ONE - MAP_BACKGROUND_SCALE)
	return visual_top_left - pivot_compensation

func _play_area_fade_transition(area_id: String, target_position: Vector2) -> void:
	_area_transition_busy = true
	area_transition_input_blocker.show()
	var fade_targets: Array[Control] = [$Background, background_shade, sub_area_container]
	_bg_tween = create_tween().set_parallel(true)
	for target in fade_targets:
		_bg_tween.tween_property(target, "modulate:a", 0.0, AREA_FADE_OUT_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _bg_tween.finished

	_clear_sub_area_locations()
	$Background.position = target_position
	_show_locations_for_area(area_id)

	_bg_tween = create_tween().set_parallel(true)
	for target in fade_targets:
		_bg_tween.tween_property(target, "modulate:a", 1.0, AREA_FADE_IN_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _bg_tween.finished
	area_transition_input_blocker.hide()
	_area_transition_busy = false

func _clear_sub_area_locations() -> void:
	for child in sub_area_container.get_children():
		sub_area_container.remove_child(child)
		child.queue_free()

func _show_locations_for_area(area_id: String):
	var locs = MapDataManager.get_area_locations(area_id)
	var final_reveal_tween: Tween = null
	if typeof(locs) == TYPE_ARRAY:
		locs = locs.duplicate()
	
	# Handle limited_locations, show them even if locked, but mark them
	var area = MapDataManager.get_area(area_id)
	if area.has("limited_locations"):
		for loc_id in area["limited_locations"]:
			var loc = MapDataManager.get_location(loc_id)
			if not loc.is_empty():
				var found = false
				for l in locs:
					if typeof(l) == TYPE_DICTIONARY and l.get("id", "") == loc_id:
						found = true
						break
				if not found:
					locs.append(loc)

	# Filter out invisible locations
	var visible_locs = []
	for loc in locs:
		if MapDataManager.is_location_visible(loc.get("id", "")):
			visible_locs.append(loc)
	locs = visible_locs

	if locs.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "该区域暂无可探索地点"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		sub_area_container.add_child(empty_label)
	else:
		var btn_size = Vector2(100, 118) # 与地点按钮缩小后的视觉尺寸保持一致
		
		# Define some fallback positions in case data doesn't have it
		var fallback_positions = [
			Vector2(150, 30),
			Vector2(450, 120),
			Vector2(700, 40),
			Vector2(950, 130),
			Vector2(1050, 50)
		]
		
		for i in range(locs.size()):
			var loc = locs[i]
			var btn = location_button_scene.instantiate()
			
			# 必须先将节点添加到场景树，触发 _ready() 后，内部的 @onready 变量才会被正确赋值
			sub_area_container.add_child(btn)
			
			if btn.has_method("setup"):
				btn.setup(loc)
			else:
				btn.text = loc.get("name", "未知地点")
			
			btn.pressed.connect(_on_location_pressed.bind(loc.get("id", "")))
			
			# 从 JSON 配置中读取 map_position
			var target_pos = Vector2.ZERO
			if loc.has("map_position"):
				var pos_data = loc["map_position"]
				if typeof(pos_data) == TYPE_DICTIONARY:
					target_pos = Vector2(pos_data.get("x", 0), pos_data.get("y", 0))
				elif typeof(pos_data) == TYPE_VECTOR2:
					target_pos = pos_data
			
			# 如果 JSON 中没有配置坐标，或者配了 0，给个后备排列坐标防止重叠
			if target_pos == Vector2.ZERO:
				target_pos = fallback_positions[i % fallback_positions.size()]
			
			
			btn.position = _get_scaled_location_position(target_pos, btn_size)
			
			# Add animation
			btn.scale = Vector2.ZERO
			btn.pivot_offset = btn_size / 2
			var tween = create_tween()
			tween.tween_property(btn, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(i * 0.1)
			final_reveal_tween = tween
	var guide_manager = get_node_or_null("/root/GuideManager")
	if guide_manager and guide_manager.has_method("refresh_current_step_display"):
		if final_reveal_tween:
			final_reveal_tween.finished.connect(
				func() -> void:
					_guide_targets_ready = true
					guide_manager.refresh_current_step_display(),
				CONNECT_ONE_SHOT
			)
		else:
			_guide_targets_ready = true
			guide_manager.call_deferred("refresh_current_step_display")
	else:
		_guide_targets_ready = final_reveal_tween == null

func _get_scaled_location_position(source_position: Vector2, button_size: Vector2) -> Vector2:
	var canvas_center := sub_area_container.size / 2.0
	var source_center := source_position + button_size / 2.0
	var scaled_center := canvas_center + (source_center - canvas_center) * MAP_BACKGROUND_SCALE
	var scaled_position := scaled_center - button_size / 2.0
	var max_position := Vector2(
		maxf(0.0, sub_area_container.size.x - button_size.x),
		maxf(0.0, sub_area_container.size.y - button_size.y)
	)
	return scaled_position.clamp(Vector2.ZERO, max_position)

func is_guide_target_ready() -> bool:
	return _guide_targets_ready

func _on_location_pressed(location_id: String):
	# 检查是否解锁
	var is_unlocked = MapDataManager.is_location_unlocked(location_id)
	if not is_unlocked:
		var reason = MapDataManager.get_location_lock_reason(location_id)
		if reason == "":
			reason = "暂未解锁"
		ToastManager.show_system_toast(reason, Color.RED)
		return
	if MapDataManager.has_method("set_last_location"):
		MapDataManager.set_last_location(location_id)
	var guide_manager = get_node_or_null("/root/GuideManager")
	if guide_manager and guide_manager.has_method("report_action"):
		guide_manager.report_action("select_map_location", {
			"location_id": location_id
		})
		
	# Transition to exploration map
	location_selected.emit(location_id)
	
	var existing_panel = get_node_or_null("LocationDetailPanel")
	if existing_panel:
		existing_panel.queue_free()
		
	var detail_scene = load("res://scenes/ui/map/core/location_detail_panel.tscn")
	if detail_scene:
		var panel = detail_scene.instantiate()
		panel.name = "LocationDetailPanel"
		add_child(panel)
		panel.setup(location_id)
		panel.enter_pressed.connect(_on_location_enter_pressed)
		if guide_manager and guide_manager.has_method("on_location_detail_panel_ready"):
			panel.guide_target_ready.connect(
				func() -> void: guide_manager.on_location_detail_panel_ready(panel),
				CONNECT_ONE_SHOT
			)

func get_area_button(area_id: String) -> Control:
	for child in area_list_container.get_children():
		if child is Control and str(child.get("area_id")) == area_id:
			return child as Control
	return null

func get_area_button_focus_entry(area_id: String) -> Dictionary:
	return _get_rounded_guide_focus_entry(get_area_button(area_id), 18.0)

func get_location_button(location_id: String) -> Control:
	for child in sub_area_container.get_children():
		if child is Control and str(child.get("location_id")) == location_id:
			return child as Control
	return null

func get_location_button_focus_entry(location_id: String) -> Dictionary:
	return _get_rounded_guide_focus_entry(get_location_button(location_id), 14.0)

func _get_rounded_guide_focus_entry(target: Control, corner_radius: float) -> Dictionary:
	if not is_instance_valid(target) or not target.is_visible_in_tree():
		return {}
	return {
		"rect": target.get_global_rect(),
		"shape": "rect",
		"shape_params": {"corner_radius": corner_radius}
	}

func _on_location_enter_pressed(location_id: String, npc_id: String):
	if _location_entry_transition_busy:
		return
	if location_id == "studio":
		_on_back_pressed()
		return
	var guide_manager = get_node_or_null("/root/GuideManager")
	if guide_manager and guide_manager.has_method("report_action"):
		guide_manager.report_action("enter_location_detail", {
			"location_id": location_id,
			"npc_id": npc_id
		})
	
	var story_trigger := _resolve_location_story_trigger(location_id)
	if not story_trigger.is_empty():
		_location_entry_transition_busy = true
		_play_location_entry_story(location_id, npc_id, story_trigger)
		_location_entry_transition_busy = false
		return
	
	_open_quick_location_scene(location_id, npc_id)

func _resolve_location_story_trigger(location_id: String) -> Dictionary:
	var entry_story := MapDataManager.get_location_entry_story(location_id)
	if not entry_story.is_empty():
		return entry_story

	var event_manager = get_node_or_null("/root/EventManager")
	if event_manager and event_manager.has_method("find_matching_auto_trigger_event"):
		var matched_event: Dictionary = event_manager.find_matching_auto_trigger_event({
			"location_id": location_id
		})
		if not matched_event.is_empty():
			return matched_event

	return {}

func _open_quick_location_scene(location_id: String, npc_id: String, duration: float = 1.0) -> void:
	if QUICK_LOCATION_SCENE == null:
		return
	var instance = QUICK_LOCATION_SCENE.instantiate()
	instance.location_id = location_id
	instance.initial_npc_id = npc_id
	SceneTransitionManager.transition_to_scene_instance(instance, duration)

func _play_location_entry_story(location_id: String, npc_id: String, story_config: Dictionary) -> void:
	var script_path := str(story_config.get("trigger_script", "")).strip_edges()
	if script_path == "":
		_open_quick_location_scene(location_id, npc_id)
		return
	if not (ResourceLoader.exists(script_path) or FileAccess.file_exists(script_path)):
		_open_quick_location_scene(location_id, npc_id)
		return

	var trigger_source_type := "scheduled_entry_story"
	var trigger_source_id := str(story_config.get("resolved_id", story_config.get("id", ""))).strip_edges()
	if str(story_config.get("event_type", "")).strip_edges() == "auto_trigger":
		trigger_source_type = "location_auto_event"
		trigger_source_id = str(story_config.get("event_id", trigger_source_id)).strip_edges()
	if trigger_source_id == "":
		trigger_source_id = script_path.get_file().get_basename()
	var debug_bridge := get_node_or_null("/root/StoryRuntimeDebugBridge")
	if debug_bridge != null:
		debug_bridge.prepare_story("scheduled_entry_story" if trigger_source_type == "scheduled_entry_story" else "event_registry", trigger_source_id, script_path, {
			"location_id": location_id,
			"npc_id": npc_id,
			"priority": int(story_config.get("priority", 0))
		})

	GameDataManager.set_meta("pending_map_entry_trigger_completion", {
		"source_type": trigger_source_type,
		"source_id": trigger_source_id,
		"location_id": location_id
	})
	GameDataManager.set_meta("play_specific_story", script_path)
	GameDataManager.set_meta("story_scene_followup_quick_location", {
		"location_id": location_id,
		"npc_id": npc_id
	})
	GameDataManager.set_meta(QUICK_LOCATION_SKIP_EVENT_META, {
		"location_id": location_id
	})

	if get_tree().root.has_node("SceneTransitionManager"):
		get_tree().root.get_node("SceneTransitionManager").transition_to_scene("res://scenes/ui/story/story_scene.tscn", 0.7)
	else:
		get_tree().change_scene_to_packed(STORY_SCENE)

func _process(_delta: float) -> void:
	if is_instance_valid(_debug_label) and is_instance_valid(sub_area_container):
		var local_pos = sub_area_container.get_local_mouse_position()
		_debug_label.text = "坐标: (%.0f, %.0f)" % [local_pos.x, local_pos.y]
		_debug_label.global_position = get_global_mouse_position() + Vector2(20, 20)
