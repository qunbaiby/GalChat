with open('e:/GalChat/GalChat/scenes/ui/main/main_scene.tscn', 'r', encoding='utf-8') as f:
    lines = f.readlines()

out_lines = []
in_panel = False
for line in lines:
    if line.startswith('[node name="DialoguePanel" type="Panel"'):
        in_panel = True
        out_lines.append('[node name="DialoguePanel" parent="." instance=ExtResource("14_dialogue")]\n')
        out_lines.append('visible = false\n')
        out_lines.append('layout_mode = 1\n')
        out_lines.append('anchors_preset = 15\n')
        out_lines.append('anchor_right = 1.0\n')
        out_lines.append('anchor_bottom = 1.0\n')
        out_lines.append('grow_horizontal = 2\n')
        out_lines.append('grow_vertical = 2\n')
        continue
    
    if in_panel:
        if line.startswith('[node '):
            if 'parent="DialoguePanel' not in line and not line.startswith('[node name="DialoguePanel"'):
                in_panel = False
                out_lines.append(line)
        continue
        
    out_lines.append(line)

# update load_steps to 20
if out_lines[0].startswith('[gd_scene load_steps=19'):
    out_lines[0] = out_lines[0].replace('load_steps=19', 'load_steps=20')

with open('e:/GalChat/GalChat/scenes/ui/main/main_scene.tscn', 'w', encoding='utf-8') as f:
    f.writelines(out_lines)
