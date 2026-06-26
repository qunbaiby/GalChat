extends Panel

signal back_requested
signal cover_pick_requested
signal top_style_progress_changed(progress: float)

const MOMENT_ITEM_SCENE = preload("res://scenes/ui/mobile/moments/moment_item.tscn")
const DeepSeekClientLocator = preload("res://scripts/api/utils/deepseek_client_locator.gd")

@onready var back_btn: Button = get_node_or_null("TopBar/BackBtn")
@onready var title_label: Label = get_node_or_null("TopBar/Title")
@onready var top_bar_bg: ColorRect = $TopBarBg
@onready var scroll: ScrollContainer = $Scroll

@onready var header: Control = $Scroll/ContentVBox/Header
@onready var cover_image: TextureRect = $Scroll/ContentVBox/Header/CoverImageFrame/CoverImage
@onready var change_cover_btn: Button = $Scroll/ContentVBox/Header/ChangeCoverBtn
@onready var player_name: Label = $Scroll/ContentVBox/Header/PlayerName
@onready var player_avatar: TextureRect = $Scroll/ContentVBox/Header/AvatarBg/PlayerAvatar
@onready var cover_shade: TextureRect = $Scroll/ContentVBox/Header/CoverShade

@onready var moment_list: VBoxContainer = $Scroll/ContentVBox/BodyPanel/BodyInset/BodyVBox/MomentListMargin/MomentList

@onready var image_viewer: ColorRect = $ImageViewer
@onready var full_image: TextureRect = $ImageViewer/FullImage
@onready var close_viewer_btn: Button = $ImageViewer/CloseViewerBtn

@onready var avatar_bg: Control = $Scroll/ContentVBox/Header/AvatarBg

var _is_cover_expanded: bool = false
var _original_header_height: float = 0.0
var _local_cover_path: String = ""
var _suppress_cover_click_once: bool = false
var _is_restoring_from_scroll: bool = false

func _ready() -> void:
	if is_instance_valid(back_btn):
		back_btn.pressed.connect(_on_back_pressed)
	scroll.get_v_scroll_bar().value_changed.connect(_on_scroll_changed)
	header.resized.connect(_update_cover_corner_mask)
	
	cover_image.gui_input.connect(_on_cover_gui_input)
	change_cover_btn.pressed.connect(_on_change_cover_pressed)
	
	close_viewer_btn.pressed.connect(_on_close_viewer_pressed)
	
	_original_header_height = maxf(1.0, header.custom_minimum_size.y)
	call_deferred("_connect_signals")
	call_deferred("_update_cover_corner_mask")
	hide()

func _connect_signals() -> void:
	var deepseek_client = _get_deepseek_client()
	if deepseek_client:
		if deepseek_client.has_signal("moment_reply_generated") and not deepseek_client.moment_reply_generated.is_connected(_on_ai_reply_generated):
			deepseek_client.moment_reply_generated.connect(_on_ai_reply_generated)
		if deepseek_client.has_signal("moment_generated") and not deepseek_client.moment_generated.is_connected(_on_ai_moment_generated):
			deepseek_client.moment_generated.connect(_on_ai_moment_generated)
	if MomentsManager and MomentsManager.has_signal("moments_updated") and not MomentsManager.moments_updated.is_connected(_on_moments_updated):
		MomentsManager.moments_updated.connect(_on_moments_updated)

func _get_deepseek_client() -> Node:
	return DeepSeekClientLocator.find(self)

func _process(delta: float) -> void:
	if visible:
		_connect_signals()

func _on_ai_moment_generated(moment_data: Dictionary) -> void:
	if visible:
		refresh_list()

func _on_ai_reply_generated(post_id: String, reply_text: String) -> void:
	# MomentsManager already handles appending to data, just refresh UI
	if visible:
		refresh_list()

func _on_moments_updated() -> void:
	if visible:
		refresh_list()

