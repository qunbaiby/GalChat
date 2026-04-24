import os
import glob
import re

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # If it's a scene file, we should ensure the galchat_theme.tres is loaded and assigned
    theme_res_id = "2_theme"
    
    # Check if galchat_theme.tres is loaded
    if 'path="res://assets/themes/galchat_theme.tres"' in content:
        # Find the id
        match = re.search(r'\[ext_resource type="Theme" uid="[^"]+" path="res://assets/themes/galchat_theme.tres" id="([^"]+)"\]', content)
        if match:
            theme_res_id = match.group(1)
    else:
        # Add the resource
        res_line = '[ext_resource type="Theme" uid="uid://cx6y837p8y74k" path="res://assets/themes/galchat_theme.tres" id="2_theme"]\n'
        content = content.replace('[ext_resource', res_line + '[ext_resource', 1)
        theme_res_id = "2_theme"
        
    # Check if the root node has the theme assigned
    # Root node usually starts with [node name="..." type="Control"] or similar
    root_node_match = re.search(r'(\[node name="[^"]+" type="[^"]+"(?: parent="[^"]+")?\]\n(?:[^\[]+\n)*)', content)
    if root_node_match:
        root_block = root_node_match.group(1)
        if 'theme = ExtResource' not in root_block:
            # Inject theme
            new_root_block = root_block + f'theme = ExtResource("{theme_res_id}")\n'
            content = content.replace(root_block, new_root_block)

    # Let's replace colors in StyleBoxFlat
    # Mobile Chat Panel
    content = re.sub(r'bg_color = Color\(0.97, 0.97, 0.98, 1\)', 'bg_color = Color(0.14, 0.11, 0.1, 0.95)', content)
    content = re.sub(r'bg_color = Color\(0.95, 0.95, 0.95, 1\)', 'bg_color = Color(0.1, 0.08, 0.07, 0.8)', content)
    content = re.sub(r'bg_color = Color\(0.54, 0.35, 0.96, 1\)', 'bg_color = Color(0.4, 0.26, 0.2, 1)', content)
    
    # Replace texts to match the dark theme
    content = re.sub(r'theme_override_colors/font_color = Color\(0.1, 0.1, 0.1, 1\)', 'theme_override_colors/font_color = Color(0.9, 0.84, 0.76, 1)', content)
    content = re.sub(r'theme_override_colors/font_color = Color\(0.2, 0.2, 0.2, 1\)', 'theme_override_colors/font_color = Color(0.9, 0.84, 0.76, 1)', content)
    content = re.sub(r'theme_override_colors/font_color = Color\(0.4, 0.4, 0.4, 1\)', 'theme_override_colors/font_color = Color(0.7, 0.6, 0.55, 1)', content)
    content = re.sub(r'theme_override_colors/font_color = Color\(0.6, 0.6, 0.6, 1\)', 'theme_override_colors/font_color = Color(0.7, 0.6, 0.55, 1)', content)
    content = re.sub(r'theme_override_colors/font_color = Color\(0.5, 0.5, 0.5, 1\)', 'theme_override_colors/font_color = Color(0.7, 0.6, 0.55, 1)', content)
    
    # mobile_interface colors
    content = re.sub(r'bg_color = Color\(0.85, 0.85, 0.88, 0.8\)', 'bg_color = Color(0.14, 0.11, 0.1, 0.85)', content)
    content = re.sub(r'bg_color = Color\(0.6, 0.8, 0.9, 0.8\)', 'bg_color = Color(0.14, 0.11, 0.1, 0.85)', content)
    content = re.sub(r'bg_color = Color\(0.9, 0.9, 0.92, 0.6\)', 'bg_color = Color(0.1, 0.08, 0.07, 0.6)', content)
    content = re.sub(r'bg_color = Color\(0.8, 0.8, 0.8, 0.5\)', 'bg_color = Color(0.14, 0.11, 0.1, 0.5)', content)
    content = re.sub(r'bg_color = Color\(0.9, 0.9, 0.9, 0.5\)', 'bg_color = Color(0.21, 0.15, 0.13, 0.8)', content)
    content = re.sub(r'border_color = Color\(1, 1, 1, 0.8\)', 'border_color = Color(0.55, 0.35, 0.27, 0.5)', content)

    # Some hardcoded icons might have `modulate = Color(0.6, 0.6, 0.6, 1)`
    content = re.sub(r'modulate = Color\(0.6, 0.6, 0.6, 1\)', 'modulate = Color(0.9, 0.84, 0.76, 1)', content)
    
    # Save back
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == "__main__":
    tscn_files = glob.glob('scenes/ui/mobile/**/*.tscn', recursive=True)
    for filepath in tscn_files:
        print(f"Processing {filepath}...")
        process_file(filepath)
