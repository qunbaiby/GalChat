extends Control

@onready var count_label: Label = $Backdrop/ContentMargin/RootVBox/BodyHBox/LeftRail/LeftMargin/LeftVBox/CountLabel
@onready var items_grid: GridContainer = $Backdrop/ContentMargin/RootVBox/BodyHBox/LeftRail/LeftMargin/LeftVBox/ListScroll/ItemsGrid
@onready var locked_only_button: CheckButton = $Backdrop/ContentMargin/RootVBox/BodyHBox/LeftRail/LeftMargin/LeftVBox/ListFooter/LockedOnlyButton
@onready var char_portrait: AnimatedSprite2D = $Backdrop/ContentMargin/RootVBox/BodyHBox/CenterStage/PreviewMargin/PreviewVBox/PortraitHolder/PortraitPivot/CharPortrait
@onready var preview_name_label: Label = $Backdrop/ContentMargin/RootVBox/BodyHBox/CenterStage/PreviewMargin/PreviewVBox/PreviewNameLabel
@onready var detail_name: Label = $Backdrop/ContentMargin/RootVBox/BodyHBox/RightInfo/InfoMargin/InfoVBox/DetailName
@onready var detail_type_tag: Label = $Backdrop/ContentMargin/RootVBox/BodyHBox/RightInfo/InfoMargin/InfoVBox/TagRow/TypeTag
@onready var detail_status_tag: Label = $Backdrop/ContentMargin/RootVBox/BodyHBox/RightInfo/InfoMargin/InfoVBox/TagRow/StatusTag
@onready var detail_collection_label: Label = $Backdrop/ContentMargin/RootVBox/BodyHBox/RightInfo/InfoMargin/InfoVBox/DetailCollectionLabel
@onready var detail_desc: RichTextLabel = $Backdrop/ContentMargin/RootVBox/BodyHBox/RightInfo/InfoMargin/InfoVBox/DetailDesc
@onready var detail_icon: TextureRect = $Backdrop/ContentMargin/RootVBox/BodyHBox/RightInfo/InfoMargin/InfoVBox/DetailPreviewPanel/DetailIcon
@onready var wear_button: Button = $Backdrop/ContentMargin/RootVBox/BodyHBox/RightInfo/InfoMargin/InfoVBox/WearButton
@onready var close_button: Button = $Backdrop/ContentMargin/RootVBox/TopBar/CloseButton

const ITEM_SCENE = preload("res://scenes/ui/wardrobe/wardrobe_item.tscn")
const DATA_PATH = "res://assets/data/wardrobe/wardrobe_data.json"
const DEFAULT_SPRITE_PATH = "res://assets/images/characters/Luna/luna.tres"

var outfits_data: Array = []
var selected_outfit: Dictionary = {}
var current_outfit_id: String = "default"
var unlocked_outfit_ids: Array = ["default"]

signal outfit_changed(new_outfit_id: String)


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	wear_button.pressed.connect(_on_wear_pressed)
	locked_only_button.toggled.connect(_on_locked_filter_toggled)
	visibility_changed.connect(_on_visibility_changed)
	hide()


func _on_visibility_changed() -> void:
	if visible:
		_load_data()
		_refresh_ui()


func _load_data() -> void:
	outfits_data.clear()
	if FileAccess.file_exists(DATA_PATH):
		var file := FileAccess.open(DATA_PATH, FileAccess.READ)
		var json := JSON.new()
		var err := json.parse(file.get_as_text())
		if err == OK:
			var data: Variant = json.get_data()
			if data is Dictionary and data.has("outfits"):
				outfits_data = (data["outfits"] as Array).duplicate(true)
	else:
		printerr("Wardrobe data not found at: ", DATA_PATH)

	if GameDataManager.profile:
		current_outfit_id = str(GameDataManager.profile.current_outfit)
		unlocked_outfit_ids = GameDataManager.profile.unlocked_outfits.duplicate()
		if not unlocked_outfit_ids.has("default"):
			unlocked_outfit_ids.append("default")


func _get_filtered_outfits() -> Array:
	if not locked_only_button.button_pressed:
		return outfits_data
	var filtered: Array = []
	for outfit in outfits_data:
		if not unlocked_outfit_ids.has(outfit.get("id", "")):
			filtered.append(outfit)
	return filtered


func _refresh_ui() -> void:
	for child in items_grid.get_children():
		child.queue_free()

	var visible_outfits: Array = _get_filtered_outfits()
	var preferred_item: Node = null

	for outfit in visible_outfits:
		var item: Node = ITEM_SCENE.instantiate()
		items_grid.add_child(item)
		if item.has_method("setup"):
			item.call("setup", outfit, current_outfit_id, unlocked_outfit_ids)
		if item.has_signal("item_selected"):
			item.connect("item_selected", Callable(self, "_on_item_selected"))
		if outfit.get("id", "") == current_outfit_id:
			preferred_item = item

	_refresh_count_label(visible_outfits.size())

	if visible_outfits.is_empty():
		_apply_empty_state()
		return

	if preferred_item == null and items_grid.get_child_count() > 0:
		preferred_item = items_grid.get_child(0)

	if preferred_item:
		var preferred_outfit: Variant = preferred_item.get("outfit_data")
		if preferred_outfit is Dictionary:
			_on_item_selected(preferred_outfit, preferred_item)


