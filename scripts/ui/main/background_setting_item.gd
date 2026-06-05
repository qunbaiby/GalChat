extends Button

@onready var preview_frame: PanelContainer = $PreviewFrame
@onready var selection_frame: PanelContainer = $SelectionFrame
@onready var preview_rect: TextureRect = $PreviewFrame/PreviewMargin/PreviewClipPanel/Preview
@onready var info_bubble: PanelContainer = $InfoBubble
@onready var title_label: Label = $InfoBubble/InfoMargin/InfoVBox/TitleLabel
@onready var subtitle_label: Label = $InfoBubble/InfoMargin/InfoVBox/SubTitleLabel
@onready var state_badge: PanelContainer = $StateBadge
@onready var state_label: Label = $StateBadge/BadgeLabel
@onready var unlock_condition_bar: PanelContainer = $UnlockConditionBar
@onready var unlock_condition_label: Label = $UnlockConditionBar/HBox/ConditionLabel

var item_data: Dictionary = {}
var _is_selected: bool = false
var _is_unlocked: bool = true

func setup(data: Dictionary, is_selected: bool, is_active: bool, is_unlocked: bool) -> void:
	item_data = data.duplicate(true)
	_is_selected = is_selected
	_is_unlocked = is_unlocked
	title_label.text = str(item_data.get("name", "未命名场景"))
	subtitle_label.text = str(item_data.get("subtitle", "")).strip_edges()
	state_badge.visible = is_active and _is_unlocked
	if is_active:
		state_label.text = "使用中"
	unlock_condition_bar.visible = not _is_unlocked
	unlock_condition_label.text = str(item_data.get("unlock_condition", "暂未解锁")).strip_edges()

	var preview_path: String = str(item_data.get("preview_path", "")).strip_edges()
	if preview_path != "" and ResourceLoader.exists(preview_path):
		preview_rect.texture = load(preview_path) as Texture2D
	else:
		preview_rect.texture = null
	_apply_card_state()

func _apply_card_state() -> void:
	selection_frame.visible = _is_selected
	preview_rect.modulate = Color(1, 1, 1, 1) if _is_unlocked else Color(0.42, 0.42, 0.42, 1)
	title_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_font_size_override("font_size", 12)
	state_label.add_theme_font_size_override("font_size", 13)
	unlock_condition_label.add_theme_font_size_override("font_size", 11)
	subtitle_label.visible = subtitle_label.text != ""
