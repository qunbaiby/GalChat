import re

with open("scenes/ui/mobile/moments/moments_panel.tscn", "r", encoding="utf-8") as f:
    content = f.read()

new_scroll_content = """[node name="Scroll" type="ScrollContainer" parent="VBox"]
layout_mode = 2
size_flags_vertical = 3
horizontal_scroll_mode = 0

[node name="ContentVBox" type="VBoxContainer" parent="VBox/Scroll"]
layout_mode = 2
size_flags_horizontal = 3
theme_override_constants/separation = 0

[node name="Header" type="Control" parent="VBox/Scroll/ContentVBox"]
custom_minimum_size = Vector2(0, 250)
layout_mode = 2

[node name="CoverImage" type="TextureRect" parent="VBox/Scroll/ContentVBox/Header"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_bottom = -30.0
grow_horizontal = 2
grow_vertical = 2
texture = ExtResource("2_theme")
expand_mode = 1
stretch_mode = 6

[node name="PlayerName" type="Label" parent="VBox/Scroll/ContentVBox/Header"]
layout_mode = 1
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -250.0
offset_top = -65.0
offset_right = -100.0
offset_bottom = -35.0
grow_horizontal = 0
grow_vertical = 0
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_colors/font_outline_color = Color(0, 0, 0, 0.5)
theme_override_constants/outline_size = 4
theme_override_font_sizes/font_size = 20
text = "Player"
horizontal_alignment = 2

[node name="AvatarBg" type="ColorRect" parent="VBox/Scroll/ContentVBox/Header"]
layout_mode = 1
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -85.0
offset_top = -80.0
offset_right = -15.0
offset_bottom = -10.0
grow_horizontal = 0
grow_vertical = 0

[node name="PlayerAvatar" type="TextureRect" parent="VBox/Scroll/ContentVBox/Header/AvatarBg"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 2.0
offset_top = 2.0
offset_right = -2.0
offset_bottom = -2.0
grow_horizontal = 2
grow_vertical = 2
expand_mode = 1
stretch_mode = 6

[node name="Spacer" type="Control" parent="VBox/Scroll/ContentVBox"]
custom_minimum_size = Vector2(0, 20)
layout_mode = 2

[node name="MomentList" type="VBoxContainer" parent="VBox/Scroll/ContentVBox"]
layout_mode = 2
size_flags_horizontal = 3
theme_override_constants/separation = 20"""

old_scroll_content = """[node name="Scroll" type="ScrollContainer" parent="VBox"]
layout_mode = 2
size_flags_vertical = 3
horizontal_scroll_mode = 0

[node name="MomentList" type="VBoxContainer" parent="VBox/Scroll"]
layout_mode = 2
size_flags_horizontal = 3
theme_override_constants/separation = 20"""

if old_scroll_content in content:
    content = content.replace(old_scroll_content, new_scroll_content)
    with open("scenes/ui/mobile/moments/moments_panel.tscn", "w", encoding="utf-8") as f:
        f.write(content)
