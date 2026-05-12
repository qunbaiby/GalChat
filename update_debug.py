import re

with open("scenes/ui/story/debug_panel.tscn", "r", encoding="utf-8") as f:
    content = f.read()

insertion = """
[node name="MomentsTestLabel" type="Label" parent="CenterContainer/Panel/VBoxContainer/TabContainer/工具与测试"]
layout_mode = 2
text = "--- 朋友圈测试 ---"
horizontal_alignment = 1

[node name="MomentsAuthorBox" type="HBoxContainer" parent="CenterContainer/Panel/VBoxContainer/TabContainer/工具与测试"]
layout_mode = 2

[node name="Label" type="Label" parent="CenterContainer/Panel/VBoxContainer/TabContainer/工具与测试/MomentsAuthorBox"]
layout_mode = 2
text = "发送者:"

[node name="MomentAuthor" type="LineEdit" parent="CenterContainer/Panel/VBoxContainer/TabContainer/工具与测试/MomentsAuthorBox"]
layout_mode = 2
size_flags_horizontal = 3
text = "AI"

[node name="Label2" type="Label" parent="CenterContainer/Panel/VBoxContainer/TabContainer/工具与测试/MomentsAuthorBox"]
layout_mode = 2
text = " 模式:"

[node name="MomentMode" type="OptionButton" parent="CenterContainer/Panel/VBoxContainer/TabContainer/工具与测试/MomentsAuthorBox"]
layout_mode = 2
item_count = 2
selected = 0
popup/item_0/text = "图文并茂"
popup/item_0/id = 0
popup/item_1/text = "纯文字"
popup/item_1/id = 1

[node name="MomentsContentBox" type="HBoxContainer" parent="CenterContainer/Panel/VBoxContainer/TabContainer/工具与测试"]
layout_mode = 2

[node name="Label" type="Label" parent="CenterContainer/Panel/VBoxContainer/TabContainer/工具与测试/MomentsContentBox"]
layout_mode = 2
text = "内容:"

[node name="MomentContent" type="TextEdit" parent="CenterContainer/Panel/VBoxContainer/TabContainer/工具与测试/MomentsContentBox"]
custom_minimum_size = Vector2(0, 60)
layout_mode = 2
size_flags_horizontal = 3
text = "这是一条测试朋友圈。"

[node name="MomentsBtnBox" type="HBoxContainer" parent="CenterContainer/Panel/VBoxContainer/TabContainer/工具与测试"]
layout_mode = 2
alignment = 1
theme_override_constants/separation = 20

[node name="SendMomentBtn" type="Button" parent="CenterContainer/Panel/VBoxContainer/TabContainer/工具与测试/MomentsBtnBox"]
custom_minimum_size = Vector2(120, 50)
layout_mode = 2
text = "手动发送"

[node name="AIGenerateMomentBtn" type="Button" parent="CenterContainer/Panel/VBoxContainer/TabContainer/工具与测试/MomentsBtnBox"]
custom_minimum_size = Vector2(120, 50)
layout_mode = 2
text = "AI生成"

"""

if "MomentsTestLabel" not in content:
    content = content.replace("[node name=\"大五人格\"", insertion + "[node name=\"大五人格\"")
    with open("scenes/ui/story/debug_panel.tscn", "w", encoding="utf-8") as f:
        f.write(content)
