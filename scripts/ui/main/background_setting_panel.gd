extends Control

signal back_requested
signal apply_requested(bg_id: String)

const ITEM_SCENE = preload("res://scenes/ui/main/background_setting_item.tscn")
const ITEM_BASE_SIZE := Vector2(369, 228)

@onready var title_label: Label = $PanelRoot/MainMargin/MainVBox/HeaderHBox/TitleLabel
@onready var left_button: Button = $PanelRoot/MainMargin/MainVBox/CarouselHBox/LeftButton
@onready var right_button: Button = $PanelRoot/MainMargin/MainVBox/CarouselHBox/RightButton
@onready var left_slot: Control = $PanelRoot/MainMargin/MainVBox/CarouselHBox/CardRow/LeftSlot
@onready var center_slot: Control = $PanelRoot/MainMargin/MainVBox/CarouselHBox/CardRow/CenterSlot
@onready var right_slot: Control = $PanelRoot/MainMargin/MainVBox/CarouselHBox/CardRow/RightSlot
@onready var description_panel: PanelContainer = $PanelRoot/MainMargin/MainVBox/DescriptionPanel
@onready var description_label: Label = $PanelRoot/MainMargin/MainVBox/DescriptionPanel/DescriptionMargin/DescriptionLabel
@onready var apply_button: Button = $PanelRoot/MainMargin/MainVBox/BottomHBox/ApplyButton
@onready var back_button: Button = $PanelRoot/MainMargin/MainVBox/HeaderHBox/BackButton
@onready var dimmer: ColorRect = $Dimmer

var _entries: Array = []
var _active_bg_id: String = ""
var _current_index: int = 0
var _carousel_tween: Tween = null
var _panel_tween: Tween = null
var _is_animating: bool = false

func _ready() -> void:
	visible = false
	left_button.pressed.connect(_show_prev)
	right_button.pressed.connect(_show_next)
	back_button.pressed.connect(hide_panel)
	apply_button.pressed.connect(_emit_apply)
	dimmer.gui_input.connect(_on_dimmer_gui_input)
	title_label.text = "主页背景设定"

func show_panel(entries: Array, active_bg_id: String) -> void:
	_entries = []
	for entry in entries:
		if entry is Dictionary:
			_entries.append(entry.duplicate(true))
	_active_bg_id = active_bg_id
	_current_index = 0
	for i in range(_entries.size()):
		if str(_entries[i].get("id", "")) == _active_bg_id:
			_current_index = i
			break

	_refresh_view()
	visible = true
	modulate.a = 0.0
	if _panel_tween:
		_panel_tween.kill()
	_panel_tween = create_tween()
	_panel_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_panel_tween.tween_property(self, "modulate:a", 1.0, 0.24)

func hide_panel() -> void:
	if not visible:
		return
	if _panel_tween:
		_panel_tween.kill()
	_panel_tween = create_tween()
	_panel_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_panel_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	_panel_tween.tween_callback(func():
		visible = false
		back_requested.emit()
	)

func set_active_bg_id(bg_id: String) -> void:
	_active_bg_id = bg_id
	_refresh_view()

func _show_prev() -> void:
	if _entries.size() <= 1 or _is_animating:
		return
	_animate_to_index(posmod(_current_index - 1, _entries.size()), -1)

func _show_next() -> void:
	if _entries.size() <= 1 or _is_animating:
		return
	_animate_to_index(posmod(_current_index + 1, _entries.size()), 1)

func _emit_apply() -> void:
	if _entries.is_empty() or _is_animating:
		return
	var entry: Dictionary = _entries[_current_index]
	var is_current_active := str(entry.get("id", "")) == _active_bg_id
	var is_current_unlocked := bool(entry.get("unlocked", true))
	if is_current_active or not is_current_unlocked:
		return
	apply_requested.emit(str(entry.get("id", "")))

func _refresh_view() -> void:
	_clear_slot(left_slot)
	_clear_slot(center_slot)
	_clear_slot(right_slot)

	if _entries.is_empty():
		description_label.text = "暂无已解锁的大厅背景。"
		apply_button.disabled = true
		left_button.disabled = true
		right_button.disabled = true
		return

	var current_entry: Dictionary = _entries[_current_index]
	var prev_entry: Dictionary = _entries[posmod(_current_index - 1, _entries.size())]
	var next_entry: Dictionary = _entries[posmod(_current_index + 1, _entries.size())]

	_add_item_to_slot(left_slot, prev_entry, false, str(prev_entry.get("id", "")) == _active_bg_id, bool(prev_entry.get("unlocked", true)), posmod(_current_index - 1, _entries.size()))
	_add_item_to_slot(center_slot, current_entry, true, str(current_entry.get("id", "")) == _active_bg_id, bool(current_entry.get("unlocked", true)), _current_index)
	_add_item_to_slot(right_slot, next_entry, false, str(next_entry.get("id", "")) == _active_bg_id, bool(next_entry.get("unlocked", true)), posmod(_current_index + 1, _entries.size()))

	description_label.text = str(current_entry.get("description", ""))
	_update_button_states()

