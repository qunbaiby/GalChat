extends Control
class_name ToastNotification

@onready var container: VBoxContainer = $ToastContainer
@onready var template: CenterContainer = $ToastTemplate

func show_toast(message: String, color: Color = Color.WHITE) -> void:
    var center = template.duplicate()
    center.visible = true
    var panel = center.get_node("Panel")
    var label = panel.get_node("Label")
    
    label.text = message
    label.add_theme_color_override("font_color", color)
    
    container.add_child(center)
    
    # Animate
    panel.modulate.a = 0
    panel.position.y -= 20
    
    var tween = create_tween()
    # 1. Fade in and slide down in parallel
    tween.set_parallel(true)
    tween.tween_property(panel, "modulate:a", 1.0, 0.3)
    tween.tween_property(panel, "position:y", panel.position.y + 20, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    
    # 2. Wait
    tween.chain().tween_interval(5.0)
    
    # 3. Fade out and slide up in parallel
    tween.chain().tween_property(panel, "modulate:a", 0.0, 0.5)
    tween.parallel().tween_property(panel, "position:y", panel.position.y - 20, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    
    tween.finished.connect(center.queue_free)
