import os
import re

theme_path = r"e:\GalChat\GalChat\assets\themes\galchat_theme.tres"
ui_dir = r"e:\GalChat\GalChat\scenes\ui"

# New Theme Content
new_theme = """[gd_resource type="Theme" load_steps=10 format=3 uid="uid://cx6y837p8y74k"]

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_BtnHover"]
bg_color = Color(0.15, 0.15, 0.2, 0.6)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.3, 0.8, 0.9, 0.8)
corner_radius_top_left = 12
corner_radius_top_right = 12
corner_radius_bottom_right = 12
corner_radius_bottom_left = 12

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_BtnNormal"]
bg_color = Color(0.05, 0.05, 0.08, 0.5)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.8, 0.8, 0.9, 0.3)
corner_radius_top_left = 12
corner_radius_top_right = 12
corner_radius_bottom_right = 12
corner_radius_bottom_left = 12

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_BtnPressed"]
bg_color = Color(0.2, 0.2, 0.25, 0.7)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.3, 0.8, 0.9, 1.0)
corner_radius_top_left = 12
corner_radius_top_right = 12
corner_radius_bottom_right = 12
corner_radius_bottom_left = 12

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_LineEdit"]
bg_color = Color(0.05, 0.05, 0.08, 0.6)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.8, 0.8, 0.9, 0.4)
corner_radius_top_left = 6
corner_radius_top_right = 6
corner_radius_bottom_right = 6
corner_radius_bottom_left = 6

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_Panel"]
bg_color = Color(0.05, 0.05, 0.08, 0.75)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.8, 0.8, 0.9, 0.2)
corner_radius_top_left = 16
corner_radius_top_right = 16
corner_radius_bottom_right = 16
corner_radius_bottom_left = 16

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_PanelContainer"]
bg_color = Color(0.05, 0.05, 0.08, 0.75)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.8, 0.8, 0.9, 0.2)
corner_radius_top_left = 16
corner_radius_top_right = 16
corner_radius_bottom_right = 16
corner_radius_bottom_left = 16

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_TabContainerPanel"]
bg_color = Color(0.05, 0.05, 0.08, 0.6)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.8, 0.8, 0.9, 0.2)
corner_radius_bottom_right = 12
corner_radius_bottom_left = 12

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_TabSelected"]
bg_color = Color(0.15, 0.15, 0.2, 0.8)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_color = Color(0.3, 0.8, 0.9, 0.8)
corner_radius_top_left = 8
corner_radius_top_right = 8

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_TabUnselected"]
bg_color = Color(0.05, 0.05, 0.08, 0.4)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_color = Color(0.8, 0.8, 0.9, 0.2)
corner_radius_top_left = 8
corner_radius_top_right = 8

[resource]
Button/colors/font_color = Color(0.9, 0.9, 0.95, 1)
Button/colors/font_hover_color = Color(1, 1, 1, 1)
Button/colors/font_pressed_color = Color(0.7, 0.9, 1, 1)
Button/styles/hover = SubResource("StyleBoxFlat_BtnHover")
Button/styles/normal = SubResource("StyleBoxFlat_BtnNormal")
Button/styles/pressed = SubResource("StyleBoxFlat_BtnPressed")
Label/colors/font_color = Color(0.9, 0.9, 0.95, 1)
LineEdit/colors/font_color = Color(0.9, 0.9, 0.95, 1)
LineEdit/styles/normal = SubResource("StyleBoxFlat_LineEdit")
OptionButton/colors/font_color = Color(0.9, 0.9, 0.95, 1)
Panel/styles/panel = SubResource("StyleBoxFlat_Panel")
PanelContainer/styles/panel = SubResource("StyleBoxFlat_PanelContainer")
RichTextLabel/colors/default_color = Color(0.9, 0.9, 0.95, 1)
TabContainer/colors/font_selected_color = Color(1, 1, 1, 1)
TabContainer/colors/font_unselected_color = Color(0.7, 0.7, 0.75, 1)
TabContainer/styles/panel = SubResource("StyleBoxFlat_TabContainerPanel")
TabContainer/styles/tab_selected = SubResource("StyleBoxFlat_TabSelected")
TabContainer/styles/tab_unselected = SubResource("StyleBoxFlat_TabUnselected")
TextEdit/colors/font_color = Color(0.9, 0.9, 0.95, 1)
TextEdit/styles/normal = SubResource("StyleBoxFlat_LineEdit")
"""

with open(theme_path, "w", encoding="utf-8") as f:
    f.write(new_theme)
print("Theme updated.")

def process_tscn(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    original_content = content

    # Replace inline light backgrounds with dark translucent
    # e.g. bg_color = Color(0.89, 0.88, 0.96, 0.85) -> bg_color = Color(0.05, 0.05, 0.08, 0.7)
    content = re.sub(r'bg_color = Color\([0-9.]+, [0-9.]+, [0-9.]+, [0-9.]+\)', r'bg_color = Color(0.05, 0.05, 0.08, 0.75)', content)
    
    # Replace thick borders or no borders with thin borders in inline styles
    # We can just add border_width = 1 if it's missing, but it's complex via regex.
    # We will just replace corner_radius 24 to 12
    content = re.sub(r'corner_radius_top_left = 24', 'corner_radius_top_left = 12', content)
    content = re.sub(r'corner_radius_top_right = 24', 'corner_radius_top_right = 12', content)
    content = re.sub(r'corner_radius_bottom_right = 24', 'corner_radius_bottom_right = 12', content)
    content = re.sub(r'corner_radius_bottom_left = 24', 'corner_radius_bottom_left = 12', content)

    # Change theme_override_colors for fonts
    content = re.sub(r'theme_override_colors/font_color = Color\([^\)]+\)', r'theme_override_colors/font_color = Color(0.9, 0.9, 0.95, 1)', content)
    content = re.sub(r'theme_override_colors/font_pressed_color = Color\([^\)]+\)', r'theme_override_colors/font_pressed_color = Color(0.7, 0.9, 1, 1)', content)
    content = re.sub(r'theme_override_colors/font_hover_color = Color\([^\)]+\)', r'theme_override_colors/font_hover_color = Color(1, 1, 1, 1)', content)
    content = re.sub(r'theme_override_colors/default_color = Color\([^\)]+\)', r'theme_override_colors/default_color = Color(0.9, 0.9, 0.95, 1)', content)

    # Make panels semi-transparent if they use self_modulate
    content = re.sub(r'self_modulate = Color\(1, 1, 1, 0.49803922\)', r'self_modulate = Color(1, 1, 1, 0.2)', content)

    if content != original_content:
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"Updated {file_path}")

for root, dirs, files in os.walk(ui_dir):
    for file in files:
        if file.endswith(".tscn"):
            process_tscn(os.path.join(root, file))

