extends Control
class_name ToastNotification

@onready var container: VBoxContainer = $ToastContainer

func show_toast(message: String, color: Color = Color.WHITE) -> void:
    var panel = PanelContainer.new()
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0, 0, 0, 0.7)
    style.corner_radius_top_left = 20
    style.corner_radius_top_right = 20
    style.corner_radius_bottom_left = 20
    style.corner_radius_bottom_right = 20
    style.content_margin_left = 20
    style.content_margin_right = 20
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    panel.add_theme_stylebox_override("panel", style)
    
    var label = Label.new()
    label.text = message
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_color_override("font_color", color)
    label.add_theme_font_size_override("font_size", 24)
    
    panel.add_child(label)
    
    # Center the panel in the container
    var center = CenterContainer.new()
    center.add_child(panel)
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
