extends CharacterBody2D

signal pet_clicked()
signal bubbles_changed()

@onready var avatar_mask: Control = $AvatarContainer/AvatarMask
@onready var state_ring: Control = $AvatarContainer/StateRing
@onready var pet_sprite: AnimatedSprite2D = $AvatarContainer/AvatarMask/AnimatedSprite2D
@onready var bubble_container: VBoxContainer = $BubbleContainer
@onready var bubble_template: PanelContainer = $BubbleContainer/SpeechBubble
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _click_start_pos: Vector2 = Vector2.ZERO

# 状态环变量
var current_state: int = 0 # 0: Idle, 1: Thinking, 2: Speaking, 3: Cooldown
var state_progress: float = 0.0
var ring_time: float = 0.0
var ring_volume: float = 0.0

var neon_material: ShaderMaterial
var _breath_tween: Tween
var _current_modulate: Color = Color.WHITE

func _ready() -> void:
    bubble_template.hide()
    
    avatar_mask.draw.connect(_on_mask_draw)
    state_ring.draw.connect(_on_ring_draw)
    
    var shader = load("res://assets/shaders/rainbow_border.gdshader")
    if shader:
        neon_material = ShaderMaterial.new()
        neon_material.shader = shader
        state_ring.material = neon_material
        state_ring.pivot_offset = Vector2(80, 80) # 160x160 的中心
    
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
    
    if pet_sprite:
        _update_sprite_scale()
        
        # 尝试加载当前角色的桌宠立绘序列帧
        if GameDataManager.profile:
            var anim_path = GameDataManager.profile.desktop_pet_frames_path
            if anim_path == "" or not ResourceLoader.exists(anim_path):
                # 如果没有专门配置桌宠动画，则降级使用主立绘动画
                anim_path = GameDataManager.profile.sprite_frames_path
                
            if anim_path != "" and ResourceLoader.exists(anim_path):
                pet_sprite.sprite_frames = load(anim_path)
                pet_sprite.play("default")