func show_panel() -> void:
	show()
	MomentsManager.mark_all_read()
	# 强制在显示时清理旧的 _local_cover_path，以防止打开时卡在旧的局部变量上
	_local_cover_path = ""
	_set_cover_expanded(false, false)
	if scroll:
		scroll.scroll_vertical = 0
	_update_header()
	_update_cover_corner_mask()
	refresh_list()
	_on_scroll_changed(scroll.scroll_vertical)

func _update_cover_corner_mask() -> void:
	var cover_size: Vector2 = Vector2(maxf(1.0, header.size.x), maxf(1.0, header.size.y))
	if cover_image.material is ShaderMaterial:
		(cover_image.material as ShaderMaterial).set_shader_parameter("rect_size", cover_size)
	if cover_shade.material is ShaderMaterial:
		(cover_shade.material as ShaderMaterial).set_shader_parameter("rect_size", cover_size)

func _on_scroll_changed(value: float) -> void:
	if _is_restoring_from_scroll:
		return
	if _is_cover_expanded and value > 0:
		_is_restoring_from_scroll = true
		_set_cover_expanded(false, true)
		scroll.scroll_vertical = 0
		_is_restoring_from_scroll = false
		return
	
	# 模拟微信朋友圈：顶部标题和背景从封面覆盖态逐步过渡到浅色导航栏
	var fade_start = 32.0
	var fade_end = maxf(120.0, _original_header_height - 92.0)
	var progress = clamp((value - fade_start) / maxf(1.0, fade_end - fade_start), 0.0, 1.0)
	top_bar_bg.color = Color(0.985, 0.988, 0.995, progress * 0.98)
	var title_color = Color(0.2, 0.2, 0.2, 1).lerp(Color(0.3, 0.35, 0.35, 1), progress)
	if is_instance_valid(title_label):
		title_label.add_theme_color_override("font_color", title_color)
	if is_instance_valid(back_btn):
		back_btn.add_theme_color_override("font_color", title_color)
	top_style_progress_changed.emit(progress)

func _on_cover_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if _suppress_cover_click_once:
			_suppress_cover_click_once = false
			return
		_set_cover_expanded(not _is_cover_expanded, true)

func suppress_cover_click_once() -> void:
	_suppress_cover_click_once = true

func _set_cover_expanded(expanded: bool, animate: bool = true) -> void:
	_is_cover_expanded = expanded
	var target_height: float = _get_target_header_height(expanded)
	var target_alpha: float = 0.0 if expanded else 1.0
	
	if not animate:
		header.custom_minimum_size.y = target_height
		player_name.modulate.a = target_alpha
		avatar_bg.modulate.a = target_alpha
		change_cover_btn.visible = expanded
		change_cover_btn.modulate.a = 1.0 if expanded else 0.0
		_update_cover_corner_mask()
		return
	
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(header, "custom_minimum_size:y", target_height, 0.3)
	tween.tween_property(player_name, "modulate:a", target_alpha, 0.3)
	tween.tween_property(avatar_bg, "modulate:a", target_alpha, 0.3)
	tween.tween_callback(_update_cover_corner_mask)
	
	if expanded:
		change_cover_btn.show()
		change_cover_btn.modulate.a = 0.0
		tween.tween_property(change_cover_btn, "modulate:a", 1.0, 0.3)
	else:
		tween.tween_property(change_cover_btn, "modulate:a", 0.0, 0.2)
		tween.chain().tween_callback(func(): change_cover_btn.hide())

func _get_target_header_height(expanded: bool) -> float:
	if not expanded:
		return _original_header_height
	
	var candidate_height: float = _original_header_height
	if scroll and scroll.size.y > 0.0:
		candidate_height = maxf(candidate_height, scroll.size.y)
	if size.y > 0.0:
		candidate_height = maxf(candidate_height, size.y)
	return candidate_height

func _on_change_cover_pressed() -> void:
	cover_pick_requested.emit()

func update_cover_from_album(path: String) -> void:
	_local_cover_path = path
	if GameDataManager:
		GameDataManager.set_archive_custom_config("moments_cover_path", path)
			
	_update_header()
	
	# 强制立刻重新绘制一下，以防 Godot 缓存
	if is_inside_tree():
		cover_image.queue_redraw()
		
	# 如果处于展开状态，点击换封面后要立刻收起并滚动到顶部，否则可能看不到效果
	if _is_cover_expanded:
		_set_cover_expanded(false, true)
	if scroll:
		scroll.scroll_vertical = 0

