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
    var event_desc = "玩家点了一份【" + item_name + "】。"
    
    deepseek_client.generate_npc_event_dialogue(npc_id, event_desc)

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
    # 应用属性增益
    var profile = GameDataManager.profile
    var stats_to_add = item_data.get("stats", {})
    var toast_msg = ""
    
    if stats_to_add.has("energy"):
        var val = stats_to_add["energy"]
        profile.current_energy += val
        if profile.current_energy > profile.max_energy:
            profile.current_energy = profile.max_energy
        toast_msg += "行动力 +%d  " % val
        
    if stats_to_add.has("mood"):
        var val = stats_to_add["mood"]
        profile.mood_value += val
        if profile.mood_value > 100:
            profile.mood_value = 100
        toast_msg += "心情 +%d  " % val
        
    if stats_to_add.has("stress"):
        var val = stats_to_add["stress"]
        profile.stress_value += val # stress 是负数，所以是加上负数（减少压力）
        if profile.stress_value < 0:
            profile.stress_value = 0
        toast_msg += "压力 %d  " % val
        
    profile.save_profile()
    
    if toast_msg != "" and ToastManager:
        ToastManager.show_system_toast("享用完毕！\n" + toast_msg)

    # 关闭当前弹窗并从树中移除
    hide()
    
    # 优先查找当前场景（通常就是快捷地图场景）
    var target_scene = null
    var children = get_tree().root.get_children()
    for i in range(children.size() - 1, -1, -1):
        var child = children[i]
        if child.name.begins_with("QuickLocationScene"):
            target_scene = child
            break
    if not target_scene:
        target_scene = get_tree().current_scene
            
    var existing_panel = null
    if target_scene and target_scene.has_node("DialoguePanel"):
        existing_panel = target_scene.get_node("DialoguePanel")
    
    if existing_panel:
        existing_panel.modulate = Color(1, 1, 1, 1) # 强制重置透明度
        existing_panel.self_modulate = Color(1, 1, 1, 1)
        existing_panel.show() # 确保它变为可见状态！
        
        # 将对话面板移到节点树末尾（最顶层渲染），防止被背景或菜单遮挡
        if existing_panel.get_parent():
            existing_panel.get_parent().move_child(existing_panel, -1)
            
        existing_panel.play_single_line("ya", "雅", ai_response_text, true)
    else:
        # 兜底逻辑
        var dialogue_scene = load("res://scenes/ui/common/dialogue_panel.tscn")
        if dialogue_scene:
            var canvas_layer = CanvasLayer.new()
            canvas_layer.layer = 100 # 确保在最前面
            get_tree().root.add_child(canvas_layer)
            
            var dialogue_panel = dialogue_scene.instantiate()
            canvas_layer.add_child(dialogue_panel)
            
            dialogue_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
            dialogue_panel.show()
            
            dialogue_panel.dialogue_finished.connect(func(): canvas_layer.queue_free())
            dialogue_panel.play_single_line("ya", "雅", ai_response_text, true)
    
    queue_free()

func _on_close_button_pressed():
    queue_free()
