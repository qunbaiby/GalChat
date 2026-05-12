import re

with open("scenes/ui/mobile/moments/moments_panel.tscn", "r", encoding="utf-8") as f:
    content = f.read()

new_content = """[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/ui/mobile/moments/moments_panel.gd" id="1_script"]
[ext_resource type="Theme" uid="uid://cx6y837p8y74k" path="res://assets/themes/galchat_theme.tres" id="2_theme"]

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_MomentsBg"]
bg_color = Color(0.15, 0.15, 0.18, 0.95)
corner_radius_top_left = 20
corner_radius_top_right = 20

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_ChangeCoverBtn"]
bg_color = Color(0, 0, 0, 0.5)
corner_radius_top_left = 4
corner_radius_top_right = 4
corner_radius_bottom_right = 4
corner_radius_bottom_left = 4

[node name="MomentsPanel" type="Panel"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_styles/panel = SubResource("StyleBoxFlat_MomentsBg")
script = ExtResource("1_script")
theme = ExtResource("2_theme")
clip_children = 1

[node name="Scroll" type="ScrollContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
horizontal_scroll_mode = 0

[node name="ContentVBox" type="VBoxContainer" parent="Scroll"]
layout_mode = 2
size_flags_horizontal = 3
theme_override_constants/separation = 0

[node name="Header" type="Control" parent="Scroll/ContentVBox"]
custom_minimum_size = Vector2(0, 350)
layout_mode = 2

[node name="CoverImage" type="TextureRect" parent="Scroll/ContentVBox/Header"]
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
mouse_filter = 0

[node name="PlayerName" type="Label" parent="Scroll/ContentVBox/Header"]
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

[node name="AvatarBg" type="ColorRect" parent="Scroll/ContentVBox/Header"]
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

[node name="PlayerAvatar" type="TextureRect" parent="Scroll/ContentVBox/Header/AvatarBg"]
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

[node name="ChangeCoverBtn" type="Button" parent="Scroll/ContentVBox/Header"]
visible = false
layout_mode = 1
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -100.0
offset_top = -120.0
offset_right = -20.0
offset_bottom = -80.0
grow_horizontal = 0
grow_vertical = 0
theme_override_styles/normal = SubResource("StyleBoxFlat_ChangeCoverBtn")
text = "换封面"

[node name="Spacer" type="Control" parent="Scroll/ContentVBox"]
custom_minimum_size = Vector2(0, 20)
layout_mode = 2

[node name="MomentListMargin" type="MarginContainer" parent="Scroll/ContentVBox"]
layout_mode = 2
size_flags_horizontal = 3
theme_override_constants/margin_left = 15
theme_override_constants/margin_right = 15
theme_override_constants/margin_bottom = 20

[node name="MomentList" type="VBoxContainer" parent="Scroll/ContentVBox/MomentListMargin"]
layout_mode = 2
size_flags_horizontal = 3
theme_override_constants/separation = 20

[node name="TopBarBg" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 10
anchor_right = 1.0
offset_bottom = 60.0
grow_horizontal = 2
color = Color(0.15, 0.15, 0.18, 0)
mouse_filter = 2

[node name="TopBar" type="HBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 10
anchor_right = 1.0
offset_left = 15.0
offset_top = 10.0
offset_right = -15.0
offset_bottom = 50.0
grow_horizontal = 2
mouse_filter = 2

[node name="BackBtn" type="Button" parent="TopBar"]
custom_minimum_size = Vector2(40, 40)
layout_mode = 2
theme_override_font_sizes/font_size = 20
text = "‹"
flat = true

[node name="Title" type="Label" parent="TopBar"]
layout_mode = 2
size_flags_horizontal = 3
theme_override_font_sizes/font_size = 18
text = "朋友圈"
horizontal_alignment = 1

[node name="FileDialog" type="FileDialog" parent="."]
title = "选择封面图片"
initial_position = 2
size = Vector2i(600, 400)
ok_button_text = "打开"
file_mode = 0
access = 2
filters = PackedStringArray("*.png, *.jpg, *.jpeg ; 图片文件")

[node name="ImageViewer" type="ColorRect" parent="."]
visible = false
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0, 0, 0, 0.9)

[node name="FullImage" type="TextureRect" parent="ImageViewer"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
expand_mode = 1
stretch_mode = 5

[node name="CloseViewerBtn" type="Button" parent="ImageViewer"]
custom_minimum_size = Vector2(40, 40)
layout_mode = 1
anchors_preset = 1
anchor_left = 1.0
anchor_right = 1.0
offset_left = -50.0
offset_top = 10.0
offset_right = -10.0
offset_bottom = 50.0
grow_horizontal = 0
theme_override_font_sizes/font_size = 20
text = "×"
flat = true

"""

with open("scenes/ui/mobile/moments/moments_panel.tscn", "w", encoding="utf-8") as f:
    f.write(new_content)
