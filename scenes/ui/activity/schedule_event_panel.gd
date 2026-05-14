extends Control

signal option_selected(option_index: int)

@onready var desc_label: RichTextLabel = $Panel/VBoxContainer/DescLabel
@onready var btn_opt1: Button = $Panel/VBoxContainer/HBoxContainer/BtnOpt1
@onready var btn_opt2: Button = $Panel/VBoxContainer/HBoxContainer/BtnOpt2

func _ready() -> void:
	btn_opt1.pressed.connect(_on_btn1_pressed)
	btn_opt2.pressed.connect(_on_btn2_pressed)

func setup(desc: String, opt1: String, opt2: String) -> void:
	desc_label.text = desc
	btn_opt1.text = opt1
	btn_opt2.text = opt2

func _on_btn1_pressed() -> void:
	option_selected.emit(0)

func _on_btn2_pressed() -> void:
	option_selected.emit(1)
