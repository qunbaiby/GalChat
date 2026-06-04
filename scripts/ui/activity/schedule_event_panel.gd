extends Control

signal option_selected(option_index: int)
signal result_confirmed

@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var desc_label: RichTextLabel = $Panel/VBoxContainer/DescLabel
@onready var option_box: HBoxContainer = $Panel/VBoxContainer/OptionsHBox
@onready var btn_opt1: Button = $Panel/VBoxContainer/OptionsHBox/BtnOpt1
@onready var btn_opt2: Button = $Panel/VBoxContainer/OptionsHBox/BtnOpt2
@onready var result_box: VBoxContainer = $Panel/VBoxContainer/ResultBox
@onready var result_desc_label: RichTextLabel = $Panel/VBoxContainer/ResultBox/ResultPanel/ResultMargin/ResultInnerVBox/ResultDesc
@onready var result_effects_label: RichTextLabel = $Panel/VBoxContainer/ResultBox/ResultPanel/ResultMargin/ResultInnerVBox/EffectsPanel/EffectsMargin/EffectsLabel
@onready var continue_button: Button = $Panel/VBoxContainer/ResultBox/ContinueButton

func _ready() -> void:
	btn_opt1.pressed.connect(_on_btn1_pressed)
	btn_opt2.pressed.connect(_on_btn2_pressed)
	continue_button.pressed.connect(_on_continue_pressed)

func setup(desc: String, opt1: String, opt2: String, title: String = "突发事件！") -> void:
	title_label.text = title
	desc_label.text = desc
	desc_label.show()
	btn_opt1.text = opt1
	btn_opt2.text = opt2
	btn_opt1.visible = opt1.strip_edges() != ""
	btn_opt2.visible = opt2.strip_edges() != ""
	option_box.show()
	result_box.hide()

func show_result(desc: String, attr_changes: Dictionary) -> void:
	desc_label.hide()
	option_box.hide()
	result_box.show()
	result_desc_label.text = desc
	result_effects_label.text = _build_effects_bbcode(attr_changes)

func _build_effects_bbcode(attr_changes: Dictionary) -> String:
	if attr_changes.is_empty():
		return "[center]本次没有额外属性变化。[/center]"
	
	var lines: Array[String] = []
	for key in attr_changes.keys():
		var value = int(attr_changes[key])
		if value == 0:
			continue
		var prefix = "+" if value > 0 else ""
		var color = "#5fbf91" if value > 0 else "#d27b7b"
		lines.append("[color=%s]%s %s%d[/color]" % [color, str(key), prefix, value])
	
	if lines.is_empty():
		return "[center]本次没有额外属性变化。[/center]"
	return "[center]%s[/center]" % "\n".join(lines)

func _on_btn1_pressed() -> void:
	option_selected.emit(0)

func _on_btn2_pressed() -> void:
	option_selected.emit(1)

func _on_continue_pressed() -> void:
	result_confirmed.emit()
