extends CharacterBody2D

signal pet_clicked()
signal bubbles_changed()

@onready var spine_sprite: SpineSprite = $SpineSprite
@onready var bubble_container: VBoxContainer = $BubbleContainer
@onready var bubble_template: PanelContainer = $BubbleContainer/SpeechBubble
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _click_start_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
    bubble_template.hide()
    
    # 动态创建一个 Control 用于可靠的点击检测，因为 Window 下物理拾取可能有坑
    var click_control = Control.new()
    # 强制指定一个默认大小，防止 collision_shape 还没初始化好导致大小为 0
    click_control.position = Vector2(-40, -10)
    click_control.size = Vector2(80, 180)
        
    if collision_shape and collision_shape.shape is RectangleShape2D:
        var size = collision_shape.shape.size
        # 确保 size 不是 0
        if size.x > 0 and size.y > 0:
            var pos = collision_shape.position - size / 2.0
            click_control.position = pos
            click_control.size = size
            
    click_control.mouse_filter = Control.MOUSE_FILTER_PASS
    click_control.gui_input.connect(_on_click_control_gui_input)
    add_child(click_control)
    
    if spine_sprite:
        var anim_state = spine_sprite.get_animation_state()
        var skeleton = spine_sprite.get_skeleton()
        if anim_state and skeleton and skeleton.get_data():
            var anims = skeleton.get_data().get_animations()
            if anims.size() > 0:
                var target_anim = anims[0].get_name()
                var anim_names = []
                for a in anims:
                    anim_names.append(a.get_name())
                    if "idle" in a.get_name().to_lower() or "daiji" in a.get_name().to_lower():
                        target_anim = a.get_name()
                
                if target_anim in anim_names:
                    anim_state.set_animation(target_anim, true, 0)
        elif is_inside_tree():
            # 如果 skeleton 还没准备好，延迟一帧处理
            call_deferred("_ready_delayed_spine")

func _ready_delayed_spine() -> void:
    if spine_sprite:
        var anim_state = spine_sprite.get_animation_state()
        var skeleton = spine_sprite.get_skeleton()
        if anim_state and skeleton and skeleton.get_data():
            var anims = skeleton.get_data().get_animations()
            if anims.size() > 0:
                var target_anim = anims[0].get_name()
                var anim_names = []
                for a in anims:
                    anim_names.append(a.get_name())
                    if "idle" in a.get_name().to_lower() or "daiji" in a.get_name().to_lower():
                        target_anim = a.get_name()
                
                if target_anim in anim_names:
                    anim_state.set_animation(target_anim, true, 0)

func _on_click_control_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                _click_start_pos = Vector2(DisplayServer.mouse_get_position())
            else:
                var current_pos = Vector2(DisplayServer.mouse_get_position())
                var dist = current_pos.distance_to(_click_start_pos)
                if dist < 10.0:
                    pet_clicked.emit()
                    _play_interact_anim()

func _play_interact_anim() -> void:
    if not spine_sprite: return
    var anim_state = spine_sprite.get_animation_state()
    if not anim_state: return
    
    var skeleton = spine_sprite.get_skeleton()
    var idle_anim = "Idle"
    var interact_anim = "Blink"
    
    if skeleton and skeleton.get_data():
        var anims = skeleton.get_data().get_animations()
        var anim_names = []
        for a in anims: anim_names.append(a.get_name())
        
        if not interact_anim in anim_names and anim_names.size() > 1:
            for anim_name_str in anim_names:
                if anim_name_str.to_lower() != "idle" and anim_name_str.to_lower() != "daiji":
                    interact_anim = anim_name_str
                    break
        
        # 更严格的 idle_anim 判定
        if not idle_anim in anim_names:
            if "idle" in anim_names:
                idle_anim = "idle"
            elif anim_names.size() > 0:
                idle_anim = anim_names[0]
                
        # 安全调用
        if interact_anim in anim_names and idle_anim in anim_names:
            anim_state.set_animation(interact_anim, false, 0)
            anim_state.add_animation(idle_anim, 0.0, true, 0)

func clear_bubbles() -> void:
    for child in bubble_container.get_children():
        if child != bubble_template:
            child.queue_free()
    bubbles_changed.emit()

func add_bubble(text: String, is_typewriter: bool = false) -> void:
    var bubble = bubble_template.duplicate()
    bubble.visible = true
    bubble_container.add_child(bubble)
    
    var label: RichTextLabel = bubble.get_node("MarginContainer/RichTextLabel")
    label.text = text
    
    if is_typewriter:
        label.visible_characters = 0
        var plain_text = text.replace("[color=green]", "").replace("[/color]", "")
        var parsed_len = plain_text.length()
        var duration = parsed_len * 0.05
        if duration <= 0: duration = 0.5
        var tween = create_tween()
        tween.tween_property(label, "visible_ratio", 1.0, duration)
        tween.finished.connect(func(): label.visible_characters = -1)
    
    var bubbles = bubble_container.get_children()
    if bubbles.size() > 4: # 包括隐藏的template
        bubbles[1].queue_free()
        
    bubbles_changed.emit()
    
    var timer = get_tree().create_timer(10.0)
    var bubble_ref = weakref(bubble)
    timer.timeout.connect(func():
        var b = bubble_ref.get_ref()
        if b and is_instance_valid(b):
            var fade_tween = create_tween()
            fade_tween.tween_property(b, "modulate:a", 0.0, 0.5)
            fade_tween.finished.connect(func(): 
                if is_instance_valid(b): 
                    b.queue_free()
                    bubbles_changed.emit()
            )
    )

func get_passthrough_rects() -> Array[Rect2]:
    var rects: Array[Rect2] = []
    if not is_inside_tree() or not visible:
        return rects
        
    # 添加角色碰撞盒区域（转换为全局坐标）
    if collision_shape and collision_shape.shape:
        var shape = collision_shape.shape
        if shape is RectangleShape2D:
            var size = shape.size
            var pos = collision_shape.global_position - size / 2.0
            rects.append(Rect2(pos, size).grow(5))
            
    # 添加可见气泡区域
    for child in bubble_container.get_children():
        if child is Control and child.is_visible_in_tree() and child != bubble_template:
            rects.append(child.get_global_rect().grow(5))
            
    return rects