func _refresh_count_label(visible_count: int) -> void:
	var unlocked_count := 0
	for outfit in outfits_data:
		if unlocked_outfit_ids.has(outfit.get("id", "")):
			unlocked_count += 1
	if locked_only_button.button_pressed:
		count_label.text = "仅看未拥有 · %d 件待收集" % visible_count
	else:
		count_label.text = "已解锁 %d / %d 套衣装" % [unlocked_count, outfits_data.size()]


func _apply_empty_state() -> void:
	selected_outfit = {}
	detail_name.text = "暂无符合筛选条件的服装"
	detail_type_tag.text = "衣橱"
	detail_status_tag.text = "空结果"
	detail_collection_label.text = "试着关闭“仅看未拥有”来查看全部衣装。"
	detail_desc.text = "当前筛选条件下没有可展示的服装条目。你可以先解锁更多衣装，或切回全部查看当前已拥有的搭配。"
	detail_icon.texture = null
	preview_name_label.text = "当前搭配预览"
	_refresh_preview_by_id(current_outfit_id)
	wear_button.text = "暂无可用搭配"
	wear_button.disabled = true


func _on_item_selected(outfit: Dictionary, item_node: Node) -> void:
	selected_outfit = outfit.duplicate(true)
	for child in items_grid.get_children():
		if child.has_method("set_selected"):
			child.call("set_selected", child == item_node)

	var outfit_id := str(outfit.get("id", "default"))
	var unlocked := unlocked_outfit_ids.has(outfit_id)

	detail_name.text = str(outfit.get("name", "未知服装"))
	detail_type_tag.text = "时装"
	detail_status_tag.text = "当前穿着" if outfit_id == current_outfit_id else ("已拥有" if unlocked else "未解锁")
	detail_collection_label.text = "衣橱收集 %d / %d · 当前筛选 %d 件" % [
		_get_unlocked_count(),
		outfits_data.size(),
		_get_filtered_outfits().size()
	]
	var desc_text := str(outfit.get("description", "暂时还没有这套衣装的描述。"))
	if not unlocked:
		desc_text += "\n\n尚未解锁：可通过后续剧情、活动或特殊事件获得。"
	detail_desc.text = desc_text

	var icon_path := str(outfit.get("icon", "")).strip_edges()
	if icon_path != "" and ResourceLoader.exists(icon_path):
		detail_icon.texture = load(icon_path)
	else:
		detail_icon.texture = null

	preview_name_label.text = str(outfit.get("name", "当前搭配预览"))
	_refresh_preview_sprite(str(outfit.get("sprite", DEFAULT_SPRITE_PATH)))
	_refresh_action_state(outfit_id, unlocked)


func _refresh_preview_by_id(outfit_id: String) -> void:
	for outfit in outfits_data:
		if str(outfit.get("id", "")) == outfit_id:
			preview_name_label.text = str(outfit.get("name", "当前搭配预览"))
			_refresh_preview_sprite(str(outfit.get("sprite", DEFAULT_SPRITE_PATH)))
			return
	preview_name_label.text = "当前搭配预览"
	_refresh_preview_sprite(DEFAULT_SPRITE_PATH)


func _refresh_preview_sprite(sprite_path: String) -> void:
	var resolved_path := sprite_path
	if resolved_path == "" or not ResourceLoader.exists(resolved_path):
		resolved_path = DEFAULT_SPRITE_PATH
	if not ResourceLoader.exists(resolved_path):
		char_portrait.sprite_frames = null
		return

	var res := load(resolved_path)
	if res is SpriteFrames:
		char_portrait.sprite_frames = res
		var frames := res as SpriteFrames
		if frames.has_animation("default"):
			char_portrait.play("default")
		elif frames.get_animation_names().size() > 0:
			char_portrait.play(frames.get_animation_names()[0])
	elif res is Texture2D:
		var frames := SpriteFrames.new()
		frames.add_animation("default")
		frames.add_frame("default", res)
		char_portrait.sprite_frames = frames
		char_portrait.play("default")
	else:
		char_portrait.sprite_frames = null


func _refresh_action_state(outfit_id: String, unlocked: bool) -> void:
	if not unlocked:
		wear_button.text = "尚未解锁"
		wear_button.disabled = true
	elif outfit_id == current_outfit_id:
		wear_button.text = "当前穿着"
		wear_button.disabled = true
	else:
		wear_button.text = "使用搭配"
		wear_button.disabled = false


func _get_unlocked_count() -> int:
	var count := 0
	for outfit in outfits_data:
		if unlocked_outfit_ids.has(outfit.get("id", "")):
			count += 1
	return count


func _on_wear_pressed() -> void:
	if selected_outfit.is_empty():
		return

	var new_id := str(selected_outfit.get("id", "default"))
	if not unlocked_outfit_ids.has(new_id):
		return

	current_outfit_id = new_id
	if GameDataManager.profile:
		GameDataManager.profile.current_outfit = current_outfit_id
		GameDataManager.profile.save_profile()
		if GameDataManager.save_manager:
			GameDataManager.save_manager.auto_save()

	for child in items_grid.get_children():
		if child.has_method("update_wearing_status"):
			child.call("update_wearing_status", current_outfit_id)

	_refresh_action_state(current_outfit_id, true)
	detail_status_tag.text = "当前穿着"
	outfit_changed.emit(current_outfit_id)


func _on_locked_filter_toggled(_pressed: bool) -> void:
	_refresh_ui()


func _on_close_pressed() -> void:
	hide()
