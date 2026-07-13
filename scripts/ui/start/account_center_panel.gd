extends Control

signal closed
signal logged_out
signal legacy_import_requested

@onready var username_label: Label = %UsernameLabel
@onready var email_label: Label = %EmailLabel
@onready var created_label: Label = %CreatedLabel
@onready var ai_mode_label: Label = %AiModeLabel
@onready var quota_label: Label = %QuotaLabel
@onready var close_button: Button = %CloseButton
@onready var import_button: Button = %ImportButton
@onready var logout_button: Button = %LogoutButton
@onready var logout_all_button: Button = %LogoutAllButton

func _ready() -> void:
	close_button.pressed.connect(_close)
	import_button.pressed.connect(func() -> void: legacy_import_requested.emit())
	logout_button.pressed.connect(_logout)
	logout_all_button.pressed.connect(_logout_all)
	OfficialAuthManager.profile_updated.connect(_apply_profile)
	_apply_profile(OfficialAuthManager.get_profile())
	_update_legacy_import_button()
	OfficialAuthManager.refresh_profile()

func _apply_profile(profile: Dictionary) -> void:
	username_label.text = str(profile.get("username", "正在读取账号资料..."))
	email_label.text = str(profile.get("masked_email", ""))
	var created_at := str(profile.get("created_at", ""))
	created_label.text = "注册于 %s" % created_at.substr(0, 10) if not created_at.is_empty() else ""
	var mode := GameDataManager.config.ai_service_mode if GameDataManager.config else "official"
	ai_mode_label.text = "官方托管" if mode == ConfigResource.AI_SERVICE_OFFICIAL else "个人 API"
	var quota = profile.get("quota", {})
	if quota is Dictionary and not quota.is_empty():
		quota_label.text = "%d / %d" % [int(quota.get("remaining", 0)), int(quota.get("limit", 0))]
	else:
		quota_label.text = "读取中"

func _update_legacy_import_button() -> void:
	var legacy_count := 0
	if GameDataManager.save_manager:
		legacy_count = GameDataManager.save_manager.get_legacy_archive_slot_ids().size()
	import_button.disabled = legacy_count <= 0
	import_button.text = "重新检查旧存档（%d）" % legacy_count if legacy_count > 0 else "没有可导入的旧存档"

func _logout() -> void:
	OfficialAuthManager.logout()
	logged_out.emit()
	_close()

func _logout_all() -> void:
	OfficialAuthManager.logout_all()
	logged_out.emit()
	_close()

func _close() -> void:
	closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
