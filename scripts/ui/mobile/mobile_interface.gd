extends Control

signal app_opened(app_name: String)

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var phone_panel: Panel = $PhonePanel

@onready var archive_btn: Button = $PhonePanel/MainMargin/VBox/PlayerInfoArea/InteractionArea/LevelVBox/BtnHBox/ArchiveBtn
@onready var affection_btn: Button = $PhonePanel/MainMargin/VBox/PlayerInfoArea/InteractionArea/LevelVBox/BtnHBox/AffectionButton
@onready var camera_btn: Button = $PhonePanel/MainMargin/VBox/CardsHBox/ButtonContainer/CameraContainer/CameraBtn
@onready var album_btn: Button = $PhonePanel/MainMargin/VBox/CardsHBox/ButtonContainer/CameraContainer/AlbumBtn
@onready var preview_image: TextureRect = $PhonePanel/MainMargin/VBox/CardsHBox/ImagePreview/ImageCard/Image
@onready var power_btn: Button = $PhonePanel/MainMargin/VBox/PowerBtn
@onready var sms_btn: Button = $PhonePanel/MainMargin/VBox/ListVBox/List1/SmsBtn
@onready var moments_btn: Button = $PhonePanel/MainMargin/VBox/ListVBox/List1/L1_Icon/MomentsButton

@onready var player_name_lbl: Label = $PhonePanel/MainMargin/VBox/PlayerInfoArea/InteractionArea/PlayerVBox/NamePlate/HBox/PlayerName
@onready var char_name_lbl: Label = $PhonePanel/MainMargin/VBox/PlayerInfoArea/InteractionArea/CharVBox/NamePlate/HBox/CharName
@onready var char_avatar_rect: TextureRect = $PhonePanel/MainMargin/VBox/PlayerInfoArea/InteractionArea/CharVBox/AvatarContainer/AvatarMask/Avatar
@onready var player_avatar_rect: TextureRect = $PhonePanel/MainMargin/VBox/PlayerInfoArea/InteractionArea/PlayerVBox/AvatarContainer/AvatarMask/Avatar
@onready var lvl_num_lbl: Label = $PhonePanel/MainMargin/VBox/PlayerInfoArea/InteractionArea/LevelVBox/TopHBox/LevelNum
@onready var lvl_progress_lbl: Label = $PhonePanel/MainMargin/VBox/PlayerInfoArea/InteractionArea/LevelVBox/TopHBox/TextVBox/LevelProgress
@onready var exp_bar: ProgressBar = $PhonePanel/MainMargin/VBox/PlayerInfoArea/InteractionArea/LevelVBox/ExpBar

@onready var affection_panel_overlay: PanelContainer = $PhonePanel/AffectionPanelOverlay
@onready var affection_back_btn: Button = $PhonePanel/AffectionPanelOverlay/VBox/TopBar/BackBtn

@onready var aff_stage_num_lbl: Label = $PhonePanel/AffectionPanelOverlay/VBox/Margin/ContentVBox/Header/StageInfo/StageNumLabel
@onready var aff_stage_title_lbl: Label = $PhonePanel/AffectionPanelOverlay/VBox/Margin/ContentVBox/Header/StageInfo/StageTitleLabel
@onready var aff_flavor_lbl: Label = $PhonePanel/AffectionPanelOverlay/VBox/Margin/ContentVBox/Header/FlavorBadge/Margin/FlavorLabel
@onready var aff_flavor_badge: PanelContainer = $PhonePanel/AffectionPanelOverlay/VBox/Margin/ContentVBox/Header/FlavorBadge

@onready var aff_stage_desc_lbl: Label = $PhonePanel/AffectionPanelOverlay/VBox/Margin/ContentVBox/DescVBox/StageDescLabel
@onready var aff_flavor_desc_lbl: Label = $PhonePanel/AffectionPanelOverlay/VBox/Margin/ContentVBox/DescVBox/FlavorDescLabel

@onready var aff_intimacy_val: Label = $PhonePanel/AffectionPanelOverlay/VBox/Margin/ContentVBox/ValuesRow/IntimacyBlock/IntimacyVal
@onready var aff_trust_val: Label = $PhonePanel/AffectionPanelOverlay/VBox/Margin/ContentVBox/ValuesRow/TrustBlock/TrustVal