func show_image_viewer(tex: Texture2D) -> void:
	if tex:
		full_image.texture = tex
		image_viewer.show()
		image_viewer.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(image_viewer, "modulate:a", 1.0, 0.2)

func _on_close_viewer_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(image_viewer, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): image_viewer.hide())

func _update_header() -> void:
	if GameDataManager.config:
		if GameDataManager.profile and GameDataManager.profile.player_name.strip_edges() != "":
			player_name.text = GameDataManager.profile.player_name
		else:
			player_name.text = GameDataManager.config.player_name
		
		var cover_path = _local_cover_path
		if cover_path == "":
			cover_path = str(GameDataManager.get_archive_custom_config("moments_cover_path", ""))
			
		if cover_path != null and cover_path != "":
			# 在 Godot 中，使用 load 替代 Image.load_from_file 有时更稳妥，特别是图片没有被识别时
			var global_path = ProjectSettings.globalize_path(cover_path)
			
			var img_loaded = false
			
			# 第一尝试：直接用 FileAccess + Image.load_from_file 加载绝对物理路径
			var abs_path = global_path
			if not FileAccess.file_exists(abs_path):
				abs_path = cover_path
				
			if FileAccess.file_exists(abs_path):
				var img = Image.load_from_file(abs_path)
				if img and not img.is_empty():
					cover_image.texture = ImageTexture.create_from_image(img)
					img_loaded = true
				
			# 第二尝试：有些时候 Godot 的 user:// 不支持 globalize_path 得到的文件直接读取，或者路径有坑
			# 这里强制用 Image.load_from_file 尝试 user:// 原始路径
			if not img_loaded and cover_path.begins_with("user://"):
				if FileAccess.file_exists(cover_path):
					var img = Image.new()
					var err = img.load(cover_path) # 注意 Godot4 中 Image 没有直接接收 user:// 的 load_from_file 宏，需要用 img.load
					if err == OK and not img.is_empty():
						cover_image.texture = ImageTexture.create_from_image(img)
						img_loaded = true
				
			# 第三尝试：通过 ResourceLoader 强制加载
			if not img_loaded:
				var tex = load(cover_path)
				if tex is Texture2D:
					cover_image.texture = tex
					img_loaded = true
					
			if not img_loaded:
				var fallback_path = ImageManager.get_image_path("cg_luna_door_sunset")
				if fallback_path != "" and ResourceLoader.exists(fallback_path):
					cover_image.texture = load(fallback_path)
				
		else:
			var fallback_path = ImageManager.get_image_path("cg_luna_door_sunset")
			if fallback_path != "" and ResourceLoader.exists(fallback_path):
				cover_image.texture = load(fallback_path)
	
	# Avatar
	var profile = GameDataManager.profile
	if profile and profile.has_method("get_player_avatar_texture"):
		player_avatar.texture = profile.get_player_avatar_texture()
	else:
		player_avatar.texture = preload("res://icon.svg")

func hide_panel() -> void:
	hide()
	back_requested.emit()

func _on_back_pressed() -> void:
	hide_panel()

func refresh_list() -> void:
	if moment_list == null:
		push_error("[MomentsPanel] 朋友圈列表节点不存在，请检查 BodyPanel/BodyInset 场景结构。")
		return
	# Clear list
	for child in moment_list.get_children():
		child.queue_free()
		
	var moments = MomentsManager.get_all_moments()
	for moment_data in moments:
		if MOMENT_ITEM_SCENE == null:
			push_error("[MomentsPanel] 无法加载朋友圈条目场景：res://scenes/ui/mobile/moments/moment_item.tscn")
			return
		var item = MOMENT_ITEM_SCENE.instantiate()
		moment_list.add_child(item)
		if item and item.has_method("setup"):
			item.setup(moment_data)

func get_header_height() -> float:
	return _original_header_height
