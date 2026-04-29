extends Node2D

var fade_tween: Tween

@onready var character_spine: SpineSprite = $Character

func _ready() -> void:
    GameDataManager.character_switched.connect(_on_character_switched)
    _update_spine_data()
    # 在 ready 阶段，如果 skeleton 未准备好，延迟一帧播放
    if is_instance_valid(character_spine) and character_spine.get_skeleton() != null:
        play_animation("Idle", true)
    else:
        call_deferred("play_animation", "Idle", true)

func _on_character_switched(char_id: String) -> void:
    _update_spine_data()
    if is_instance_valid(character_spine) and character_spine.get_skeleton() != null:
        play_animation("Idle", true)
    else:
        call_deferred("play_animation", "Idle", true)

func _update_spine_data() -> void:
    if not is_instance_valid(character_spine): return
    var path = GameDataManager.profile.spine_path
    if path != "" and ResourceLoader.exists(path):
        var res = load(path)
        if res is SpineSkeletonDataResource:
            character_spine.skeleton_data_res = res
            pass

# 提供一个公共方法，允许外部强制更新 Spine 数据而不读取 Profile
func load_spine_by_path(path: String) -> void:
    if not is_instance_valid(character_spine): return
    if path != "" and ResourceLoader.exists(path):
        var res = load(path)
        if res is SpineSkeletonDataResource:
            character_spine.skeleton_data_res = res
            
            # 同样也用 deferred 延迟，确保底层完成绑定
            if is_instance_valid(character_spine) and character_spine.get_skeleton() != null:
                play_animation("Idle", true)
            else:
                call_deferred("play_animation", "Idle", true)

# 保留原本的 update_sprite 接口以防外部调用报错，但不再处理图片切换
func update_sprite(new_texture: Texture2D) -> void:
    # 以后可以根据传入的心情名字或者状态来切换动画
    # 目前暂时全部映射为 Idle
    play_animation("Idle", true)

# 新增播放 Spine 动画的接口
func play_animation(anim_name: String, loop: bool = true) -> void:
    if not is_instance_valid(character_spine):
        return
        
    var skeleton = character_spine.get_skeleton()
    if not skeleton or not skeleton.get_data():
        return
        
    var anim_state = character_spine.get_animation_state()
    if not anim_state:
        return
        
    var anims = skeleton.get_data().get_animations()
    var anim_names = []
    for a in anims:
        anim_names.append(a.get_name())
        
    # 如果请求的动画不存在，回退到 Idle 或者第一个可用动画
    var target_anim = anim_name
    if not target_anim in anim_names:
        if "idle" in anim_names:
            target_anim = "idle"
        elif "Idle" in anim_names:
            target_anim = "Idle"
        elif anim_names.size() > 0:
            target_anim = anim_names[0]
        else:
            return
            
    # 如果当前正在播放的就是目标动画，并且要求循环，则不打断
    var current_track = anim_state.get_current(0)
    if current_track and current_track.get_animation().get_name() == target_anim and loop:
        return
        
    # 安全调用：确保 target_anim 确实存在于 skeleton data 中
    if target_anim in anim_names:
        anim_state.set_animation(target_anim, loop, 0)

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