import re
import os

def replace_in_file(filepath, replacements):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    for old, new in replacements:
        content = content.replace(old, new)
        
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

replacements_tscn = [
    ('bg_color = Color(0.95, 0.95, 0.97, 1)', 'bg_color = Color(0.14, 0.11, 0.1, 0.95)'),
    ('theme_override_colors/font_color = Color(0.2, 0.2, 0.2, 1)', 'theme_override_colors/font_color = Color(0.9, 0.84, 0.76, 1)'),
]
replace_in_file('scenes/ui/mobile/chat/mobile_contact_list.tscn', replacements_tscn)

replacements_gd_contact = [
    ('style.bg_color = Color(1, 1, 1, 1)', 'style.bg_color = Color(0.14, 0.11, 0.1, 0.85)'),
    ('hover_style.bg_color = Color(0.95, 0.95, 0.95, 1)', 'hover_style.bg_color = Color(0.21, 0.15, 0.13, 0.8)'),
    ('name_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))', 'name_label.add_theme_color_override("font_color", Color(0.9, 0.84, 0.76))'),
    ('desc_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))', 'desc_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.55))'),
]
replace_in_file('scripts/ui/mobile/chat/mobile_contact_list.gd', replacements_gd_contact)

replacements_gd_chat = [
    ('style.bg_color = Color(0.9, 0.9, 0.9, 1)', 'style.bg_color = Color(0.14, 0.11, 0.1, 0.85)'),
    ('style.bg_color = Color(1, 1, 1, 1)', 'style.bg_color = Color(0.14, 0.11, 0.1, 0.85)'),
    ('label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))', 'label.add_theme_color_override("font_color", Color(0.9, 0.84, 0.76))'),
    ('Color(0.2, 0.2, 0.2, 1) if is_voice else Color(1, 1, 1, 1)', 'Color(0.4, 0.26, 0.2, 1) if is_voice else Color(0.14, 0.11, 0.1, 0.85)'),
    ('transcribe_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)', 'transcribe_style.bg_color = Color(0.1, 0.08, 0.07, 0.8)'),
    ('t_style.bg_color = Color(0.2, 0.2, 0.2, 1)', 't_style.bg_color = Color(0.14, 0.11, 0.1, 0.85)'),
    ('av_style.bg_color = Color(1, 1, 1, 1)', 'av_style.bg_color = Color(0.14, 0.11, 0.1, 1)'),
    ('name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))', 'name_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.55))'),
]
replace_in_file('scripts/ui/mobile/chat/mobile_chat_panel.gd', replacements_gd_chat)

print("Fixed colors in gd and tscn files.")
