extends PanelContainer

signal back_requested

const EVENT_REGISTRY_PATH := "res://assets/data/events/event_registry.json"
const MAP_DATA_PATH := "res://assets/data/map/core/map_data.json"

@onready var back_btn: Button = $Margin/VBox/TopBar/BackButton
@onready var stage_switch_option: OptionButton = $Margin/VBox/TopBar/StageSwitchBox/StageOption
@onready var level_label: Label = $Margin/VBox/Scroll/ContentVBox/HeroCard/Margin/VBox/HeartRow/HeartCard/Center/VBox/LevelLabel
@onready var stage_title_label: Label = $Margin/VBox/Scroll/ContentVBox/HeroCard/Margin/VBox/HeartRow/MetaVBox/StageTitleLabel
@onready var points_label: Label = $Margin/VBox/Scroll/ContentVBox/HeroCard/Margin/VBox/HeartRow/MetaVBox/PointsLabel
@onready var stage_progress_bar: ProgressBar = $Margin/VBox/Scroll/ContentVBox/HeroCard/Margin/VBox/StageProgressBar
@onready var breakthrough_label: Label = $Margin/VBox/Scroll/ContentVBox/BreakthroughCard/Margin/VBox/BreakthroughLabel
@onready var intimacy_value_label: Label = $Margin/VBox/Scroll/ContentVBox/StatsCard/Margin/VBox/IntimacyRow/HBox/Value
@onready var trust_value_label: Label = $Margin/VBox/Scroll/ContentVBox/StatsCard/Margin/VBox/TrustRow/HBox/Value
@onready var state_badge_panel: PanelContainer = $Margin/VBox/Scroll/ContentVBox/StatusCard/Margin/VBox/TitleRow/StateBadge
@onready var state_badge_label: Label = $Margin/VBox/Scroll/ContentVBox/StatusCard/Margin/VBox/TitleRow/StateBadge/StateBadgeLabel
@onready var summary_label: Label = $Margin/VBox/Scroll/ContentVBox/StageCard/Margin/VBox/SummaryLabel
@onready var milestone_label: Label = $Margin/VBox/Scroll/ContentVBox/StatusCard/Margin/VBox/MilestoneLabel

var _event_registry_cache: Dictionary = {}
var _map_name_cache: Dictionary = {}
var _bound_profile = null
var _is_refreshing_stage_option := false

func _ready() -> void:
    hide()
    if is_instance_valid(back_btn) and not back_btn.pressed.is_connected(_on_back_pressed):
        back_btn.pressed.connect(_on_back_pressed)
    if is_instance_valid(stage_switch_option) and not stage_switch_option.item_selected.is_connected(_on_stage_option_selected):
        stage_switch_option.item_selected.connect(_on_stage_option_selected)
    _bind_profile(GameDataManager.profile if GameDataManager else null)

func _exit_tree() -> void:
    _bind_profile(null)

func show_panel(profile) -> void:
    _bind_profile(profile)
    update_ui(profile)
    show()

func hide_panel() -> void:
    hide()

func _bind_profile(profile) -> void:
    if _bound_profile == profile:
        return
    if _bound_profile != null:
        if _bound_profile.profile_updated.is_connected(_on_profile_updated):
            _bound_profile.profile_updated.disconnect(_on_profile_updated)
        if _bound_profile.stage_upgraded.is_connected(_on_stage_upgraded):
            _bound_profile.stage_upgraded.disconnect(_on_stage_upgraded)
    _bound_profile = profile
    if _bound_profile != null:
        if not _bound_profile.profile_updated.is_connected(_on_profile_updated):
            _bound_profile.profile_updated.connect(_on_profile_updated)
        if not _bound_profile.stage_upgraded.is_connected(_on_stage_upgraded):
            _bound_profile.stage_upgraded.connect(_on_stage_upgraded)

func _on_profile_updated() -> void:
    if _bound_profile != null and visible:
        update_ui(_bound_profile)

func _on_stage_upgraded(_new_stage: int) -> void:
    if _bound_profile != null and visible:
        update_ui(_bound_profile)

func _on_back_pressed() -> void:
    back_requested.emit()

func _refresh_stage_options(profile) -> void:
    if stage_switch_option == null:
        return
    _is_refreshing_stage_option = true
    stage_switch_option.clear()
    if profile != null:
        for stage_conf in profile.stages_config:
            if not (stage_conf is Dictionary):
                continue
            var stage_num := int(stage_conf.get("stage", 0))
            if stage_num <= 0:
                continue
            var stage_title := str(stage_conf.get("stageTitle", "阶段 %d" % stage_num)).strip_edges()
            stage_switch_option.add_item("LV %d %s" % [stage_num, stage_title], stage_num)
        for index in range(stage_switch_option.item_count):
            if stage_switch_option.get_item_id(index) == int(profile.current_stage):
                stage_switch_option.select(index)
                break
    _is_refreshing_stage_option = false

