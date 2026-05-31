extends Control

signal info_submitted

const DEFAULT_TITLE := "同学"
const DEFAULT_GENDER := "男"
const DEFAULT_BIRTH_YEAR := 2003
const MBTI_PLACEHOLDER := "未选择  >"
const PLAYER_AVATAR_MALE := "res://assets/images/ui/player/avatar_male.svg"
const PLAYER_AVATAR_FEMALE := "res://assets/images/ui/player/avatar_female.svg"
const PLAYER_AVATAR_OTHER := "res://assets/images/ui/player/avatar_other.svg"
const MBTI_TYPES: Array[Dictionary] = [
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

var player_info: Dictionary = {}
var selected_mbti: String = "未选择"
var _selected_gender: String = DEFAULT_GENDER
var _gender_group: ButtonGroup
var _gender_normal_style: StyleBoxFlat
var _gender_selected_style: StyleBoxFlat

@onready var popup_panel: Panel = %PopupPanel
@onready var avatar_preview: TextureRect = %AvatarPreview
@onready var name_input: LineEdit = %NameInput
@onready var title_input: LineEdit = %TitleInput
@onready var male_btn: Button = %MaleBtn
@onready var female_btn: Button = %FemaleBtn
@onready var birthday_value_button: Button = %BirthdayValueButton
@onready var birthday_editor: HBoxContainer = %BirthdayEditor
@onready var year_spin: SpinBox = %YearSpin
@onready var month_spin: SpinBox = %MonthSpin
@onready var day_spin: SpinBox = %DaySpin
@onready var zodiac_label: Label = %ZodiacLabel
@onready var mbti_button: Button = %MBTIButton
@onready var confirm_btn: Button = %ConfirmBtn
@onready var mbti_popup: Panel = %MBTIPopup
@onready var mbti_grid: GridContainer = %MBTIGrid
@onready var close_mbti_btn: Button = %CloseMBTI

func _ready() -> void:
	_build_gender_styles()
	_init_gender_buttons()
	_init_spin_boxes()
	_init_mbti_grid()
	_load_existing_profile()
	_bind_live_updates()
	_update_days(int(month_spin.value))
	_update_zodiac()
	_update_avatar_preview()
	_update_completion_progress()
	mbti_button.pressed.connect(_show_mbti_popup)
	birthday_value_button.pressed.connect(_toggle_birthday_editor)
	close_mbti_btn.pressed.connect(_hide_mbti_popup)
	confirm_btn.pressed.connect(_on_confirm_pressed)

func _bind_live_updates() -> void:
	name_input.text_changed.connect(_update_completion_progress)
	title_input.text_changed.connect(_update_completion_progress)

func _build_gender_styles() -> void:
	_gender_normal_style = StyleBoxFlat.new()
	_gender_normal_style.bg_color = Color(1, 1, 1, 0.96)
	_gender_normal_style.border_width_left = 1
	_gender_normal_style.border_width_top = 1
	_gender_normal_style.border_width_right = 1
	_gender_normal_style.border_width_bottom = 1
	_gender_normal_style.border_color = Color(0.89, 0.82, 0.72, 1)
	_gender_normal_style.corner_radius_top_left = 14
	_gender_normal_style.corner_radius_top_right = 14
	_gender_normal_style.corner_radius_bottom_left = 14
	_gender_normal_style.corner_radius_bottom_right = 14

	_gender_selected_style = StyleBoxFlat.new()
	_gender_selected_style.bg_color = Color(0.956863, 0.529412, 0.188235, 1)
	_gender_selected_style.border_width_left = 1
	_gender_selected_style.border_width_top = 1
	_gender_selected_style.border_width_right = 1
	_gender_selected_style.border_width_bottom = 1
	_gender_selected_style.border_color = Color(0.89, 0.52, 0.21, 1)
	_gender_selected_style.corner_radius_top_left = 14
	_gender_selected_style.corner_radius_top_right = 14
	_gender_selected_style.corner_radius_bottom_left = 14
	_gender_selected_style.corner_radius_bottom_right = 14

func _init_gender_buttons() -> void:
	_gender_group = ButtonGroup.new()
	_setup_gender_button(male_btn, "男")
	_setup_gender_button(female_btn, "女")

func _setup_gender_button(button: Button, gender: String) -> void:
	button.toggle_mode = true
	button.button_group = _gender_group
	button.pressed.connect(_on_gender_pressed.bind(gender))

func _init_spin_boxes() -> void:
	_setup_spin_box(year_spin, 1970, 2099, DEFAULT_BIRTH_YEAR)
	_setup_spin_box(month_spin, 1, 12, 1)
	_setup_spin_box(day_spin, 1, 31, 1)
	year_spin.value_changed.connect(_on_year_value_changed)
	month_spin.value_changed.connect(_on_month_value_changed)
	day_spin.value_changed.connect(_on_day_value_changed)

func _setup_spin_box(spin: SpinBox, min_value: int, max_value: int, default_value: int) -> void:
	spin.step = 1
	spin.allow_greater = false
	spin.allow_lesser = false
	spin.min_value = min_value
	spin.max_value = max_value
	spin.value = default_value
	var line_edit: LineEdit = spin.get_line_edit()
	if line_edit:
		line_edit.editable = false
		line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER

func _load_existing_profile() -> void:
	if not GameDataManager.profile:
		_select_gender(DEFAULT_GENDER)
		mbti_button.text = MBTI_PLACEHOLDER
		_update_birthday_display()
		return

	var profile = GameDataManager.profile
	name_input.text = str(profile.player_name)
	title_input.text = str(profile.player_title)
	selected_mbti = str(profile.player_mbti).strip_edges()
	if selected_mbti == "":
		selected_mbti = "未选择"
	mbti_button.text = MBTI_PLACEHOLDER if selected_mbti == "未选择" else _build_mbti_button_text(selected_mbti)

	var gender = str(profile.player_gender).strip_edges()
	if gender != "男" and gender != "女":
		gender = DEFAULT_GENDER
	_select_gender(gender)

	var year := DEFAULT_BIRTH_YEAR
	var month := 1
	var day := 1
	var birthday_text = str(profile.player_birthday).strip_edges()
	if birthday_text != "":
		var iso_matcher := RegEx.new()
		iso_matcher.compile("(\\d{4})-(\\d{1,2})-(\\d{1,2})")
		var iso_result = iso_matcher.search(birthday_text)
		if iso_result:
			year = clampi(int(iso_result.get_string(1)), 1970, 2099)
			month = clampi(int(iso_result.get_string(2)), 1, 12)
			day = maxi(1, int(iso_result.get_string(3)))
		else:
			var legacy_matcher := RegEx.new()
			legacy_matcher.compile("(\\d+)月(\\d+)日")
			var legacy_result = legacy_matcher.search(birthday_text)
			if legacy_result:
				month = clampi(int(legacy_result.get_string(1)), 1, 12)
				day = maxi(1, int(legacy_result.get_string(2)))

	year_spin.value = year
	month_spin.value = month
	_update_days(month)
	day_spin.value = mini(day, int(day_spin.max_value))
	_update_birthday_display()

func _select_gender(gender: String) -> void:
	_selected_gender = "女" if gender == "女" else "男"
	male_btn.button_pressed = _selected_gender == "男"
	female_btn.button_pressed = _selected_gender == "女"
	_apply_gender_button_style(male_btn)
	_apply_gender_button_style(female_btn)

func _apply_gender_button_style(button: Button) -> void:
	var selected = button.button_pressed
	var normal_style = _gender_selected_style if selected else _gender_normal_style
	var font_color = Color(1, 1, 1, 1) if selected else Color(0.33, 0.28, 0.22, 1)
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", normal_style)
	button.add_theme_stylebox_override("pressed", _gender_selected_style)
	button.add_theme_stylebox_override("focus", normal_style)
	button.add_theme_color_override("font_color", font_color)

func _on_gender_pressed(gender: String) -> void:
	_select_gender(gender)
	_update_avatar_preview()
	_update_completion_progress()

func _resolve_player_avatar_path(gender: String) -> String:
	match gender:
		"女":
			return PLAYER_AVATAR_FEMALE
		_:
			return PLAYER_AVATAR_MALE

func _update_avatar_preview() -> void:
	var avatar_path = _resolve_player_avatar_path(_selected_gender)
	if ResourceLoader.exists(avatar_path):
		var texture = load(avatar_path)
		if texture is Texture2D:
			avatar_preview.texture = texture

func _update_days(month: int) -> void:
	var days_in_month := 31
	if month == 2:
		days_in_month = 29
	elif month == 4 or month == 6 or month == 9 or month == 11:
		days_in_month = 30
	var current_day = int(day_spin.value)
	day_spin.max_value = days_in_month
	day_spin.value = mini(current_day, days_in_month)

func _on_year_value_changed(_value: float) -> void:
	_update_birthday_display()
	_update_completion_progress()

func _on_month_value_changed(value: float) -> void:
	_update_days(int(value))
	_update_zodiac()
	_update_birthday_display()
	_update_completion_progress()

func _on_day_value_changed(_value: float) -> void:
	_update_zodiac()
	_update_birthday_display()
	_update_completion_progress()

func _toggle_birthday_editor() -> void:
	birthday_editor.visible = not birthday_editor.visible
	_update_birthday_display()

func _update_birthday_display() -> void:
	var arrow = "v" if birthday_editor.visible else ">"
	birthday_value_button.text = "%s  %s" % [_get_formatted_birthday(), arrow]

func _get_formatted_birthday() -> String:
	return "%04d-%02d-%02d" % [int(year_spin.value), int(month_spin.value), int(day_spin.value)]

func _update_zodiac() -> void:
	var month = int(month_spin.value)
	var day = int(day_spin.value)
	zodiac_label.text = _get_zodiac_name(month, day)

func _get_zodiac_name(month: int, day: int) -> String:
	if (month == 3 and day >= 21) or (month == 4 and day <= 19):
		return "白羊座 ♈"
	if (month == 4 and day >= 20) or (month == 5 and day <= 20):
		return "金牛座 ♉"
	if (month == 5 and day >= 21) or (month == 6 and day <= 21):
		return "双子座 ♊"
	if (month == 6 and day >= 22) or (month == 7 and day <= 22):
		return "巨蟹座 ♋"
	if (month == 7 and day >= 23) or (month == 8 and day <= 22):
		return "狮子座 ♌"
	if (month == 8 and day >= 23) or (month == 9 and day <= 22):
		return "处女座 ♍"
	if (month == 9 and day >= 23) or (month == 10 and day <= 23):
		return "天秤座 ♎"
	if (month == 10 and day >= 24) or (month == 11 and day <= 22):
		return "天蝎座 ♏"
	if (month == 11 and day >= 23) or (month == 12 and day <= 21):
		return "射手座 ♐"
	if (month == 12 and day >= 22) or (month == 1 and day <= 19):
		return "摩羯座 ♑"
	if (month == 1 and day >= 20) or (month == 2 and day <= 18):
		return "水瓶座 ♒"
	if (month == 2 and day >= 19) or (month == 3 and day <= 20):
		return "双鱼座 ♓"
	return "未知星座"

func _init_mbti_grid() -> void:
	for child in mbti_grid.get_children():
		child.queue_free()

	for type_info in MBTI_TYPES:
		var mbti_id = str(type_info.get("id", ""))
		var mbti_name = str(type_info.get("name", ""))
		var mbti_desc = str(type_info.get("desc", ""))
		var button = Button.new()
		button.custom_minimum_size = Vector2(0, 82)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "%s (%s)\n%s" % [mbti_id, mbti_name, mbti_desc]
		button.add_theme_font_size_override("font_size", 14)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_on_mbti_selected.bind(mbti_id, mbti_name))
		mbti_grid.add_child(button)

