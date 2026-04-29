with open('e:/GalChat/GalChat/scenes/ui/map/core/quick_location_scene.tscn', 'r', encoding='utf-8') as f:
    lines = f.readlines()

out_lines = []
in_panel = False
for line in lines:
    if line.startswith('[node name="DialoguePanel" type="Panel"'):
        in_panel = True
        out_lines.append('[node name="DialoguePanel" parent="." instance=ExtResource("2_dialogue")]\n')
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

# add ext resource at top
new_out = []
for line in out_lines:
    new_out.append(line)
    if line.startswith('[ext_resource type="Script"'):
        new_out.append('[ext_resource type="PackedScene" uid="uid://cy8xxa3qqt4m2" path="res://scenes/ui/common/dialogue_panel.tscn" id="2_dialogue"]\n')

# update load_steps to 3
if new_out[0].startswith('[gd_scene load_steps=2'):
    new_out[0] = '[gd_scene load_steps=3 format=3 uid="uid://11qncg5lxfxf"]\n'

with open('e:/GalChat/GalChat/scenes/ui/map/core/quick_location_scene.tscn', 'w', encoding='utf-8') as f:
    f.writelines(new_out)
