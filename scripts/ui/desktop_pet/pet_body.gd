extends CharacterBody2D

signal pet_clicked()
signal bubbles_changed()

@onready var avatar_mask: Control = $AvatarContainer/AvatarMask
@onready var state_ring: Control = $AvatarContainer/StateRing
@onready var spine_sprite: SpineSprite = $AvatarContainer/AvatarMask/SpineSprite
@onready var bubble_container: VBoxContainer = $BubbleContainer
@onready var bubble_template: PanelContainer = $BubbleContainer/SpeechBubble
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _click_start_pos: Vector2 = Vector2.ZERO

# 状态环变量
var current_state: int = 0 # 0: Idle, 1: Thinking, 2: Speaking, 3: Cooldown
var state_progress: float = 0.0
var ring_time: float = 0.0
var ring_volume: float = 0.0

func _ready() -> void:
    bubble_template.hide()
    
    avatar_mask.draw.connect(_on_mask_draw)
    state_ring.draw.connect(_on_ring_draw)
    
    # 动态创建一个 Control 用于可靠的点击检测
    var click_control = Control.new()
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

func _process(delta: float) -> void:
    ring_time += delta
    if is_instance_valid(state_ring):
        state_ring.queue_redraw()

func _on_mask_draw() -> void:
    var center = avatar_mask.size / 2.0
    var radius = min(avatar_mask.size.x, avatar_mask.size.y) / 2.0
    
    # 绘制一个带抗锯齿效果的高分辨率多边形近似圆，填充纯白色，背景保持透明
    # Godot 4.x 的 clip_children 如果使用 draw_circle 在透明窗口下会产生黑色背景Bug
    var points = PackedVector2Array()
    var num_points = 64
    for i in range(num_points):
        var angle = i * TAU / num_points
        points.append(center + Vector2(cos(angle), sin(angle)) * radius)
        
    avatar_mask.draw_colored_polygon(points, Color.WHITE)

func _on_ring_draw() -> void:
    var center = state_ring.size / 2.0
    var radius = min(state_ring.size.x, state_ring.size.y) / 2.0
    
    # 绘制基础底环
    var base_color = Color(0.3, 0.3, 0.3, 0.5)
    state_ring.draw_arc(center, radius, 0, TAU, 64, base_color, 4.0, true)
    
    # 根据不同状态绘制动态特效
    if current_state == 1: # Thinking
        var start_angle = ring_time * 5.0
        var end_angle = start_angle + PI / 2.0
        state_ring.draw_arc(center, radius, start_angle, end_angle, 32, Color(0.4, 0.8, 1.0, 0.9), 4.0, true)
    elif current_state == 2: # Speaking
        var glow = radius + ring_volume * 20.0
        state_ring.draw_arc(center, glow, 0, TAU, 64, Color(0.4, 0.8, 1.0, 0.6), 3.0, true)
    elif current_state == 3: # App Switch Observing (10s)
        # 绿色圆环，平滑缓慢填满
        var angle = lerp(0.0, TAU, state_progress)
        state_ring.draw_arc(center, radius, -PI/2, -PI/2 + angle, 64, Color(0.3, 0.8, 0.3, 0.8), 4.0, true)
    elif current_state == 4: # Proactive Chat Cooldown (long timer)
        # 橙黄色圆环，表示大招冷却中，非常缓慢地填满
        var angle = lerp(0.0, TAU, state_progress)
        state_ring.draw_arc(center, radius, -PI/2, -PI/2 + angle, 64, Color(0.8, 0.6, 0.2, 0.8), 4.0, true)

func set_pet_state(state: int, progress: float = 0.0) -> void:
    current_state = state
    state_progress = progress

func update_voice_volume(vol: float) -> void:
    ring_volume = lerp(ring_volume, vol, 0.2)

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
    
    # 获取遮罩和状态环的组合区域
    if avatar_mask and avatar_mask.is_visible_in_tree():
        # 给状态环预留足够的空间，避免被裁剪
        rects.append(avatar_mask.get_global_rect().grow(10))
        
    if state_ring and state_ring.is_visible_in_tree():
        rects.append(state_ring.get_global_rect().grow(10))
        
    # 获取对话气泡的区域
    if bubble_container and bubble_container.is_visible_in_tree():
        # 我们需要为气泡预留一个固定的最大区域，防止空的时候被裁掉
        # 使用基于节点初始 offset 的固定矩形，而不是依赖可能收缩的动态 size
        var base_pos = bubble_container.global_position
        var reserved_rect = Rect2(base_pos.x, base_pos.y, 400, 250)
        rects.append(reserved_rect.grow(10))
            
    return rects
