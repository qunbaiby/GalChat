extends Control
class_name DrawingBoardPanel

signal creation_completed(image_path: String, prompt: String)
signal creation_failed(error_msg: String)
signal close_requested()

@onready var viewport: SubViewport = %SubViewport
@onready var lines_container: Node2D = %LinesContainer
@onready var drawing_area: Control = %DrawingArea

@export var line_color: Color = Color.BLACK
@export var line_width: float = 4.0

var current_line: Line2D = null
var is_drawing: bool = false
var deepseek_client: Node = null

var _current_drawing_success_cb: Callable
var _current_drawing_fail_cb: Callable
var _current_i2i_success_cb: Callable
var _current_i2i_fail_cb: Callable

func _ready() -> void:
    var clear_btn = %ClearButton
    var guide_btn = %GuideButton
    var close_btn = %CloseButton
    
    clear_btn.pressed.connect(_on_clear_pressed)
    guide_btn.pressed.connect(_on_guide_pressed)
    close_btn.pressed.connect(func(): close_requested.emit())
    
    drawing_area.gui_input.connect(_on_drawing_area_gui_input)
    _find_deepseek_client()

func _find_deepseek_client() -> void:
    deepseek_client = DeepSeekClientLocator.find(self)

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
        _start_vision_analysis(base64_str)

func _start_vision_analysis(base64_image: String) -> void:
    if deepseek_client == null:
        creation_failed.emit("找不到 DeepSeekClient，请检查 AI 服务配置")
        return
        
    show_loading("Luna正在仔细观察草图...")
    
    # 优化提示词：只提取主体和动作，严禁描述画风
    var sys_prompt = "你是一个专业的草图分析助手。请仔细观察这幅草图，仅提取画面的核心内容：主体对象是谁/是什么、在什么场景下、正在做什么动作。\n\n【重要限制】\n1. 绝对不要描述画风（严禁出现“简笔画”、“黑白”、“线条”、“手绘”等词汇）。\n2. 直接输出纯客观的画面内容描述，不要包含任何前缀或解释。"
    var user_prompt = "请提取草图的主体内容和动作："
    
    _current_drawing_success_cb = Callable(self, "_on_drawing_vision_completed").bind(base64_image)
    _current_drawing_fail_cb = Callable(self, "_on_drawing_vision_failed")
    
    deepseek_client.vision_request_completed.connect(_current_drawing_success_cb)
    deepseek_client.vision_request_failed.connect(_current_drawing_fail_cb)
    
    deepseek_client.send_vision_request(sys_prompt, user_prompt, base64_image)

func _disconnect_drawing_vision_signals() -> void:
    if _current_drawing_success_cb.is_valid() and deepseek_client.vision_request_completed.is_connected(_current_drawing_success_cb):
        deepseek_client.vision_request_completed.disconnect(_current_drawing_success_cb)
    if _current_drawing_fail_cb.is_valid() and deepseek_client.vision_request_failed.is_connected(_current_drawing_fail_cb):
        deepseek_client.vision_request_failed.disconnect(_current_drawing_fail_cb)

func _on_drawing_vision_completed(response: Dictionary, base64_image: String) -> void:
    _disconnect_drawing_vision_signals()
    
    # 打印原始返回值，方便排查解析问题
    print("[DrawingBoardPanel] Vision API Raw Response: ", response)
    
    var vision_text = ""
    
    # 兼容两种 API 响应格式：
    # 1. OpenAI 标准格式 (choices[0].message.content)
    if response.has("choices") and response["choices"] is Array and response["choices"].size() > 0:
        var choice = response["choices"][0]
        if choice is Dictionary and choice.has("message"):
            var msg = choice["message"]
            if msg is Dictionary and msg.has("content"):
                var content = msg["content"]
                if typeof(content) == TYPE_STRING:
                    vision_text = content
                elif typeof(content) == TYPE_ARRAY:
                    # 有些视觉模型的 content 依然是数组格式
                    for c in content:
                        if c is Dictionary and c.has("text"):
                            vision_text += c["text"]
                            
    # 2. 火山引擎 Doubao Responses 格式 (output[0].message.content[0].text)
    if vision_text.is_empty() and response.has("output") and response["output"] is Array:
        for item in response["output"]:
            if item is Dictionary and item.get("type") == "message" and item.has("content") and item["content"] is Array:
                for c in item["content"]:
                    if c is Dictionary and c.get("type") == "output_text":
                        vision_text += c.get("text", "")
                            
    # 去除前后空白字符
    vision_text = vision_text.strip_edges()
    
    if vision_text.is_empty():
        vision_text = "一幅充满想象力的画作" # Fallback
        
    print("[DrawingBoardPanel] 视觉分析完成，提取的提示词为: ", vision_text)
    
    show_loading("Luna正在根据草图作画...")
    
    # 增加强烈的风格设定约束
    var image_prompt = "请根据草图的构图，结合以下画面内容，绘制一幅高质量的插画：\n"
    image_prompt += "【画面内容】：" + vision_text + "\n"
    image_prompt += "【风格要求】：精美的二次元动漫风格，色彩鲜艳，光影丰富，细节精致，赛璐璐涂法，大师级画作，高分辨率。"
    
    _current_i2i_success_cb = Callable(self, "_on_image_to_image_completed").bind(vision_text)
    _current_i2i_fail_cb = Callable(self, "_on_image_to_image_failed")
    
    deepseek_client.image_to_image_completed.connect(_current_i2i_success_cb)
    deepseek_client.image_to_image_failed.connect(_current_i2i_fail_cb)
    
    deepseek_client.send_image_to_image_request(base64_image, image_prompt)

func _disconnect_i2i_signals() -> void:
    if _current_i2i_success_cb.is_valid() and deepseek_client.image_to_image_completed.is_connected(_current_i2i_success_cb):
        deepseek_client.image_to_image_completed.disconnect(_current_i2i_success_cb)
    if _current_i2i_fail_cb.is_valid() and deepseek_client.image_to_image_failed.is_connected(_current_i2i_fail_cb):
        deepseek_client.image_to_image_failed.disconnect(_current_i2i_fail_cb)

func _on_drawing_vision_failed(error_msg: String) -> void:
    _disconnect_drawing_vision_signals()
    hide_loading()
    creation_failed.emit("草图分析失败: " + error_msg)

func _on_image_to_image_completed(image_path: String, vision_text: String) -> void:
    _disconnect_i2i_signals()
    hide_loading()
    creation_completed.emit(image_path, vision_text)

func _on_image_to_image_failed(error_msg: String) -> void:
    _disconnect_i2i_signals()
    hide_loading()
    creation_failed.emit("生成失败: " + error_msg)

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
