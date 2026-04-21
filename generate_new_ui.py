import re

tscn_path = r"f:\GODOT游戏模板\aigame\gal-chat\scenes\ui\mobile\mobile_interface.tscn"

# First, read the animation and other top-level resources from the original file
with open(tscn_path, 'r', encoding='utf-8') as f:
    content = f.read()

# We'll just generate the entire tscn content manually
new_tscn = """[gd_scene load_steps=15 format=3 uid="uid://c3q0g1d3h7f9x"]

[ext_resource type="Script" uid="uid://dmxk4q7w9g3c5" path="res://scripts/ui/mobile/mobile_interface.gd" id="1_script"]
[ext_resource type="Theme" uid="uid://cx6y837p8y74k" path="res://assets/themes/galchat_theme.tres" id="2_theme"]

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_PhoneBg"]
bg_color = Color(0.8, 0.82, 0.85, 1)
corner_radius_top_left = 0
corner_radius_top_right = 0
corner_radius_bottom_right = 0
corner_radius_bottom_left = 0

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_Card"]
bg_color = Color(0.85, 0.85, 0.88, 0.8)
corner_radius_top_left = 15
corner_radius_top_right = 15
corner_radius_bottom_right = 15
corner_radius_bottom_left = 15
shadow_color = Color(0, 0, 0, 0.05)
shadow_size = 5

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_CardBlue"]
bg_color = Color(0.6, 0.8, 0.9, 0.8)
corner_radius_top_left = 15
corner_radius_top_right = 15
corner_radius_bottom_right = 15
corner_radius_bottom_left = 15

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_List"]
bg_color = Color(0.9, 0.9, 0.92, 0.8)
corner_radius_top_left = 20
corner_radius_top_right = 20
corner_radius_bottom_right = 20
corner_radius_bottom_left = 20

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_ListIcon"]
bg_color = Color(0.8, 0.8, 0.85, 0.8)
corner_radius_top_left = 15
corner_radius_top_right = 15
corner_radius_bottom_right = 15
corner_radius_bottom_left = 15

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_PowerBtn"]
bg_color = Color(0.95, 0.95, 0.95, 0.5)
corner_radius_top_left = 30
corner_radius_top_right = 30
corner_radius_bottom_right = 30
corner_radius_bottom_left = 30
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color(1, 1, 1, 0.8)

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_Avatar"]
bg_color = Color(0.2, 0.2, 0.2, 1)
corner_radius_top_left = 40
corner_radius_top_right = 40
corner_radius_bottom_right = 40
corner_radius_bottom_left = 40
border_width_left = 3
border_width_top = 3
border_width_right = 3
border_width_bottom = 3
border_color = Color(0.8, 0.8, 0.8, 1)

[sub_resource type="Animation" id="Animation_Init"]
resource_name = "RESET"
length = 0.001
tracks/0/type = "value"
tracks/0/imported = false
tracks/0/enabled = true
tracks/0/path = NodePath("PhonePanel:position")
tracks/0/interp = 1
tracks/0/loop_wrap = true
tracks/0/keys = {
"times": PackedFloat32Array(0),
"transitions": PackedFloat32Array(1),
"update": 0,
"values": [Vector2(0, 720)]
}
tracks/1/type = "value"
tracks/1/imported = false
tracks/1/enabled = true
tracks/1/path = NodePath("ColorRect:color")
tracks/1/interp = 1
tracks/1/loop_wrap = true
tracks/1/keys = {
"times": PackedFloat32Array(0),
"transitions": PackedFloat32Array(1),
"update": 0,
"values": [Color(0, 0, 0, 0)]
}

[sub_resource type="Animation" id="Animation_SlideUp"]
resource_name = "slide_up"
length = 0.3
tracks/0/type = "value"
tracks/0/imported = false
tracks/0/enabled = true
tracks/0/path = NodePath("PhonePanel:position")
tracks/0/interp = 2
tracks/0/loop_wrap = true
tracks/0/keys = {
"times": PackedFloat32Array(0, 0.3),
"transitions": PackedFloat32Array(0.5, 1),
"update": 0,
"values": [Vector2(0, 720), Vector2(0, 0)]
}
tracks/1/type = "value"
tracks/1/imported = false
tracks/1/enabled = true
tracks/1/path = NodePath("ColorRect:color")
tracks/1/interp = 2
tracks/1/loop_wrap = true
tracks/1/keys = {
"times": PackedFloat32Array(0, 0.3),
"transitions": PackedFloat32Array(1, 1),
"update": 0,
"values": [Color(0, 0, 0, 0), Color(0, 0, 0, 0.3)]
}

[sub_resource type="Animation" id="Animation_SlideDown"]
resource_name = "slide_down"
length = 0.2
tracks/0/type = "value"
tracks/0/imported = false
tracks/0/enabled = true
tracks/0/path = NodePath("PhonePanel:position")
tracks/0/interp = 2
tracks/0/loop_wrap = true
tracks/0/keys = {
"times": PackedFloat32Array(0, 0.2),
"transitions": PackedFloat32Array(2, 1),
"update": 0,
"values": [Vector2(0, 0), Vector2(0, 720)]
}
tracks/1/type = "value"
tracks/1/imported = false
tracks/1/enabled = true
tracks/1/path = NodePath("ColorRect:color")
tracks/1/interp = 2
tracks/1/loop_wrap = true
tracks/1/keys = {
"times": PackedFloat32Array(0, 0.2),
"transitions": PackedFloat32Array(1, 1),
"update": 0,
"values": [Color(0, 0, 0, 0.3), Color(0, 0, 0, 0)]
}

[sub_resource type="AnimationLibrary" id="AnimationLibrary_Phone"]
_data = {
"RESET": SubResource("Animation_Init"),
"slide_down": SubResource("Animation_SlideDown"),
"slide_up": SubResource("Animation_SlideUp")
}

[node name="MobileInterface" type="Control"]
visible = false
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_script")
theme = ExtResource("2_theme")

[node name="ColorRect" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0, 0, 0, 0)

[node name="PhonePanel" type="PanelContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_top = 720.0
offset_bottom = 720.0
grow_horizontal = 2
grow_vertical = 2
theme_override_styles/panel = SubResource("StyleBoxFlat_PhoneBg")

[node name="BgGradient" type="ColorRect" parent="PhonePanel"]
layout_mode = 2
color = Color(0.7, 0.75, 0.82, 1)

[node name="MapPlaceholder" type="Control" parent="PhonePanel"]
layout_mode = 2
mouse_filter = 2

[node name="Avatar1" type="Panel" parent="PhonePanel/MapPlaceholder"]
layout_mode = 0
offset_left = 200.0
offset_top = 180.0
offset_right = 280.0
offset_bottom = 260.0
theme_override_styles/panel = SubResource("StyleBoxFlat_Avatar")

[node name="Avatar2" type="Panel" parent="PhonePanel/MapPlaceholder"]
layout_mode = 0
offset_left = 550.0
offset_top = 100.0
offset_right = 630.0
offset_bottom = 180.0
theme_override_styles/panel = SubResource("StyleBoxFlat_Avatar")

[node name="Avatar3" type="Panel" parent="PhonePanel/MapPlaceholder"]
layout_mode = 0
offset_left = 500.0
offset_top = 220.0
offset_right = 580.0
offset_bottom = 300.0
theme_override_styles/panel = SubResource("StyleBoxFlat_Avatar")

[node name="Avatar4" type="Panel" parent="PhonePanel/MapPlaceholder"]
layout_mode = 0
offset_left = 850.0
offset_top = 240.0
offset_right = 930.0
offset_bottom = 320.0
theme_override_styles/panel = SubResource("StyleBoxFlat_Avatar")

[node name="MarginContainer" type="MarginContainer" parent="PhonePanel"]
layout_mode = 2
theme_override_constants/margin_left = 40
theme_override_constants/margin_top = 20
theme_override_constants/margin_right = 40
theme_override_constants/margin_bottom = 20

[node name="VBox" type="VBoxContainer" parent="PhonePanel/MarginContainer"]
layout_mode = 2
theme_override_constants/separation = 15

[node name="TopBar" type="HBoxContainer" parent="PhonePanel/MarginContainer/VBox"]
layout_mode = 2

[node name="SignalLabel" type="Label" parent="PhonePanel/MarginContainer/VBox/TopBar"]
layout_mode = 2
theme_override_colors/font_color = Color(0.5, 0.5, 0.5, 1)
theme_override_font_sizes/font_size = 14
text = "●●●●● 6G"

[node name="Spacer" type="Control" parent="PhonePanel/MarginContainer/VBox/TopBar"]
layout_mode = 2
size_flags_horizontal = 3

[node name="BatteryLabel" type="Label" parent="PhonePanel/MarginContainer/VBox/TopBar"]
layout_mode = 2
theme_override_colors/font_color = Color(0.5, 0.5, 0.5, 1)
theme_override_font_sizes/font_size = 14
text = "98% ■"

[node name="MapSpacer" type="Control" parent="PhonePanel/MarginContainer/VBox"]
custom_minimum_size = Vector2(0, 250)
layout_mode = 2

[node name="TimeDateHBox" type="HBoxContainer" parent="PhonePanel/MarginContainer/VBox"]
layout_mode = 2
theme_override_constants/separation = 20
alignment = 0

[node name="BigTimeLabel" type="Label" parent="PhonePanel/MarginContainer/VBox/TimeDateHBox"]
layout_mode = 2
theme_override_colors/font_color = Color(0.2, 0.2, 0.2, 1)
theme_override_font_sizes/font_size = 64
text = "23:41"

[node name="UTC" type="Label" parent="PhonePanel/MarginContainer/VBox/TimeDateHBox"]
layout_mode = 2
size_flags_vertical = 8
theme_override_colors/font_color = Color(0.4, 0.4, 0.4, 1)
theme_override_font_sizes/font_size = 16
text = "UTC+8"

[node name="DateLabel" type="Label" parent="PhonePanel/MarginContainer/VBox/TimeDateHBox"]
layout_mode = 2
size_flags_vertical = 8
theme_override_colors/font_color = Color(0.3, 0.3, 0.3, 1)
theme_override_font_sizes/font_size = 20
text = "4月21日 星期二"

[node name="Spacer" type="Control" parent="PhonePanel/MarginContainer/VBox/TimeDateHBox"]
layout_mode = 2
size_flags_horizontal = 3

[node name="NavButton" type="Button" parent="PhonePanel/MarginContainer/VBox/TimeDateHBox"]
layout_mode = 2
size_flags_vertical = 8
theme_override_colors/font_color = Color(0.5, 0.5, 0.5, 1)
text = "////// 导航 ■"
flat = true

[node name="AppCardsHBox" type="HBoxContainer" parent="PhonePanel/MarginContainer/VBox"]
layout_mode = 2
theme_override_constants/separation = 20

[node name="Card1" type="Panel" parent="PhonePanel/MarginContainer/VBox/AppCardsHBox"]
custom_minimum_size = Vector2(400, 120)
layout_mode = 2
theme_override_styles/panel = SubResource("StyleBoxFlat_Card")

[node name="Label" type="Label" parent="PhonePanel/MarginContainer/VBox/AppCardsHBox/Card1"]
layout_mode = 0
offset_left = 20.0
offset_top = 15.0
offset_right = 92.0
offset_bottom = 38.0
theme_override_colors/font_color = Color(0.4, 0.4, 0.4, 1)
text = "你我之间"

[node name="Icon" type="Label" parent="PhonePanel/MarginContainer/VBox/AppCardsHBox/Card1"]
layout_mode = 0
offset_left = 40.0
offset_top = 40.0
offset_right = 140.0
offset_bottom = 140.0
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_font_sizes/font_size = 60
text = "♡"

[node name="ArchiveBtn" type="Button" parent="PhonePanel/MarginContainer/VBox/AppCardsHBox/Card1"]
layout_mode = 0
offset_left = 300.0
offset_top = 70.0
offset_right = 380.0
offset_bottom = 101.0
text = "档案入口"

[node name="Card2" type="Panel" parent="PhonePanel/MarginContainer/VBox/AppCardsHBox"]
custom_minimum_size = Vector2(200, 120)
layout_mode = 2
theme_override_styles/panel = SubResource("StyleBoxFlat_Card")

[node name="Label" type="Label" parent="PhonePanel/MarginContainer/VBox/AppCardsHBox/Card2"]
layout_mode = 0
offset_left = 20.0
offset_top = 15.0
offset_right = 92.0
offset_bottom = 38.0
theme_override_colors/font_color = Color(0.4, 0.4, 0.4, 1)
text = "大数据中心"

[node name="Icon" type="Label" parent="PhonePanel/MarginContainer/VBox/AppCardsHBox/Card2"]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -30.0
offset_top = -10.0
offset_right = 30.0
offset_bottom = 50.0
grow_horizontal = 2
grow_vertical = 2
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_font_sizes/font_size = 50
text = "☁"
horizontal_alignment = 1

[node name="Card3" type="Panel" parent="PhonePanel/MarginContainer/VBox/AppCardsHBox"]
custom_minimum_size = Vector2(200, 120)
layout_mode = 2
size_flags_horizontal = 3
theme_override_styles/panel = SubResource("StyleBoxFlat_CardBlue")

[node name="Label" type="Label" parent="PhonePanel/MarginContainer/VBox/AppCardsHBox/Card3"]
layout_mode = 0
offset_left = 20.0
offset_top = 15.0
offset_right = 92.0
offset_bottom = 38.0
theme_override_colors/font_color = Color(0.4, 0.4, 0.4, 1)
text = "通话"

[node name="Icon" type="Label" parent="PhonePanel/MarginContainer/VBox/AppCardsHBox/Card3"]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -30.0
offset_top = -10.0
offset_right = 30.0
offset_bottom = 50.0
grow_horizontal = 2
grow_vertical = 2
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_font_sizes/font_size = 50
text = "✆"
horizontal_alignment = 1

[node name="List1" type="Panel" parent="PhonePanel/MarginContainer/VBox"]
custom_minimum_size = Vector2(0, 100)
layout_mode = 2
theme_override_styles/panel = SubResource("StyleBoxFlat_List")

[node name="Title" type="Label" parent="PhonePanel/MarginContainer/VBox/List1"]
layout_mode = 0
offset_left = 20.0
offset_top = 10.0
offset_right = 68.0
offset_bottom = 33.0
theme_override_colors/font_color = Color(0.4, 0.4, 0.4, 1)
theme_override_font_sizes/font_size = 14
text = "短消息"

[node name="ContentBg" type="Panel" parent="PhonePanel/MarginContainer/VBox/List1"]
layout_mode = 0
offset_left = 40.0
offset_top = 40.0
offset_right = 700.0
offset_bottom = 80.0
theme_override_styles/panel = SubResource("StyleBoxFlat_Card")

[node name="ContentText" type="Label" parent="PhonePanel/MarginContainer/VBox/List1/ContentBg"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_colors/font_color = Color(0.5, 0.5, 0.5, 1)
theme_override_font_sizes/font_size = 20
text = "暂时没有新的短消息。"
horizontal_alignment = 1
vertical_alignment = 1

[node name="IconBg" type="Panel" parent="PhonePanel/MarginContainer/VBox/List1"]
layout_mode = 0
offset_left = 750.0
offset_top = 10.0
offset_right = 830.0
offset_bottom = 90.0
theme_override_styles/panel = SubResource("StyleBoxFlat_ListIcon")

[node name="Icon" type="Label" parent="PhonePanel/MarginContainer/VBox/List1/IconBg"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_font_sizes/font_size = 40
text = "✉"
horizontal_alignment = 1
vertical_alignment = 1

[node name="List2" type="Panel" parent="PhonePanel/MarginContainer/VBox"]
custom_minimum_size = Vector2(0, 100)
layout_mode = 2
theme_override_styles/panel = SubResource("StyleBoxFlat_List")

[node name="Title" type="Label" parent="PhonePanel/MarginContainer/VBox/List2"]
layout_mode = 0
offset_left = 20.0
offset_top = 10.0
offset_right = 68.0
offset_bottom = 33.0
theme_override_colors/font_color = Color(0.4, 0.4, 0.4, 1)
theme_override_font_sizes/font_size = 14
text = "通话记录"

[node name="ContentBg" type="Panel" parent="PhonePanel/MarginContainer/VBox/List2"]
layout_mode = 0
offset_left = 40.0
offset_top = 40.0
offset_right = 700.0
offset_bottom = 80.0
theme_override_styles/panel = SubResource("StyleBoxFlat_Card")

[node name="ContentText" type="Label" parent="PhonePanel/MarginContainer/VBox/List2/ContentBg"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_colors/font_color = Color(0.5, 0.5, 0.5, 1)
theme_override_font_sizes/font_size = 20
text = "左然的未接来电。"
horizontal_alignment = 1
vertical_alignment = 1

[node name="IconBg" type="Panel" parent="PhonePanel/MarginContainer/VBox/List2"]
layout_mode = 0
offset_left = 750.0
offset_top = 10.0
offset_right = 830.0
offset_bottom = 90.0
theme_override_styles/panel = SubResource("StyleBoxFlat_ListIcon")

[node name="Icon" type="Label" parent="PhonePanel/MarginContainer/VBox/List2/IconBg"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_font_sizes/font_size = 40
text = "☎"
horizontal_alignment = 1
vertical_alignment = 1

[node name="Spacer" type="Control" parent="PhonePanel/MarginContainer/VBox"]
layout_mode = 2
size_flags_vertical = 3

[node name="BottomHint" type="Label" parent="PhonePanel/MarginContainer/VBox"]
layout_mode = 2
theme_override_colors/font_color = Color(0.4, 0.4, 0.4, 1)
theme_override_font_sizes/font_size = 14
text = "◆ 开启快捷入口后点击主页手机默认进入【你我之间】"

[node name="PowerButton" type="Button" parent="PhonePanel/MarginContainer/VBox"]
custom_minimum_size = Vector2(60, 60)
layout_mode = 2
size_flags_horizontal = 4
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_font_sizes/font_size = 24
theme_override_styles/normal = SubResource("StyleBoxFlat_PowerBtn")
theme_override_styles/hover = SubResource("StyleBoxFlat_PowerBtn")
theme_override_styles/pressed = SubResource("StyleBoxFlat_PowerBtn")
text = "⏻"

[node name="AnimationPlayer" type="AnimationPlayer" parent="."]
libraries = {
"": SubResource("AnimationLibrary_Phone")
}
"""

with open(tscn_path, 'w', encoding='utf-8') as f:
    f.write(new_tscn)

print("Saved new tscn!")
