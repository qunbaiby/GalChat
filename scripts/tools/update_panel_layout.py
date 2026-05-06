import os

tscn_path = r"f:\GODOT游戏模板\aigame\gal-chat\scenes\ui\common\dialogue_panel.tscn"
with open(tscn_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Modify DialogueLayer
# Move to bottom: anchor_top=1, anchor_bottom=1, offset_top=-180, offset_bottom=-80
content = content.replace(
"""[node name="DialogueLayer" type="PanelContainer" parent="."]
layout_mode = 1
anchors_preset = 14
anchor_top = 0.5
anchor_right = 1.0
anchor_bottom = 0.5
offset_top = 60.0
offset_bottom = 100.0""",
"""[node name="DialogueLayer" type="PanelContainer" parent="."]
layout_mode = 1
anchors_preset = 12
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_top = -220.0
offset_bottom = -100.0""")

# 2. Modify QuickOptionLayer
# Move to middle: anchor_top=0.5, anchor_bottom=0.5, offset_top=-150, offset_bottom=50
content = content.replace(
"""[node name="QuickOptionLayer" type="Control" parent="."]
layout_mode = 1
anchors_preset = 14
anchor_top = 0.5
anchor_right = 1.0
anchor_bottom = 0.5
offset_top = 160.0
offset_bottom = 260.0""",
"""[node name="QuickOptionLayer" type="Control" parent="."]
layout_mode = 1
anchors_preset = 14
anchor_top = 0.5
anchor_right = 1.0
anchor_bottom = 0.5
offset_top = -100.0
offset_bottom = 100.0""")

# 3. Change QuickOptions from HFlowContainer to VBoxContainer
content = content.replace(
"""[node name="QuickOptions" type="HFlowContainer" parent="QuickOptionLayer/ScrollContainer"]""",
"""[node name="QuickOptions" type="VBoxContainer" parent="QuickOptionLayer/ScrollContainer"]""")

# 4. Modify HistoryButton and EndChatButton positions to match the new layout
content = content.replace(
"""[node name="HistoryButton" type="Button" parent="."]
layout_mode = 1
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -103.0
offset_top = -326.0
offset_right = -53.0
offset_bottom = -295.0""",
"""[node name="HistoryButton" type="Button" parent="."]
layout_mode = 1
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -120.0
offset_top = -140.0
offset_right = -50.0
offset_bottom = -110.0""")

content = content.replace(
"""[node name="EndChatButton" type="Button" parent="."]
layout_mode = 1
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -102.0
offset_top = -596.0
offset_right = -12.0
offset_bottom = -565.0""",
"""[node name="EndChatButton" type="Button" parent="."]
layout_mode = 1
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -120.0
offset_top = -100.0
offset_right = -50.0
offset_bottom = -70.0""")

with open(tscn_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated dialogue_panel.tscn")
