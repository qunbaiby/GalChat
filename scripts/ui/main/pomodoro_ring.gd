extends Control

var progress: float = 0.0 # 0.0 to 1.0
var ring_color: Color = Color(0.3, 0.7, 1.0, 1.0)
var bg_color: Color = Color(0.2, 0.2, 0.25, 1.0)
var thickness: float = 12.0

func _draw() -> void:
    var center = size / 2.0
    var radius = min(size.x, size.y) / 2.0 - thickness / 2.0
    
    # Draw background ring
    draw_arc(center, radius, 0, TAU, 64, bg_color, thickness, true)
    
    # Draw progress ring
    if progress > 0:
        var start_angle = -PI / 2.0
        var end_angle = start_angle + progress * TAU
        draw_arc(center, radius, start_angle, end_angle, 64, ring_color, thickness, true)

func set_progress(val: float, color: Color) -> void:
    progress = clamp(val, 0.0, 1.0)
    ring_color = color
    queue_redraw()
