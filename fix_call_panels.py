import re

def replace_in_file(filepath, replacements):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    for old, new in replacements:
        content = content.replace(old, new)
        
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

replacements_voice = [
    ('bg_color = Color(0.101960786, 0.12156863, 0.14901961, 1)', 'bg_color = Color(0.14, 0.11, 0.1, 0.95)'),
    ('bg_color = Color(0.8, 0.8, 0.8, 1)', 'bg_color = Color(0.21, 0.15, 0.13, 0.8)'),
    ('bg_color = Color(0.8, 0.2, 0.2, 1)', 'bg_color = Color(0.8, 0.3, 0.25, 1)'),
    ('bg_color = Color(0.2, 0.6, 0.2, 1)', 'bg_color = Color(0.4, 0.5, 0.3, 1)'),
    ('theme_override_colors/font_color = Color(1, 1, 1, 1)', 'theme_override_colors/font_color = Color(0.9, 0.84, 0.76, 1)'),
    ('theme_override_colors/font_color = Color(0.7, 0.7, 0.7, 1)', 'theme_override_colors/font_color = Color(0.7, 0.6, 0.55, 1)'),
    ('theme_override_colors/default_color = Color(0.9, 0.9, 0.9, 1)', 'theme_override_colors/default_color = Color(0.9, 0.84, 0.76, 1)'),
]
replace_in_file('scenes/ui/mobile/chat/voice_call_panel.tscn', replacements_voice)

replacements_video = [
    ('bg_color = Color(0.050980393, 0.050980393, 0.050980393, 0.6313726)', 'bg_color = Color(0.1, 0.08, 0.07, 0.6)'),
    ('bg_color = Color(0.8, 0.2, 0.2, 1)', 'bg_color = Color(0.8, 0.3, 0.25, 1)'),
    ('bg_color = Color(0.2, 0.6, 0.2, 1)', 'bg_color = Color(0.4, 0.5, 0.3, 1)'),
    ('theme_override_colors/font_color = Color(1, 1, 1, 1)', 'theme_override_colors/font_color = Color(0.9, 0.84, 0.76, 1)'),
    ('theme_override_colors/font_color = Color(0.9, 0.9, 0.9, 1)', 'theme_override_colors/font_color = Color(0.9, 0.84, 0.76, 1)'),
    ('theme_override_colors/default_color = Color(1, 1, 1, 1)', 'theme_override_colors/default_color = Color(0.9, 0.84, 0.76, 1)'),
]
replace_in_file('scenes/ui/mobile/chat/video_call_panel.tscn', replacements_video)

print("Fixed call panels colors.")
