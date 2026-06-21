extends Control

const DateStoryManager = preload("res://scripts/data/date_story_manager.gd")
const DatePlanState = preload("res://scripts/ui/date/date_plan_state.gd")
const DateScenePresenter = preload("res://scripts/ui/date/date_scene_presenter.gd")
const DateBubbleController = preload("res://scripts/ui/date/date_bubble_controller.gd")
const DateGenerationController = preload("res://scripts/ui/date/date_generation_controller.gd")
const DeepSeekClientLocator = preload("res://scripts/api/utils/deepseek_client_locator.gd")
const DeepSeekClient = preload("res://scripts/api/deepseek_client.gd")
const CharacterProfile = preload("res://scripts/data/character_profile.gd")
const STORY_SCENE_PATH := "res://scenes/ui/story/story_scene.tscn"
const DATE_CHARACTER_PROFILE_PATH := "res://assets/data/interaction/date_character_profiles.json"
const DATE_FIXED_CHARACTER_ID := "luna"

@onready var portrait_texture = %PortraitTexture
@onready var bubble_panel = %BubblePanel
@onready var bubble_text = %BubbleText
@onready var heart_level = %HeartLevel
@onready var resonance_bar = %ResonanceBar
@onready var resonance_text = %ResonanceText
@onready var cancel_btn = %CancelButton
@onready var date_btn = %DateButton

@onready var date_type_vbox = %DateTypeVBox
@onready var slot_morning = %SlotMorning
@onready var slot_afternoon = %SlotAfternoon
@onready var slot_evening = %SlotEvening

@onready var custom_image_popup = %CustomImagePopup
@onready var drop_hint = %DropHint
@onready var preview_rect = %PreviewRect
@onready var confirm_image_btn = %ConfirmImageBtn
@onready var cancel_image_btn = %CancelImageBtn

var _bubble_stream_buffer: String = ""
var _is_closing: bool = false

var _date_config: Dictionary = {}
var _pending_custom_texture: Texture2D = null
var _pending_custom_file_path: String = ""
var _pending_custom_slot: String = ""
var _plan_state: DatePlanState = null
var _presenter: DateScenePresenter = null
var _bubble_controller: DateBubbleController = null
var _generation_controller: DateGenerationController = null
var _date_character_profile: Dictionary = {}
var _date_runtime_profile: CharacterProfile = null
var _local_deepseek_client: DeepSeekClient = null

const SLOT_CUSTOM_TEXT := "现实邀约"

func _ready() -> void:
	cancel_btn.pressed.connect(_on_cancel_pressed)
	date_btn.pressed.connect(_on_date_pressed)
	confirm_image_btn.pressed.connect(_on_confirm_image_pressed)
	cancel_image_btn.pressed.connect(_on_cancel_image_pressed)
	
	get_window().files_dropped.connect(_on_files_dropped)
	
	_date_runtime_profile = _load_luna_runtime_profile()
	_date_character_profile = _load_date_character_profile()
	_local_deepseek_client = DeepSeekClient.new()
	add_child(_local_deepseek_client)
	_plan_state = DatePlanState.new()
	_plan_state.setup_from_story_time()
	_presenter = DateScenePresenter.new()
	add_child(_presenter)
	_presenter.setup(self, {
		"portrait_texture": portrait_texture,
		"heart_level": heart_level,
		"resonance_bar": resonance_bar,
		"resonance_text": resonance_text,
		"slot_buttons": {
			"morning": slot_morning,
			"afternoon": slot_afternoon,
			"evening": slot_evening
		}
	}, _date_character_profile)
	_presenter.slot_clicked.connect(_on_slot_pressed)
	_bubble_controller = DateBubbleController.new()
	add_child(_bubble_controller)
	_bubble_controller.setup(bubble_panel, bubble_text, _date_character_profile, DATE_FIXED_CHARACTER_ID)
	_bubble_controller.set_runtime_profile(_date_runtime_profile)
	_generation_controller = DateGenerationController.new()
	add_child(_generation_controller)
	_generation_controller.setup(_date_character_profile)
	_generation_controller.set_runtime_profile(_date_runtime_profile)
	_generation_controller.generation_state_changed.connect(_on_generation_state_changed)
	_generation_controller.story_ready.connect(_on_generated_story_ready)
	
	_load_date_config()

	_load_luna_animated_portrait()
	
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	
	_init_ui()
	_plan_state.load_draft()
	if _presenter:
		_presenter.refresh_all_slots(_plan_state.get_slots())
	_trigger_greeting_bubble()

func _load_luna_animated_portrait() -> void:
	if _presenter:
		_presenter.load_portrait(_date_character_profile)

func _init_ui() -> void:
	if _presenter and _date_runtime_profile:
		_presenter.refresh_profile_summary(_date_runtime_profile)

func _init_slots() -> void:
	if _presenter and _plan_state:
		_presenter.refresh_all_slots(_plan_state.get_slots())

