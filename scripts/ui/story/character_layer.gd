extends Node2D

var fade_tween: Tween

@onready var character_ani: AnimatedSprite2D = $CharacterAni

func _ready() -> void:
    GameDataManager.character_switched.connect(_on_character_switched)
    _update_character_ani()

func _on_character_switched(char_id: String) -> void:
    _update_character_ani()

func _update_spine_data() -> void:
    # 废弃，由 _update_character_ani 接管
    var dynamic_sprite = get_node_or_null("DynamicSprite")
    if dynamic_sprite:
        dynamic_sprite.hide()
        
    if is_instance_valid(character_ani):
        character_ani.show()
        _update_character_ani()

# 新增：更新立绘动画状态
func _update_character_ani() -> void:
    if not is_instance_valid(character_ani): return
    
    # 动态加载对应的动画帧
    if GameDataManager.profile and GameDataManager.profile.sprite_frames_path != "":
        if ResourceLoader.exists(GameDataManager.profile.sprite_frames_path):
            character_ani.sprite_frames = load(GameDataManager.profile.sprite_frames_path)
            
    # 首先尝试获取表情对应的立绘
    var expression = GameDataManager.profile.current_expression
    
    # 获取图片路径
    var sprite_path = GameDataManager.expression_system.get_expression_sprite_path(expression)
    if sprite_path != "":
        # 如果是外部文件
        if sprite_path.begins_with("user://"):
            var img = Image.new()
            var err = img.load(sprite_path)
            if err == OK:
                var tex = ImageTexture.create_from_image(img)
                _set_sprite_texture(tex)
                return
        # 如果是内置文件
        elif ResourceLoader.exists(sprite_path):
            var tex = load(sprite_path)
            if tex is Texture2D:
                _set_sprite_texture(tex)
                return
                
    # 回退到 AnimatedSprite2D 自身配置
    var frames = character_ani.sprite_frames
    if frames and frames.has_animation(expression):
        character_ani.play(expression)
    else:
        # 如果没有对应心情的动画，尝试回退到 "calm" 或 "idle" 等默认动画
        if frames and frames.has_animation("calm"):
            character_ani.play("calm")
        elif frames and frames.has_animation("idle"):
            character_ani.play("idle")
        elif frames and frames.has_animation("default"):
            character_ani.play("default")

func _set_sprite_texture(tex: Texture2D) -> void:
    # 动态创建一个 Sprite2D 来替代 AnimatedSprite2D 的显示
    var dynamic_sprite = get_node_or_null("DynamicSprite")
    if not dynamic_sprite:
        dynamic_sprite = Sprite2D.new()
        dynamic_sprite.name = "DynamicSprite"
        dynamic_sprite.position = character_ani.position
        dynamic_sprite.scale = character_ani.scale
        add_child(dynamic_sprite)
    
    dynamic_sprite.texture = tex
    dynamic_sprite.show()
    character_ani.hide()

# 兼容外部调用
func load_sprite_frames_by_path(path: String) -> void:
    var dynamic_sprite = get_node_or_null("DynamicSprite")
    if dynamic_sprite:
        dynamic_sprite.hide()
        
    if is_instance_valid(character_ani):
        if path != "" and ResourceLoader.exists(path):
            character_ani.sprite_frames = load(path)
        character_ani.show()
        _update_character_ani()

# 保留原本的 update_sprite 接口以防外部调用报错
func update_sprite(new_texture: Texture2D) -> void:
    pass

# 兼容外部调用的空方法
func play_animation(anim_name: String, loop: bool = true) -> void:
    pass

# 新增：控制立绘显示与隐藏（支持动画）
func show_character(anim_type: String = "fade_in") -> void:
    show()
    if fade_tween and fade_tween.is_valid():
        fade_tween.kill()
    fade_tween = create_tween()
    
    match anim_type:
        "fade_in":
            modulate.a = 0.0
            position = Vector2.ZERO
            fade_tween.tween_property(self, "modulate:a", 1.0, 0.5)
        "slide_top":
            modulate.a = 1.0
            position = Vector2(0, -200)
            fade_tween.tween_property(self, "position", Vector2.ZERO, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
        "slide_bottom":
            modulate.a = 1.0
            position = Vector2(0, 200)
            fade_tween.tween_property(self, "position", Vector2.ZERO, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
        "slide_left":
            modulate.a = 1.0
            position = Vector2(-200, 0)
            fade_tween.tween_property(self, "position", Vector2.ZERO, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
        "slide_right":
            modulate.a = 1.0
            position = Vector2(200, 0)
            fade_tween.tween_property(self, "position", Vector2.ZERO, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
        _:
            modulate.a = 1.0
            position = Vector2.ZERO
            if fade_tween and fade_tween.is_valid():
                fade_tween.kill() # 如果没有要执行的动画，一定要杀掉空 tween

func hide_character(anim_type: String = "fade_out") -> void:
    if fade_tween and fade_tween.is_valid():
        fade_tween.kill()
    fade_tween = create_tween()
    
    match anim_type:
        "fade_out":
            fade_tween.tween_property(self, "modulate:a", 0.0, 0.5)
        "slide_out_top":
            fade_tween.tween_property(self, "position", Vector2(0, -200), 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
            fade_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
        "slide_out_bottom":
            fade_tween.tween_property(self, "position", Vector2(0, 200), 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
            fade_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
        "slide_out_left":
            fade_tween.tween_property(self, "position", Vector2(-200, 0), 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
            fade_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
        "slide_out_right":
            fade_tween.tween_property(self, "position", Vector2(200, 0), 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
            fade_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
        _:
            modulate.a = 0.0
            if fade_tween and fade_tween.is_valid():
                fade_tween.kill() # 如果没有要执行的动画，一定要杀掉空 tween
            self.hide()
            return # 直接返回，不再调用最后的 tween_callback
            
    fade_tween.tween_callback(self.hide)