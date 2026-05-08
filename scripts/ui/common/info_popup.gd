extends CanvasLayer

signal popup_closed

@onready var title_label: Label = $Control/CenterContainer/PopupPanel/VBox/TitleBar/Margin/HBox/TitleLabel
@onready var close_button: Button = $Control/CenterContainer/PopupPanel/VBox/TitleBar/Margin/HBox/CloseButton
@onready var icon_rect: TextureRect = $Control/CenterContainer/PopupPanel/VBox/ContentMargin/ContentVBox/TopHBox/LeftVBox/IconPanel/Margin/Icon
@onready var owned_label: Label = $Control/CenterContainer/PopupPanel/VBox/ContentMargin/ContentVBox/TopHBox/LeftVBox/OwnedLabel
@onready var item_name_label: Label = $Control/CenterContainer/PopupPanel/VBox/ContentMargin/ContentVBox/TopHBox/RightVBox/ItemNameLabel
@onready var desc_label: Label = $Control/CenterContainer/PopupPanel/VBox/ContentMargin/ContentVBox/TopHBox/RightVBox/DescLabel
@onready var confirm_button: Button = $Control/CenterContainer/PopupPanel/VBox/ContentMargin/ContentVBox/ConfirmButton
@onready var dim_bg: ColorRect = $Control/DimBg

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	confirm_button.pressed.connect(_on_close_pressed)
	
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
		owned_label.hide()
	else:
		owned_label.text = "已拥有: " + owned_count
		owned_label.show()

func _on_close_pressed() -> void:
	popup_closed.emit()
	queue_free()

func _on_dim_bg_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_close_pressed()
