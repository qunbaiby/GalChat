extends Node2D

var fade_tween: Tween

@onready var character_rect: TextureRect = $Character

func update_sprite(new_texture: Texture2D) -> void:
    if character_rect.texture == new_texture:
        return
        
    if fade_tween and fade_tween.is_running():
        fade_tween.kill()
        
    fade_tween = create_tween()
    
    # 1. Fade out
    fade_tween.tween_property(character_rect, "modulate:a", 0.0, 0.2)
    
    # 2. Swap texture when invisible
    fade_tween.tween_callback(func(): character_rect.texture = new_texture)
    
    # 3. Fade in
    fade_tween.tween_property(character_rect, "modulate:a", 1.0, 0.2)