func _add_item_to_slot(slot: Control, entry: Dictionary, is_selected: bool, is_active: bool, is_unlocked: bool, target_index: int) -> void:
	if _entries.size() == 1 and not is_selected:
		return
	var item := _build_item(slot, entry, is_selected, is_active, is_unlocked, target_index)
	var target_transform: Dictionary = _get_slot_item_transform(slot)
	item.position = target_transform["position"]
	item.scale = target_transform["scale"]
	item.modulate.a = 1.0

func _build_item(slot: Control, entry: Dictionary, is_selected: bool, is_active: bool, is_unlocked: bool, target_index: int) -> Button:
	var item := ITEM_SCENE.instantiate() as Button
	slot.add_child(item)
	item.layout_mode = 0
	item.anchor_left = 0.0
	item.anchor_top = 0.0
	item.anchor_right = 0.0
	item.anchor_bottom = 0.0
	if item.has_method("setup"):
		item.setup(entry, is_selected, is_active, is_unlocked)
	item.pressed.connect(func():
		if _is_animating:
			return
		if target_index == _current_index:
			return
		var direction := 1 if target_index > _current_index else -1
		if _entries.size() > 2:
			if _current_index == 0 and target_index == _entries.size() - 1:
				direction = -1
			elif _current_index == _entries.size() - 1 and target_index == 0:
				direction = 1
		_animate_to_index(target_index, direction)
	)
	return item

func _clear_slot(slot: Control) -> void:
	for child in slot.get_children():
		child.queue_free()

func _on_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide_panel()

func _animate_to_index(new_index: int, direction: int) -> void:
	if _is_animating or _entries.is_empty() or new_index == _current_index:
		return

	_is_animating = true
	_update_button_states()
	if _carousel_tween:
		_carousel_tween.kill()

	var old_left := _get_first_slot_item(left_slot)
	var old_center := _get_first_slot_item(center_slot)
	var old_right := _get_first_slot_item(right_slot)

	_current_index = new_index
	var current_entry: Dictionary = _entries[_current_index]
	var prev_entry: Dictionary = _entries[posmod(_current_index - 1, _entries.size())]
	var next_entry: Dictionary = _entries[posmod(_current_index + 1, _entries.size())]

	var incoming_left: Button = null
	var incoming_center: Button = null
	var incoming_right: Button = null

	if not (_entries.size() == 1):
		incoming_left = _build_item(left_slot, prev_entry, false, str(prev_entry.get("id", "")) == _active_bg_id, bool(prev_entry.get("unlocked", true)), posmod(_current_index - 1, _entries.size()))
		incoming_right = _build_item(right_slot, next_entry, false, str(next_entry.get("id", "")) == _active_bg_id, bool(next_entry.get("unlocked", true)), posmod(_current_index + 1, _entries.size()))
	incoming_center = _build_item(center_slot, current_entry, true, str(current_entry.get("id", "")) == _active_bg_id, bool(current_entry.get("unlocked", true)), _current_index)

	var incoming_offset := Vector2(110 * direction, 0)
	var outgoing_offset := Vector2(-110 * direction, 0)
	_prepare_incoming_item(incoming_left, _get_slot_item_transform(left_slot), incoming_offset, 0.94)
	_prepare_incoming_item(incoming_center, _get_slot_item_transform(center_slot), incoming_offset * 1.15, 0.92)
	_prepare_incoming_item(incoming_right, _get_slot_item_transform(right_slot), incoming_offset, 0.94)

	_carousel_tween = create_tween()
	_carousel_tween.set_parallel(true)
	_carousel_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_animate_outgoing_item(_carousel_tween, old_left, outgoing_offset, 0.94)
	_animate_outgoing_item(_carousel_tween, old_center, outgoing_offset * 1.05, 0.9)
	_animate_outgoing_item(_carousel_tween, old_right, outgoing_offset, 0.94)
	_animate_incoming_item(_carousel_tween, incoming_left, _get_slot_item_transform(left_slot))
	_animate_incoming_item(_carousel_tween, incoming_center, _get_slot_item_transform(center_slot))
	_animate_incoming_item(_carousel_tween, incoming_right, _get_slot_item_transform(right_slot))
	_carousel_tween.tween_property(description_label, "modulate:a", 0.0, 0.08).from(1.0)
	_carousel_tween.tween_property(description_label, "position:x", 16.0 * direction, 0.08).from(0.0)
	_carousel_tween.chain().tween_callback(func():
		description_label.text = str(current_entry.get("description", ""))
		description_label.position = Vector2(-16.0 * direction, 0)
	)
	_carousel_tween.tween_property(description_label, "modulate:a", 1.0, 0.16).from(0.0)
	_carousel_tween.tween_property(description_label, "position:x", 0.0, 0.16).from(-16.0 * direction)
	await _carousel_tween.finished

	_finalize_slot(left_slot, incoming_left)
	_finalize_slot(center_slot, incoming_center)
	_finalize_slot(right_slot, incoming_right)
	description_label.modulate.a = 1.0
	description_label.position = Vector2.ZERO
	_is_animating = false
	_update_button_states()

