extends Control

signal info_submitted

const DEFAULT_GENDER := ""
const DEFAULT_BIRTH_YEAR := 2003
const DEFAULT_BIRTH_MONTH := 1
const DEFAULT_BIRTH_DAY := 1
const BIRTHDAY_PLACEHOLDER := "请选择生日"
const MBTI_PLACEHOLDER := "未选择  >"
const MBTI_OPTION_ITEM_SCENE_PATH := "res://scenes/ui/story/mbti_option_item.tscn"
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
var _birth_year: int = DEFAULT_BIRTH_YEAR
var _birth_month: int = 1
var _birth_day: int = 1
var _has_birthdate_selection: bool = false
var _gender_group: ButtonGroup
var _gender_button_theme_cache: Dictionary = {}

@onready var popup_panel: PanelContainer = %PopupPanel
@onready var avatar_preview: TextureRect = %AvatarPreview
@onready var name_input: LineEdit = %NameInput
@onready var male_btn: Button = %MaleBtn
@onready var female_btn: Button = %FemaleBtn
@onready var birthday_editor: PanelContainer = %BirthdayEditor
@onready var year_spin_box: SpinBox = %YearSpinBox
@onready var month_spin_box: SpinBox = %MonthSpinBox
@onready var day_spin_box: SpinBox = %DaySpinBox
@onready var zodiac_label: Label = %ZodiacLabel
@onready var mbti_button: Button = %MBTIButton
@onready var confirm_btn: Button = %ConfirmBtn
@onready var mbti_popup: PanelContainer = %MBTIPopup
@onready var mbti_grid: GridContainer = %MBTIGrid
@onready var close_mbti_btn: Button = %CloseMBTI
@onready var mbti_grid_margin: PanelContainer = mbti_popup.get_node("Margin/VBox/MBTIGridMargin") as PanelContainer
@onready var mbti_scroll: ScrollContainer = mbti_popup.get_node("Margin/VBox/MBTIGridMargin/Scroll") as ScrollContainer

func _ready() -> void:
	_build_gender_styles()
	_init_gender_buttons()
	_init_birthday_inputs()
	_configure_mbti_popup_layout()
	_init_mbti_grid()
	_load_existing_profile()
	_bind_live_updates()
	_update_days(_birth_month)
	_update_zodiac()
	_sync_birthday_inputs()
	_update_avatar_preview()
	_update_completion_progress()
	mbti_button.pressed.connect(_show_mbti_popup)
	close_mbti_btn.pressed.connect(_hide_mbti_popup)
	confirm_btn.pressed.connect(_on_confirm_pressed)

func _bind_live_updates() -> void:
	name_input.text_changed.connect(_update_completion_progress)

func _build_gender_styles() -> void:
	_cache_gender_button_theme(male_btn)
	_cache_gender_button_theme(female_btn)

func _init_gender_buttons() -> void:
	_gender_group = ButtonGroup.new()
	_setup_gender_button(male_btn, "男")
	_setup_gender_button(female_btn, "女")
	_clear_gender_selection()

func _setup_gender_button(button: Button, gender: String) -> void:
	button.toggle_mode = true
	button.button_group = _gender_group
	button.pressed.connect(_on_gender_pressed.bind(gender))

func _cache_gender_button_theme(button: Button) -> void:
	_gender_button_theme_cache[button] = {
		"normal_style": _duplicate_stylebox(button.get_theme_stylebox("normal")),
		"hover_style": _duplicate_stylebox(button.get_theme_stylebox("hover")),
		"pressed_style": _duplicate_stylebox(button.get_theme_stylebox("pressed")),
		"font_color": button.get_theme_color("font_color"),
		"font_pressed_color": button.get_theme_color("font_pressed_color"),
		"font_hover_color": button.get_theme_color("font_hover_color"),
		"font_hover_pressed_color": button.get_theme_color("font_hover_pressed_color")
	}

func _duplicate_stylebox(stylebox: StyleBox) -> StyleBox:
	if stylebox == null:
		return null
	return stylebox.duplicate()

