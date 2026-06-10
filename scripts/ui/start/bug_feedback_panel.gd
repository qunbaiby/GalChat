extends Control

@onready var title_input: LineEdit = $CenterContainer/PanelRoot/MainMargin/ContentVBox/BodyScroll/BodyVBox/FormCard/FormMargin/FormVBox/BasicGrid/TitleVBox/TitleInput
@onready var category_option: OptionButton = $CenterContainer/PanelRoot/MainMargin/ContentVBox/BodyScroll/BodyVBox/FormCard/FormMargin/FormVBox/BasicGrid/CategoryVBox/CategoryOption
@onready var steps_edit: TextEdit = $CenterContainer/PanelRoot/MainMargin/ContentVBox/BodyScroll/BodyVBox/FormCard/FormMargin/FormVBox/StepsEdit
@onready var expected_edit: TextEdit = $CenterContainer/PanelRoot/MainMargin/ContentVBox/BodyScroll/BodyVBox/FormCard/FormMargin/FormVBox/ResultVBox/ExpectedVBox/ExpectedEdit
@onready var actual_edit: TextEdit = $CenterContainer/PanelRoot/MainMargin/ContentVBox/BodyScroll/BodyVBox/FormCard/FormMargin/FormVBox/ResultVBox/ActualVBox/ActualEdit
@onready var contact_input: LineEdit = $CenterContainer/PanelRoot/MainMargin/ContentVBox/BodyScroll/BodyVBox/FormCard/FormMargin/FormVBox/ContactInput
@onready var env_info_label: RichTextLabel = $CenterContainer/PanelRoot/MainMargin/ContentVBox/BodyScroll/BodyVBox/InfoCard/InfoMargin/InfoVBox/EnvInfoLabel
@onready var status_label: Label = $CenterContainer/PanelRoot/MainMargin/ContentVBox/BodyScroll/BodyVBox/BottomBar/StatusLabel
@onready var copy_env_button: Button = $CenterContainer/PanelRoot/MainMargin/ContentVBox/BodyScroll/BodyVBox/BottomBar/Actions/CopyEnvButton
@onready var copy_feedback_button: Button = $CenterContainer/PanelRoot/MainMargin/ContentVBox/BodyScroll/BodyVBox/BottomBar/Actions/CopyFeedbackButton
@onready var close_button: Button = $CenterContainer/PanelRoot/MainMargin/ContentVBox/TopBar/CloseButton

const CATEGORY_ITEMS := [
	"界面显示",
	"剧情流程",
	"存档/读档",
	"音频表现",
	"性能卡顿",
	"其他问题"
]

func _ready() -> void:
	_setup_options()
	_fill_runtime_info()
	copy_env_button.pressed.connect(_on_copy_env_pressed)
	copy_feedback_button.pressed.connect(_on_copy_feedback_pressed)
	close_button.pressed.connect(hide_panel)
	visible = false


func show_panel() -> void:
	_fill_runtime_info()
	visible = true
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.18)
	call_deferred("_focus_title_input")


func hide_panel() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.16)
	tween.tween_callback(func() -> void:
		visible = false
	)


func _focus_title_input() -> void:
	if title_input:
		title_input.grab_focus()


func _setup_options() -> void:
	category_option.clear()
	for item in CATEGORY_ITEMS:
		category_option.add_item(item)


func _fill_runtime_info() -> void:
	var version_info: Dictionary = Engine.get_version_info()
	var version_text := "%s.%s.%s" % [
		version_info.get("major", 0),
		version_info.get("minor", 0),
		version_info.get("patch", 0)
	]
	var size: Vector2i = get_viewport().get_visible_rect().size
	var current_scene := ""
	if get_tree().current_scene:
		current_scene = str(get_tree().current_scene.scene_file_path)
	if current_scene == "":
		current_scene = "未进入具体场景"

	var lines := [
		"[b]版本信息[/b]",
		"客户端版本：开发中版本",
		"引擎版本：Godot %s" % version_text,
		"平台：%s" % OS.get_name(),
		"显示尺寸：%d x %d" % [size.x, size.y],
		"当前场景：%s" % current_scene,
		"",
		"[b]填写建议[/b]",
		"1. 标题描述核心问题，例如“设置页关闭按钮与标题重叠”。",
		"2. 复现步骤尽量按操作顺序填写。",
		"3. 期望结果与实际结果分开写，方便快速定位。"
	]
	env_info_label.text = "\n".join(lines)
	status_label.text = "建议先填写标题和复现步骤，再复制反馈内容。"


func _build_feedback_text() -> String:
	var lines := [
		"# GalChat BUG 反馈",
		"",
		"标题：%s" % _safe_value(title_input.text, "未填写"),
		"问题分类：%s" % category_option.get_item_text(category_option.selected),
		"联系方式：%s" % _safe_value(contact_input.text, "未填写"),
		"",
		"## 复现步骤",
		_safe_multiline(steps_edit.text),
		"",
		"## 期望结果",
		_safe_multiline(expected_edit.text),
		"",
		"## 实际结果",
		_safe_multiline(actual_edit.text),
		"",
		"## 运行信息",
		env_info_label.get_parsed_text()
	]
	return "\n".join(lines)


func _safe_value(value: String, fallback: String) -> String:
	var trimmed := value.strip_edges()
	return trimmed if trimmed != "" else fallback


func _safe_multiline(value: String) -> String:
	var trimmed := value.strip_edges()
	return trimmed if trimmed != "" else "未填写"


func _on_copy_env_pressed() -> void:
	DisplayServer.clipboard_set(env_info_label.get_parsed_text())
	status_label.text = "已复制运行信息，可直接附在反馈里。"
	_show_toast("已复制运行信息")


func _on_copy_feedback_pressed() -> void:
	DisplayServer.clipboard_set(_build_feedback_text())
	status_label.text = "已复制完整反馈模板，现在可以直接粘贴给开发者。"
	_show_toast("已复制 BUG 反馈内容")


func _show_toast(message: String) -> void:
	if get_tree().root.has_node("ToastManager"):
		ToastManager.show_system_toast(message, Color(0.57, 0.82, 0.76, 1))
