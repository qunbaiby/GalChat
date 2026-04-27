extends Control

signal info_submitted

var player_info: Dictionary = {}

@onready var panel: Panel = $Panel
@onready var name_input: LineEdit = $Panel/MarginContainer/VBoxContainer/NameHBox/NameInput
@onready var gender_option: OptionButton = $Panel/MarginContainer/VBoxContainer/GenderHBox/GenderOption
@onready var month_option: OptionButton = $Panel/MarginContainer/VBoxContainer/BirthdayHBox/MonthOption
@onready var day_option: OptionButton = $Panel/MarginContainer/VBoxContainer/BirthdayHBox/DayOption
@onready var confirm_btn: Button = $Panel/MarginContainer/VBoxContainer/BtnHBox/ConfirmBtn

func _ready() -> void:
	# 性别选择
	gender_option.add_item("男", 0)
	gender_option.add_item("女", 1)
	gender_option.add_item("其他", 2)
	
	# 生日选择
	for m in range(1, 13):
		month_option.add_item(str(m) + "月", m)
	month_option.item_selected.connect(_on_month_selected)
	
	_update_days(1)
	
	confirm_btn.pressed.connect(_on_confirm_pressed)

func _update_days(month: int) -> void:
	var days_in_month = 31
	if month == 2:
		days_in_month = 29
	elif month in [4, 6, 9, 11]:
		days_in_month = 30
		
	var current_selected = -1
	if day_option.item_count > 0:
		current_selected = day_option.get_selected_id()
		
	day_option.clear()
	for d in range(1, days_in_month + 1):
		day_option.add_item(str(d) + "日", d)
		
	if current_selected != -1 and current_selected <= days_in_month:
		day_option.select(current_selected - 1)
	else:
		day_option.select(0)

func _on_month_selected(index: int) -> void:
	var month = month_option.get_item_id(index)
	_update_days(month)

func _on_confirm_pressed() -> void:
	var name_text = name_input.text.strip_edges()
	if name_text.is_empty():
		name_input.grab_focus()
		return
		
	var gender_text = gender_option.get_item_text(gender_option.selected)
	var month_text = month_option.get_item_text(month_option.selected)
	var day_text = day_option.get_item_text(day_option.selected)
	
	player_info = {
		"name": name_text,
		"gender": gender_text,
		"birthday": month_text + day_text,
		"profession": "创奇引路人"
	}
	
	info_submitted.emit()