func _on_stage_option_selected(index: int) -> void:
    if _is_refreshing_stage_option or _bound_profile == null:
        return
    if index < 0 or index >= stage_switch_option.item_count:
        return
    var target_stage := stage_switch_option.get_item_id(index)
    if target_stage <= 0 or int(_bound_profile.current_stage) == target_stage:
        return
    _bound_profile.force_set_stage(target_stage)
    update_ui(_bound_profile)

func _get_flavor_info(intimacy: float, trust: float) -> Dictionary:
    var flavor_text := "防备疏离"
    var flavor_color := Color("c97a92")
    var flavor_desc := "仍然保持着安全距离，对彼此的靠近还带着观察与试探。"

    if intimacy >= 60.0 or trust >= 60.0:
        if intimacy >= trust * 1.5:
            flavor_text = "偏执迷恋"
            flavor_color = Color("ff8aa5")
            flavor_desc = "爱意浓度远高于安全感，渴望靠近，也更容易因为不安而患得患失。"
        elif trust >= intimacy * 1.5:
            flavor_text = "灵魂知己"
            flavor_color = Color("7cc7ff")
            flavor_desc = "彼此已经建立高度信任，像最默契的同伴，能够安心把心事交给对方。"
        else:
            flavor_text = "灵魂伴侣"
            flavor_color = Color("ff7ba8")
            flavor_desc = "爱意与安全感都十分充足，关系稳定而亲密，已经是彼此的重要依靠。"

    return {
        "text": flavor_text,
        "color": flavor_color,
        "desc": flavor_desc
    }

func _ensure_reference_cache() -> void:
    if _event_registry_cache.is_empty() and FileAccess.file_exists(EVENT_REGISTRY_PATH):
        var event_file = FileAccess.open(EVENT_REGISTRY_PATH, FileAccess.READ)
        if event_file:
            var event_json = JSON.new()
            if event_json.parse(event_file.get_as_text()) == OK:
                var event_data = event_json.get_data()
                var events = event_data.get("events", [])
                for event_item in events:
                    var event_id = str(event_item.get("event_id", ""))
                    if event_id != "":
                        _event_registry_cache[event_id] = event_item
            event_file.close()

    if _map_name_cache.is_empty() and FileAccess.file_exists(MAP_DATA_PATH):
        var map_file = FileAccess.open(MAP_DATA_PATH, FileAccess.READ)
        if map_file:
            var map_json = JSON.new()
            if map_json.parse(map_file.get_as_text()) == OK:
                var map_data = map_json.get_data()
                var locations: Dictionary = map_data.get("locations", {})
                for location_id in locations.keys():
                    var location_info = locations[location_id]
                    if location_info is Dictionary:
                        _map_name_cache[str(location_id)] = str(location_info.get("name", location_id))
            map_file.close()

func _describe_milestone_story(event_id: String) -> String:
    if event_id == "":
        return ""

    _ensure_reference_cache()
    if not _event_registry_cache.has(event_id):
        return "完成里程碑事件【%s】" % event_id

    var event_info: Dictionary = _event_registry_cache[event_id]
    var parts: Array[String] = []
    var conditions = event_info.get("conditions", [])
    for condition in conditions:
        if not (condition is Dictionary):
            continue
        match str(condition.get("type", "")):
            "location":
                var location_id = str(condition.get("value", ""))
                var location_name = _map_name_cache.get(location_id, location_id)
                parts.append("前往【%s】" % location_name)
            "weather":
                parts.append("天气为【%s】" % str(condition.get("value", "")))
            "npc_stage":
                parts.append("相关角色阶段达到 %s" % str(condition.get("min_stage", "")))

    if parts.is_empty():
        return "完成里程碑事件【%s】" % event_id
    return "，".join(parts)

func _get_milestone_story_id(conf: Dictionary) -> String:
    return str(conf.get("milestone_story", "")).strip_edges()

func _build_breakthrough_hint(profile, conf: Dictionary, progress_info: Dictionary) -> Dictionary:
    var resonance_target: float = float(progress_info.get("display_max", 0.0))
    var milestone_story := _get_milestone_story_id(conf)
    var event_manager = get_tree().root.get_node_or_null("EventManager")
    var milestone_done := false
    if milestone_story != "" and event_manager and event_manager.has_method("is_event_triggered"):
        milestone_done = event_manager.is_event_triggered(milestone_story)

    var parts: Array[String] = []
    if not progress_info.get("is_max_stage", false):
        parts.append("共感值达到：%.0f" % resonance_target)
    else:
        parts.append("当前已达到最高阶段")

    if milestone_story != "":
        var milestone_desc = _describe_milestone_story(milestone_story)
        if milestone_done:
            parts.append("里程碑剧情：%s（已完成）" % milestone_desc)
        else:
            parts.append("里程碑剧情：%s（待触发）" % milestone_desc)
    elif not progress_info.get("is_max_stage", false):
        parts.append("里程碑剧情：当前阶段暂未配置")

    return {
        "text": "突破到下一阶段需要满足：\n" + "\n".join(parts),
        "milestone_done": milestone_done
    }

