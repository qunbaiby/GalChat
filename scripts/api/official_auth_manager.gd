extends Node

signal auth_state_changed(is_authenticated: bool, message: String)
signal quota_updated(remaining: int, limit: int)
signal email_code_sent(success: bool, message: String)
signal password_reset_completed(success: bool, message: String)
signal session_state_changed(state: int, message: String)
signal profile_updated(profile: Dictionary)
signal access_token_ready(success: bool, message: String)

const CREDENTIALS_PATH := "user://official_ai_credentials.json"
const REFRESH_MARGIN_SECONDS := 60
const EMAIL_CODE_COOLDOWN_SECONDS := 60

enum SessionState { RESTORING, SIGNED_OUT, SIGNED_IN }

var _http: HTTPRequest
var _credentials: Dictionary = {}
var _access_expires_at: int = 0
var _request_kind: String = ""
var _session_state: SessionState = SessionState.RESTORING
var _profile: Dictionary = {}
var _refresh_in_progress: bool = false

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 20.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	_credentials = _load_or_create_credentials()
	if str(_credentials.get("refresh_token", "")).is_empty():
		_set_session_state(SessionState.SIGNED_OUT, "登录后开始陪伴")
	else:
		_set_session_state(SessionState.RESTORING, "正在验证账号...")
	call_deferred("restore_session")

func restore_session() -> void:
	if not _is_gateway_url_valid():
		_clear_stored_session("服务地址无效，请检查设置")
		return
	if _has_valid_access_token():
		auth_state_changed.emit(true, "已连接官方 AI 服务")
		refresh_quota()
		return
	var refresh_token: String = str(_credentials.get("refresh_token", ""))
	if not refresh_token.is_empty() and not _refresh_in_progress:
		_refresh_in_progress = true
		_send_auth_request("refresh", "/v1/auth/refresh", {"refresh_token": refresh_token})

func ensure_authenticated() -> void:
	restore_session()

func ensure_valid_access_token() -> bool:
	if _has_valid_access_token():
		return true
	if str(_credentials.get("refresh_token", "")).is_empty():
		return false
	if _refresh_in_progress:
		var pending_result: Array = await access_token_ready
		return bool(pending_result[0])
	_refresh_in_progress = true
	_set_session_state(SessionState.RESTORING, "正在刷新登录状态...")
	_send_auth_request("refresh", "/v1/auth/refresh", {"refresh_token": str(_credentials.get("refresh_token", ""))})
	var refresh_result: Array = await access_token_ready
	return bool(refresh_result[0])

func force_refresh_access_token() -> bool:
	GameDataManager.config.clear_official_access_token()
	_access_expires_at = 0
	return await ensure_valid_access_token()

func is_authenticated() -> bool:
	return _has_valid_access_token()

func get_session_state() -> SessionState:
	return _session_state

func get_profile() -> Dictionary:
	return _profile.duplicate(true)

func get_user_id() -> String:
	return str(_credentials.get("user_id", "")).strip_edges()

func send_email_code(email: String) -> void:
	_send_auth_request("email_code", "/v1/auth/email/code", {"email": email.strip_edges().to_lower()})

func register_with_email(username: String, email: String, password: String, verification_code: String) -> void:
	_send_auth_request("email_register", "/v1/auth/email/register", {
		"username": username.strip_edges().to_lower(),
		"email": email.strip_edges().to_lower(),
		"password": password,
		"verification_code": verification_code.strip_edges()
	})

func login_with_email(identity: String, password: String) -> void:
	_send_auth_request("email_login", "/v1/auth/email/login", {
		"identity": identity.strip_edges().to_lower(),
		"password": password
	})

func send_password_reset_code(email: String) -> void:
	_send_auth_request("password_reset_code", "/v1/auth/password/reset/code", {
		"email": email.strip_edges().to_lower()
	})

func reset_password(email: String, password: String, verification_code: String) -> void:
	_send_auth_request("password_reset", "/v1/auth/password/reset", {
		"email": email.strip_edges().to_lower(),
		"new_password": password,
		"verification_code": verification_code.strip_edges()
	})

