extends Button

static var _grayscale_texture_cache: Dictionary = {}

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
var _is_active: bool = false
var _preview_source_texture: Texture2D = null
var _compact_mode: bool = false

func setup(data: Dictionary, is_selected: bool, is_active: bool, is_unlocked: bool) -> void:
    item_data = data.duplicate(true)
    _is_selected = is_selected
    _is_unlocked = is_unlocked
    _is_active = is_active
    title_label.text = str(item_data.get("name", "未命名场景"))
    subtitle_label.text = str(item_data.get("subtitle", "")).strip_edges()
    if is_active:
        state_label.text = "使用中"
    else:
        state_label.text = ""
    unlock_condition_bar.visible = not _is_unlocked
    unlock_condition_label.text = str(item_data.get("unlock_condition", "暂未解锁")).strip_edges()

    var preview_path: String = str(item_data.get("preview_path", "")).strip_edges()
    if preview_path != "" and ResourceLoader.exists(preview_path):
        _preview_source_texture = load(preview_path) as Texture2D
    else:
        _preview_source_texture = null
    _apply_card_state()

func _apply_card_state() -> void:
    selection_frame.visible = _is_selected
    preview_rect.modulate = Color(1, 1, 1, 1)
    preview_rect.material = null
    preview_rect.texture = _make_grayscale_texture(_preview_source_texture) if (not _is_unlocked and _preview_source_texture != null) else _preview_source_texture
    subtitle_label.visible = subtitle_label.text != ""
    state_badge.visible = (not _compact_mode) and _is_active and _is_unlocked
    info_bubble.visible = not _compact_mode
    unlock_condition_bar.visible = _compact_mode or not _is_unlocked

func set_compact_mode(compact: bool) -> void:
    _compact_mode = compact
    _apply_card_state()

func _make_grayscale_texture(source_texture: Texture2D) -> Texture2D:
    if source_texture == null:
        return null
    var cache_key := source_texture.resource_path
    if cache_key == "":
        cache_key = str(source_texture.get_rid().get_id())
    if _grayscale_texture_cache.has(cache_key):
        return _grayscale_texture_cache[cache_key]
    var image := source_texture.get_image()
    if image == null:
        return source_texture
    var gray_image := image.duplicate()
    gray_image.decompress()
    gray_image.convert(Image.FORMAT_RGBA8)
    var width: int = gray_image.get_width()
    var height: int = gray_image.get_height()
    for y in range(height):
        for x in range(width):
            var color: Color = gray_image.get_pixel(x, y)
            var gray: float = color.r * 0.299 + color.g * 0.587 + color.b * 0.114
            gray_image.set_pixel(x, y, Color(gray, gray, gray, color.a))
    var gray_texture := ImageTexture.create_from_image(gray_image)
    _grayscale_texture_cache[cache_key] = gray_texture
    return gray_texture
