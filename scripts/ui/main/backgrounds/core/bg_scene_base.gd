extends Control
class_name BackgroundSceneBase

## 背景场景基类
## 所有自定义背景场景（图片、动画、Spine等）都应该继承此类或实现类似接口

# 当场景准备完毕且可以显示角色时触发
signal background_ready

func _ready() -> void:
	# 默认实现：直接认为准备就绪
	call_deferred("emit_signal", "background_ready")

## 播放特定的环境动画（如白天到黑夜切换）
func play_environment_anim(anim_name: String) -> void:
	pass

## 获取角色应该站立的位置锚点（如果有的话）
func get_character_anchor() -> Vector2:
	return Vector2(size.x / 2.0, size.y)
