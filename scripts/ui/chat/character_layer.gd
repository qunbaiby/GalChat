extends Node2D

var fade_tween: Tween

@onready var character_spine: SpineSprite = $Character

func _ready() -> void:
    GameDataManager.character_switched.connect(_on_character_switched)
    _update_spine_data()
    # 初始化时播放默认的 idle 动画
    play_animation("Idle", true)

func _on_character_switched(char_id: String) -> void:
    _update_spine_data()
    play_animation("Idle", true)

func _update_spine_data() -> void:
    if not is_instance_valid(character_spine): return
    var path = GameDataManager.profile.spine_path
    if path != "" and ResourceLoader.exists(path):
        var res = load(path)
        if res is SpineSkeletonDataResource:
            character_spine.skeleton_data_res = res
            # Need to update or rebuild the SpineSprite? Setting skeleton_data_res might be enough
            pass

# 保留原本的 update_sprite 接口以防外部调用报错，但不再处理图片切换
func update_sprite(new_texture: Texture2D) -> void:
    # 以后可以根据传入的心情名字或者状态来切换动画
    # 目前暂时全部映射为 Idle
    play_animation("Idle", true)

# 新增播放 Spine 动画的接口
func play_animation(anim_name: String, loop: bool = true) -> void:
    if not is_instance_valid(character_spine):
        return
        
    var anim_state = character_spine.get_animation_state()
    if not anim_state:
        return
        
    var skeleton = character_spine.get_skeleton()
    if not skeleton or not skeleton.get_data():
        return
        
    var anims = skeleton.get_data().get_animations()
    var anim_names = []
    for a in anims:
        anim_names.append(a.get_name())
        
    # 如果请求的动画不存在，回退到 Idle 或者第一个可用动画
    var target_anim = anim_name
    if not target_anim in anim_names:
        if "Idle" in anim_names:
            target_anim = "Idle"
        elif anim_names.size() > 0:
            target_anim = anim_names[0]
        else:
            return
            
    # 如果当前正在播放的就是目标动画，并且要求循环，则不打断
    var current_track = anim_state.get_current(0)
    if current_track and current_track.get_animation().get_name() == target_anim and loop:
        return
        
    anim_state.set_animation(target_anim, loop, 0)