func _build_stage_progress(profile, current_stage: int, conf: Dictionary) -> Dictionary:
    var current_resonance: float = profile.intimacy + profile.trust
    var resonance_threshold: float = float(conf.get("resonance_threshold", 0.0))
    var is_max_stage: bool = resonance_threshold >= 9999.0

    if resonance_threshold <= 0.0 and not is_max_stage:
        var next_conf: Dictionary = profile.get_stage_config(current_stage + 1)
        if not next_conf.is_empty():
            resonance_threshold = float(next_conf.get("resonance_threshold", 0.0))

    var display_max: float = resonance_threshold
    if is_max_stage:
        display_max = max(current_resonance, 100.0)
    elif display_max <= 0.0:
        display_max = max(current_resonance, 100.0)

    return {
        "display_current": current_resonance,
        "display_max": display_max,
        "bar_value": min(current_resonance, display_max),
        "is_max_stage": is_max_stage
    }

func update_ui(profile) -> void:
    if profile == null:
        return
    _refresh_stage_options(profile)

    var current_stage: int = int(profile.current_stage)
    var conf: Dictionary = profile.get_current_stage_config()
    if conf.is_empty():
        return

    var intimacy: float = float(profile.intimacy)
    var trust: float = float(profile.trust)
    var flavor_info := _get_flavor_info(intimacy, trust)
    var progress_info := _build_stage_progress(profile, current_stage, conf)

    level_label.text = "LV %d" % current_stage
    stage_title_label.text = str(conf.get("stageTitle", "未命名阶段"))
    if bool(progress_info.get("is_max_stage", false)):
        points_label.text = "%.0f / MAX" % float(progress_info.get("display_current", 0.0))
    else:
        points_label.text = "%.0f / %.0f" % [float(progress_info.get("display_current", 0.0)), float(progress_info.get("display_max", 0.0))]

    stage_progress_bar.min_value = 0.0
    stage_progress_bar.max_value = float(progress_info.get("display_max", 100.0))
    stage_progress_bar.value = float(progress_info.get("bar_value", 0.0))

    var breakthrough_info := _build_breakthrough_hint(profile, conf, progress_info)
    breakthrough_label.text = str(breakthrough_info.get("text", ""))
    breakthrough_label.add_theme_color_override(
        "font_color",
        Color(0.35, 0.67, 0.46, 1) if bool(breakthrough_info.get("milestone_done", false)) else Color(0.45, 0.48, 0.56, 1)
    )

    intimacy_value_label.text = "%.0f" % intimacy
    trust_value_label.text = "%.0f" % trust

    var flavor_text := str(flavor_info.get("text", ""))
    var flavor_color: Color = flavor_info.get("color", Color.WHITE)
    var flavor_desc := str(flavor_info.get("desc", ""))
    state_badge_label.text = flavor_text
    state_badge_label.add_theme_color_override("font_color", flavor_color)
    summary_label.text = "阶段【%s】\n%s" % [
        str(conf.get("stageTitle", "")),
        str(conf.get("stageDesc", "暂无描述"))
    ]

    var badge_style := StyleBoxFlat.new()
    badge_style.bg_color = Color(flavor_color, 0.12)
    badge_style.border_width_left = 1
    badge_style.border_width_top = 1
    badge_style.border_width_right = 1
    badge_style.border_width_bottom = 1
    badge_style.border_color = Color(flavor_color, 0.32)
    badge_style.corner_radius_top_left = 16
    badge_style.corner_radius_top_right = 16
    badge_style.corner_radius_bottom_left = 16
    badge_style.corner_radius_bottom_right = 16
    if is_instance_valid(state_badge_panel):
        state_badge_panel.add_theme_stylebox_override("panel", badge_style)

    var fill_style := StyleBoxFlat.new()
    fill_style.bg_color = flavor_color
    fill_style.corner_radius_top_left = 6
    fill_style.corner_radius_top_right = 6
    fill_style.corner_radius_bottom_left = 6
    fill_style.corner_radius_bottom_right = 6
    stage_progress_bar.add_theme_stylebox_override("fill", fill_style)

    milestone_label.text = "状态概览：%s" % flavor_desc
    milestone_label.add_theme_color_override("font_color", Color(0.45, 0.48, 0.56, 1))