func _load_date_config() -> void:
	var path = "res://assets/data/interaction/date_config.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var text = file.get_as_text()
			var json = JSON.new()
			var error = json.parse(text)
			if error == OK:
				var data = json.get_data()
				if data is Dictionary:
					_date_config = data
					print("Date config loaded successfully.")
					_populate_date_types()
				else:
					printerr("Date config is not a Dictionary.")
			else:
				printerr("Failed to parse date_config.json at line ", json.get_error_line(), ": ", json.get_error_message())
	else:
		printerr("date_config.json not found at ", path)

var _date_type_item_scene = preload("res://scenes/ui/date/date_type_item.tscn")
var _date_location_item_scene = preload("res://scenes/ui/date/date_location_item.tscn")

func _populate_date_types() -> void:
	if not _date_config.has("date_types"):
		return
		
	for child in date_type_vbox.get_children():
		child.queue_free()
		
	for type_data in _date_config["date_types"]:
		var type_item = _date_type_item_scene.instantiate()
		date_type_vbox.add_child(type_item)
		type_item.set_type_info(type_data["id"], type_data["name"])

		if bool(type_data.get("custom_upload", false)):
			var custom_item = _date_location_item_scene.instantiate()
			type_item.add_location_node(custom_item)
			custom_item.setup("custom_" + str(type_data["id"]), "上传现实照片", str(type_data["id"]))
			custom_item.add_requested.connect(_on_add_custom_location_pressed)
		elif type_data.has("locations"):
			for loc_id in type_data["locations"]:
				var loc_data_dict = MapDataManager.get_location(loc_id)
				var loc_name = loc_data_dict.get("name", loc_id)
				
				var loc_item = _date_location_item_scene.instantiate()
				type_item.add_location_node(loc_item)
				loc_item.setup(loc_id, loc_name, type_data["id"])
				loc_item.add_requested.connect(_on_add_location_pressed)

func _on_add_location_pressed(loc_id: String, loc_name: String, type_id: String) -> void:
	var found_slot := _plan_state.assign_first_available(loc_id, loc_name, type_id)
	if found_slot == "":
		if ToastManager:
			ToastManager.show_toast("没有可用的空闲时间段了")
		return
	_refresh_slots()
	_plan_state.save_draft()
	if _bubble_controller:
		_bubble_controller.request_slot_comment(_find_deepseek_client(), _build_slot_comment_payload(found_slot))

func _on_add_custom_location_pressed(loc_id: String, loc_name: String) -> void:
	var found_slot := _plan_state.get_first_available_slot()
	if found_slot == "":
		if ToastManager:
			ToastManager.show_toast("没有可用的空闲时间段了")
		return
	
	_pending_custom_slot = found_slot
	_pending_custom_texture = null
	_pending_custom_file_path = ""
	preview_rect.texture = null
	drop_hint.show()
	custom_image_popup.show()

func _on_files_dropped(files: PackedStringArray) -> void:
	if not custom_image_popup.visible:
		return
	if files.size() > 0:
		var file_path = files[0]
		if file_path.to_lower().ends_with(".png") or file_path.to_lower().ends_with(".jpg") or file_path.to_lower().ends_with(".jpeg"):
			var image = Image.new()
			var err = image.load(file_path)
			if err == OK:
				var tex = ImageTexture.create_from_image(image)
				_pending_custom_texture = tex
				_pending_custom_file_path = file_path
				preview_rect.texture = tex
				drop_hint.hide()
			else:
				if ToastManager:
					ToastManager.show_toast("图片加载失败")
		else:
			if ToastManager:
				ToastManager.show_toast("请拖入有效的图片文件 (png/jpg/jpeg)")

func _on_confirm_image_pressed() -> void:
	_apply_custom_texture_to_pending_slot()

func _on_cancel_image_pressed() -> void:
	_pending_custom_slot = ""
	_pending_custom_texture = null
	_pending_custom_file_path = ""
	preview_rect.texture = null
	custom_image_popup.hide()

func _apply_custom_texture_to_pending_slot() -> void:
	if _pending_custom_texture == null or _pending_custom_file_path == "":
		if ToastManager:
			ToastManager.show_toast("请先拖入图片")
		return

	var target_slot := _pending_custom_slot
	if target_slot == "":
		if ToastManager:
			ToastManager.show_toast("没有可用的空闲时间段了")
		return
	var saved_path := _save_custom_image_to_slot(_pending_custom_file_path, target_slot)
	if saved_path == "":
		if ToastManager:
			ToastManager.show_toast("图片保存失败")
		return
	_plan_state.assign_location(target_slot, "custom_location", SLOT_CUSTOM_TEXT, "real_photo", saved_path)
	_refresh_slots()
	_plan_state.save_draft()
	if _bubble_controller:
		_bubble_controller.request_slot_comment(_find_deepseek_client(), _build_slot_comment_payload(target_slot))

	_pending_custom_slot = ""
	_pending_custom_texture = null
	_pending_custom_file_path = ""
	preview_rect.texture = null
	custom_image_popup.hide()