func _init_birthday_inputs() -> void:
	year_spin_box.min_value = 1970
	year_spin_box.max_value = 2099
	year_spin_box.step = 1
	year_spin_box.rounded = true
	year_spin_box.value_changed.connect(_on_birth_year_changed)

	month_spin_box.min_value = 1
	month_spin_box.max_value = 12
	month_spin_box.step = 1
	month_spin_box.rounded = true
	month_spin_box.value_changed.connect(_on_birth_month_changed)

	day_spin_box.min_value = 1
	day_spin_box.max_value = 31
	day_spin_box.step = 1
	day_spin_box.rounded = true
	day_spin_box.value_changed.connect(_on_birth_day_changed)

	_sync_birthday_inputs()

func _load_existing_profile() -> void:
	if not GameDataManager.profile:
		_clear_gender_selection()
		_clear_birthday_selection()
		mbti_button.text = MBTI_PLACEHOLDER
		selected_mbti = "未选择"
		return

	var profile = GameDataManager.profile
	name_input.text = str(profile.player_name).substr(0, 10)
	selected_mbti = str(profile.player_mbti).strip_edges()
	if selected_mbti == "":
		selected_mbti = "未选择"
	mbti_button.text = MBTI_PLACEHOLDER if selected_mbti == "未选择" else _build_mbti_button_text(selected_mbti)
	_refresh_mbti_button_styles()

	var gender = str(profile.player_gender).strip_edges()
	if gender != "男" and gender != "女":
		_clear_gender_selection()
	else:
		_select_gender(gender)

	var year: int = DEFAULT_BIRTH_YEAR
	var month: int = DEFAULT_BIRTH_MONTH
	var day: int = DEFAULT_BIRTH_DAY
	var birthday_text: String = str(profile.player_birthday).strip_edges()
	_has_birthdate_selection = birthday_text != ""
	if birthday_text != "":
		var iso_matcher := RegEx.new()
		iso_matcher.compile("(\\d{4})-(\\d{1,2})-(\\d{1,2})")
		var iso_result: RegExMatch = iso_matcher.search(birthday_text)
		if iso_result:
			year = clampi(int(iso_result.get_string(1)), 1970, 2099)
			month = clampi(int(iso_result.get_string(2)), 1, 12)
			day = maxi(1, int(iso_result.get_string(3)))
		else:
			var legacy_matcher := RegEx.new()
			legacy_matcher.compile("(\\d+)月(\\d+)日")
			var legacy_result: RegExMatch = legacy_matcher.search(birthday_text)
			if legacy_result:
				month = clampi(int(legacy_result.get_string(1)), 1, 12)
				day = maxi(1, int(legacy_result.get_string(2)))

	_birth_year = year
	_birth_month = month
	_birth_day = day
	_update_days(_birth_month)
	_birth_day = mini(_birth_day, _get_days_in_month(_birth_month))
	_sync_birthday_inputs()
	_update_zodiac()

func _clear_gender_selection() -> void:
	_selected_gender = DEFAULT_GENDER
	male_btn.set_pressed_no_signal(false)
	female_btn.set_pressed_no_signal(false)
	_apply_gender_button_style(male_btn)
	_apply_gender_button_style(female_btn)

func _clear_birthday_selection() -> void:
	_birth_year = DEFAULT_BIRTH_YEAR
	_birth_month = DEFAULT_BIRTH_MONTH
	_birth_day = DEFAULT_BIRTH_DAY
	_has_birthdate_selection = false
	_sync_birthday_inputs()
	_update_zodiac()

func _select_gender(gender: String) -> void:
	_selected_gender = "女" if gender == "女" else "男"
	male_btn.button_pressed = _selected_gender == "男"
	female_btn.button_pressed = _selected_gender == "女"
	_apply_gender_button_style(male_btn)
	_apply_gender_button_style(female_btn)

