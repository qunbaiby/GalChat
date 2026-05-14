extends Control
class_name DrawingBoardPanel

signal image_captured(base64_string: String)
signal close_requested()

@onready var viewport: SubViewport = %SubViewport
@onready var lines_container: Node2D = %LinesContainer
@onready var drawing_area: Control = %DrawingArea

@export var line_color: Color = Color.BLACK
@export var line_width: float = 4.0

var current_line: Line2D = null
var is_drawing: bool = false

func _ready() -> void:
	var clear_btn = %ClearButton
	var guide_btn = %GuideButton
	var close_btn = %CloseButton
	
	clear_btn.pressed.connect(_on_clear_pressed)
	guide_btn.pressed.connect(_on_guide_pressed)
	close_btn.pressed.connect(func(): close_requested.emit())
	
	drawing_area.gui_input.connect(_on_drawing_area_gui_input)

func _on_drawing_area_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_drawing(event.position)
			else:
				stop_drawing()
	elif event is InputEventMouseMotion and is_drawing:
		add_point(event.position)

func start_drawing(pos: Vector2) -> void:
	is_drawing = true
	current_line = Line2D.new()
	current_line.default_color = line_color
	current_line.width = line_width
	current_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	current_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	current_line.joint_mode = Line2D.LINE_JOINT_ROUND
	current_line.antialiased = true
	lines_container.add_child(current_line)
	current_line.add_point(pos)

func add_point(pos: Vector2) -> void:
	if current_line:
		current_line.add_point(pos)

func stop_drawing() -> void:
	is_drawing = false
	current_line = null

func _on_clear_pressed() -> void:
	for child in lines_container.get_children():
		child.queue_free()

func _on_guide_pressed() -> void:
	capture_and_emit()

func capture_and_emit() -> void:
	# 等待渲染完成
	await RenderingServer.frame_post_draw
	var img: Image = viewport.get_texture().get_image()
	if img:
		var buffer: PackedByteArray = img.save_png_to_buffer()
		var base64_str: String = Marshalls.raw_to_base64(buffer)
		image_captured.emit(base64_str)

func show_loading(text: String) -> void:
	var loading_label = get_node_or_null("%LoadingLabel")
	var loading_panel = get_node_or_null("%LoadingPanel")
	if loading_panel:
		if loading_label:
			loading_label.text = text
		loading_panel.show()

func hide_loading() -> void:
	var loading_panel = get_node_or_null("%LoadingPanel")
	if loading_panel:
		loading_panel.hide()
