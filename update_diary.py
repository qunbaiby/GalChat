import re

with open("scenes/ui/diary/diary_panel.tscn", "r", encoding="utf-8") as f:
    content = f.read()

# Add StyleBoxFlat_Polaroid after StyleBoxFlat_Divider
polaroid_style = """[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_Polaroid"]
bg_color = Color(1, 1, 1, 1)
shadow_color = Color(0, 0, 0, 0.15)
shadow_size = 10
shadow_offset = Vector2(2, 4)

"""
if "StyleBoxFlat_Polaroid" not in content:
    content = content.replace("[node name=\"DiaryPanel\"", polaroid_style + "[node name=\"DiaryPanel\"")

# Replace LeftPage's PhotoContainer with the new layout
old_photo_container = """[node name="PhotoContainer" type="CenterContainer" parent="CenterContainer/DiaryBook/Margin/HBox/LeftPage"]
layout_mode = 2
size_flags_vertical = 3

[node name="PhotoRect" type="TextureRect" parent="CenterContainer/DiaryBook/Margin/HBox/LeftPage/PhotoContainer"]
custom_minimum_size = Vector2(350, 350)
layout_mode = 2
expand_mode = 1
stretch_mode = 5

[node name="Label" type="Label" parent="CenterContainer/DiaryBook/Margin/HBox/LeftPage/PhotoContainer/PhotoRect"]
visible = false
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_colors/font_color = Color(0.4, 0.4, 0.4, 1)
text = "暂无照片"
horizontal_alignment = 1
vertical_alignment = 1"""

new_photo_container = """[node name="PhotoContainer" type="Control" parent="CenterContainer/DiaryBook/Margin/HBox/LeftPage"]
layout_mode = 2
size_flags_vertical = 3

[node name="Polaroid1" type="PanelContainer" parent="CenterContainer/DiaryBook/Margin/HBox/LeftPage/PhotoContainer"]
layout_mode = 0
offset_left = 10.0
offset_top = 20.0
offset_right = 230.0
offset_bottom = 200.0
rotation = -0.15
theme_override_styles/panel = SubResource("StyleBoxFlat_Polaroid")

[node name="Margin" type="MarginContainer" parent="CenterContainer/DiaryBook/Margin/HBox/LeftPage/PhotoContainer/Polaroid1"]
layout_mode = 2
mouse_filter = 2
theme_override_constants/margin_left = 10
theme_override_constants/margin_top = 10
theme_override_constants/margin_right = 10
theme_override_constants/margin_bottom = 30

[node name="Image" type="TextureRect" parent="CenterContainer/DiaryBook/Margin/HBox/LeftPage/PhotoContainer/Polaroid1/Margin"]
layout_mode = 2
mouse_filter = 2
expand_mode = 1
stretch_mode = 6

[node name="Polaroid2" type="PanelContainer" parent="CenterContainer/DiaryBook/Margin/HBox/LeftPage/PhotoContainer"]
layout_mode = 0
offset_left = 180.0
offset_top = 70.0
offset_right = 400.0
offset_bottom = 250.0
rotation = 0.08
theme_override_styles/panel = SubResource("StyleBoxFlat_Polaroid")

[node name="Margin" type="MarginContainer" parent="CenterContainer/DiaryBook/Margin/HBox/LeftPage/PhotoContainer/Polaroid2"]
layout_mode = 2
mouse_filter = 2
theme_override_constants/margin_left = 10
theme_override_constants/margin_top = 10
theme_override_constants/margin_right = 10
theme_override_constants/margin_bottom = 30

[node name="Image" type="TextureRect" parent="CenterContainer/DiaryBook/Margin/HBox/LeftPage/PhotoContainer/Polaroid2/Margin"]
layout_mode = 2
mouse_filter = 2
expand_mode = 1
stretch_mode = 6

[node name="Polaroid3" type="PanelContainer" parent="CenterContainer/DiaryBook/Margin/HBox/LeftPage/PhotoContainer"]
layout_mode = 0
offset_left = 50.0
offset_top = 220.0
offset_right = 270.0
offset_bottom = 400.0
rotation = -0.05
theme_override_styles/panel = SubResource("StyleBoxFlat_Polaroid")

[node name="Margin" type="MarginContainer" parent="CenterContainer/DiaryBook/Margin/HBox/LeftPage/PhotoContainer/Polaroid3"]
layout_mode = 2
mouse_filter = 2
theme_override_constants/margin_left = 10
theme_override_constants/margin_top = 10
theme_override_constants/margin_right = 10
theme_override_constants/margin_bottom = 30

[node name="Image" type="TextureRect" parent="CenterContainer/DiaryBook/Margin/HBox/LeftPage/PhotoContainer/Polaroid3/Margin"]
layout_mode = 2
mouse_filter = 2
expand_mode = 1
stretch_mode = 6"""

content = content.replace(old_photo_container, new_photo_container)

# Add ImageViewer at the end of the file
image_viewer = """
[node name="ImageViewer" type="ColorRect" parent="."]
visible = false
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0, 0, 0, 0.85)

[node name="FullImage" type="TextureRect" parent="ImageViewer"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 50.0
offset_top = 50.0
offset_right = -50.0
offset_bottom = -50.0
grow_horizontal = 2
grow_vertical = 2
expand_mode = 1
stretch_mode = 5

[node name="CloseViewerBtn" type="Button" parent="ImageViewer"]
custom_minimum_size = Vector2(60, 60)
layout_mode = 1
anchors_preset = 1
anchor_left = 1.0
anchor_right = 1.0
offset_left = -80.0
offset_top = 20.0
offset_right = -20.0
offset_bottom = 80.0
grow_horizontal = 0
theme_override_font_sizes/font_size = 28
text = "X"
"""
if "ImageViewer" not in content:
    content += image_viewer

with open("scenes/ui/diary/diary_panel.tscn", "w", encoding="utf-8") as f:
    f.write(content)
