import re

def update_tscn(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Add Theme ext_resource
    if 'ext_resource type="Theme"' not in content:
        content = content.replace(
            '[ext_resource type="Texture2D" uid="uid://c65yonwnp2sge" path="res://assets/images/backgrounds/desktop_pet/desktop_pet_bg.png" id="2_yofv2"]',
            '[ext_resource type="Theme" uid="uid://cx6y837p8y74k" path="res://assets/themes/galchat_theme.tres" id="1_theme"]\n[ext_resource type="Texture2D" uid="uid://c65yonwnp2sge" path="res://assets/images/backgrounds/desktop_pet/desktop_pet_bg.png" id="2_yofv2"]'
        )

    # Add StyleBoxFlat sub_resource
    style_box = """[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_InputBg"]
bg_color = Color(0.89, 0.88, 0.96, 0.95)
border_width_left = 3
border_width_top = 3
border_width_right = 3
border_width_bottom = 3
border_color = Color(0.65, 0.58, 0.8, 1)
corner_radius_top_left = 12
corner_radius_top_right = 12
corner_radius_bottom_right = 12
corner_radius_bottom_left = 12
shadow_color = Color(0, 0, 0, 0.1)
shadow_size = 4

"""
    if 'id="StyleBoxFlat_InputBg"' not in content:
        content = content.replace(
            '[sub_resource type="AudioStreamMicrophone"',
            style_box + '[sub_resource type="AudioStreamMicrophone"'
        )

    # Add theme to Control
    if 'theme = ExtResource("1_theme")' not in content:
        content = content.replace(
            'grow_vertical = 2\n\n[node name="Background_layer"',
            'grow_vertical = 2\ntheme = ExtResource("1_theme")\n\n[node name="Background_layer"'
        )

    # Modify InputLayer
    old_input_layer = """[node name="InputLayer" type="Panel" parent="Control"]
custom_minimum_size = Vector2(500, 0)
layout_mode = 1
anchors_preset = 12
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_top = -38.0
grow_horizontal = 2
grow_vertical = 0

[node name="HBoxContainer" type="HBoxContainer" parent="Control/InputLayer"]
custom_minimum_size = Vector2(500, 0)
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/separation = 5"""

    new_input_layer = """[node name="InputLayer" type="PanelContainer" parent="Control"]
custom_minimum_size = Vector2(500, 0)
layout_mode = 1
anchors_preset = 12
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_top = -58.0
offset_bottom = -10.0
grow_horizontal = 2
grow_vertical = 0
theme_override_styles/panel = SubResource("StyleBoxFlat_InputBg")

[node name="MarginContainer" type="MarginContainer" parent="Control/InputLayer"]
layout_mode = 2
theme_override_constants/margin_left = 10
theme_override_constants/margin_top = 10
theme_override_constants/margin_right = 10
theme_override_constants/margin_bottom = 10

[node name="HBoxContainer" type="HBoxContainer" parent="Control/InputLayer/MarginContainer"]
custom_minimum_size = Vector2(500, 0)
layout_mode = 2
theme_override_constants/separation = 10"""

    content = content.replace(old_input_layer, new_input_layer)

    # Modify buttons
    buttons_old = """[node name="VoiceRecordButton" type="Button" parent="Control/InputLayer/HBoxContainer"]
custom_minimum_size = Vector2(60, 0)
layout_mode = 2
theme_override_font_sizes/font_size = 25
text = "🎙"

[node name="SendButton" type="Button" parent="Control/InputLayer/HBoxContainer"]
custom_minimum_size = Vector2(60, 0)
layout_mode = 2
theme_override_font_sizes/font_size = 20
text = "发送"

[node name="Close" type="Button" parent="Control/InputLayer/HBoxContainer"]
custom_minimum_size = Vector2(60, 0)
layout_mode = 2
text = "关闭\"\"\""""

    buttons_old = """[node name="VoiceRecordButton" type="Button" parent="Control/InputLayer/HBoxContainer"]
custom_minimum_size = Vector2(60, 0)
layout_mode = 2
theme_override_font_sizes/font_size = 25
text = "🎙"

[node name="SendButton" type="Button" parent="Control/InputLayer/HBoxContainer"]
custom_minimum_size = Vector2(60, 0)
layout_mode = 2
theme_override_font_sizes/font_size = 20
text = "发送"

[node name="Close" type="Button" parent="Control/InputLayer/HBoxContainer"]
custom_minimum_size = Vector2(60, 0)
layout_mode = 2
text = "关闭" """

    # Actually let's just do regex for parent="Control/InputLayer/HBoxContainer"
    content = content.replace('parent="Control/InputLayer/HBoxContainer"', 'parent="Control/InputLayer/MarginContainer/HBoxContainer"')

    # Update UIContainer buttons
    ui_container_old = """[node name="UIContainer" type="VBoxContainer" parent="Control"]
layout_mode = 0
offset_left = 615.0
offset_top = 350.0
offset_right = 696.0
offset_bottom = 451.0

[node name="MainWindowButton" type="Button" parent="Control/UIContainer"]
layout_mode = 2
text = "主界面"

[node name="CloseButton" type="Button" parent="Control/UIContainer"]
layout_mode = 2
text = "关闭"

[node name="DialogueButton" type="Button" parent="Control/UIContainer"]
layout_mode = 2
text = "聊天" """

    ui_container_new = """[node name="UIContainer" type="VBoxContainer" parent="Control"]
layout_mode = 0
offset_left = 615.0
offset_top = 350.0
offset_right = 696.0
offset_bottom = 470.0
theme_override_constants/separation = 10

[node name="MainWindowButton" type="Button" parent="Control/UIContainer"]
custom_minimum_size = Vector2(0, 32)
layout_mode = 2
text = "主界面"

[node name="CloseButton" type="Button" parent="Control/UIContainer"]
custom_minimum_size = Vector2(0, 32)
layout_mode = 2
text = "关闭"

[node name="DialogueButton" type="Button" parent="Control/UIContainer"]
custom_minimum_size = Vector2(0, 32)
layout_mode = 2
text = "聊天" """
    content = content.replace(ui_container_old.strip(), ui_container_new.strip())

    # Fix load_steps
    content = re.sub(r'load_steps=\d+', 'load_steps=11', content)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

update_tscn('f:/GODOT游戏模板/aigame/gal-chat/scenes/ui/desktop_pet/desktop_pet.tscn')