func refresh_quota() -> void:
	refresh_profile()

func refresh_profile() -> void:
	if not _has_valid_access_token() or _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	_request_kind = "profile"
	_http.request(
		_gateway_url("/v1/account/profile"),
		["Authorization: Bearer " + GameDataManager.config.official_access_token],
		HTTPClient.METHOD_GET
	)

func logout() -> void:
	if _has_valid_access_token() and _http.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		_request_kind = "logout"
		_http.request(
			_gateway_url("/v1/auth/logout"),
			["Authorization: Bearer " + GameDataManager.config.official_access_token],
			HTTPClient.METHOD_POST
		)
	_credentials.erase("refresh_token")
	_credentials.erase("user_id")
	_save_credentials()
	_clear_access_token("已退出账号")

func logout_all() -> void:
	if _has_valid_access_token() and _http.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		_request_kind = "logout_all"
		_http.request(
			_gateway_url("/v1/auth/logout-all"),
			["Authorization: Bearer " + GameDataManager.config.official_access_token],
			HTTPClient.METHOD_POST
		)
	_credentials.erase("refresh_token")
	_credentials.erase("user_id")
	_save_credentials()
	_clear_access_token("已退出所有设备")

func _send_auth_request(kind: String, path: String, payload: Dictionary) -> void:
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		if kind == "refresh":
			_finish_access_token_refresh(false, "认证服务正在处理其他请求，请稍后重试")
		return
	_request_kind = kind
	var error := _http.request(
		_gateway_url(path),
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if error != OK:
		_request_kind = ""
		if kind == "refresh":
			_clear_stored_session("无法验证账号，请重新登录")
			_finish_access_token_refresh(false, "无法验证账号，请重新登录")
		auth_state_changed.emit(false, "无法发起连接：%s" % error_string(error))

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var kind := _request_kind
	_request_kind = ""
	var response_text := body.get_string_from_utf8().strip_edges()
	var data: Variant = null
	if not response_text.is_empty():
		var json := JSON.new()
		if json.parse(response_text) == OK:
			data = json.data
	if kind == "profile":
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200 and data is Dictionary:
			_profile = data
			profile_updated.emit(_profile.duplicate(true))
			var quota = data.get("quota", {})
			if quota is Dictionary:
				quota_updated.emit(int(quota.get("remaining", 0)), int(quota.get("limit", 0)))
		elif result != HTTPRequest.RESULT_SUCCESS:
			auth_state_changed.emit(false, _network_error_message(result))
		elif response_code == 401:
			_clear_stored_session("登录已过期，请重新登录")
		return
	if kind == "logout" or kind == "logout_all":
		return
	if kind == "email_code" or kind == "password_reset_code":
		var code_sent := result == HTTPRequest.RESULT_SUCCESS and response_code == 204
		email_code_sent.emit(code_sent, "验证码已发送" if code_sent else "验证码发送失败%s" % _response_error_detail(data))
		return
	if kind == "password_reset":
		var reset_success := result == HTTPRequest.RESULT_SUCCESS and response_code == 204
		var reset_message := "密码已重置，请使用新密码登录" if reset_success else "密码重置失败%s" % _response_error_detail(data)
		password_reset_completed.emit(reset_success, reset_message)
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		if kind == "refresh":
			_finish_access_token_refresh(false, _network_error_message(result))
		auth_state_changed.emit(false, _network_error_message(result))
		return
	if response_code == 200 or response_code == 201:
		_apply_token_response(data, kind)
		return
	if kind == "refresh":
		_clear_stored_session("登录已过期，请重新登录")
		_finish_access_token_refresh(false, "登录已过期，请重新登录")
		return
	var detail := _response_error_detail(data)
	auth_state_changed.emit(false, "官方 AI 服务认证失败（%d）%s" % [response_code, detail])

func _apply_token_response(data: Variant, request_kind: String) -> void:
	if not (data is Dictionary):
		if request_kind == "refresh":
			_finish_access_token_refresh(false, "官方 AI 服务返回无效")
		auth_state_changed.emit(false, "官方 AI 服务返回无效")
		return
	var access_token: String = str(data.get("access_token", ""))
	var refresh_token: String = str(data.get("refresh_token", ""))
	var user_id: String = str(data.get("user_id", "")).strip_edges()
	if access_token.is_empty() or refresh_token.is_empty() or user_id.is_empty():
		if request_kind == "refresh":
			_finish_access_token_refresh(false, "官方 AI 服务凭证缺失")
		auth_state_changed.emit(false, "官方 AI 服务凭证缺失")
		return
	GameDataManager.config.set_official_access_token(access_token)
	_access_expires_at = int(Time.get_unix_time_from_system()) + int(data.get("expires_in", 900))
	_credentials["refresh_token"] = refresh_token
	_credentials["user_id"] = user_id
	_save_credentials()
	_set_session_state(SessionState.SIGNED_IN, "账号已连接")
	auth_state_changed.emit(true, "已连接官方 AI 服务")
	if request_kind == "refresh":
		_finish_access_token_refresh(true, "登录状态已刷新")
	refresh_quota()

func _finish_access_token_refresh(success: bool, message: String) -> void:
	if not _refresh_in_progress:
		return
	_refresh_in_progress = false
	access_token_ready.emit(success, message)

func _has_valid_access_token() -> bool:
	return not GameDataManager.config.official_access_token.is_empty() and int(Time.get_unix_time_from_system()) < _access_expires_at - REFRESH_MARGIN_SECONDS

func _gateway_url(path: String) -> String:
	return GameDataManager.config.official_ai_gateway_url.trim_suffix("/").trim_suffix("/v1/game") + path

func _is_gateway_url_valid() -> bool:
	var gateway_url: String = GameDataManager.config.official_ai_gateway_url.strip_edges()
	return gateway_url.begins_with("http://") or gateway_url.begins_with("https://")

func _network_error_message(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "无法解析官方服务域名，请检查服务地址"
		HTTPRequest.RESULT_CANT_CONNECT:
			return "无法连接官方服务，请确认网关已启动"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "官方服务连接中断"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "官方服务 HTTPS 证书校验失败"
		HTTPRequest.RESULT_TIMEOUT:
			return "连接官方服务超时"
		_:
			return "官方服务网络异常（%d）" % result

func _response_error_detail(data: Variant) -> String:
	if data is Dictionary:
		var detail: String = str(data.get("detail", "")).strip_edges()
		if not detail.is_empty():
			match detail:
				"Please wait before requesting another verification code.":
					return "：请求过于频繁，请稍后再试"
				"Too many failed login attempts. Please retry later.":
					return "：登录失败次数过多，请稍后再试"
				"Invalid email or password.":
					return "：用户名、邮箱或密码不正确"
				"Verification code is invalid or expired.":
					return "：验证码无效、已过期或尝试次数过多"
				"Email is already registered.":
					return "：邮箱或用户名已被注册"
				"Verification email could not be sent.":
					return "：邮件发送失败，请稍后重试"
				_:
					return "：请求未能完成"
	return ""

func _load_or_create_credentials() -> Dictionary:
	if FileAccess.file_exists(CREDENTIALS_PATH):
		var file := FileAccess.open(CREDENTIALS_PATH, FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text()) if file else null
		if parsed is Dictionary:
			return parsed
	var credentials := {}
	_credentials = credentials
	_save_credentials()
	return credentials

func _save_credentials() -> void:
	var file := FileAccess.open(CREDENTIALS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_credentials))

func _clear_access_token(message: String) -> void:
	GameDataManager.config.clear_official_access_token()
	_access_expires_at = 0
	_profile.clear()
	_set_session_state(SessionState.SIGNED_OUT, message)
	auth_state_changed.emit(false, message)

func _clear_stored_session(message: String) -> void:
	_credentials.erase("refresh_token")
	_credentials.erase("user_id")
	_save_credentials()
	_clear_access_token(message)

func _set_session_state(state: SessionState, message: String) -> void:
	_session_state = state
	session_state_changed.emit(state, message)