@onready var aff_resonance_bar: ProgressBar = $PhonePanel/AffectionPanelOverlay/VBox/Margin/ContentVBox/ProgressSection/ResonanceBar
@onready var aff_resonance_val: Label = $PhonePanel/AffectionPanelOverlay/VBox/Margin/ContentVBox/ProgressSection/ResonanceBar/ValueLabel
@onready var aff_milestone_lbl: Label = $PhonePanel/AffectionPanelOverlay/VBox/Margin/ContentVBox/ProgressSection/MilestoneLabel

var archive_panel_instance = null
var contact_list_instance = null
var chat_panel_instance = null
var camera_panel_instance = null
var album_panel_instance = null
var moments_panel_instance = null

var _album_photos: Array = []
var _current_photo_idx: int = 0
var _photo_timer: float = 0.0
const PHOTO_CHANGE_INTERVAL: float = 5.0

var preview_image_next: TextureRect

func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)
	
	preview_image_next = preview_image.duplicate()
	preview_image.get_parent().add_child(preview_image_next)
	preview_image_next.hide()
	
	# 绑定信号
	archive_btn.pressed.connect(_on_archive_app_pressed)
	affection_btn.pressed.connect(_on_affection_button_pressed)
	affection_back_btn.pressed.connect(_on_affection_back_pressed)
	power_btn.pressed.connect(_on_close_pressed)
	sms_btn.pressed.connect(_on_sms_app_pressed)
	moments_btn.pressed.connect(_on_moments_button_pressed)
	
	camera_btn.pressed.connect(_on_camera_app_pressed)
	album_btn.pressed.connect(_on_album_app_pressed)

func _process(delta: float) -> void:
	if visible:
		if _album_photos.size() > 1:
			_photo_timer += delta
			if _photo_timer >= PHOTO_CHANGE_INTERVAL:
				_photo_timer = 0.0
				_current_photo_idx = (_current_photo_idx + 1) % _album_photos.size()
				_update_preview_image()