func _update_sprite_scale() -> void:
    if not pet_sprite: return
    
    if _breath_tween:
        _breath_tween.kill()
        
    var base_scale = 0.5
    if GameDataManager.config:
        base_scale *= float(GameDataManager.config.pet_scale_multiplier)
        
    pet_sprite.scale = Vector2(base_scale, base_scale)
    
    var scale_max_x = base_scale * (0.52 / 0.5)
    var scale_min_y = base_scale * (0.48 / 0.5)
    
    _breath_tween = create_tween().set_loops()
    _breath_tween.tween_property(pet_sprite, "scale", Vector2(scale_max_x, scale_min_y), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _breath_tween.tween_property(pet_sprite, "scale", Vector2(base_scale, base_scale), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _update_time_based_lighting() -> void:
    if not pet_sprite: return
    
    var time_dict = Time.get_datetime_dict_from_system()
    var hour = time_dict["hour"]
    
    var target_color = Color.WHITE
    
    # 根据现实时间调整立绘和光环的整体色调与亮度
    if hour >= 6 and hour < 9:
        # 清晨：带点晨雾的偏蓝冷色，亮度正常
        target_color = Color(0.95, 0.98, 1.0, 1.0)
    elif hour >= 9 and hour < 16:
        # 白天：正常明亮
        target_color = Color.WHITE
    elif hour >= 16 and hour < 19:
        # 黄昏：偏暖黄/橙色，夕阳感
        target_color = Color(1.0, 0.95, 0.9, 1.0)
    elif hour >= 19 and hour < 22:
        # 傍晚：稍微变暗，轻微偏蓝紫
        target_color = Color(0.9, 0.9, 0.95, 1.0)
    else:
        # 深夜 (22~6)：明显变暗，降低刺眼感（夜间模式）
        target_color = Color(0.75, 0.75, 0.85, 1.0)
        
    # 平滑过渡颜色
    _current_modulate = _current_modulate.lerp(target_color, 0.05)
    pet_sprite.modulate = _current_modulate
    if is_instance_valid(state_ring):
        state_ring.modulate = _current_modulate

func _process(delta: float) -> void:
    _update_time_based_lighting()
    
    ring_time += delta
    if is_instance_valid(state_ring):
        if neon_material:
            # 统一定义基础宽度，保证切换状态时视觉大小严格一致
            var BASE_WIDTH = 0.022
            var BASE_BLUR = 0.015
            
            if current_state == 0: # Idle (常驻完整光环)
                neon_material.set_shader_parameter("progress", 1.0)
                state_ring.rotation = 0.0
                
                # 【强化版呼吸灯效果】大幅增加透明度跨度，并让光晕随之扩散，但实体线条粗细保持稳定
                var breath = (sin(ring_time * 2.5) + 1.0) * 0.5 # 呼吸频率稍微调快一点点，显得更有生机
                var alpha_mod = lerp(0.15, 0.95, breath) # 从极暗到极亮，对比度拉满
                var current_blur = lerp(BASE_BLUR, BASE_BLUR + 0.012, breath) # 让发光范围也跟着呼吸膨胀
                
                neon_material.set_shader_parameter("color1", Color(0.4, 0.75, 1.0, alpha_mod))
                neon_material.set_shader_parameter("color2", Color(0.7, 0.95, 1.0, alpha_mod))
                neon_material.set_shader_parameter("speed", 0.4)
                neon_material.set_shader_parameter("border_width", BASE_WIDTH) # 核心边界死死钉住，防止锯齿
                neon_material.set_shader_parameter("blur", current_blur)
                
            elif current_state == 1: # Thinking
                neon_material.set_shader_parameter("progress", 0.35)
                state_ring.rotation = ring_time * 6.0
                
                # 【强烈的霓虹爆闪与流动感】
                var flicker = (sin(ring_time * 12.0) + 1.0) * 0.5
                neon_material.set_shader_parameter("color1", Color(0.1, 0.8, 1.0, 1.0))
                neon_material.set_shader_parameter("color2", Color(0.8, 0.2, 1.0, 1.0))
                neon_material.set_shader_parameter("speed", 4.0)
                neon_material.set_shader_parameter("border_width", BASE_WIDTH)
                neon_material.set_shader_parameter("blur", BASE_BLUR + flicker * 0.01)
                
            elif current_state == 2: # Speaking
                neon_material.set_shader_parameter("progress", 1.0)
                state_ring.rotation = ring_time * 1.5
                
                # 【随声浪起伏的动感音波】
                neon_material.set_shader_parameter("color1", Color(1.0, 0.2, 0.5, 1.0))
                neon_material.set_shader_parameter("color2", Color(1.0, 0.6, 0.2, 1.0))
                neon_material.set_shader_parameter("speed", 3.0)
                
                # 说话时允许增粗，但基础值严格对齐
                var target_width = BASE_WIDTH + ring_volume * 0.04
                var target_blur = BASE_BLUR + ring_volume * 0.05
                neon_material.set_shader_parameter("border_width", target_width)
                neon_material.set_shader_parameter("blur", target_blur)
                
            elif current_state == 3: # App Switch Observing (Green)
                neon_material.set_shader_parameter("progress", state_progress)
                state_ring.rotation = 0.0
                
                # 【倒计时的脉冲充能感】
                var pulse = (sin(ring_time * 5.0) + 1.0) * 0.5
                neon_material.set_shader_parameter("color1", Color(0.1, 1.0, 0.4, 0.8 + pulse * 0.2))
                neon_material.set_shader_parameter("color2", Color(0.5, 1.0, 0.8, 0.8 + pulse * 0.2))
                neon_material.set_shader_parameter("speed", 1.5)
                neon_material.set_shader_parameter("border_width", BASE_WIDTH)
                neon_material.set_shader_parameter("blur", BASE_BLUR + pulse * 0.01)
                
            elif current_state == 4: # Proactive Chat Cooldown (Orange)
                neon_material.set_shader_parameter("progress", state_progress)
                state_ring.rotation = 0.0
                
                var pulse = (sin(ring_time * 3.0) + 1.0) * 0.5
                neon_material.set_shader_parameter("color1", Color(1.0, 0.4, 0.0, 0.8 + pulse * 0.2))
                neon_material.set_shader_parameter("color2", Color(1.0, 0.8, 0.1, 0.8 + pulse * 0.2))
                neon_material.set_shader_parameter("speed", 1.0)
                neon_material.set_shader_parameter("border_width", BASE_WIDTH)
                neon_material.set_shader_parameter("blur", BASE_BLUR + pulse * 0.01)
        state_ring.queue_redraw()

func _on_mask_draw() -> void:
    var center = avatar_mask.size / 2.0
    # 将遮罩半径往内缩小3个像素，使其完美隐藏在状态环的内侧，避免边缘锯齿漏出
    var radius = (min(avatar_mask.size.x, avatar_mask.size.y) / 2.0) - 3.0
    
    # 绘制一个带抗锯齿效果的高分辨率多边形近似圆，填充纯白色，背景保持透明
    # Godot 4.x 的 clip_children 如果使用 draw_circle 在透明窗口下会产生黑色背景Bug
    var points = PackedVector2Array()
    var num_points = 128 # 增加多边形顶点数，使圆形边缘更平滑
    for i in range(num_points):
        var angle = i * TAU / num_points
        points.append(center + Vector2(cos(angle), sin(angle)) * radius)
        
    avatar_mask.draw_colored_polygon(points, Color.WHITE)

func _on_ring_draw() -> void:
    if neon_material:
        # 用白色矩形铺满整个 Control 区域，Shader 会将其渲染为霓虹圆环
        state_ring.draw_rect(Rect2(Vector2.ZERO, state_ring.size), Color.WHITE)
    else:
        var center = state_ring.size / 2.0
        # 让底环也往内缩一点，匹配遮罩的尺寸并避免被控件边缘裁切
        var radius = (min(state_ring.size.x, state_ring.size.y) / 2.0) - 3.0
        
        # 绘制基础底环
        var base_color = Color(0.3, 0.3, 0.3, 0.5)
        state_ring.draw_arc(center, radius, 0, TAU, 128, base_color, 6.0, true)
        
        # 根据不同状态绘制动态特效
        if current_state == 0: # Idle
            state_ring.draw_arc(center, radius, 0, TAU, 128, Color(0.8, 0.8, 0.9, 0.5), 6.0, true)
        elif current_state == 1: # Thinking
            var start_angle = ring_time * 5.0
            var end_angle = start_angle + PI / 2.0
            state_ring.draw_arc(center, radius, start_angle, end_angle, 64, Color(0.4, 0.8, 1.0, 0.9), 6.0, true)
        elif current_state == 2: # Speaking
            var glow = radius + ring_volume * 25.0
            state_ring.draw_arc(center, glow, 0, TAU, 128, Color(0.4, 0.8, 1.0, 0.6), 5.0, true)
        elif current_state == 3: # App Switch Observing (10s)
            # 绿色圆环，平滑缓慢填满
            var angle = lerp(0.0, TAU, state_progress)
            state_ring.draw_arc(center, radius, -PI/2, -PI/2 + angle, 128, Color(0.3, 0.8, 0.3, 0.8), 6.0, true)
        elif current_state == 4: # Proactive Chat Cooldown (long timer)
            # 橙黄色圆环，表示大招冷却中，非常缓慢地填满
            var angle = lerp(0.0, TAU, state_progress)
            state_ring.draw_arc(center, radius, -PI/2, -PI/2 + angle, 128, Color(0.8, 0.6, 0.2, 0.8), 6.0, true)

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
    if not pet_sprite: return
    
    if _breath_tween:
        _breath_tween.kill()
        
    var base_scale = 0.5
    if GameDataManager.config:
        base_scale *= float(GameDataManager.config.pet_scale_multiplier)
        
    var scale_1_x = base_scale * (0.55 / 0.5)
    var scale_1_y = base_scale * (0.45 / 0.5)
    var scale_2_x = base_scale * (0.48 / 0.5)
    var scale_2_y = base_scale * (0.52 / 0.5)
    
    var tween = create_tween()
    tween.tween_property(pet_sprite, "scale", Vector2(scale_1_x, scale_1_y), 0.1).set_trans(Tween.TRANS_QUAD)
    tween.tween_property(pet_sprite, "scale", Vector2(scale_2_x, scale_2_y), 0.15).set_trans(Tween.TRANS_BOUNCE)
    tween.tween_property(pet_sprite, "scale", Vector2(base_scale, base_scale), 0.1).set_trans(Tween.TRANS_QUAD)
    tween.finished.connect(_update_sprite_scale)

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
    
    # 彻底解决导出后气泡不换行、不撑开高度的终极方案：
    # 1. 强制赋予绝对宽度，让底层 TextServer 有换行的物理依据
    label.custom_minimum_size.x = 250
    label.size.x = 250
    
    # 2. 强制重置状态，清除从隐藏模板 Duplicate 带来的缓存 Bug
    label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
    label.fit_content = false
    label.fit_content = true
    
    # 3. 给予极小延迟，等待底层字体排版完成后，连续强制赋高度
    var check_timer = get_tree().create_timer(0.01)
    check_timer.timeout.connect(func():
        if is_instance_valid(label) and is_instance_valid(bubble):
            label.size.x = 250
            var content_h = label.get_content_height()
            if content_h > 0:
                label.custom_minimum_size.y = content_h
                bubble.size = Vector2.ZERO # 强制父级 PanelContainer 贴合收缩
                
                # 再次延迟一帧进行最终画面确认
                get_tree().process_frame.connect(func():
                    if is_instance_valid(label) and is_instance_valid(bubble):
                        label.custom_minimum_size.y = label.get_content_height()
                        bubble.size = Vector2.ZERO
                , CONNECT_ONE_SHOT)
    )
    
    if is_typewriter:
        label.visible_ratio = 0.0
        var plain_text = text.replace("[color=green]", "").replace("[/color]", "")
        var parsed_len = plain_text.length()
        var duration = parsed_len * 0.05
        if duration <= 0: duration = 0.5
        var tween = create_tween()
        tween.tween_property(label, "visible_ratio", 1.0, duration)
    
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
        rects.append(avatar_mask.get_global_rect().grow(5))
        
    # 获取实际显示的对话气泡的区域
    if bubble_container and bubble_container.is_visible_in_tree():
        for child in bubble_container.get_children():
            if child is Control and child.visible and child.modulate.a > 0.01:
                # 仅将当前真正显示的气泡加入鼠标遮挡区域
                rects.append(child.get_global_rect().grow(5))
            
    return rects

func get_body_global_rect() -> Rect2:
    var body_rect := Rect2()
    var has_rect := false
    
    if avatar_mask and avatar_mask.is_visible_in_tree():
        body_rect = avatar_mask.get_global_rect().grow(5)
        has_rect = true
    
    if state_ring and state_ring.is_visible_in_tree():
        var ring_rect := state_ring.get_global_rect().grow(5)
        body_rect = body_rect.merge(ring_rect) if has_rect else ring_rect
        has_rect = true
    
    if has_rect:
        return body_rect
    
    return Rect2(global_position - Vector2(40, 90), Vector2(80, 180))
