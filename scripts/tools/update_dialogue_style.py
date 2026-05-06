import os

tscn_path = r"f:\GODOT游戏模板\aigame\gal-chat\scenes\ui\common\dialogue_panel.tscn"
with open(tscn_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Make the dialogue text style
# We should update `assets/themes/dialogue_panel_style.tres`

style_path = r"f:\GODOT游戏模板\aigame\gal-chat\assets\themes\dialogue_panel_style.tres"
style_content = """[gd_resource type="StyleBoxTexture" load_steps=3 format=3 uid="uid://cx1g6j2n0v2t2"]

[sub_resource type="Gradient" id="Gradient_p1a2b"]
colors = PackedColorArray(0, 0, 0, 0, 0, 0, 0, 0.7, 0, 0, 0, 0.9, 0, 0, 0, 0)
offsets = PackedFloat32Array(0, 0.3, 0.7, 1)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_c3d4e"]
gradient = SubResource("Gradient_p1a2b")
fill_to = Vector2(0, 1)
fill_from = Vector2(0, 0)

[resource]
texture = SubResource("GradientTexture2D_c3d4e")
content_margin_left = 100.0
content_margin_right = 100.0
content_margin_top = 20.0
content_margin_bottom = 20.0
"""

with open(style_path, 'w', encoding='utf-8') as f:
    f.write(style_content)

print("Updated dialogue_panel_style.tres")

# Now we need to update quick_option_item.gd to match the option style
