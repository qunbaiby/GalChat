extends "res://scripts/ui/main/backgrounds/core/bg_scene_base.gd"

@onready var bg_rect: TextureRect = $background

func _ready() -> void:
	super._ready()

# 如果有特殊的环境切换需求可以在这里实现
func play_environment_anim(anim_name: String) -> void:
	# 例如根据白天黑夜改变颜色
	if anim_name == "night":
		bg_rect.modulate = Color(0.5, 0.5, 0.7)
	elif anim_name == "day":
		bg_rect.modulate = Color(1, 1, 1)