func _apply_gender_button_style(button: Button) -> void:
	var theme_cache: Dictionary = _gender_button_theme_cache.get(button, {})
	if theme_cache.is_empty():
		return
	var selected: bool = button.button_pressed
	var normal_style: StyleBox = theme_cache.get("pressed_style") if selected else theme_cache.get("normal_style")
	var hover_style: StyleBox = theme_cache.get("pressed_style") if selected else theme_cache.get("hover_style")
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", theme_cache.get("pressed_style"))
	button.add_theme_stylebox_override("focus", normal_style)
	button.add_theme_color_override("font_color", theme_cache.get("font_pressed_color") if selected else theme_cache.get("font_color"))
	button.add_theme_color_override("font_hover_color", theme_cache.get("font_hover_pressed_color") if selected else theme_cache.get("font_hover_color"))
	button.add_theme_color_override("font_pressed_color", theme_cache.get("font_pressed_color"))
	button.add_theme_color_override("font_hover_pressed_color", theme_cache.get("font_hover_pressed_color"))

func _on_gender_pressed(gender: String) -> void:
	_select_gender(gender)
	_update_avatar_preview()
	_update_completion_progress()

func _resolve_player_avatar_path(gender: String) -> String:
	match gender:
		"女":
			return PLAYER_AVATAR_FEMALE
		"":
			return PLAYER_AVATAR_OTHER
		_:
			return PLAYER_AVATAR_MALE

func _update_avatar_preview() -> void:
	var avatar_path = _resolve_player_avatar_path(_selected_gender)
	if ResourceLoader.exists(avatar_path):
		var texture = load(avatar_path)
		if texture is Texture2D:
			avatar_preview.texture = texture

func _update_days(month: int) -> void:
	var days_in_month: int = _get_days_in_month(month)
	_birth_day = mini(_birth_day, days_in_month)
	if day_spin_box != null:
		day_spin_box.max_value = days_in_month

func _get_days_in_month(month: int) -> int:
	if month == 2:
		return 29
	if month == 4 or month == 6 or month == 9 or month == 11:
		return 30
	return 31

func _sync_birthday_inputs() -> void:
	if year_spin_box == null or month_spin_box == null or day_spin_box == null:
		return
	year_spin_box.set_block_signals(true)
	month_spin_box.set_block_signals(true)
	day_spin_box.set_block_signals(true)
	year_spin_box.value = _birth_year
	month_spin_box.value = _birth_month
	_update_days(_birth_month)
	day_spin_box.value = _birth_day
	year_spin_box.set_block_signals(false)
	month_spin_box.set_block_signals(false)
	day_spin_box.set_block_signals(false)

func _on_birth_year_changed(value: float) -> void:
	_has_birthdate_selection = true
	_birth_year = clampi(int(round(value)), 1970, 2099)
	_sync_birthday_inputs()
	_update_zodiac()
	_update_completion_progress()

func _on_birth_month_changed(value: float) -> void:
	_has_birthdate_selection = true
	_birth_month = clampi(int(round(value)), 1, 12)
	_update_days(_birth_month)
	_sync_birthday_inputs()
	_update_zodiac()
	_update_completion_progress()

func _on_birth_day_changed(value: float) -> void:
	_has_birthdate_selection = true
	_birth_day = clampi(int(round(value)), 1, _get_days_in_month(_birth_month))
	_sync_birthday_inputs()
	_update_zodiac()
	_update_completion_progress()

func _get_formatted_birthday() -> String:
	if not _has_birthdate_selection:
		return ""
	return "%04d-%02d-%02d" % [_birth_year, _birth_month, _birth_day]

