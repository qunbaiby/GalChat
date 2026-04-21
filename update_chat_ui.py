import os
import re

theme_path = r"e:\GalChat\GalChat\assets\themes\galchat_theme.tres"
chat_scene_path = r"e:\GalChat\GalChat\scenes\ui\chat\chat_scene.tscn"

# 1. Update Theme for sharper, wider buttons (Reference Image 1)
with open(theme_path, "r", encoding="utf-8") as f:
    theme_content = f.read()

# Change corner radius from 12 to 2 for buttons
theme_content = re.sub(r'corner_radius_([a-z_]+) = 12', r'corner_radius_\1 = 2', theme_content)
# Make buttons slightly more opaque and bluish dark
theme_content = re.sub(r'bg_color = Color\(0\.05, 0\.05, 0\.08, 0\.5\)', r'bg_color = Color(0.08, 0.08, 0.15, 0.8)', theme_content)

with open(theme_path, "w", encoding="utf-8") as f:
    f.write(theme_content)


# 2. Update Chat Scene Layout (Reference Images 1 & 2)
with open(chat_scene_path, "r", encoding="utf-8") as f:
    chat_content = f.read()

# Extract parts to replace
# We want to replace DialogueLayer and QuickOptionLayer blocks completely.

dialogue_layer_new = """[node name="DialogueLayer" type="ColorRect" parent="."]
anchors_preset = 12
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_top = -260.0
offset_bottom = -80.0
grow_horizontal = 2
grow_vertical = 0
color = Color(0, 0, 0, 0.5)

[node name="NameLabel" type="Label" parent="DialogueLayer"]
layout_mode = 1
offset_left = 150.0
offset_top = 25.0
offset_right = 350.0
offset_bottom = 55.0
theme_override_font_sizes/font_size = 20
text = "Character Name"
vertical_alignment = 1

[node name="NameLine" type="ColorRect" parent="DialogueLayer/NameLabel"]
layout_mode = 1
anchors_preset = 12
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_top = 2.0
offset_right = -100.0
offset_bottom = 3.0
grow_horizontal = 2
grow_vertical = 0
color = Color(0.8, 0.8, 0.9, 0.6)

[node name="RichTextLabel" type="RichTextLabel" parent="DialogueLayer"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 250.0
offset_top = 60.0
offset_right = -250.0
offset_bottom = -20.0
grow_horizontal = 2
grow_vertical = 2
theme_override_font_sizes/normal_font_size = 22
bbcode_enabled = true
text = "Dialogue text goes here..."

[node name="SkipButton" type="Button" parent="DialogueLayer"]
layout_mode = 1
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -150.0
offset_top = -50.0
offset_right = -50.0
offset_bottom = -20.0
grow_horizontal = 0
grow_vertical = 0
theme_override_colors/font_color = Color(0.6, 0.6, 0.6, 1)
theme_override_colors/font_hover_color = Color(1, 1, 1, 1)
theme_override_font_sizes/font_size = 16
text = "Skip"
flat = true"""

quick_option_layer_new = """[node name="QuickOptionLayer" type="Control" parent="."]
anchors_preset = 7
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
offset_left = -400.0
offset_top = -450.0
offset_right = 400.0
offset_bottom = -280.0
grow_horizontal = 2
grow_vertical = 0

[node name="QuickOptions" type="VBoxContainer" parent="QuickOptionLayer"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/separation = 15
alignment = 1"""

# Regex replace DialogueLayer block
chat_content = re.sub(r'\[node name="DialogueLayer" type="Panel" parent="\."\].*?(?=\[node name="QuickOptionLayer" type="Panel" parent="\."\])', dialogue_layer_new + '\n\n', chat_content, flags=re.DOTALL)

# Regex replace QuickOptionLayer block
chat_content = re.sub(r'\[node name="QuickOptionLayer" type="Panel" parent="\."\].*?(?=\[node name="AffectionButton" type="Button" parent="\."\])', quick_option_layer_new + '\n\n', chat_content, flags=re.DOTALL)

with open(chat_scene_path, "w", encoding="utf-8") as f:
    f.write(chat_content)

print("Updated chat_scene.tscn and galchat_theme.tres")
