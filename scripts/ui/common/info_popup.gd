extends CanvasLayer

signal popup_closed

@onready var close_button: Button = $Control/CenterContainer/PopupPanel/HBox/RightArea/VBox/TopHBox/CloseButton
@onready var icon_rect: TextureRect = $Control/CenterContainer/PopupPanel/HBox/LeftArea/Icon
@onready var owned_label: Label = $Control/CenterContainer/PopupPanel/HBox/LeftArea/OwnedBox/Margin/HBox/OwnedLabel
@onready var title_label: Label = $Control/CenterContainer/PopupPanel/HBox/RightArea/VBox/TopHBox/TagPanel/Margin/TitleLabel
@onready var item_name_label: Label = $Control/CenterContainer/PopupPanel/HBox/RightArea/VBox/ItemNameLabel
@onready var desc_label: Label = $Control/CenterContainer/PopupPanel/HBox/RightArea/VBox/DescLabel
@onready var dim_bg: ColorRect = $Control/DimBg

func _ready() -> void:
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# Optionally, clicking the dim background closes it
	if dim_bg:
		dim_bg.gui_input.connect(_on_dim_bg_gui_input)

func setup(title_text: String, item_name: String, icon_texture: Texture2D, desc_text: String, owned_count: String = "") -> void:
	if not is_inside_tree():
		await ready
		
	title_label.text = title_text
	item_name_label.text = item_name
	icon_rect.texture = icon_texture
	desc_label.text = desc_text
	
	if owned_count == "":
		owned_label.text = "0"
	else:
		owned_label.text = owned_count

func _on_close_pressed() -> void:
	popup_closed.emit()
	queue_free()

func _on_dim_bg_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_close_pressed()