func _show_mbti_popup() -> void:
	mbti_popup.show()

func _hide_mbti_popup() -> void:
	mbti_popup.hide()

func _on_mbti_selected(mbti_id: String, mbti_name: String) -> void:
	selected_mbti = mbti_id
	mbti_button.text = _build_mbti_button_text(mbti_id)
	_update_completion_progress()
	_hide_mbti_popup()

func _build_mbti_button_text(mbti_id: String) -> String:
	for type_info in MBTI_TYPES:
		var current_id = str(type_info.get("id", ""))
		if current_id == mbti_id:
			return "%s - %s  >" % [mbti_id, str(type_info.get("name", ""))]
	return "%s  >" % mbti_id

func _update_completion_progress(_changed_text: String = "") -> void:
	return

func _on_confirm_pressed() -> void:
	var name_text = name_input.text.strip_edges()
	if name_text.is_empty():
		name_input.grab_focus()
		return

	var title_text = title_input.text.strip_edges()
	if title_text.is_empty():
		title_text = DEFAULT_TITLE

	var gender_text = _selected_gender
	var birthday_text = _get_formatted_birthday()
	var avatar_path = _resolve_player_avatar_path(gender_text)

	player_info = {
		"name": name_text,
		"preferred_title": title_text,
		"gender": gender_text,
		"birthday": birthday_text,
		"zodiac": zodiac_label.text,
		"mbti": selected_mbti,
		"profession": "创奇引路人",
		"avatar_path": avatar_path
	}

	if GameDataManager.memory_manager:
		var core_mem1 = "玩家的真实姓名是：%s，希望我称呼其为：%s" % [name_text, title_text]
		var core_mem2 = "玩家的生理性别是：%s，生日是：%s（%s），MBTI人格类型为：%s" % [gender_text, birthday_text, zodiac_label.text, selected_mbti]
		GameDataManager.memory_manager.add_memory("core", core_mem1)
		GameDataManager.memory_manager.add_memory("core", core_mem2)

	info_submitted.emit()
