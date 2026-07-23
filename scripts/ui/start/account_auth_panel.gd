extends Control

signal authenticated
signal closed
signal local_mode_requested

const LOCAL_MODE_CLICK_THRESHOLD := 7

@onready var login_tab: Button = %LoginTab
@onready var register_tab: Button = %RegisterTab
@onready var reset_tab: Button = %ResetTab
@onready var email_input: LineEdit = %EmailInput
@onready var username_input: LineEdit = %UsernameInput
@onready var password_input: LineEdit = %PasswordInput
@onready var confirm_password_input: LineEdit = %ConfirmPasswordInput
@onready var code_row: HBoxContainer = %CodeRow
@onready var code_input: LineEdit = %CodeInput
@onready var send_code_button: Button = %SendCodeButton
@onready var submit_button: Button = %SubmitButton
@onready var status_label: Label = %StatusLabel
@onready var close_button: Button = %CloseButton
@onready var version_button: Button = %VersionButton

enum AuthMode { LOGIN, REGISTER, RESET }

var _mode := AuthMode.LOGIN
var _code_cooldown_remaining := 0
var _code_cooldown_timer: Timer
var _version_click_count := 0

func _ready() -> void:
	login_tab.pressed.connect(func() -> void: _set_mode(AuthMode.LOGIN))
	register_tab.pressed.connect(func() -> void: _set_mode(AuthMode.REGISTER))
	reset_tab.pressed.connect(func() -> void: _set_mode(AuthMode.RESET))
	send_code_button.pressed.connect(_on_send_code_pressed)
	submit_button.pressed.connect(_on_submit_pressed)
	close_button.pressed.connect(_close)
	version_button.pressed.connect(_on_version_pressed)
	email_input.text_submitted.connect(func(_text: String) -> void: _on_submit_pressed())
	password_input.text_submitted.connect(func(_text: String) -> void: _on_submit_pressed())
	confirm_password_input.text_submitted.connect(func(_text: String) -> void: _on_submit_pressed())
	code_input.text_submitted.connect(func(_text: String) -> void: _on_submit_pressed())
	OfficialAuthManager.auth_state_changed.connect(_on_auth_state_changed)
	OfficialAuthManager.email_code_sent.connect(_on_email_code_sent)
	OfficialAuthManager.password_reset_completed.connect(_on_password_reset_completed)
	_code_cooldown_timer = Timer.new()
	_code_cooldown_timer.wait_time = 1.0
	_code_cooldown_timer.timeout.connect(_on_code_cooldown_tick)
	add_child(_code_cooldown_timer)
	_set_mode(AuthMode.LOGIN)
	username_input.grab_focus()

func _on_version_pressed() -> void:
	_version_click_count += 1
	if _version_click_count < LOCAL_MODE_CLICK_THRESHOLD:
		return
	version_button.disabled = true
	local_mode_requested.emit()

func show_register() -> void:
	_set_mode(AuthMode.REGISTER)

func _set_mode(mode: AuthMode) -> void:
	_mode = mode
	var needs_code := mode != AuthMode.LOGIN
	code_row.visible = needs_code
	username_input.visible = mode != AuthMode.RESET
	email_input.visible = mode != AuthMode.LOGIN
	confirm_password_input.visible = needs_code
	username_input.placeholder_text = "用户名" if mode == AuthMode.LOGIN else "用户名（3-24 位字母、数字或下划线）"
	email_input.placeholder_text = "邮箱地址"
	password_input.placeholder_text = "新密码（至少 8 位）" if mode == AuthMode.RESET else "密码（至少 8 位）"
	confirm_password_input.placeholder_text = "再次输入新密码" if mode == AuthMode.RESET else "再次输入密码"
	login_tab.button_pressed = mode == AuthMode.LOGIN
	register_tab.button_pressed = mode == AuthMode.REGISTER
	reset_tab.button_pressed = mode == AuthMode.RESET
	match mode:
		AuthMode.REGISTER:
			submit_button.text = "创建账号"
			status_label.text = "验证码将发送到你的邮箱"
		AuthMode.RESET:
			submit_button.text = "重置密码"
			status_label.text = "验证邮箱后设置新密码"
		_:
			submit_button.text = "登录"
			status_label.text = "使用用户名和密码继续"

func _on_send_code_pressed() -> void:
	var email := email_input.text.strip_edges()
	if not email.contains("@"):
		_show_error("请输入有效邮箱")
		return
	send_code_button.disabled = true
	status_label.text = "正在发送验证码..."
	if _mode == AuthMode.RESET:
		OfficialAuthManager.send_password_reset_code(email)
	else:
		OfficialAuthManager.send_email_code(email)

func _on_submit_pressed() -> void:
	var username := username_input.text.strip_edges()
	var email := email_input.text.strip_edges()
	var password := password_input.text
	if password.length() < 8:
		_show_error("密码至少需要 8 位")
		return
	if _mode != AuthMode.LOGIN:
		if not email.contains("@"):
			_show_error("请输入有效邮箱")
			return
		if password != confirm_password_input.text:
			_show_error("两次输入的密码不一致")
			return
		var code := code_input.text.strip_edges()
		if code.length() != 6 or not code.is_valid_int():
			_show_error("请输入 6 位数字验证码")
			return
		if _mode == AuthMode.REGISTER:
			if username.length() < 3:
				_show_error("用户名至少需要 3 位")
				return
			OfficialAuthManager.register_with_email(username, email, password, code)
		else:
			OfficialAuthManager.reset_password(email, password, code)
	else:
		if username.length() < 3:
			_show_error("请输入用户名")
			return
		OfficialAuthManager.login_with_email(username, password)
	submit_button.disabled = true
	status_label.text = "正在验证账号..."

func _on_email_code_sent(success: bool, message: String) -> void:
	if success:
		_code_cooldown_remaining = OfficialAuthManager.EMAIL_CODE_COOLDOWN_SECONDS
		_code_cooldown_timer.start()
		_update_code_button()
	else:
		send_code_button.disabled = false
	status_label.text = message
	status_label.modulate = Color("4f6864") if success else Color("b64f55")

func _on_code_cooldown_tick() -> void:
	_code_cooldown_remaining -= 1
	if _code_cooldown_remaining <= 0:
		_code_cooldown_timer.stop()
	_update_code_button()

func _update_code_button() -> void:
	send_code_button.disabled = _code_cooldown_remaining > 0
	send_code_button.text = "%d 秒后重发" % _code_cooldown_remaining if _code_cooldown_remaining > 0 else "发送验证码"

func _on_auth_state_changed(success: bool, message: String) -> void:
	submit_button.disabled = false
	status_label.text = "登录成功" if success else message
	status_label.modulate = Color("2f776a") if success else Color("b64f55")
	if success:
		authenticated.emit()
		await get_tree().create_timer(0.35).timeout
		_close()

func _on_password_reset_completed(success: bool, message: String) -> void:
	submit_button.disabled = false
	status_label.text = message
	status_label.modulate = Color("2f776a") if success else Color("b64f55")
	if success:
		password_input.clear()
		confirm_password_input.clear()
		code_input.clear()
		_set_mode(AuthMode.LOGIN)

func _show_error(message: String) -> void:
	status_label.text = message
	status_label.modulate = Color("b64f55")

func _close() -> void:
	closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