func _update_button_states() -> void:
	if _entries.is_empty():
		left_button.visible = false
		right_button.visible = false
		return
	var current_entry: Dictionary = _entries[_current_index]
	var is_current_active := str(current_entry.get("id", "")) == _active_bg_id
	var is_current_unlocked := bool(current_entry.get("unlocked", true))
	left_button.visible = _entries.size() > 1
	right_button.visible = _entries.size() > 1
	left_button.disabled = _entries.size() <= 1 or _is_animating
	right_button.disabled = _entries.size() <= 1 or _is_animating
	apply_button.disabled = is_current_active or not is_current_unlocked or _is_animating
	apply_button.modulate = Color(0.88, 0.88, 0.9, 1) if is_current_active or not is_current_unlocked else Color(1, 1, 1, 1)

func _get_first_slot_item(slot: Control) -> Button:
	for child in slot.get_children():
		if child is Button:
			return child as Button
	return null

func _get_slot_item_transform(slot: Control) -> Dictionary:
	var slot_size: Vector2 = slot.size
	if slot_size.x <= 1.0 or slot_size.y <= 1.0:
		slot_size = slot.custom_minimum_size
	if slot_size.x <= 1.0 or slot_size.y <= 1.0:
		slot_size = ITEM_BASE_SIZE

	var scale_factor: float = min(slot_size.x / ITEM_BASE_SIZE.x, slot_size.y / ITEM_BASE_SIZE.y)
	var final_scale := Vector2(scale_factor, scale_factor)
	var scaled_size := ITEM_BASE_SIZE * scale_factor
	var final_position := Vector2(
		(slot_size.x - scaled_size.x) * 0.5,
		(slot_size.y - scaled_size.y) * 0.5
	)
	return {
		"position": final_position,
		"scale": final_scale,
	}

func _prepare_incoming_item(item: Button, target_transform: Dictionary, offset: Vector2, start_scale_factor: float) -> void:
	if item == null:
		return
	var target_position: Vector2 = target_transform["position"]
	var target_scale: Vector2 = target_transform["scale"]
	item.position = target_position + offset
	item.scale = target_scale * start_scale_factor
	item.modulate.a = 0.0

func _animate_outgoing_item(tween: Tween, item: Button, offset: Vector2, end_scale_factor: float) -> void:
	if item == null:
		return
	var current_position: Vector2 = item.position
	var current_scale: Vector2 = item.scale
	tween.tween_property(item, "position", current_position + offset, 0.24)
	tween.tween_property(item, "scale", current_scale * end_scale_factor, 0.24)
	tween.tween_property(item, "modulate:a", 0.0, 0.18)

func _animate_incoming_item(tween: Tween, item: Button, target_transform: Dictionary) -> void:
	if item == null:
		return
	tween.tween_property(item, "position", target_transform["position"], 0.28)
	tween.tween_property(item, "scale", target_transform["scale"], 0.28)
	tween.tween_property(item, "modulate:a", 1.0, 0.22)

func _finalize_slot(slot: Control, keep_item: Button) -> void:
	for child in slot.get_children():
		if child != keep_item:
			child.queue_free()
	if keep_item:
		var target_transform: Dictionary = _get_slot_item_transform(slot)
		keep_item.position = target_transform["position"]
		keep_item.scale = target_transform["scale"]
		keep_item.modulate.a = 1.0
