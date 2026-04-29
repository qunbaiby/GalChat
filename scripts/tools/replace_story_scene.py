with open('e:/GalChat/GalChat/scenes/ui/story/story_scene.tscn', 'r', encoding='utf-8') as f:
    lines = f.readlines()

out_lines = []
in_panel = False
for line in lines:
    if line.startswith('[node name="DialogueLayer" type="ColorRect"'):
        in_panel = True
        # add the common DialoguePanel as a child of UIPanel
        out_lines.append('[node name="DialoguePanel" parent="UIPanel" instance=ExtResource("13_dialogue")]\n')
        out_lines.append('layout_mode = 1\n')
        out_lines.append('anchors_preset = 15\n')
        out_lines.append('anchor_right = 1.0\n')
        out_lines.append('anchor_bottom = 1.0\n')
        out_lines.append('grow_horizontal = 2\n')
        out_lines.append('grow_vertical = 2\n')
        continue
    
    if in_panel:
        if line.startswith('[node '):
            if 'parent="UIPanel/DialogueLayer' not in line and not line.startswith('[node name="DialogueLayer"'):
                in_panel = False
                out_lines.append(line)
        continue
        
    out_lines.append(line)

if out_lines[0].startswith('[gd_scene load_steps=12'):
    out_lines[0] = out_lines[0].replace('load_steps=12', 'load_steps=13')

with open('e:/GalChat/GalChat/scenes/ui/story/story_scene.tscn', 'w', encoding='utf-8') as f:
    f.writelines(out_lines)