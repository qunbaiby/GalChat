extends Control

signal info_submitted

var player_info: Dictionary = {}
var selected_mbti: String = "未选择"

const MBTI_TYPES = [
	{"id": "INTJ", "name": "建筑师", "desc": "富有想象力和战略性的思想家，一切皆在计划之中。"},
	{"id": "INTP", "name": "逻辑学家", "desc": "具有创造力的发明家，对知识有着不可抑制的渴望。"},
	{"id": "ENTJ", "name": "指挥官", "desc": "大胆、富有想象力且意志强大的领导者，总能找到解决方法。"},
	{"id": "ENTP", "name": "辩论家", "desc": "聪明好奇的思想者，无法抗拒智力上的挑战。"},
	{"id": "INFJ", "name": "提倡者", "desc": "安静而神秘，同时鼓舞人心且不知疲倦的理想主义者。"},
	{"id": "INFP", "name": "调停者", "desc": "诗意、善良且利他，总是热衷于帮助正义事业。"},
	{"id": "ENFJ", "name": "主人公", "desc": "富有魅力和鼓舞人心的领导者，有使听众着迷的能力。"},
	{"id": "ENFP", "name": "竞选者", "desc": "热情、有创造力、爱交际的自由精神，总能找到理由微笑。"},
	{"id": "ISTJ", "name": "物流师", "desc": "实际且注重事实的个人，其可靠性不容怀疑。"},
	{"id": "ISFJ", "name": "守卫者", "desc": "非常专注而温暖的保护者，时刻准备着保卫他们爱的人。"},
	{"id": "ESTJ", "name": "总经理", "desc": "出色的管理者，在管理事物或人的方面无与伦比。"},
	{"id": "ESFJ", "name": "执政官", "desc": "极有同情心、爱交际和受欢迎的人，总是热心提供帮助。"},
	{"id": "ISTP", "name": "鉴赏家", "desc": "大胆而实际的实验家，掌握所有工具。"},
	{"id": "ISFP", "name": "探险家", "desc": "灵活有魅力的艺术家，时刻准备着探索和体验新鲜事物。"},
	{"id": "ESTP", "name": "企业家", "desc": "聪明、精力充沛且非常敏锐的人，真正享受生活在边缘。"},
	{"id": "ESFP", "name": "表演者", "desc": "自发、精力充沛且热情的表演者，生活在他们周围永不无聊。"}
]

@onready var panel: Panel = $Panel
@onready var name_input: LineEdit = $Panel/MarginContainer/VBoxContainer/FormBox/NameField/NameInput
@onready var title_input: LineEdit = $Panel/MarginContainer/VBoxContainer/FormBox/TitleField/TitleInput
@onready var gender_option: OptionButton = $Panel/MarginContainer/VBoxContainer/FormBox/GenderField/GenderOption
@onready var month_option: OptionButton = $Panel/MarginContainer/VBoxContainer/FormBox/BirthdayField/BirthdayBox/MonthOption
@onready var day_option: OptionButton = $Panel/MarginContainer/VBoxContainer/FormBox/BirthdayField/BirthdayBox/DayOption
@onready var zodiac_label: Label = $Panel/MarginContainer/VBoxContainer/FormBox/MBTIField/TopBox/ZodiacLabel
@onready var mbti_button: Button = $Panel/MarginContainer/VBoxContainer/FormBox/MBTIField/MBTIButton
@onready var confirm_btn: Button = $Panel/MarginContainer/VBoxContainer/ConfirmBtn

@onready var mbti_popup: Panel = $MBTIPopup
@onready var mbti_grid: GridContainer = $MBTIPopup/Margin/VBox/Scroll/Grid
@onready var close_mbti_btn: Button = $MBTIPopup/Margin/VBox/CloseMBTI

func _ready() -> void:
	# 性别选择
	gender_option.add_item("男", 0)
	gender_option.add_item("女", 1)
	gender_option.add_item("其他", 2)
	
	# 生日选择
	for m in range(1, 13):
		month_option.add_item(str(m) + "月", m)
	month_option.item_selected.connect(_on_month_selected)
	day_option.item_selected.connect(_on_day_selected)
	
	_update_days(1)
	_update_zodiac()
	
	# MBTI 面板初始化
	_init_mbti_grid()
	mbti_button.pressed.connect(_show_mbti_popup)
	close_mbti_btn.pressed.connect(_hide_mbti_popup)
	
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
	_update_zodiac()