func _load_album_photos() -> void:
	_album_photos.clear()
	var dir_path = "user://saves/photos"
	if DirAccess.dir_exists_absolute(dir_path):
		var dir = DirAccess.open(dir_path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and file_name.ends_with(".png"):
					_album_photos.append(dir_path + "/" + file_name)
				file_name = dir.get_next()
	
	if _album_photos.size() > 0:
		_album_photos.sort()
		_album_photos.reverse()
		_current_photo_idx = 0
		_photo_timer = 0.0
		_update_preview_image(false)
	else:
		if GameDataManager.config and "default_image_path" in GameDataManager.config:
			var path = GameDataManager.config.default_image_path
			if FileAccess.file_exists(path):
				preview_image.texture = load(path)

func _update_preview_image(animate: bool = true) -> void:
	if _album_photos.size() > 0:
		var path = _album_photos[_current_photo_idx]
		var img = Image.load_from_file(path)
		if img:
			var tex = ImageTexture.create_from_image(img)
			if not animate:
				if is_instance_valid(preview_image):
					preview_image.texture = tex
					preview_image.position = Vector2.ZERO
					preview_image.modulate.a = 1.0
				return
				
			if is_instance_valid(preview_image) and is_instance_valid(preview_image_next):
				var card_width = preview_image.get_parent().size.x
				if card_width == 0:
					card_width = 225
					
				preview_image_next.texture = tex
				preview_image_next.position = Vector2(card_width, 0)
				preview_image_next.modulate.a = 1.0
				preview_image_next.show()
				
				var tween = create_tween()
				tween.set_parallel(true)
				tween.set_trans(Tween.TRANS_CUBIC)
				tween.set_ease(Tween.EASE_OUT)
				
				# Slide both images to the left
				tween.tween_property(preview_image, "position:x", -card_width, 0.6)
				tween.tween_property(preview_image_next, "position:x", 0, 0.6)
				
				tween.chain().tween_callback(func():
					preview_image.texture = tex
					preview_image.position = Vector2.ZERO
					preview_image_next.hide()
				)

func _update_time() -> void:
	pass

func show_phone() -> void:
	if GameDataManager.config and GameDataManager.profile:
		var profile = GameDataManager.profile
		if is_instance_valid(player_name_lbl): player_name_lbl.text = profile.player_name
		
		var c_name = profile.char_name
		if c_name == "": c_name = "未知角色"
		if is_instance_valid(char_name_lbl): char_name_lbl.text = c_name
		
		if profile.avatar != "" and is_instance_valid(char_avatar_rect):
			var tex = load(profile.avatar)
			if tex: char_avatar_rect.texture = tex
		
		var current_stage = profile.current_stage
		var conf = profile.get_current_stage_config()
		
		if is_instance_valid(lvl_num_lbl): lvl_num_lbl.text = str(current_stage)
		
		var current_resonance = profile.intimacy + profile.trust
		var res_threshold = 9999.0
		if not conf.is_empty():
			res_threshold = float(conf.get("resonance_threshold", 9999))
			
		var display_res_max = res_threshold
		if res_threshold >= 9999:
			display_res_max = max(current_resonance, 100)
			
		if is_instance_valid(lvl_progress_lbl): 
			lvl_progress_lbl.text = "%.1f/MAX" % current_resonance if res_threshold >= 9999 else "%.1f/%d" % [current_resonance, int(res_threshold)]
			
		if is_instance_valid(exp_bar): 
			exp_bar.min_value = 0
			exp_bar.max_value = display_res_max
			exp_bar.value = min(current_resonance, display_res_max)
			
	_load_album_photos()
			
	show()
	animation_player.play("slide_up")

func hide_phone() -> void:
	animation_player.play("slide_down")

func _on_close_pressed() -> void:
	hide_phone()

func _on_affection_button_pressed() -> void:
	_update_affection_ui()
	affection_panel_overlay.show()

func _on_affection_back_pressed() -> void:
	affection_panel_overlay.hide()

func get_stage_color(stage: int) -> Color:
	match stage:
		1: return Color("9e9e9e") # 初始 (灰色)
		2: return Color("81d4fa") # 拘谨 (浅蓝)
		3: return Color("4dd0e1") # 熟络 (青色)
		4: return Color("81c784") # 亲近 (浅绿)
		5: return Color("aed581") # 信赖 (绿色)
		6: return Color("fff176") # 暧昧 (浅黄)
		7: return Color("ffb74d") # 倾心 (橙色)
		8: return Color("f06292") # 热恋 (粉色)
		9: return Color("ba68c8") # 挚爱 (紫色)
		_: return Color.WHITE

func set_bar_color(bar: ProgressBar, color: Color) -> void:
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = color
	bar.add_theme_stylebox_override("fill", stylebox)

func _update_affection_ui() -> void:
	var profile = GameDataManager.profile
	if not profile: return
	
	var current_stage = profile.current_stage
	var conf = profile.get_current_stage_config()
	if conf.is_empty(): return
	
	var intimacy = profile.intimacy
	var trust = profile.trust
	
	if is_instance_valid(aff_stage_num_lbl): aff_stage_num_lbl.text = "STAGE " + str(current_stage)
	if is_instance_valid(aff_stage_title_lbl): aff_stage_title_lbl.text = conf.get("stageTitle", "")
	if is_instance_valid(aff_intimacy_val): aff_intimacy_val.text = "%.1f" % intimacy
	if is_instance_valid(aff_trust_val): aff_trust_val.text = "%.1f" % trust
	
	# Flavor logic
	var flavor_text = "防备疏离"
	var flavor_color = Color("9e9e9e") # 灰色
	var flavor_desc = ""
	
	if intimacy >= 60 or trust >= 60:
		if intimacy >= trust * 1.5:
			flavor_text = "偏执迷恋"
			flavor_color = Color("e57373") # 红色
			flavor_desc = "【风味】极度缺乏安全感，对你有着强烈的占有欲，患得患失。"
		elif trust >= intimacy * 1.5:
			flavor_text = "灵魂知己"
			flavor_color = Color("64b5f6") # 蓝色
			flavor_desc = "【风味】毫无防备的默契盟友，彼此完全信任，但暂无强烈的恋爱冲动。"
		else:
			flavor_text = "灵魂伴侣"
			flavor_color = Color("f06292") # 粉色
			flavor_desc = "【风味】极致的爱意与绝对的安全感，完全卸下伪装的专属依赖。"
	else:
		flavor_desc = "【风味】仍然保持着安全的社交距离，带着审视与戒备。"
	
	if is_instance_valid(aff_flavor_lbl):
		aff_flavor_lbl.text = flavor_text
		
	if is_instance_valid(aff_stage_desc_lbl):
		aff_stage_desc_lbl.text = "【阶段】" + conf.get("stageDesc", conf.get("relationship_desc", conf.get("description", "")))
	
	if is_instance_valid(aff_flavor_desc_lbl):
		aff_flavor_desc_lbl.text = flavor_desc
		aff_flavor_desc_lbl.add_theme_color_override("font_color", flavor_color)
		
	if is_instance_valid(aff_flavor_badge):
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = flavor_color
		stylebox.corner_radius_top_left = 12
		stylebox.corner_radius_top_right = 12
		stylebox.corner_radius_bottom_left = 12
		stylebox.corner_radius_bottom_right = 12
		aff_flavor_badge.add_theme_stylebox_override("panel", stylebox)
		
	if is_instance_valid(aff_resonance_bar):
		set_bar_color(aff_resonance_bar, flavor_color)
		var current_resonance = intimacy + trust
		var resonance_threshold = float(conf.get("resonance_threshold", 100))
		
		var display_max = resonance_threshold
		if resonance_threshold >= 9999: # 满级
			var prev_stage = max(1, current_stage - 1)
			var prev_conf = profile.get_stage_config(prev_stage)
			var min_val = float(prev_conf.get("resonance_threshold", 0)) if not prev_conf.is_empty() else 0
			display_max = min_val + 500
			
		aff_resonance_bar.min_value = 0
		aff_resonance_bar.max_value = display_max
		aff_resonance_bar.value = min(current_resonance, display_max)
		
		if is_instance_valid(aff_resonance_val):
			if resonance_threshold >= 9999:
				aff_resonance_val.text = "✨ 共感度: %.1f / MAX" % current_resonance
			else:
				aff_resonance_val.text = "✨ 共感度: %.1f / %d" % [current_resonance, int(resonance_threshold)]

	if is_instance_valid(aff_milestone_lbl):
		var milestone_event = conf.get("milestone_event", "")
		if milestone_event == "" or current_stage >= 9:
			aff_milestone_lbl.hide()
		else:
			aff_milestone_lbl.show()
			var event_manager = get_tree().root.get_node_or_null("EventManager")
			if event_manager and event_manager.has_method("is_event_triggered") and event_manager.is_event_triggered(milestone_event):
				aff_milestone_lbl.text = "📌 阶段里程碑: 已达成"
				aff_milestone_lbl.add_theme_color_override("font_color", Color("81c784")) # 绿
			else:
				aff_milestone_lbl.text = "📌 阶段里程碑: 尚未解锁"
				aff_milestone_lbl.add_theme_color_override("font_color", Color("e57373")) # 红

func _on_archive_app_pressed() -> void:
	if archive_panel_instance == null:
		var ArchivePanelObj = load("res://scenes/ui/archive/archive_panel.tscn")
		archive_panel_instance = ArchivePanelObj.instantiate()
		phone_panel.add_child(archive_panel_instance)
		archive_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		phone_panel.move_child(archive_panel_instance, -1)
	archive_panel_instance.show_panel()

func _on_camera_app_pressed() -> void:
	if camera_panel_instance == null:
		var CameraPanelObj = load("res://scenes/ui/mobile/camera_panel.tscn")
		camera_panel_instance = CameraPanelObj.instantiate()
		get_tree().get_root().add_child(camera_panel_instance)
		camera_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		camera_panel_instance.camera_closed.connect(_on_camera_closed)
	else:
		get_tree().get_root().move_child(camera_panel_instance, -1)
		
	camera_panel_instance.show_panel()
	
	# 隐藏手机界面和主界面UI
	hide_phone()
	# 找到 MainScene 里的 UIPanel 并隐藏
	var main_scene = get_tree().get_root().get_node_or_null("MainScene")
	if main_scene and main_scene.has_node("UIPanel"):
		main_scene.get_node("UIPanel").visible = false

func _on_camera_closed() -> void:
	# 恢复主界面UI并显示手机
	var main_scene = get_tree().get_root().get_node_or_null("MainScene")
	if main_scene and main_scene.has_node("UIPanel"):
		main_scene.get_node("UIPanel").visible = true
	show_phone()

func _on_album_app_pressed() -> void:
	if album_panel_instance == null:
		var AlbumPanelObj = load("res://scenes/ui/mobile/album_panel.tscn")
		album_panel_instance = AlbumPanelObj.instantiate()
		phone_panel.add_child(album_panel_instance)
		album_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		phone_panel.move_child(album_panel_instance, -1)
		
	# Reset picker mode when opening directly from app list
	album_panel_instance.set_picker_mode(false)
	if album_panel_instance.photo_picked.is_connected(_on_album_photo_picked_for_cover):
		album_panel_instance.photo_picked.disconnect(_on_album_photo_picked_for_cover)
	album_panel_instance.show_panel()

func _on_sms_app_pressed() -> void:
	if contact_list_instance == null:
		var ContactListObj = load("res://scenes/ui/mobile/chat/mobile_contact_list.tscn")
		contact_list_instance = ContactListObj.instantiate()
		phone_panel.add_child(contact_list_instance)
		contact_list_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		contact_list_instance.back_requested.connect(_on_contact_list_back)
		contact_list_instance.character_selected.connect(_on_character_selected)
	else:
		phone_panel.move_child(contact_list_instance, -1)
	contact_list_instance.show_panel()

func _on_moments_button_pressed() -> void:
	if moments_panel_instance == null:
		var MomentsPanelObj = load("res://scenes/ui/mobile/moments/moments_panel.tscn")
		moments_panel_instance = MomentsPanelObj.instantiate()
		phone_panel.add_child(moments_panel_instance)
		moments_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		moments_panel_instance.cover_pick_requested.connect(_on_moments_cover_pick_requested)
	else:
		phone_panel.move_child(moments_panel_instance, -1)
	moments_panel_instance.show_panel()

func _on_moments_cover_pick_requested() -> void:
	if album_panel_instance == null:
		var AlbumPanelObj = load("res://scenes/ui/mobile/album_panel.tscn")
		album_panel_instance = AlbumPanelObj.instantiate()
		phone_panel.add_child(album_panel_instance)
		album_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		phone_panel.move_child(album_panel_instance, -1)
		
	album_panel_instance.set_picker_mode(true, "更换封面")
	if not album_panel_instance.photo_picked.is_connected(_on_album_photo_picked_for_cover):
		album_panel_instance.photo_picked.connect(_on_album_photo_picked_for_cover)
	album_panel_instance.show_panel()

func _on_album_photo_picked_for_cover(path: String) -> void:
	if album_panel_instance:
		if album_panel_instance.photo_picked.is_connected(_on_album_photo_picked_for_cover):
			album_panel_instance.photo_picked.disconnect(_on_album_photo_picked_for_cover)
		album_panel_instance.hide_panel()
		
	if moments_panel_instance:
		moments_panel_instance.update_cover_from_album(path)

func _on_contact_list_back() -> void:
	if contact_list_instance:
		contact_list_instance.hide_panel()

func _on_character_selected(char_id: String) -> void:
	if chat_panel_instance == null:
		var ChatPanelObj = load("res://scenes/ui/mobile/chat/mobile_chat_panel.tscn")
		chat_panel_instance = ChatPanelObj.instantiate()
		phone_panel.add_child(chat_panel_instance)
		chat_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		chat_panel_instance.back_requested.connect(_on_chat_panel_back)
		chat_panel_instance.incoming_call_ended.connect(_on_incoming_call_ended)
	else:
		phone_panel.move_child(chat_panel_instance, -1)
		
	chat_panel_instance.setup(char_id)
	chat_panel_instance.show_panel()

func _on_chat_panel_back() -> void:
	if chat_panel_instance:
		chat_panel_instance.hide_panel()

func _on_incoming_call_ended() -> void:
	hide_phone()

func open_call_directly(char_id: String, is_video: bool, is_fixed: bool = false) -> void:
	if chat_panel_instance == null:
		var ChatPanelObj = load("res://scenes/ui/mobile/chat/mobile_chat_panel.tscn")
		chat_panel_instance = ChatPanelObj.instantiate()
		phone_panel.add_child(chat_panel_instance)
		chat_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		chat_panel_instance.back_requested.connect(_on_chat_panel_back)
		chat_panel_instance.incoming_call_ended.connect(_on_incoming_call_ended)
	else:
		phone_panel.move_child(chat_panel_instance, -1)
		
	chat_panel_instance.setup(char_id)
	chat_panel_instance.show_panel()
	
	# 延迟一帧等待 chat_panel 准备完毕，然后直接触发对应的通话按钮并传递参数
	await get_tree().process_frame
	if is_video:
		chat_panel_instance.start_video_call(true, is_fixed)
	else:
		chat_panel_instance.start_voice_call(true, is_fixed)

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "slide_down":
		hide()
		if chat_panel_instance:
			chat_panel_instance.hide_panel(true)
			if chat_panel_instance.voice_call_panel_instance:
				chat_panel_instance.voice_call_panel_instance.hide()
			if chat_panel_instance.video_call_panel_instance:
				chat_panel_instance.video_call_panel_instance.hide()
