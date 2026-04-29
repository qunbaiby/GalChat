import sys

with open('e:/GalChat/GalChat/scenes/ui/map/core/quick_location_scene.tscn', 'r', encoding='utf-8') as f:
    lines = f.readlines()

out_lines = []
in_panel = False
for line in lines:
    if line.startswith('[node name="DialoguePanel" type="Panel"'):
        in_panel = True
        out_lines.append('[gd_scene load_steps=2 format=3]\n\n')
        out_lines.append('[ext_resource type="Script" path="res://scripts/ui/common/dialogue_panel.gd" id="1_script"]\n\n')
        out_lines.append('[node name="DialoguePanel" type="Panel"]\n')
        out_lines.append('visible = false\n')
        out_lines.append('anchors_preset = 15\n')
        out_lines.append('anchor_right = 1.0\n')
        out_lines.append('anchor_bottom = 1.0\n')
        out_lines.append('grow_horizontal = 2\n')
        out_lines.append('grow_vertical = 2\n')
        out_lines.append('script = ExtResource("1_script")\n')
        continue
    
    if in_panel:
        if line.startswith('[node '):
            if 'parent="DialoguePanel' not in line and not line.startswith('[node name="DialoguePanel"'):
                break
            
            line = line.replace('parent="DialoguePanel"', 'parent="."')
            line = line.replace('parent="DialoguePanel/', 'parent="')
            
        out_lines.append(line)

with open('e:/GalChat/GalChat/scenes/ui/common/dialogue_panel.tscn', 'w', encoding='utf-8') as f:
    f.writelines(out_lines)