func _update_zodiac() -> void:
	if not _has_birthdate_selection:
		zodiac_label.text = BIRTHDAY_PLACEHOLDER
		return
	var month: int = _birth_month
	var day: int = _birth_day
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

	var item_scene: PackedScene = load(MBTI_OPTION_ITEM_SCENE_PATH)
	if item_scene == null:
		return

	for type_info in MBTI_TYPES:
		var mbti_id: String = str(type_info.get("id", ""))
		var mbti_name: String = str(type_info.get("name", ""))
		var mbti_desc: String = str(type_info.get("desc", ""))
		var item: Node = item_scene.instantiate()
		mbti_grid.add_child(item)
		if item.has_method("setup_item"):
			item.call("setup_item", mbti_id, mbti_name, mbti_desc)
		if item.has_signal("selected"):
			item.connect("selected", Callable(self, "_on_mbti_selected"))
	_refresh_mbti_button_styles()

func _configure_mbti_popup_layout() -> void:
	mbti_popup.clip_contents = true
	mbti_popup.hide()
	mbti_grid_margin.clip_contents = true
	mbti_grid_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mbti_grid_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mbti_scroll.clip_contents = true
	mbti_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mbti_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mbti_scroll.scroll_horizontal = 0
	mbti_scroll.scroll_vertical = 0
	mbti_grid.clip_contents = true
	mbti_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _refresh_mbti_button_styles() -> void:
	for child in mbti_grid.get_children():
		if not child.has_method("get_mbti_id") or not child.has_method("set_selected_state"):
			continue
		var item_mbti_id: String = str(child.call("get_mbti_id"))
		var is_selected: bool = selected_mbti != "未选择" and item_mbti_id == selected_mbti
		child.call("set_selected_state", is_selected)

func _show_mbti_popup() -> void:
	_refresh_mbti_button_styles()
	mbti_scroll.scroll_horizontal = 0
	mbti_scroll.scroll_vertical = 0
	mbti_popup.show()

func _hide_mbti_popup() -> void:
	mbti_scroll.scroll_horizontal = 0
	mbti_scroll.scroll_vertical = 0
	mbti_popup.hide()

func _on_mbti_selected(mbti_id: String, mbti_name: String) -> void:
	selected_mbti = mbti_id
	mbti_button.text = _build_mbti_button_text(mbti_id)
	_refresh_mbti_button_styles()
	_update_completion_progress()
	_hide_mbti_popup()

func _build_mbti_button_text(mbti_id: String) -> String:
	for type_info in MBTI_TYPES:
		var current_id = str(type_info.get("id", ""))
		if current_id == mbti_id:
			return "%s - %s  >" % [mbti_id, str(type_info.get("name", ""))]
	return "%s  >" % mbti_id

func _update_completion_progress(_changed_text: String = "") -> void:
	var name_text: String = name_input.text.strip_edges()
	var has_name: bool = not name_text.is_empty()
	var has_gender: bool = _selected_gender == "男" or _selected_gender == "女"
	var has_birthday: bool = _has_birthdate_selection and not _get_formatted_birthday().is_empty()
	var has_mbti: bool = selected_mbti != "" and selected_mbti != "未选择"
	confirm_btn.disabled = not (has_name and has_gender and has_birthday and has_mbti)

func _on_confirm_pressed() -> void:
	if confirm_btn.disabled:
		return
	var name_text = name_input.text.strip_edges().substr(0, 10)
	if name_text.is_empty():
		name_input.grab_focus()
		return

	var gender_text = _selected_gender
	var birthday_text = _get_formatted_birthday()
	var avatar_path = _resolve_player_avatar_path(gender_text)

	player_info = {
		"name": name_text,
		"gender": gender_text,
		"birthday": birthday_text,
		"zodiac": zodiac_label.text,
		"mbti": selected_mbti,
		"profession": "创奇引路人",
		"avatar_path": avatar_path
	}

	if GameDataManager.memory_manager:
		var core_mem1 = "玩家的真实姓名是：%s" % name_text
		var core_mem2 = "玩家的生理性别是：%s，生日是：%s（%s），MBTI人格类型为：%s" % [gender_text, birthday_text, zodiac_label.text, selected_mbti]
		GameDataManager.memory_manager.add_memory("core", core_mem1)
		GameDataManager.memory_manager.add_memory("core", core_mem2)

	info_submitted.emit()
