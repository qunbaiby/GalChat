extends CharacterBody2D

@export var move_speed: float = 200.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var current_direction: Vector2 = Vector2.DOWN

func _physics_process(_delta: float) -> void:
    var input_dir = Vector2.ZERO
    input_dir.x = Input.get_axis("ui_left", "ui_right")
    input_dir.y = Input.get_axis("ui_up", "ui_down")
    
    if input_dir != Vector2.ZERO:
        input_dir = input_dir.normalized()
        current_direction = input_dir
        velocity = input_dir * move_speed
        _update_animation("walk")
    else:
        velocity = Vector2.ZERO
        _update_animation("idle")
        
    move_and_slide()

func _update_animation(state: String) -> void:
    var anim_name = state + "_"
    
    if current_direction.y > 0.5:
        anim_name += "down"
    elif current_direction.y < -0.5:
        anim_name += "up"
    elif current_direction.x > 0:
        anim_name += "right"
    elif current_direction.x < 0:
        anim_name += "left"
    else:
        anim_name += "down"
        
    if animation_player.has_animation(anim_name):
        animation_player.play(anim_name)