func _on_day_selected(index: int) -> void:
	_update_zodiac()

func _update_zodiac() -> void:
	var month = month_option.get_item_id(month_option.selected)
	var day = day_option.get_item_id(day_option.selected)
	zodiac_label.text = _get_zodiac_name(month, day)

func _get_zodiac_name(month: int, day: int) -> String:
	if (month == 3 and day >= 21) or (month == 4 and day <= 19): return "白羊座 ♈"
	elif (month == 4 and day >= 20) or (month == 5 and day <= 20): return "金牛座 ♉"
	elif (month == 5 and day >= 21) or (month == 6 and day <= 21): return "双子座 ♊"
	elif (month == 6 and day >= 22) or (month == 7 and day <= 22): return "巨蟹座 ♋"
	elif (month == 7 and day >= 23) or (month == 8 and day <= 22): return "狮子座 ♌"
	elif (month == 8 and day >= 23) or (month == 9 and day <= 22): return "处女座 ♍"
	elif (month == 9 and day >= 23) or (month == 10 and day <= 23): return "天秤座 ♎"
	elif (month == 10 and day >= 24) or (month == 11 and day <= 22): return "天蝎座 ♏"
	elif (month == 11 and day >= 23) or (month == 12 and day <= 21): return "射手座 ♐"
	elif (month == 12 and day >= 22) or (month == 1 and day <= 19): return "摩羯座 ♑"
	elif (month == 1 and day >= 20) or (month == 2 and day <= 18): return "水瓶座 ♒"
	elif (month == 2 and day >= 19) or (month == 3 and day <= 20): return "双鱼座 ♓"
	return "未知"

func _init_mbti_grid() -> void:
	for child in mbti_grid.get_children():
		child.queue_free()
		
	for type_info in MBTI_TYPES:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 80)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = type_info["id"] + " (" + type_info["name"] + ")\n" + type_info["desc"]
		# 设置多行显示
		btn.add_theme_font_size_override("font_size", 14)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		btn.pressed.connect(func(): _on_mbti_selected(type_info["id"], type_info["name"]))
		mbti_grid.add_child(btn)

func _show_mbti_popup() -> void:
	mbti_popup.show()

func _hide_mbti_popup() -> void:
	mbti_popup.hide()

func _on_mbti_selected(mbti_id: String, mbti_name: String) -> void:
	selected_mbti = mbti_id
	mbti_button.text = mbti_id + " - " + mbti_name
	_hide_mbti_popup()

func _on_confirm_pressed() -> void:
	var name_text = name_input.text.strip_edges()
	if name_text.is_empty():
		name_input.grab_focus()
		return
		
	var title_text = title_input.text.strip_edges()
	if title_text.is_empty():
		title_text = "同学" # 默认称呼
		
	var gender_text = gender_option.get_item_text(gender_option.selected)
	var month_text = month_option.get_item_text(month_option.selected)
	var day_text = day_option.get_item_text(day_option.selected)
	
	player_info = {
		"name": name_text,
		"preferred_title": title_text,
		"gender": gender_text,
		"birthday": month_text + day_text,
		"zodiac": zodiac_label.text,
		"mbti": selected_mbti,
		"profession": "创奇引路人"
	}
	
	# 保存至核心记忆
	if GameDataManager.memory_manager:
		var core_mem1 = "玩家的真实姓名是：%s，希望我称呼其为：%s" % [name_text, title_text]
		var core_mem2 = "玩家的生理性别是：%s，生日是：%s（%s），MBTI人格类型为：%s" % [gender_text, player_info["birthday"], zodiac_label.text, selected_mbti]
		GameDataManager.memory_manager.add_memory("core", core_mem1)
		GameDataManager.memory_manager.add_memory("core", core_mem2)
	
	info_submitted.emit()
