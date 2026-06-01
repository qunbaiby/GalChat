extends Button

signal option_pressed(option_id: String)

@onready var icon_label: Label = $CardPanel/Margin/VBox/ArtPanel/IconLabel
@onready var title_label: Label = $CardPanel/Margin/VBox/TitleWrap/Title
@onready var subtitle_label: Label = $CardPanel/Margin/VBox/TitleWrap/SubTitle
@onready var desc_label: Label = $CardPanel/Margin/VBox/Desc
@onready var cost_icon_top: Label = $CardPanel/Margin/VBox/CostBox/CostVBox/CostRowTop/CostIconTop
@onready var cost_text_top: Label = $CardPanel/Margin/VBox/CostBox/CostVBox/CostRowTop/CostTextTop
@onready var cost_value_top: Label = $CardPanel/Margin/VBox/CostBox/CostVBox/CostRowTop/CostValueTop
@onready var cost_icon_bottom: Label = $CardPanel/Margin/VBox/CostBox/CostVBox/CostRowBottom/CostIconBottom
@onready var cost_text_bottom: Label = $CardPanel/Margin/VBox/CostBox/CostVBox/CostRowBottom/CostTextBottom
@onready var cost_value_bottom: Label = $CardPanel/Margin/VBox/CostBox/CostVBox/CostRowBottom/CostValueBottom
@onready var gain_top_icon: Label = $CardPanel/Margin/VBox/GainsBox/GainTop/GainTopIcon
@onready var gain_top_label: Label = $CardPanel/Margin/VBox/GainsBox/GainTop/GainTopLabel
@onready var gain_bottom_icon: Label = $CardPanel/Margin/VBox/GainsBox/GainBottom/GainBottomIcon
@onready var gain_bottom_label: Label = $CardPanel/Margin/VBox/GainsBox/GainBottom/GainBottomLabel

@export var normal_style: StyleBox
@export var selected_style: StyleBox

var _option_id: String = ""

func _ready() -> void:
	pressed.connect(_on_pressed)
	
	if normal_style:
		add_theme_stylebox_override("normal", normal_style)
		add_theme_stylebox_override("hover", normal_style)
		add_theme_stylebox_override("pressed", normal_style)

func setup_option(data: Dictionary) -> void:
	_option_id = str(data.get("id", "")).strip_edges()
	icon_label.text = str(data.get("icon", "•"))
	title_label.text = str(data.get("name", "未命名项目"))
	subtitle_label.text = str(data.get("subtitle", "COURSE"))
	desc_label.text = str(data.get("desc", ""))
	_build_cost_lines(data.get("cost_lines", []))
	_build_gain_tags(data.get("gain_tags", []))

func set_selected(is_selected: bool) -> void:
	if is_selected:
		if selected_style:
			add_theme_stylebox_override("normal", selected_style)
			add_theme_stylebox_override("hover", selected_style)
			add_theme_stylebox_override("pressed", selected_style)
	else:
		if normal_style:
			add_theme_stylebox_override("normal", normal_style)
			add_theme_stylebox_override("hover", normal_style)
			add_theme_stylebox_override("pressed", normal_style)

func _build_cost_lines(lines: Array) -> void:
	var final_lines: Array[Dictionary] = []
	for line in lines:
		if line is Dictionary:
			final_lines.append(line)
		else:
			var raw_text := str(line).strip_edges()
			if raw_text != "":
				final_lines.append({"icon":"◉","label":raw_text,"value":""})
	var top := final_lines[0] if final_lines.size() > 0 else {"icon":"⚡","label":"行动力","value":"-0"}
	var bottom := final_lines[1] if final_lines.size() > 1 else {"icon":"◷","label":"时间","value":"+0"}
	cost_icon_top.text = str(top.get("icon", "◉"))
	cost_text_top.text = str(top.get("label", "行动力"))
	cost_value_top.text = str(top.get("value", "-0"))
	cost_icon_bottom.text = str(bottom.get("icon", "◉"))
	cost_text_bottom.text = str(bottom.get("label", "时间"))
	cost_value_bottom.text = str(bottom.get("value", "+0"))

func _build_gain_tags(tags: Array) -> void:
	var final_tags: Array[Dictionary] = []
	for tag in tags:
		if tag is Dictionary:
			final_tags.append(tag)
		else:
			var raw_text := str(tag).strip_edges()
			if raw_text != "":
				final_tags.append({"icon":"✦","text":raw_text})
	var top := final_tags[0] if final_tags.size() > 0 else {"icon":"✦","text":"成长 +0"}
	var bottom := final_tags[1] if final_tags.size() > 1 else {"icon":"✦","text":"附加 +0"}
	gain_top_icon.text = str(top.get("icon", "✦"))
	gain_top_label.text = str(top.get("text", "成长 +0"))
	gain_bottom_icon.text = str(bottom.get("icon", "✦"))
	gain_bottom_label.text = str(bottom.get("text", "附加 +0"))

func _on_pressed() -> void:
	option_pressed.emit(_option_id)
