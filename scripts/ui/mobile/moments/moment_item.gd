extends VBoxContainer

@onready var avatar_rect: TextureRect = $Header/Avatar
@onready var name_label: Label = $Header/Name
@onready var content_label: Label = $Content
@onready var images_grid: GridContainer = $ImagesGrid
@onready var time_label: Label = $Actions/TimeLabel
@onready var like_btn: Button = $Actions/LikeBtn
@onready var comment_btn: Button = $Actions/CommentBtn

@onready var comments_area: PanelContainer = $CommentsArea
@onready var likes_label: Label = $CommentsArea/Margin/VBox/LikesLabel
@onready var h_separator: HSeparator = $CommentsArea/Margin/VBox/HSeparator
@onready var comments_list: VBoxContainer = $CommentsArea/Margin/VBox/CommentsList

@onready var comment_input_area: HBoxContainer = $CommentInputArea
@onready var comment_input: LineEdit = $CommentInputArea/LineEdit
@onready var send_comment_btn: Button = $CommentInputArea/SendBtn

var _moment_id: String = ""

func _ready() -> void:
	like_btn.pressed.connect(_on_like_pressed)
	comment_btn.pressed.connect(_on_comment_pressed)
	send_comment_btn.pressed.connect(_on_send_comment_pressed)
	comment_input_area.hide()

func setup(data: Dictionary) -> void:
	_moment_id = data.get("id", "")
	name_label.text = data.get("author", "未知")
	content_label.text = data.get("content", "")
	time_label.text = data.get("time", "")
	
	# Load avatar
	var data_avatar = data.get("avatar", "")
	if data_avatar != "" and FileAccess.file_exists(data_avatar):
		avatar_rect.texture = load(data_avatar)
	else:
		var avatar_path = "res://assets/images/characters/%s/avatar.png" % name_label.text
		if FileAccess.file_exists(avatar_path):
			avatar_rect.texture = load(avatar_path)
		elif FileAccess.file_exists("res://assets/images/characters/avatar_%s.png" % name_label.text):
			avatar_rect.texture = load("res://assets/images/characters/avatar_%s.png" % name_label.text)
	
	# Images
	for child in images_grid.get_children():
		child.queue_free()
	var images = data.get("images", [])
	
	var img_count = images.size()
	if img_count == 1:
		images_grid.columns = 1
	elif img_count == 2 or img_count == 4:
		images_grid.columns = 2
	else:
		images_grid.columns = 3
		
	for img_path in images:
		var tex_rect = TextureRect.new()
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		
		if img_count == 1:
			tex_rect.custom_minimum_size = Vector2(180, 240)
		else:
			tex_rect.custom_minimum_size = Vector2(80, 80)
			
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_PASS
		tex_rect.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		if img_path.begins_with("user://") or img_path.begins_with("res://"):
			if FileAccess.file_exists(img_path):
				var img = Image.load_from_file(img_path)
				if img:
					tex_rect.texture = ImageTexture.create_from_image(img)
					
		tex_rect.gui_input.connect(func(event): _on_image_clicked(event, tex_rect.texture))
		images_grid.add_child(tex_rect)
		
	_update_likes_and_comments(data)

func _on_image_clicked(event: InputEvent, tex: Texture2D) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var curr = get_parent()
		while curr:
			if curr.has_method("show_image_viewer"):
				curr.show_image_viewer(tex)
				break
			curr = curr.get_parent()

func _update_likes_and_comments(data: Dictionary) -> void:
	var likes_count = data.get("likes", 0)
	var is_liked = data.get("is_liked", false)
	
	like_btn.text = "取消" if is_liked else "点赞"
	
	if likes_count > 0:
		likes_label.text = "❤ %d 人觉得很赞" % likes_count
		likes_label.show()
	else:
		likes_label.hide()
		
	for child in comments_list.get_children():
		child.queue_free()
		
	var comments = data.get("comments", [])
	for comment in comments:
		var c_label = Label.new()
		c_label.text = "%s: %s" % [comment.get("author", "未知"), comment.get("content", "")]
		c_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c_label.add_theme_font_size_override("font_size", 14)
		c_label.add_theme_color_override("font_color", Color(0.411765, 0.439216, 0.490196))
		comments_list.add_child(c_label)
		
	if likes_count > 0 and comments.size() > 0:
		h_separator.show()
	else:
		h_separator.hide()
		
	if likes_count == 0 and comments.size() == 0:
		comments_area.hide()
	else:
		comments_area.show()

func _on_like_pressed() -> void:
	if _moment_id == "": return
	MomentsManager.toggle_like(_moment_id)
	var updated_data = MomentsManager.get_moment(_moment_id)
	_update_likes_and_comments(updated_data)

func _on_comment_pressed() -> void:
	comment_input_area.visible = !comment_input_area.visible
	if comment_input_area.visible:
		comment_input.grab_focus()

func _on_send_comment_pressed() -> void:
	var text = comment_input.text.strip_edges()
	if text == "" or _moment_id == "": return
	
	var player_name = "我"
	if GameDataManager.has_method("get_config") and GameDataManager.config:
		player_name = GameDataManager.config.player_name
		
	MomentsManager.add_comment(_moment_id, player_name, text)
	comment_input.text = ""
	comment_input_area.hide()
	
	var updated_data = MomentsManager.get_moment(_moment_id)
	_update_likes_and_comments(updated_data)
	
	# Task 5: Call AI for reply
	var author = updated_data.get("author", "")
	if author != player_name:
		var deepseek_client = get_tree().root.get_node_or_null("MainScene/DeepSeekClient")
		if deepseek_client and deepseek_client.has_method("send_moment_reply"):
			deepseek_client.send_moment_reply(_moment_id, text)
		else:
			print("DeepSeekClient.send_moment_reply not found on MainScene/DeepSeekClient!")