func _on_slot_pressed(period_id: String) -> void:
	var slot_data := _plan_state.get_slot(period_id)
	if not bool(slot_data.get("enabled", true)):
		return
	if str(slot_data.get("location_id", "")).strip_edges() != "":
		_plan_state.clear_slot(period_id)
		_refresh_slots()
		_plan_state.save_draft()

func _trigger_greeting_bubble() -> void:
	if _bubble_controller:
		_bubble_controller.request_greeting(_find_deepseek_client())

func _exit_tree() -> void:
	if get_window() and get_window().files_dropped.is_connected(_on_files_dropped):
		get_window().files_dropped.disconnect(_on_files_dropped)
	if _bubble_controller:
		_bubble_controller.cleanup()
	if _generation_controller:
		_generation_controller.cleanup()

func _on_cancel_pressed() -> void:
	if _is_closing:
		return
	_is_closing = true
	_plan_state.save_draft()
	if _bubble_controller:
		_bubble_controller.cleanup()
	if _generation_controller:
		_generation_controller.cancel()
			
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)

func _on_date_pressed() -> void:
	if _generation_controller and _generation_controller.is_generating():
		return
	var plan_list := _plan_state.build_plan_list()
	if plan_list.is_empty():
		if ToastManager:
			ToastManager.show_toast("请至少选择一个约会地点！")
		return

	for item in plan_list:
		if str(item.get("location_id", "")) == "custom_location":
			if ToastManager:
				ToastManager.show_toast("现实邀约暂未接入动态剧情，请先选择地图地点")
			return
	_plan_state.clear_draft()
	if _generation_controller:
		_generation_controller.start_date_plan(plan_list)

func _find_deepseek_client() -> Node:
	if _local_deepseek_client and is_instance_valid(_local_deepseek_client):
		return _local_deepseek_client
	return DeepSeekClientLocator.find(self)

func _on_generation_state_changed(active: bool) -> void:
	date_btn.disabled = active
	cancel_btn.disabled = active

func _on_generated_story_ready(script_data: Dictionary) -> void:
	if _is_closing:
		return
	_play_generated_date_story(script_data)

func _play_generated_date_story(script_data: Dictionary) -> void:
	if script_data.is_empty():
		if ToastManager:
			ToastManager.show_toast("约会剧情生成失败")
		return

	GameDataManager.set_meta("play_runtime_story_data", script_data)
	GameDataManager.set_meta("story_scene_return_to_main_on_finish", true)

	if get_tree().root.has_node("SceneTransitionManager"):
		get_tree().root.get_node("SceneTransitionManager").transition_to_scene(STORY_SCENE_PATH)
	else:
		get_tree().change_scene_to_file(STORY_SCENE_PATH)

func _refresh_slots() -> void:
	if _presenter and _plan_state:
		_presenter.refresh_all_slots(_plan_state.get_slots())

func _get_current_date_character_id() -> String:
	return DATE_FIXED_CHARACTER_ID

func _load_luna_runtime_profile() -> CharacterProfile:
	if GameDataManager and GameDataManager.profile:
		var active_char_id := str(GameDataManager.profile.current_character_id).strip_edges().to_lower()
		if active_char_id == DATE_FIXED_CHARACTER_ID:
			return GameDataManager.profile
	var profile := CharacterProfile.new()
	profile.load_profile(DATE_FIXED_CHARACTER_ID)
	return profile

func _load_date_character_profile() -> Dictionary:
	var profiles: Dictionary = {}
	if FileAccess.file_exists(DATE_CHARACTER_PROFILE_PATH):
		var file := FileAccess.open(DATE_CHARACTER_PROFILE_PATH, FileAccess.READ)
		if file:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK and json.get_data() is Dictionary:
				profiles = json.get_data()
	var default_profile: Dictionary = profiles.get("default", {}).duplicate(true)
	var specific_profile: Dictionary = profiles.get(DATE_FIXED_CHARACTER_ID, {}).duplicate(true)
	default_profile.merge(specific_profile, true)
	return default_profile

func _build_slot_comment_payload(period_id: String) -> Dictionary:
	var slot_data := _plan_state.get_slot(period_id)
	slot_data["period_id"] = period_id
	slot_data["period_label"] = _get_period_label(period_id)
	return slot_data

func _get_period_label(period_id: String) -> String:
	match period_id:
		"morning":
			return "早上"
		"afternoon":
			return "下午"
		"evening":
			return "晚上"
	return period_id

func _save_custom_image_to_slot(source_path: String, slot_id: String) -> String:
	var image := Image.new()
	if image.load(source_path) != OK:
		return ""
	var target_dir := GameDataManager.get_character_save_dir().path_join("date_drafts")
	if not DirAccess.dir_exists_absolute(target_dir):
		DirAccess.make_dir_recursive_absolute(target_dir)
	var target_path := target_dir.path_join("date_custom_%s.png" % slot_id)
	var save_err := image.save_png(target_path)
	if save_err != OK:
		return ""
	return target_path
