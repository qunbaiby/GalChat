extends CanvasLayer

var item_data: Dictionary = {}
var ai_response_text: String = ""
var is_generating: bool = false
var is_progress_done: bool = false

@onready var title_label = $Panel/TitleLabel
@onready var progress_bar = $Panel/ProgressBar
@onready var result_icon = $Panel/ResultIcon
@onready var icon_label = $Panel/ResultIcon/PlaceholderIcon/IconLabel
@onready var dialogue_label = $Panel/DialogueLabel
@onready var consume_button = $Panel/ConsumeButton
@onready var close_button = $Panel/CloseButton
@onready var deepseek_client = DeepSeekClient.new()

func setup(item: Dictionary) -> void:
    item_data = item

func _ready():
    if item_data.is_empty():
        return
        
    add_child(deepseek_client)
    deepseek_client.npc_event_dialogue_completed.connect(_on_ai_success)
    deepseek_client.npc_event_dialogue_failed.connect(_on_ai_failed)
    
    icon_label.text = item_data.get("name", "物品")
    
    # 开始进度条动画
    _start_progress()
    
    # 同时发起 AI 请求
    _request_ai_dialogue()

func _start_progress():
    is_progress_done = false
    progress_bar.value = 0
    var tween = create_tween()
    tween.tween_property(progress_bar, "value", 100.0, 3.0) # 假设制作需要 3 秒
    tween.finished.connect(_on_progress_finished)

func _on_progress_finished():
    is_progress_done = true
    _check_completion()

func _request_ai_dialogue():
    if GameDataManager.config.api_key.is_empty():
        ai_response_text = "你的 " + item_data.get("name", "单品") + " 做好啦，慢用哦。"
        _on_ai_finished()
        return
        
    is_generating = true
    
    var npc_id = "ya" # 咖啡厅专属雅
    var item_name = item_data.get("name", "单品")
    
    deepseek_client.generate_npc_event_dialogue(npc_id, "order", {"item_name": item_name})

func _on_ai_success(dialogue: String):
    ai_response_text = dialogue
    _on_ai_finished()

func _on_ai_failed(error_msg: String):
    ai_response_text = "（雅微笑着递上了单品）" # 兜底
    _on_ai_finished()

func _on_ai_finished():
    is_generating = false
    _check_completion()

func _check_completion():
    # 只有当进度条跑完且AI回复也生成完，才展示结果
    if is_progress_done and not is_generating:
        progress_bar.hide()
        title_label.text = "制作完成！"
        result_icon.show()
        consume_button.show()
        close_button.show()
        
        # 将AI的台词先放在标签里，等点击“食用”再显示
        dialogue_label.text = "[b]雅:[/b] " + ai_response_text

func _on_consume_button_pressed():
    # 关闭当前弹窗并从树中移除
    hide()
    
    # 优先查找当前正在交互的快捷地图场景（因为它肯定在树上并且处于激活状态）
    var target_scene = null
    var root = get_tree().root
    for child in root.get_children():
        if child.name == "QuickLocationScene":
            target_scene = child
            break
            
    var existing_panel = null
    if target_scene and target_scene.has_node("DialoguePanel"):
        existing_panel = target_scene.get_node("DialoguePanel")
    
    if existing_panel:
        existing_panel.modulate = Color(1, 1, 1, 1) # 强制重置透明度，防止被别的地方 Tween 设为了全透明
        existing_panel.self_modulate = Color(1, 1, 1, 1)
        existing_panel.show() # 确保它变为可见状态！
        # 确保面板处于最顶层
        existing_panel.move_to_front()
        existing_panel.play_single_line("ya", "雅", ai_response_text, true)
    else:
        # 兜底逻辑
        var dialogue_scene = load("res://scenes/ui/common/dialogue_panel.tscn")
        if dialogue_scene:
            var canvas_layer = CanvasLayer.new()
            canvas_layer.layer = 100 # 确保在最前面
            var dialogue_panel = dialogue_scene.instantiate()
            canvas_layer.add_child(dialogue_panel)
            get_tree().root.add_child(canvas_layer)
            
            dialogue_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
            dialogue_panel.size = get_viewport().get_visible_rect().size
            dialogue_panel.show()
            
            dialogue_panel.dialogue_finished.connect(func(): canvas_layer.queue_free())
            dialogue_panel.play_single_line("ya", "雅", ai_response_text, true)
    
    queue_free()

func _on_close_button_pressed():
    queue_free()
