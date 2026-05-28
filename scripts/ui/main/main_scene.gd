extends Control

const PhotoMemoryManagerScript = preload("res://scripts/data/photo_memory_manager.gd")

@onready var ui_panel: Panel = $UIPanel
@onready var rest_button: Button = $UIPanel/RestButton
@onready var desktop_pet_button: Button = $UIPanel/BottomBarHBox/BtnHBox/DesktopPetButton
@onready var hide_ui_button: Button = $UIPanel/SystemButton/HideUIButton
@onready var camera_button: Button = $UIPanel/SystemButton/CameraButton
@onready var phone_button: Button = $UIPanel/SystemButton/PhoneButton
@onready var affection_button: Button = $UIPanel/AffectionButton
@onready var pomodoro_button: Button = $UIPanel/PomodoroButton
@onready var wardrobe_button: Button = $UIPanel/WardrobeButton

@onready var diary_button: Button = $UIPanel/BottomBarHBox/BtnHBox/DiaryButton
@onready var main_action_button: Button = $UIPanel/MainActionButton

var _photo_manager = PhotoMemoryManagerScript.new()
@onready var stats_panel = $UIPanel/StatsPanel
@onready var top_status_panel = $UIPanel/TopStatusPanel
@onready var bgm: AudioStreamPlayer = $BGM
@onready var music_player: Panel = $UIPanel/MusicPlayer
@onready var diary_panel: Control = $UIPanel/DiaryPanel
@onready var diary_notification: PanelContainer = $UIPanel/DiaryNotification
@onready var topic_panel: Panel = $TopicPanel
@onready var topic_container: VBoxContainer = $TopicPanel/TopicContainer
@onready var wardrobe_panel: Control = $WardrobePanel
@onready var dialogue_panel: Control = $DialoguePanel
@onready var dialogue_name_label: Label = $DialoguePanel/DialogueLayer/VBox/NameLabel
@onready var dialogue_text: RichTextLabel = $DialoguePanel/DialogueLayer/VBox/RichTextLabel
@onready var input_layer: Panel = $DialoguePanel/InputLayer
@onready var input_field: TextEdit = $DialoguePanel/InputLayer/HBoxContainer/InputField
@onready var send_btn: Button = $DialoguePanel/InputLayer/HBoxContainer/SendButton
@onready var end_chat_btn: Button = $DialoguePanel/EndChatButton
@onready var history_btn: Button = $DialoguePanel/HistoryButton
@onready var quick_options_container = $DialoguePanel/QuickOptionLayer/ScrollContainer/QuickOptions

@onready var deepseek_client = $DeepSeekClient

@onready var interact_group: VBoxContainer = $UIPanel/InteractGroup
@onready var chat_button: Button = $UIPanel/InteractGroup/ChatButton
@onready var gift_button: Button = $UIPanel/InteractGroup/GiftButton
@onready var interactive_button: Button = $UIPanel/InteractGroup/InteractiveButton
@onready var interactive_sub_menu: Control = $UIPanel/InteractiveSubMenu
@onready var co_create_button: Button = $UIPanel/InteractiveSubMenu/Margin/VBox/CoCreateButton

var activity_panel_instance = null
var drawing_board_instance = null

var _chat_tween: Tween = null
var _typewriter_tween: Tween = null
var stream_live_buffer: String = ""
var stream_live_active: bool = false

var _accumulated_stats: Dictionary = {
    "intimacy": 0.0,
    "trust": 0.0,
    "openness": 0.0,
    "conscientiousness": 0.0,
    "extraversion": 0.0,
    "agreeableness": 0.0,
    "neuroticism": 0.0
}

const QuickOptionListHelper = preload("res://scripts/ui/story/quick_option_list_helper.gd")

var settings_panel_instance = null
var desktop_pet_instance: Window = null
var chat_scene_instance = null
var archive_panel_instance = null
var affection_panel_instance = null
var mobile_interface_instance = null
var incoming_call_notification_instance = null
var history_panel_instance = null
var pomodoro_panel_instance = null
var schedule_panel_instance = null
var save_load_panel_instance = null

var _story_mode_active: bool = false
var _main_action_mode: String = "schedule"

var _window_detector: Node = null
var _is_afk: bool = false
var _afk_timer: Timer = null
var _ui_tween: Tween = null
var audio_player: AudioStreamPlayer = null

var map_scene_instance = null

const TOPIC_LIST = [
    "最近在忙些什么呢？",
    "今天天气真不错，对吧？",
    "有什么心事想和我聊聊吗？",
    "推荐一本你喜欢的书或电影吧。",
    "聊聊你的兴趣爱好吧！",
    "最近有遇到什么有趣的事吗？",
	"周末通常是怎么过的呢？"
]

var stream_live_queue: Array = []
var stream_live_worker_running: bool = false
var stream_live_done: bool = false

var is_proactive_greeting: bool = false
var proactive_greeting_step: int = 0
var is_memory_revisit_active: bool = false
var _generated_image_panel: Panel = null

var _waiting_for_chat_click: bool = false
signal _chat_click_proceed

var pending_options_data = []
var is_text_playback_finished = true

func _on_main_chat_pressed() -> void:
    _animate_button(chat_button)
    
    if _ui_tween:
        _ui_tween.kill()
    _ui_tween = create_tween()
    _ui_tween.tween_property(ui_panel, "modulate:a", 0.0, 0.3)
    _ui_tween.tween_callback(func(): ui_panel.visible = false)
    
    if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
        current_bg_scene.set_ui_hidden(true)
    
    topic_panel.visible = true
    topic_panel.modulate.a = 0.0
    var t_tween = create_tween()
    t_tween.tween_property(topic_panel, "modulate:a", 1.0, 0.3)
    
    _populate_topics()

func _populate_topics() -> void:
    for child in topic_container.get_children():
        child.queue_free()

    QuickOptionListHelper.show_loading_item(topic_container)
    
    # 请求 AI 动态生成话题
    var profile = GameDataManager.profile
    var stage_conf = profile.get_current_stage_config()
    var stage_title = stage_conf.get("stageTitle", "陌生人")
    var world_bg = profile.description.replace("{char_name}", profile.char_name)
    
    var prompt = "【系统指令】\n当前世界观与角色设定：%s\n\n请基于当前玩家作为少女【%s】的“指导人”身份，以及你们当前的情感阶段（当前阶段：%s），以指导人的口吻，生成 3 个符合当前关系深度的聊天话题选项。\n要求：\n1. 话题必须严格符合上述的世界观设定！绝对禁止凭空捏造“魔法”、“修仙”、“草药学”等不符合设定的元素。\n2. 话题可以是符合世界观的教导、关心、日常询问或指导性的话语。\n3. 直接输出 3 个选项，每行一个。\n4. 不要带有序号（如 1. 2. 3.）、破折号或其他前缀。\n5. 话题要自然、简短（20字以内）。" % [world_bg, profile.char_name, stage_title]
    
    deepseek_client.generate_dynamic_topics(prompt, func(text: String):
        if text.is_empty():
            _render_dynamic_topics("最近在忙些什么呢？\n今天天气真不错，对吧？\n有什么心事想和我聊聊吗？")
        else:
            _render_dynamic_topics(text)
    )

func _render_dynamic_topics(raw_text: String) -> void:
    var topics = QuickOptionListHelper.parse_topic_lines(
        raw_text,
        ["聊点什么呢？", "天气不错", "分享件有趣的事"],
        3
    )
    QuickOptionListHelper.populate_option_items(topic_container, topics, _on_topic_selected, 60.0)

func _on_topic_selected(topic: String) -> void:
    # 执行互动开销（行动力、金币、经验、心情、时间等）
    if GameDataManager.interaction_manager:
        if not GameDataManager.interaction_manager.execute_interaction("chat_luna_topic"):
            return
    else:
        if not GameDataManager.profile.consume_energy(5):
            ToastManager.show_system_toast("行动力不足，需要5点行动力", Color.RED)
            return
        
    if top_status_panel and top_status_panel.has_method("_update_ui"):
        top_status_panel._update_ui()
        
    var t_tween = create_tween()
    t_tween.tween_property(topic_panel, "modulate:a", 0.0, 0.3)
    t_tween.tween_callback(func(): topic_panel.visible = false)
    
    dialogue_panel.visible = true
    dialogue_panel.modulate.a = 0.0
    var d_tween = create_tween()
    d_tween.tween_property(dialogue_panel, "modulate:a", 1.0, 0.3)
    
    dialogue_name_label.text = GameDataManager.profile.char_name
    dialogue_text.text = "..."
    input_field.text = ""
    input_field.editable = false
    send_btn.disabled = true
    
    if end_chat_btn:
        end_chat_btn.show()
    if history_btn:
        history_btn.show()
    
    for child in quick_options_container.get_children():
        child.queue_free()
        
    var stage_conf = GameDataManager.profile.get_current_stage_config()
    var stage_desc = stage_conf.get("stageDesc", "")
    var player_name = GameDataManager.profile.player_title
    if player_name.is_empty():
        player_name = "指导人"
    var user_msg = "【系统提示】玩家主动选择了话题：“" + topic + "” 与你聊天。玩家当前的身份是你的指导人，且你对玩家的称呼是“" + player_name + "”。当前你们的情感阶段是：" + stage_desc + "。请你结合当前的身份、情感阶段和心情，以第一人称主动向玩家打招呼并展开这个话题。不要复述系统提示，直接给出纯台词回复（必须包含括号动作描写）。"
    deepseek_client.send_chat_message_stream(user_msg, "main_chat")

func _on_topic_panel_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
        # 右键点击空白处取消话题弹窗
        var t_tween = create_tween()
        t_tween.tween_property(topic_panel, "modulate:a", 0.0, 0.3)
        t_tween.tween_callback(func(): topic_panel.visible = false)
        
        # 恢复主UI显示
        ui_panel.visible = true
        ui_panel.modulate.a = 0.0
        if _ui_tween:
            _ui_tween.kill()
        _ui_tween = create_tween()
        _ui_tween.tween_property(ui_panel, "modulate:a", 1.0, 0.3)
        
        if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
            current_bg_scene.set_ui_hidden(false)

var is_ending_chat: bool = false

func _on_gift_pressed() -> void:
    if is_instance_valid(gift_button):
        _animate_button(gift_button)
    
    var gift_popup_path = "res://scenes/ui/gift/gift_panel.tscn"
    if FileAccess.file_exists(gift_popup_path):
        var gift_popup_scene = load(gift_popup_path)
        if gift_popup_scene:
            var popup = gift_popup_scene.instantiate()
            ui_panel.add_child(popup)
            
            if popup.has_signal("gift_sent"):
                popup.gift_sent.connect(_on_gift_sent)
                
            if popup.has_method("show_panel"):
                popup.show_panel()

func _on_gift_sent(gift_data: Dictionary) -> void:
    var gift_id = gift_data.get("id", "")
    if gift_id == "":
        return
        
    # 委托 GiftManager 处理，它内部会调用 interaction_manager 扣除行动力/时间等，并处理亲密和信任加成
    var res = GameDataManager.gift_manager.send_gift(GameDataManager.profile, gift_id)
    if not res.success:
        ToastManager.show_system_toast(res.msg, Color.RED)
        return
        
    # 显示Toast
    ToastManager.show_toast("送出了 [%s]" % gift_data.get("name", "礼物"), Color(0.6, 0.4, 0.8, 0.9))
    if res.gained_intimacy > 0:
        ToastManager.show_stat_toast("intimacy", "亲密 +%.1f" % res.gained_intimacy)
    if res.gained_trust > 0:
        ToastManager.show_stat_toast("trust", "信任 +%.1f" % res.gained_trust)
        
    if top_status_panel and top_status_panel.has_method("_update_ui"):
        top_status_panel._update_ui()
        
    # 送礼后触发对话面板和特定话题
    if _ui_tween:
        _ui_tween.kill()
    _ui_tween = create_tween()
    _ui_tween.tween_property(ui_panel, "modulate:a", 0.0, 0.3)
    _ui_tween.tween_callback(func(): ui_panel.visible = false)
    
    if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
        current_bg_scene.set_ui_hidden(true)
    
    dialogue_panel.visible = true
    dialogue_panel.modulate.a = 0.0
    var d_tween = create_tween()
    d_tween.tween_property(dialogue_panel, "modulate:a", 1.0, 0.3)
    
    dialogue_name_label.text = GameDataManager.profile.char_name
    dialogue_text.text = "..."
    input_field.text = ""
    input_field.editable = false
    send_btn.disabled = true
    
    if end_chat_btn:
        end_chat_btn.show()
    if history_btn:
        history_btn.show()
    
    for child in quick_options_container.get_children():
        child.queue_free()
        
    var gift_name = gift_data.get("name", "礼物")
    var stage_conf = GameDataManager.profile.get_current_stage_config()
    var stage_desc = stage_conf.get("stageDesc", "")
    var player_name = GameDataManager.profile.player_title
    if player_name.is_empty():
        player_name = "指导人"
        
    var user_msg = "【系统提示】玩家（当前身份：" + player_name + "）刚刚送给你一份礼物：【" + gift_name + "】。当前情感阶段是：" + stage_desc + "。请结合你的性格、心情和这份礼物的特点，主动对玩家说出你的感谢和反应（必须包含动作描写）。不要复述系统提示，直接给出台词。"
    deepseek_client.send_chat_message_stream(user_msg, "main_chat")

func _on_rest_pressed() -> void:
    _animate_button(rest_button)
    
    # 检查行动力
    var energy_val = GameDataManager.profile.current_energy
    var energy_warning = energy_val > 0
    
    # 检查时间
    var time_warning = false
    if GameDataManager.story_time_manager:
        var current_time = GameDataManager.story_time_manager.current_hour * 60 + GameDataManager.story_time_manager.current_minute
        # 假设 24:00 是 1440 分钟，如果小于这个值，说明时间还早
        if current_time < 1440:
            time_warning = true
    
    if energy_warning or time_warning:
        var warning_text = ""
        if energy_warning and time_warning:
            warning_text = "还有未消耗的行动力，且时间还早，确定要休息了吗？"
        elif energy_warning:
            warning_text = "还有未消耗的行动力，确定要休息了吗？"
        else:
            warning_text = "时间还早，确定要休息了吗？"
            
        var ConfirmDialogObj = load("res://scenes/ui/common/confirm_dialog.tscn")
        var confirm_dialog = ConfirmDialogObj.instantiate()
        add_child(confirm_dialog)
        confirm_dialog.setup(warning_text)
        confirm_dialog.confirmed.connect(_execute_rest_transition.bind(confirm_dialog))
        confirm_dialog.canceled.connect(func(): confirm_dialog.queue_free())
    else:
        _execute_rest_transition(null)

func _execute_rest_transition(dialog: Node) -> void:
    if is_instance_valid(dialog):
        dialog.queue_free()
        
    # 屏蔽交互
    ui_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    
    # 创建黑屏遮罩
    var black_screen = ColorRect.new()
    black_screen.color = Color.BLACK
    black_screen.modulate.a = 0.0
    black_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    # 确保盖在最上面
    add_child(black_screen)
    move_child(black_screen, get_child_count() - 1)
    
    var tween = create_tween()
    # 1. 黑屏淡入
    tween.tween_property(black_screen, "modulate:a", 1.0, 1.0)
    
    # 2. 执行跳过逻辑
    tween.tween_callback(func():
        if GameDataManager.story_time_manager:
            # 跳到下一天
            GameDataManager.story_time_manager.advance_day(1)
            # 确保时间设置为早上6点
            GameDataManager.story_time_manager.current_hour = 6
            GameDataManager.story_time_manager.current_minute = 0
            GameDataManager.story_time_manager.current_period = GameDataManager.story_time_manager.PERIOD_MORNING
            GameDataManager.story_time_manager.time_advanced.emit(0, GameDataManager.story_time_manager.current_period)
            
            # 恢复行动力等日常重置逻辑可以在这里或者时间管理器的跨天信号里处理
            GameDataManager.profile.current_energy = GameDataManager.profile.max_energy
            
            GameDataManager.profile.save_profile()
            GameDataManager.story_time_manager.save_data()
            GameDataManager.save_manager.auto_save()
    )

    # 3. 停留一会
    tween.tween_interval(1.0)
    
    # 4. 黑屏淡出
    tween.tween_property(black_screen, "modulate:a", 0.0, 1.0)
    tween.tween_callback(func():
        black_screen.queue_free()
        ui_panel.mouse_filter = Control.MOUSE_FILTER_PASS
    )
    print("[MainScene] 休息按钮被点击，预留接口")

func _on_interactive_pressed() -> void:
    _animate_button(interactive_button)
    interactive_sub_menu.visible = not interactive_sub_menu.visible

func _on_co_create_pressed() -> void:
    _animate_button(co_create_button)
    interactive_sub_menu.visible = false
    if drawing_board_instance == null:
        var DrawingBoardObj = load("res://scenes/ui/activity/drawing_board_panel.tscn")
        drawing_board_instance = DrawingBoardObj.instantiate()
        ui_panel.add_child(drawing_board_instance)
        drawing_board_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        if drawing_board_instance.has_signal("creation_completed"):
            drawing_board_instance.creation_completed.connect(_on_drawing_creation_completed)
        if drawing_board_instance.has_signal("creation_failed"):
            drawing_board_instance.creation_failed.connect(_on_drawing_creation_failed)
        if drawing_board_instance.has_signal("close_requested"):
            drawing_board_instance.close_requested.connect(func(): drawing_board_instance.hide())
    drawing_board_instance.show()

func _on_drawing_creation_completed(image_path: String, prompt: String) -> void:
    if drawing_board_instance:
        drawing_board_instance.hide()

    if image_path.strip_edges() != "":
        var photo_manager = PhotoMemoryManagerScript.new()
        var memory_context = GameDataManager.memory_manager.build_story_memory_context() if GameDataManager.memory_manager else {}
        photo_manager.register_photo(image_path, "drawing_image", {
            "album_category": "drawing",
            "memory_context": memory_context,
            "preferred_layers": ["bond", "emotion", "habit"],
            "source_title": "一起完成的画",
            "source_text": prompt,
            "source_id": str(Time.get_unix_time_from_system()),
            "prompt": prompt,
            "source_char_id": str(GameDataManager.profile.current_character_id) if GameDataManager.profile else ""
        })
    
    # 执行互动开销
    if GameDataManager.interaction_manager:
        GameDataManager.interaction_manager.execute_interaction("co_create_board")
    
    # 显示图片和对话
    _show_generated_image_and_dialogue(image_path)

func _on_drawing_creation_failed(error_msg: String) -> void:
    ToastManager.show_system_toast(error_msg, Color.RED)

func _show_generated_image_and_dialogue(image_path: String) -> void:
    if is_instance_valid(_generated_image_panel):
        _generated_image_panel.queue_free()
    _generated_image_panel = null

    # 利用系统的图库面板或者创建临时的面板显示图片
    var tex = ImageTexture.create_from_image(Image.load_from_file(image_path))
    if tex == null:
        ToastManager.show_system_toast("无法加载生成的图片", Color.RED)
        return
        
    var tex_rect = TextureRect.new()
    tex_rect.texture = tex
    tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    
    var panel = Panel.new()
    _generated_image_panel = panel
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0, 0, 0, 0.8)
    panel.add_theme_stylebox_override("panel", style)
    
    tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.add_child(tex_rect)
    
    var close_btn = Button.new()
    close_btn.text = "关闭"
    close_btn.position = Vector2(20, 20)
    close_btn.add_theme_font_size_override("font_size", 24)
    close_btn.pressed.connect(func(): panel.queue_free())
    panel.add_child(close_btn)
    
    add_child(panel)
    move_child(panel, dialogue_panel.get_index())
    
    # 显示对话
    if _ui_tween:
        _ui_tween.kill()
    _ui_tween = create_tween()
    _ui_tween.tween_property(ui_panel, "modulate:a", 0.0, 0.3)
    _ui_tween.tween_callback(func(): ui_panel.visible = false)
    
    if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
        current_bg_scene.set_ui_hidden(true)
    
    dialogue_panel.visible = true
    dialogue_panel.modulate.a = 0.0
    var d_tween = create_tween()
    d_tween.tween_property(dialogue_panel, "modulate:a", 1.0, 0.3)
    
    dialogue_name_label.text = GameDataManager.profile.char_name
    dialogue_text.text = "哥哥，我根据你画的草图，丰富了一下细节，你看好看吗？"
    dialogue_text.visible_ratio = 0.0
    
    if _typewriter_tween:
        _typewriter_tween.kill()
    _typewriter_tween = create_tween()
    _typewriter_tween.tween_property(dialogue_text, "visible_ratio", 1.0, 1.5)
    
    input_field.text = ""
    input_field.editable = true
    send_btn.disabled = false
    
    if end_chat_btn:
        end_chat_btn.show()
    if history_btn:
        history_btn.show()
    
    for child in quick_options_container.get_children():
        child.queue_free()

func _on_end_chat_pressed() -> void:
    if _story_mode_active:
        return
    var event_manager = get_node_or_null("/root/EventManager")
    if event_manager and event_manager.has_method("execute_event"):
        event_manager.execute_event("farewell")

func _close_chat_panel() -> void:
    if is_instance_valid(_generated_image_panel):
        _generated_image_panel.queue_free()
    _generated_image_panel = null
    is_memory_revisit_active = false

    _show_accumulated_stats()
    
    var d_tween = create_tween()
    d_tween.tween_property(dialogue_panel, "modulate:a", 0.0, 0.3)
    d_tween.tween_callback(func(): dialogue_panel.visible = false)
    
    ui_panel.visible = true
    ui_panel.modulate.a = 0.0
    if _ui_tween:
        _ui_tween.kill()
    _ui_tween = create_tween()
    _ui_tween.tween_property(ui_panel, "modulate:a", 1.0, 0.3)
    
    if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
        current_bg_scene.set_ui_hidden(false)

func _on_send_pressed() -> void:
    if _story_mode_active:
        return
    var text = input_field.text.strip_edges()
    if text.is_empty():
        return
        
    input_field.text = ""
    input_field.editable = false
    send_btn.disabled = true
    
    for child in quick_options_container.get_children():
        child.queue_free()
        
    GameDataManager.history.add_message("player", text, "", "main_chat")
    
    dialogue_name_label.text = "我"
    
    var display_text = text
    var color_regex_zh = RegEx.new()
    color_regex_zh.compile("（(.*?)）")
    display_text = color_regex_zh.sub(display_text, "[color=green]（$1）[/color]", true)
    var color_regex_en = RegEx.new()
    color_regex_en.compile("\\((.*?)\\)")
    display_text = color_regex_en.sub(display_text, "[color=green]($1)[/color]", true)
    
    dialogue_text.bbcode_enabled = true
    dialogue_text.text = display_text
    dialogue_text.visible_ratio = 0.0
    
    if _typewriter_tween:
        _typewriter_tween.kill()
    _typewriter_tween = create_tween()
    var dur = max(0.5, text.length() * 0.05)
    _typewriter_tween.tween_property(dialogue_text, "visible_ratio", 1.0, dur)
    
    if is_inside_tree():
        while _typewriter_tween and _typewriter_tween.is_valid() and _typewriter_tween.is_running():
            await get_tree().process_frame
            
    dialogue_text.visible_ratio = 1.0
    dialogue_text.visible_characters = -1
    
    if is_proactive_greeting:
        is_proactive_greeting = false
        
    deepseek_client.send_chat_message_stream(text, "main_chat")

func _on_chat_stream_started() -> void:
    stream_live_active = true
    stream_live_done = false
    stream_live_buffer = ""
    stream_live_queue.clear()
    is_text_playback_finished = false
    pending_options_data.clear()
    
    if _waiting_for_chat_click:
        _waiting_for_chat_click = false
        _chat_click_proceed.emit()
        
    _try_start_stream_worker()

func _on_chat_stream_delta(delta_text: String) -> void:
    if not stream_live_active:
        return
    stream_live_buffer += delta_text
    _extract_stream_segments(false)
    _try_start_stream_worker()

func _on_chat_response(response: Dictionary) -> void:
    if stream_live_active:
        stream_live_done = true
        _extract_stream_segments(true)
        _try_start_stream_worker()
        
        # 我们不再在这里直接保存全量内容，因为 _stream_worker_loop 会逐句保存并附带语音缓存
        # GameDataManager.history.add_message("char", deepseek_client._chat_stream_full_text, "", "main_chat")
        deepseek_client.send_options_generation(deepseek_client._chat_stream_full_text, "", "main_chat")
        deepseek_client.send_emotion_generation(deepseek_client._chat_stream_full_text)
        return
        
    if response.has("choices") and response["choices"].size() > 0:
        var reply = response["choices"][0]["message"]["content"]
        # 我们不再在这里直接保存全量内容，因为 _stream_worker_loop 会逐句保存并附带语音缓存
        # GameDataManager.history.add_message("char", reply, "", "main_chat")
        deepseek_client.send_options_generation(reply, "", "main_chat")
        deepseek_client.send_emotion_generation(reply)
            
        dialogue_name_label.text = GameDataManager.profile.char_name
        
        var display_text = reply
        var color_regex_zh = RegEx.new()
        color_regex_zh.compile("（(.*?)）")
        display_text = color_regex_zh.sub(display_text, "[color=green]（$1）[/color]", true)
        var color_regex_en = RegEx.new()
        color_regex_en.compile("\\((.*?)\\)")
        display_text = color_regex_en.sub(display_text, "[color=green]($1)[/color]", true)
        
        dialogue_text.bbcode_enabled = true
        dialogue_text.text = display_text
        dialogue_text.visible_ratio = 1.0
        input_field.editable = true
        send_btn.disabled = false
    else:
        dialogue_name_label.text = GameDataManager.profile.char_name
        dialogue_text.text = "似乎走神了..."
        input_field.editable = true
        send_btn.disabled = false

func _extract_stream_segments(force_flush: bool) -> void:
    var delim = "[SPLIT]"
    while true:
        var idx = stream_live_buffer.find(delim)
        if idx == -1:
            break
        var part = stream_live_buffer.substr(0, idx).strip_edges()
        stream_live_buffer = stream_live_buffer.substr(idx + delim.length())
        if part != "":
            stream_live_queue.append(part)
            
    if force_flush:
        var last_part = stream_live_buffer.strip_edges()
        stream_live_buffer = ""
        if last_part != "":
            var parts = _auto_split_message(last_part)
            for p in parts:
                if typeof(p) == TYPE_STRING:
                    var tp = p.strip_edges()
                    if tp != "":
                        stream_live_queue.append(tp)

func _auto_split_message(text: String) -> Array:
    if "[SPLIT]" in text:
        return text.split("[SPLIT]", false)
        
    var mood_tag = ""
    var pure_text = text
    var mood_regex = RegEx.new()
    mood_regex.compile("(?i)(?:<|\\<|《|\\[|【)\\s*(mood|心情)\\s*[:：]\\s*([^>\\>》\\]】]+)\\s*(?:>|\\>|》|\\]|】)")
    var mood_match = mood_regex.search(text)
    if mood_match:
        mood_tag = mood_match.get_string()
        pure_text = text.replace(mood_tag, "")
        
    var modified_text = pure_text
    
    # 新增策略0：优先将大模型输出的换行符视为消息分隔符
    # 很多时候AI会用换行来排版不同的动作和对话
    modified_text = modified_text.replace("\r\n", "\n")
    var nl_regex = RegEx.new()
    nl_regex.compile("\\n+")
    modified_text = nl_regex.sub(modified_text, "[SPLIT]", true)
    
    # 修复：确保连续的 [SPLIT] 被合并为一个
    modified_text = modified_text.replace("[SPLIT][SPLIT]", "[SPLIT]")
    modified_text = modified_text.replace("[SPLIT] [SPLIT]", "[SPLIT]")
    
    if not "[SPLIT]" in modified_text:
        var endings = ["。", "！", "？", "……", "”", "」", "~", "～"]
        var brackets = ["（", "("]
        
        # 策略1：根据“标点+动作括号”完美切分，这样刚好能保证切分后下一句以动作开头，带着后续的对话
        for end_char in endings:
            for bracket in brackets:
                modified_text = modified_text.replace(end_char + bracket, end_char + "[SPLIT]" + bracket)
                modified_text = modified_text.replace(end_char + " " + bracket, end_char + "[SPLIT]" + bracket)
                
        # 策略2：如果文本仍未切分且过长（>80字），强行按标点切分
        if not "[SPLIT]" in modified_text and modified_text.length() > 80:
            modified_text = modified_text.replace("。", "。[SPLIT]")
            modified_text = modified_text.replace("！", "！[SPLIT]")
            modified_text = modified_text.replace("？", "？[SPLIT]")
            # 避免把连续的标点切碎
            modified_text = modified_text.replace("[SPLIT][SPLIT]", "[SPLIT]")
        
    var parts = modified_text.split("[SPLIT]", false)
    var merged_parts = []
    var temp_str = ""
    
    for p in parts:
        var tp = p.strip_edges()
        if tp == "": continue
        
        if temp_str == "":
            temp_str = tp
        else:
            # 优化：判断当前片段(tp)或者暂存片段(temp_str)是否*仅仅*包含动作描写（没有实质对话内容）
            var tp_clean = tp
            var temp_clean = temp_str
            var action_regex = RegEx.new()
            action_regex.compile("（.*?）|\\(.*?\\)")
            tp_clean = action_regex.sub(tp_clean, "", true).strip_edges()
            temp_clean = action_regex.sub(temp_clean, "", true).strip_edges()
            
            # 如果其中一个片段仅仅只有动作描写（去掉括号后无内容），则必须合并
            if tp_clean == "" or temp_clean == "":
                temp_str += " " + tp
            else:
                merged_parts.append(temp_str)
                temp_str = tp
                
    if temp_str != "":
        merged_parts.append(temp_str)

    merged_parts = ChatSplitHelper.merge_incomplete_parentheses(merged_parts)
        
    # 新增限制：如果某一条消息长度超过 60，强制进行二次切分
    var final_split_parts = []
    for part in merged_parts:
        if part.length() > 60:
            var split_part = part
            var endings = ["。", "！", "？", "……", "”", "」", "~", "～"]
            var brackets = ["（", "("]
            # 尝试在动作前切分
            for end_char in endings:
                for bracket in brackets:
                    split_part = split_part.replace(end_char + bracket, end_char + "[FORCE_SPLIT]" + bracket)
                    split_part = split_part.replace(end_char + " " + bracket, end_char + "[FORCE_SPLIT]" + bracket)
            
            # 如果依然没有切分开，强行按标点切分
            if not "[FORCE_SPLIT]" in split_part:
                split_part = split_part.replace("。", "。[FORCE_SPLIT]")
                split_part = split_part.replace("！", "！[FORCE_SPLIT]")
                split_part = split_part.replace("？", "？[FORCE_SPLIT]")
                split_part = split_part.replace("[FORCE_SPLIT][FORCE_SPLIT]", "[FORCE_SPLIT]")
                
            var sub_parts = split_part.split("[FORCE_SPLIT]", false)
            for sp in sub_parts:
                if sp.strip_edges() != "":
                    final_split_parts.append(sp.strip_edges())
        else:
            final_split_parts.append(part)
            
    merged_parts = final_split_parts
    merged_parts = ChatSplitHelper.merge_incomplete_parentheses(merged_parts)
        
    # 限制最多3条
    if merged_parts.size() > 3:
        # 只保留前3条，或者把后面的内容全部合并到第3条里
        var truncated_parts = []
        truncated_parts.append(merged_parts[0])
        truncated_parts.append(merged_parts[1])
        truncated_parts.append(merged_parts[2])
        merged_parts = truncated_parts
        
    if merged_parts.size() > 0 and mood_tag != "":
        merged_parts[merged_parts.size() - 1] += mood_tag
        
    if merged_parts.size() == 0:
        return [text]
        
    return merged_parts

func _try_start_stream_worker() -> void:
    if stream_live_worker_running:
        return
    stream_live_worker_running = true
    _stream_worker_loop()

func _stream_worker_loop() -> void:
    while stream_live_queue.size() > 0 or (stream_live_active and not stream_live_done):
        if not stream_live_active and stream_live_queue.size() == 0:
            break
            
        if stream_live_queue.size() > 0:
            var text = stream_live_queue.pop_front()
            
            # 清理情绪标签等
            var mood_regex = RegEx.new()
            mood_regex.compile("(?i)(?:<|\\<|《|\\[|【)\\s*(mood|心情)\\s*[:：]\\s*([^>\\>》\\]】]+)\\s*(?:>|\\>|》|\\]|】)")
            var pure_text = mood_regex.sub(text, "", true).strip_edges()
            
            if pure_text == "":
                continue
                
            dialogue_name_label.text = GameDataManager.profile.char_name
            
            # 强制清理：只保留最开头的一个动作描述，移除其余所有动作描述
            var extract_regex = RegEx.new()
            extract_regex.compile("（.*?）|\\(.*?\\)")
            var matches = extract_regex.search_all(pure_text)
            if matches.size() > 0:
                var first_action = matches[0].get_string()
                var no_action_text = extract_regex.sub(pure_text, "", true).strip_edges()
                pure_text = first_action + " " + no_action_text
            
            var display_text = pure_text
            var color_regex_zh = RegEx.new()
            color_regex_zh.compile("（(.*?)）")
            display_text = color_regex_zh.sub(display_text, "[color=green]（$1）[/color]", true)
            var color_regex_en = RegEx.new()
            color_regex_en.compile("\\((.*?)\\)")
            display_text = color_regex_en.sub(display_text, "[color=green]($1)[/color]", true)
            
            dialogue_text.bbcode_enabled = true
            dialogue_text.text = display_text
            dialogue_text.visible_ratio = 0.0
            
            var current_cache_key = ""
            
            if _typewriter_tween:
                _typewriter_tween.kill()
            _typewriter_tween = create_tween()
            var dur = max(0.5, pure_text.length() * 0.05)
            _typewriter_tween.tween_property(dialogue_text, "visible_ratio", 1.0, dur)
            
            var is_tts_started = false
            var tts_text = pure_text
            var action_regex = RegEx.new()
            action_regex.compile("（.*?）|\\(.*?\\)")
            tts_text = action_regex.sub(tts_text, "", true).strip_edges()
            
            if GameDataManager.config.voice_enabled:
                var regex_tts = RegEx.new()
                regex_tts.compile("[a-zA-Z0-9\u4e00-\u9fa5]")
                if regex_tts.search(tts_text) != null:
                    is_tts_started = true
                    var options = {}
                    # 保存 cache key，为了后续写入历史记录关联语音播放 (简单用md5替代原来的内部方法)
                    current_cache_key = (tts_text + str(options)).md5_text()
                    TTSManager.synthesize(tts_text, options)
            
            # 这里必须等待一帧，确保 TTS 组件内部有机会触发 success 信号
            await get_tree().process_frame
            
            # 将该条切分后的消息存入历史记录中
            GameDataManager.history.add_message("char", pure_text, current_cache_key, "main_chat")
            
            if is_inside_tree():
                while _typewriter_tween and _typewriter_tween.is_valid() and _typewriter_tween.is_running():
                    if not stream_live_active:
                        break
                    await get_tree().process_frame
                    
            if not stream_live_active:
                break
                
            dialogue_text.visible_ratio = 1.0
            dialogue_text.visible_characters = -1
            
            _waiting_for_chat_click = false
                
            if is_tts_started and is_inside_tree() and audio_player:
                var wait_count = 0
                while not audio_player.playing and wait_count < 10:
                    if not stream_live_active:
                        break
                    await get_tree().create_timer(0.05).timeout
                    wait_count += 1
                    
                wait_count = 0
                while audio_player.playing and is_inside_tree() and wait_count < 1200:
                    if not stream_live_active:
                        if audio_player: audio_player.stop()
                        break
                    await get_tree().create_timer(0.05).timeout
                    wait_count += 1
                    
            if is_inside_tree():
                await get_tree().create_timer(1.0).timeout
                
            if audio_player and audio_player.playing:
                audio_player.stop()
                
            if not stream_live_active:
                break
        else:
            if is_inside_tree():
                await get_tree().create_timer(0.1).timeout

    stream_live_worker_running = false
    stream_live_active = false
    
    is_text_playback_finished = true
    
    if is_ending_chat or is_proactive_greeting:
        if audio_player and audio_player.playing:
            await audio_player.finished
        await get_tree().create_timer(1.0).timeout
        _close_chat_panel()
        if input_layer:
            input_layer.show()
        is_ending_chat = false
        is_proactive_greeting = false
        is_memory_revisit_active = false
        return
        
    _try_show_options()
    
    input_field.editable = true
    send_btn.disabled = false

func _on_chat_click_proceed_handler() -> void:
    pass

func _on_tts_success(audio_stream: AudioStream, text: String) -> void:
    if _story_mode_active:
        return
    if audio_player:
        audio_player.stream = audio_stream
        audio_player.play()

func _on_tts_failed(error_msg: String, text: String) -> void:
    if _story_mode_active:
        return
    print("MainScene TTS 失败: ", error_msg)

func _on_dialogue_panel_gui_input(event: InputEvent) -> void:
    if _story_mode_active:
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if dialogue_text.visible_ratio < 1.0:
            if _typewriter_tween:
                _typewriter_tween.kill()
            dialogue_text.visible_ratio = 1.0
            dialogue_text.visible_characters = -1
        elif _waiting_for_chat_click:
            _waiting_for_chat_click = false
            _chat_click_proceed.emit()

func _show_accumulated_stats() -> void:
    var display_keys = {
        "intimacy": "亲密",
        "trust": "信任"
    }
    
    for key in _accumulated_stats.keys():
        var val = _accumulated_stats[key]
        if abs(val) > 0.01: # Avoid floating point inaccuracies
            if display_keys.has(key):
                var sign_str = "+" if val > 0 else ""
                var formatted_val = sign_str + ("%.1f" % val)
                ToastManager.show_stat_toast(key, display_keys[key] + " " + formatted_val)
        _accumulated_stats[key] = 0.0 # reset for next time

func _on_emotion_response(response: Dictionary) -> void:
    if response.has("choices") and response["choices"].size() > 0:
        var reply = response["choices"][0]["message"]["content"]
        var regex = RegEx.new()
        regex.compile("(?i)(?:<|\\<|《|\\[|【)\\s*(intimacy|trust|亲密度|亲密变化|信任度|信任值|信任变化|openness|conscientiousness|extraversion|agreeableness|neuroticism)\\s*[:：]\\s*([^>\\>》\\]】]+)\\s*(?:>|\\>|》|\\]|】)")
        var matches = regex.search_all(reply)
        var has_changes = false
        var personality_feedback: Dictionary = {}
        
        for m in matches:
            var tag = m.get_string(1).to_lower()
            var val = m.get_string(2).strip_edges()
            var f_val = val.to_float()
            
            if tag == "intimacy" or tag.begins_with("亲密"):
                GameDataManager.profile.update_intimacy(f_val)
                has_changes = true
                _accumulated_stats["intimacy"] += f_val
            elif tag == "trust" or tag.begins_with("信任"):
                GameDataManager.profile.update_trust(f_val)
                has_changes = true
                _accumulated_stats["trust"] += f_val
            elif tag in ["openness", "conscientiousness", "extraversion", "agreeableness", "neuroticism"]:
                if f_val != 0.0:
                    has_changes = true
                    personality_feedback[tag] = float(personality_feedback.get(tag, 0.0)) + f_val
                    _accumulated_stats[tag] += f_val
        if not personality_feedback.is_empty():
            GameDataManager.personality_system.apply_personality_feedback(
                GameDataManager.profile,
                personality_feedback,
                "main_scene_emotion",
                {
                    "force_log": true
                }
            )
                    
        if has_changes:
            GameDataManager.profile.save_profile()
            if stats_panel and stats_panel.has_method("_update_ui"):
                stats_panel._update_ui()
            if top_status_panel and top_status_panel.has_method("_update_ui"):
                top_status_panel._update_ui()

func _on_options_response(response: Dictionary) -> void:
    if response.has("choices") and response["choices"].size() > 0:
        var reply = response["choices"][0]["message"]["content"]
        var json = JSON.new()
        
        # 提取可能的 JSON 代码块
        var json_str = reply
        var regex = RegEx.new()
        regex.compile("```(?:json)?\\s*(\\{[\\s\\S]*?\\})\\s*```")
        var match = regex.search(reply)
        if match:
            json_str = match.get_string(1).strip_edges()
        else:
            var start_idx = reply.find("{")
            var end_idx = reply.rfind("}")
            if start_idx != -1 and end_idx != -1 and end_idx > start_idx:
                json_str = reply.substr(start_idx, end_idx - start_idx + 1)
                
        if json.parse(json_str.strip_edges()) == OK:
            var data = json.get_data()
            if data is Dictionary and data.has("options") and data["options"] is Array:
                pending_options_data = data["options"]
                _try_show_options()
                return

func _try_show_options() -> void:
    if is_text_playback_finished and pending_options_data.size() > 0:
        QuickOptionListHelper.populate_option_items_with_index(
            quick_options_container,
            pending_options_data,
            _on_quick_option_selected
        )
        pending_options_data.clear()

func _on_quick_option_selected(text: String, index: int = -1) -> void:
    if index == 0:
        # 正面选项
        GameDataManager.profile.update_intimacy(5)
        GameDataManager.profile.update_trust(5)
    elif index == 1:
        # 负面选项
        GameDataManager.profile.update_intimacy(-5)
        GameDataManager.profile.update_trust(-5)
        
    input_field.text = text
    _on_send_pressed()

@onready var bg_container: Control = $BackgroundContainer
var current_bg_scene: Node = null

func _ready() -> void:
    # 动态加载主界面背景场景
    var main_bg_path = ImageManager.get_image_path("main_bg_scene")
    if main_bg_path == "" or not ResourceLoader.exists(main_bg_path):
        main_bg_path = "res://scenes/ui/main/backgrounds/locations/default_room_bg.tscn"
        
    _load_bg_scene(main_bg_path)
            
    if GameDataManager.config:
        GameDataManager.config.apply_settings()
        
    var window = get_window()
    window.close_requested.connect(_on_close_requested)
    
    hide_ui_button.pressed.connect(_on_hide_ui_pressed)
    camera_button.pressed.connect(_on_camera_pressed)
    phone_button.pressed.connect(_on_phone_pressed)
    affection_button.pressed.connect(_on_affection_pressed)
    rest_button.pressed.connect(_on_rest_pressed)
    main_action_button.pressed.connect(_on_main_action_pressed)
    desktop_pet_button.pressed.connect(_on_desktop_pet_pressed)
    diary_button.pressed.connect(_on_diary_pressed)
    pomodoro_button.pressed.connect(_on_pomodoro_pressed)
    if wardrobe_button:
        wardrobe_button.pressed.connect(_on_wardrobe_pressed)
    if wardrobe_panel:
        wardrobe_panel.outfit_changed.connect(_on_outfit_changed)
        
    if GameDataManager.profile and GameDataManager.profile.current_outfit != "default":
        call_deferred("_apply_saved_outfit")
    
    chat_button.pressed.connect(_on_main_chat_pressed)
    gift_button.pressed.connect(_on_gift_pressed)
    interactive_button.pressed.connect(_on_interactive_pressed)
    co_create_button.pressed.connect(_on_co_create_pressed)
    if end_chat_btn:
        end_chat_btn.pressed.connect(_on_end_chat_pressed)
    if history_btn:
        history_btn.pressed.connect(_on_history_pressed)
    if send_btn:
        send_btn.pressed.connect(_on_send_pressed)
    
    deepseek_client.chat_stream_started.connect(_on_chat_stream_started)
    deepseek_client.chat_stream_delta.connect(_on_chat_stream_delta)
    deepseek_client.chat_request_completed.connect(_on_chat_response)
    deepseek_client.options_request_completed.connect(_on_options_response)
    deepseek_client.emotion_request_completed.connect(_on_emotion_response)
    
    topic_panel.visible = false
    topic_panel.modulate.a = 0.0
    dialogue_panel.visible = false
    dialogue_panel.modulate.a = 0.0
    if dialogue_panel.has_signal("panel_clicked"):
        dialogue_panel.panel_clicked.connect(_on_dialogue_panel_gui_input)
    
    diary_notification.modulate.a = 0.0
    diary_notification.position.x = 1300 # Initial off-screen position
    
    audio_player = AudioStreamPlayer.new()
    audio_player.name = "MainTTSPlayer"
    add_child(audio_player)
    
    TTSManager.tts_success.connect(_on_tts_success)
    TTSManager.tts_failed.connect(_on_tts_failed)
            
    GameDataManager.character_switched.connect(_on_character_switched)
    
    if chat_button and GameDataManager.profile:
        chat_button.text = "与 " + GameDataManager.profile.char_name + " 聊天"
    
    var level_label = affection_button.get_node("HBoxContainer/LevelLabel")
    if level_label and GameDataManager.profile:
        var stage_conf = GameDataManager.profile.get_current_stage_config()
        level_label.text = stage_conf.get("stageTitle", "陌生人")
        
    # 动画：按钮点击弹性反馈 - 这些现在可以通过检查是否有 size 动态计算 pivot_offset
    # 或者我们在 inspector 中设置好的也会生效。这里保留以防有些按钮大小动态变化
    # 注意：已经在 _animate_button 里加了 btn.pivot_offset = btn.size / 2.0
    # 所以下面这些其实可以移除，但保留也没坏处
    camera_button.pivot_offset = camera_button.size / 2
    phone_button.pivot_offset = phone_button.size / 2
    rest_button.pivot_offset = rest_button.size / 2
    desktop_pet_button.pivot_offset = desktop_pet_button.size / 2
    hide_ui_button.pivot_offset = hide_ui_button.size / 2
    affection_button.pivot_offset = affection_button.size / 2
    if has_node("UIPanel/MainActionButton"):
        main_action_button.pivot_offset = main_action_button.size / 2
        
    # Setup neon effects
    _add_neon_effect_to_button(rest_button)
    if has_node("UIPanel/MainActionButton"):
        _add_neon_effect_to_button(main_action_button)
    
    # 恢复整个主窗口的鼠标输入响应，清除可能因为之前透明测试遗留的 passthrough 多边形
    if not is_queued_for_deletion():
        DisplayServer.window_set_mouse_passthrough(PackedVector2Array(), get_window().get_window_id())
    
    # Update StatsPanel explicitly when returning to main scene
    if stats_panel and stats_panel.has_method("_update_ui"):
        stats_panel._update_ui()
        
    if top_status_panel and top_status_panel.has_method("_update_ui"):
        top_status_panel._update_ui()
        
    # 尝试找回已存在的桌宠实例
    if get_tree().root.has_node("DesktopPet"):
        desktop_pet_instance = get_tree().root.get_node("DesktopPet")
        
    # 关联音乐播放器
    if is_instance_valid(music_player) and is_instance_valid(bgm):
        music_player.set_audio_player(bgm)
        
    # 初始化挂机检测
    var window_detector_path = "res://scripts/csharp/WindowDetector.cs"
    if FileAccess.file_exists(window_detector_path):
        var WindowDetectorObj = load(window_detector_path)
        if WindowDetectorObj:
            _window_detector = WindowDetectorObj.new()
            add_child(_window_detector)
            # 把当前主窗口的真实 HWND 传给 C# 层，用于精准判断
            var win_id = get_window().get_window_id()
            var hwnd = DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, win_id)
            if hwnd:
                _window_detector.call("SetMainHwnd", hwnd)
            
    _afk_timer = Timer.new()
    _afk_timer.wait_time = 1.0
    _afk_timer.autostart = true
    _afk_timer.timeout.connect(_check_afk_status)
    add_child(_afk_timer)

    # 先同步主按钮状态，避免下面的延迟逻辑执行期间仍保留旧文案和旧行为。
    _update_button_states_by_time()
    
    # 检查是否刚刚完成开场剧情，如果是则触发主动问候
    if GameDataManager.get_meta("just_finished_intro_story", false):
        GameDataManager.set_meta("just_finished_intro_story", false)
        # 延迟 1.5 秒再触发主动问候，使得场景过渡更加平滑
        await get_tree().create_timer(1.5).timeout
        _trigger_proactive_greeting()
    elif GameDataManager.history and GameDataManager.history.messages.size() > 0:
        await get_tree().create_timer(0.8).timeout
        _try_trigger_memory_revisit()

    if GameDataManager.story_time_manager:
        GameDataManager.story_time_manager.time_advanced.connect(_on_story_time_advanced)

func _process(delta: float) -> void:
    pass

func _update_button_states_by_time() -> void:
    if not GameDataManager.story_time_manager: return
    var date_dict = GameDataManager.story_time_manager.get_current_date_dict()
    var weekday = date_dict.weekday
    var current_hour = GameDataManager.story_time_manager.current_hour
    
    var interact_trigger_btn = null
    if is_instance_valid(current_bg_scene):
        interact_trigger_btn = current_bg_scene.get_node_or_null("InteractTriggerButton")
    
    # 1. 休息到周六或周日：外出解禁，课程安排禁用，显示互动触发按钮
    if weekday == 0 or weekday == 6:
        if main_action_button:
            main_action_button.disabled = false
            main_action_button.text = "外出"
        _main_action_mode = "map"
        if interact_group: interact_group.visible = false
        if interact_trigger_btn:
            interact_trigger_btn.visible = true
            interact_trigger_btn.modulate.a = 1.0
        if rest_button:
            rest_button.show()
            rest_button.disabled = false
    else:
        # 周一到周五
        # 3. 到了周五晚上八点（20:00 及之后）：课程安排和外出都禁用，显示互动触发按钮
        if weekday == 5 and current_hour >= 20:
            if main_action_button:
                main_action_button.disabled = true
                main_action_button.text = "行程安排"
            _main_action_mode = "disabled"
            if interact_group: interact_group.visible = false
            if interact_trigger_btn:
                interact_trigger_btn.visible = true
                interact_trigger_btn.modulate.a = 1.0
            if rest_button:
                rest_button.show()
                rest_button.disabled = false
        else:
            # 2. 周内（周一至周五 20:00前）：外出禁用，隐藏互动触发按钮和互动组，只能进行课程安排
            if main_action_button:
                main_action_button.disabled = false
                main_action_button.text = "行程安排"
            _main_action_mode = "schedule"
            if interact_group: interact_group.visible = false
            if interact_trigger_btn: interact_trigger_btn.visible = false
            if rest_button:
                rest_button.hide()
                rest_button.disabled = true

func _on_story_time_advanced(_days: int, _current_period: String) -> void:
    _update_button_states_by_time()

func _trigger_proactive_greeting() -> void:
    var event_manager = get_node_or_null("/root/EventManager")
    if event_manager and event_manager.has_method("execute_event"):
        event_manager.execute_event("proactive_greeting")

func _try_trigger_memory_revisit() -> void:
    if dialogue_panel.visible or is_memory_revisit_active:
        return
    if GameDataManager.memory_manager == null:
        return
    var trigger_context = GameDataManager.memory_manager.build_story_memory_context()
    var revisit_data = GameDataManager.memory_manager.get_revisit_event_candidate(trigger_context)
    if revisit_data.is_empty():
        return
    GameDataManager.memory_manager.mark_memory_revisited(revisit_data.get("memory_id", ""), trigger_context)
    var event_manager = get_node_or_null("/root/EventManager")
    if event_manager and event_manager.has_method("execute_event"):
        event_manager.execute_event("memory_revisit", revisit_data)

func start_memory_revisit(revisit_data: Dictionary) -> void:
    if revisit_data.is_empty():
        return
    is_memory_revisit_active = true
    
    if _ui_tween:
        _ui_tween.kill()
    _ui_tween = create_tween()
    _ui_tween.tween_property(ui_panel, "modulate:a", 0.0, 0.3)
    _ui_tween.tween_callback(func(): ui_panel.visible = false)
    
    if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
        current_bg_scene.set_ui_hidden(true)
    
    dialogue_panel.visible = true
    dialogue_panel.modulate.a = 0.0
    var d_tween = create_tween()
    d_tween.tween_property(dialogue_panel, "modulate:a", 1.0, 0.3)
    
    dialogue_name_label.text = GameDataManager.profile.char_name
    dialogue_text.text = "..."
    input_field.text = ""
    input_field.editable = false
    send_btn.disabled = true
    
    if end_chat_btn:
        end_chat_btn.show()
    if history_btn:
        history_btn.show()
    if input_layer:
        input_layer.show()
    
    for child in quick_options_container.get_children():
        child.queue_free()
    
    var user_msg = GameDataManager.prompt_manager.build_memory_revisit_prompt(GameDataManager.profile, revisit_data, revisit_data.get("trigger_context", {}))
    deepseek_client.send_chat_message_stream(user_msg, "main_chat")

func start_proactive_greeting(prompt_type: String) -> void:
    is_proactive_greeting = true
    proactive_greeting_step = 0
    
    if _ui_tween:
        _ui_tween.kill()
    _ui_tween = create_tween()
    _ui_tween.tween_property(ui_panel, "modulate:a", 0.0, 0.3)
    _ui_tween.tween_callback(func(): ui_panel.visible = false)
    
    if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
        current_bg_scene.set_ui_hidden(true)
    
    dialogue_panel.visible = true
    dialogue_panel.modulate.a = 0.0
    var d_tween = create_tween()
    d_tween.tween_property(dialogue_panel, "modulate:a", 1.0, 0.3)
    
    dialogue_name_label.text = GameDataManager.profile.char_name
    dialogue_text.text = "..."
    input_field.text = ""
    input_field.editable = false
    send_btn.disabled = true
    
    # 隐藏不需要的按钮和输入框
    if end_chat_btn:
        end_chat_btn.hide()
    if history_btn:
        history_btn.hide()
    if input_layer:
        input_layer.hide()
    
    for child in quick_options_container.get_children():
        child.queue_free()
        
    # 使用传入的 prompt_type 生成对应的主动问候 prompt
    var user_msg = GameDataManager.prompt_manager.build_proactive_greeting_prompt(GameDataManager.profile, prompt_type)
    deepseek_client.send_chat_message_stream(user_msg, "main_chat")

func start_farewell() -> void:
    if is_ending_chat:
        return
        
    if deepseek_client._chat_stream_active:
        deepseek_client._stop_chat_stream()
        
    stream_live_active = false
    stream_live_worker_running = false
    stream_live_queue.clear()
    
    if audio_player and audio_player.playing:
        audio_player.stop()
        
    if _typewriter_tween:
        _typewriter_tween.kill()
        
    is_ending_chat = true
    
    input_field.editable = false
    send_btn.disabled = true
    
    if end_chat_btn:
        end_chat_btn.hide()
    if history_btn:
        history_btn.hide()
    if input_layer:
        input_layer.hide()
        
    for child in quick_options_container.get_children():
        child.queue_free()
        
    var prompt = "【系统提示：玩家想要结束对话。请结合你当前的身份、心情和性格，说一句简短的结束语作为告别（必须包含括号动作描写）。绝对不要提到你是AI。】"
    deepseek_client.send_chat_message_stream(prompt, "main_chat")

func _add_neon_effect_to_button(btn: Button) -> void:
    if btn.name == "RestButton":
        var style = btn.get_theme_stylebox("normal").duplicate()
        btn.add_theme_stylebox_override("normal", style)
        btn.add_theme_stylebox_override("hover", style)
        btn.add_theme_stylebox_override("pressed", style)
        btn.add_theme_stylebox_override("focus", style)
        style.border_color = Color(0, 0, 0, 0)
        style.shadow_color = Color(0, 0, 0, 0)
        style.shadow_size = 0
        btn.set_meta("neon_style", style)
    elif btn.name == "MainActionButton":
        var mat = btn.material.duplicate() as ShaderMaterial
        var style = btn.get_theme_stylebox("normal")
        var bg_color = Color(0.15, 0.16, 0.18, 0.7) # 默认的半透明灰色
        if style is StyleBoxFlat:
            bg_color = style.bg_color
            
        btn.material = null
        
        var empty_style = StyleBoxEmpty.new()
        btn.add_theme_stylebox_override("normal", empty_style)
        btn.add_theme_stylebox_override("hover", empty_style)
        btn.add_theme_stylebox_override("pressed", empty_style)
        btn.add_theme_stylebox_override("focus", empty_style)
        
        var bg_rect = ColorRect.new()
        bg_rect.color = bg_color # 恢复半透明底色，让 Shader 去裁剪它
        
        var pad = 0.15
        var h = btn.size.y / (1.0 - 2.0 * pad)
        var w = btn.size.x + h * 2.0 * pad
        bg_rect.size = Vector2(w, h)
        bg_rect.position = Vector2(-h * pad, -h * pad)
        bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
        bg_rect.show_behind_parent = true
        
        mat.set_shader_parameter("padding", pad)
        mat.set_shader_parameter("aspect_ratio", w / h)
        mat.set_shader_parameter("border_width", 0.0)
        mat.set_shader_parameter("border_color", Color(0, 0, 0, 0))
        mat.set_shader_parameter("glow_size", 0.0)
        mat.set_shader_parameter("glow_color", Color(0, 0, 0, 0))
        
        # 关键修复：把原本的纯色背景色通过 shader parameter 传给 shader，让 shader 自己去画内部的半透明底色！
        if mat.get_shader().get_code().find("uniform vec4 bg_color") != -1:
            mat.set_shader_parameter("bg_color", bg_color)
        else:
            # 如果 shader 没有暴露 bg_color 属性，我们依然依赖 bg_rect 的颜色，但是要确保原本按钮不要画方块背景
            pass
        
        bg_rect.material = mat
        btn.add_child(bg_rect)
        btn.set_meta("neon_mat", mat)
        
    btn.mouse_entered.connect(_on_neon_btn_hover.bind(btn, true))
    btn.mouse_exited.connect(_on_neon_btn_hover.bind(btn, false))
    btn.button_down.connect(_on_neon_btn_press.bind(btn, true))
    btn.button_up.connect(_on_neon_btn_press.bind(btn, false))

func _on_neon_btn_hover(btn: Button, is_hover: bool) -> void:
    if btn.has_meta("neon_tween"):
        var tween = btn.get_meta("neon_tween") as Tween
        if tween: tween.kill()
    if btn.has_meta("neon_loop"):
        var loop = btn.get_meta("neon_loop") as Tween
        if loop: loop.kill()
        
    if btn.button_pressed: return
    
    var tween = create_tween().set_parallel(true)
    btn.set_meta("neon_tween", tween)
    
    var target_color = Color(0.0, 0.8, 1.0, 0.8) # 青蓝色
    var target_border = 1
    var target_shadow = 2
    var target_shader_border = 0.008
    var target_shader_glow = 0.015
    
    if not is_hover:
        target_color = Color(0, 0, 0, 0)
        target_border = 0
        target_shadow = 0
        target_shader_border = 0.0
        target_shader_glow = 0.0
        
    if btn.has_meta("neon_style"):
        var style = btn.get_meta("neon_style") as StyleBoxFlat
        tween.tween_property(style, "border_color", target_color, 0.3)
        tween.tween_property(style, "shadow_color", target_color, 0.3)
        tween.tween_property(style, "border_width_left", target_border, 0.3)
        tween.tween_property(style, "border_width_top", target_border, 0.3)
        tween.tween_property(style, "border_width_right", target_border, 0.3)
        tween.tween_property(style, "border_width_bottom", target_border, 0.3)
        tween.tween_property(style, "shadow_size", target_shadow, 0.3)
    elif btn.has_meta("neon_mat"):
        var mat = btn.get_meta("neon_mat") as ShaderMaterial
        tween.tween_method(func(v): mat.set_shader_parameter("border_color", v), mat.get_shader_parameter("border_color"), target_color, 0.3)
        tween.tween_method(func(v): mat.set_shader_parameter("glow_color", v), mat.get_shader_parameter("glow_color"), target_color, 0.3)
        tween.tween_method(func(v): mat.set_shader_parameter("border_width", v), mat.get_shader_parameter("border_width"), target_shader_border, 0.3)
        tween.tween_method(func(v): mat.set_shader_parameter("glow_size", v), mat.get_shader_parameter("glow_size"), target_shader_glow, 0.3)
        
    if is_hover:
        tween.chain().tween_callback(_start_neon_loop.bind(btn, Color(0.0, 0.8, 1.0, 0.8), Color(1.0, 0.0, 0.5, 0.8), 1.0))

func _on_neon_btn_press(btn: Button, is_pressed: bool) -> void:
    if btn.has_meta("neon_tween"):
        var tween = btn.get_meta("neon_tween") as Tween
        if tween: tween.kill()
    if btn.has_meta("neon_loop"):
        var loop = btn.get_meta("neon_loop") as Tween
        if loop: loop.kill()
        
    var tween = create_tween().set_parallel(true)
    btn.set_meta("neon_tween", tween)
    
    if is_pressed:
        var target_color = Color(1.0, 0.9, 0.2, 1.0) # 黄色/爆亮
        if btn.has_meta("neon_style"):
            var style = btn.get_meta("neon_style") as StyleBoxFlat
            tween.tween_property(style, "border_color", target_color, 0.1)
            tween.tween_property(style, "shadow_color", target_color, 0.1)
            tween.tween_property(style, "border_width_left", 1, 0.1)
            tween.tween_property(style, "border_width_top", 1, 0.1)
            tween.tween_property(style, "border_width_right", 1, 0.1)
            tween.tween_property(style, "border_width_bottom", 1, 0.1)
            tween.tween_property(style, "shadow_size", 2, 0.1)
        elif btn.has_meta("neon_mat"):
            var mat = btn.get_meta("neon_mat") as ShaderMaterial
            tween.tween_method(func(v): mat.set_shader_parameter("border_color", v), mat.get_shader_parameter("border_color"), target_color, 0.1)
            tween.tween_method(func(v): mat.set_shader_parameter("glow_color", v), mat.get_shader_parameter("glow_color"), target_color, 0.1)
            tween.tween_method(func(v): mat.set_shader_parameter("border_width", v), mat.get_shader_parameter("border_width"), 0.008, 0.1)
            tween.tween_method(func(v): mat.set_shader_parameter("glow_size", v), mat.get_shader_parameter("glow_size"), 0.015, 0.1)
            
        tween.chain().tween_callback(_start_neon_loop.bind(btn, Color(1.0, 0.9, 0.2, 1.0), Color(1.0, 0.2, 0.2, 1.0), 0.2))
    else:
        _on_neon_btn_hover(btn, btn.is_hovered())

func _start_neon_loop(btn: Button, color1: Color, color2: Color, duration: float) -> void:
    var loop = create_tween().set_loops()
    btn.set_meta("neon_loop", loop)
    
    if btn.has_meta("neon_style"):
        var style = btn.get_meta("neon_style") as StyleBoxFlat
        loop.tween_property(style, "border_color", color2, duration)
        loop.parallel().tween_property(style, "shadow_color", color2, duration)
        loop.tween_property(style, "border_color", color1, duration)
        loop.parallel().tween_property(style, "shadow_color", color1, duration)
    elif btn.has_meta("neon_mat"):
        var mat = btn.get_meta("neon_mat") as ShaderMaterial
        loop.tween_method(func(v): mat.set_shader_parameter("border_color", v), color1, color2, duration)
        loop.parallel().tween_method(func(v): mat.set_shader_parameter("glow_color", v), color1, color2, duration)
        loop.tween_method(func(v): mat.set_shader_parameter("border_color", v), color2, color1, duration)
        loop.parallel().tween_method(func(v): mat.set_shader_parameter("glow_color", v), color2, color1, duration)

func _check_afk_status() -> void:
    var window = get_window()
    var is_minimized = window.mode == Window.MODE_MINIMIZED
    
    var is_covered_fullscreen = false
    if is_instance_valid(_window_detector):
        is_covered_fullscreen = _window_detector.call("IsAnyFullScreenWindowCovering")
        
    var should_be_afk = is_minimized or is_covered_fullscreen
    
    if should_be_afk != _is_afk:
        _is_afk = should_be_afk
        if _is_afk:
            _on_enter_afk()
        else:
            _on_exit_afk()

func _on_enter_afk() -> void:
    print("[MainScene] 视为主场景后台挂机，暂停音乐与进度")
    if bgm:
        bgm.stream_paused = true
        
func _on_exit_afk() -> void:
    print("[MainScene] 退出后台挂机模式，恢复音乐与进度")
    if bgm:
        bgm.stream_paused = false

func _on_desktop_pet_pressed() -> void:
    _animate_button(desktop_pet_button)
    if is_instance_valid(desktop_pet_instance):
        # 桌宠已存在，关闭它。先隐藏以防止输入系统报错
        desktop_pet_instance.hide()
        desktop_pet_instance.queue_free()
        desktop_pet_instance = null
    else:
        # 创建桌宠，直接挂载在 root 下，这样切换场景也不会被销毁
        var DesktopPetObj = load("res://scenes/ui/desktop_pet/desktop_pet.tscn")
        desktop_pet_instance = DesktopPetObj.instantiate()
        get_tree().root.add_child(desktop_pet_instance)

func _on_incoming_call_accepted(char_id: String, is_video: bool, is_fixed: bool = false) -> void:
    # 接听电话：打开手机面板
    if mobile_interface_instance == null or not mobile_interface_instance.visible:
        _on_phone_pressed()
        
    # 告诉手机面板直接跳转到通话界面
    mobile_interface_instance.open_call_directly(char_id, is_video, is_fixed)

func _on_phone_pressed() -> void:
    _animate_button(phone_button)
    if mobile_interface_instance == null:
        var MobileInterfaceObj = load("res://scenes/ui/mobile/mobile_interface.tscn")
        mobile_interface_instance = MobileInterfaceObj.instantiate()
        add_child(mobile_interface_instance)
        mobile_interface_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        mobile_interface_instance.app_opened.connect(_on_mobile_app_opened)
        mobile_interface_instance.phone_closing.connect(_on_phone_closing)
    
    if is_instance_valid(chat_scene_instance) and chat_scene_instance.visible:
        mobile_interface_instance.get_parent().remove_child(mobile_interface_instance)
        add_child(mobile_interface_instance)
        move_child(mobile_interface_instance, -1)
    
    if _ui_tween:
        _ui_tween.kill()
    _ui_tween = create_tween()
    _ui_tween.set_parallel(true)
    _ui_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    _ui_tween.tween_property(ui_panel, "modulate:a", 0.0, 0.4)
    _ui_tween.tween_property(bg_container, "position:x", -245.0, 0.4)
    _ui_tween.chain().tween_callback(func(): ui_panel.visible = false)
    
    if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
        current_bg_scene.set_ui_hidden(true)
        
    mobile_interface_instance.show_phone()

func _on_phone_closing() -> void:
    if _ui_tween:
        _ui_tween.kill()
    ui_panel.visible = true
    _ui_tween = create_tween()
    _ui_tween.set_parallel(true)
    _ui_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    _ui_tween.tween_property(ui_panel, "modulate:a", 1.0, 0.4)
    _ui_tween.tween_property(bg_container, "position:x", 0.0, 0.4)
    
    if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
        current_bg_scene.set_ui_hidden(false)

func _on_mobile_app_opened(app_name: String) -> void:
    pass # 目前 archive 由 mobile_interface 自己处理，如果有其他 app 可以加在这里

func _on_main_action_pressed() -> void:
    _animate_button(main_action_button)
    if _main_action_mode == "map":
        print("[MainScene] Map button pressed")
        if GameDataManager.profile:
            if GameDataManager.profile.neuroticism >= 80.0:
                var ConfirmDialogObj = load("res://scenes/ui/common/confirm_dialog.tscn")
                var confirm_dialog = ConfirmDialogObj.instantiate()
                add_child(confirm_dialog)
                confirm_dialog.setup("她现在的状态不太好，把自己锁在房间\n里不愿意出门...\n(需要通过聊天或互动安抚情绪)")
                if confirm_dialog.cancel_button:
                    confirm_dialog.cancel_button.hide()
                return
        SceneTransitionManager.transition_to_scene("res://scenes/ui/map/core/world_map_scene.tscn")
    elif _main_action_mode == "schedule":
        if activity_panel_instance == null:
            var ActivityPanelObj = load("res://scenes/ui/activity/activity_panel.tscn")
            activity_panel_instance = ActivityPanelObj.instantiate()
            add_child(activity_panel_instance)
            activity_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        activity_panel_instance.show_panel()

func _load_bg_scene(path: String) -> void:
    if current_bg_scene != null:
        current_bg_scene.queue_free()
        current_bg_scene = null
        
    var bg_packed = load(path)
    if bg_packed:
        current_bg_scene = bg_packed.instantiate()
        bg_container.add_child(current_bg_scene)
        if current_bg_scene.has_signal("background_ready"):
            current_bg_scene.background_ready.connect(func(): print("[MainScene] Background Scene Ready: ", path))
            
        var story_btn = current_bg_scene.get_node_or_null("StoryButton")
        if story_btn:
            story_btn.pressed.connect(_on_galchat_pressed)
            story_btn.pivot_offset = story_btn.size / 2
            
        var interact_trigger_btn = current_bg_scene.get_node_or_null("InteractTriggerButton")
        if interact_trigger_btn:
            interact_trigger_btn.pressed.connect(_on_interact_trigger_pressed)
            interact_trigger_btn.pivot_offset = interact_trigger_btn.size / 2

func _on_interact_trigger_pressed() -> void:
    if is_instance_valid(current_bg_scene) and current_bg_scene.has_node("InteractTriggerButton"):
        var btn = current_bg_scene.get_node("InteractTriggerButton")
        _animate_button(btn)
        var tween = create_tween()
        tween.tween_property(btn, "modulate:a", 0.0, 0.2)
        tween.tween_callback(func(): btn.visible = false)
        
    if interact_group:
        interact_group.modulate.a = 0.0
        interact_group.visible = true
        var g_tween = create_tween()
        g_tween.tween_property(interact_group, "modulate:a", 1.0, 0.3)

func _on_galchat_pressed() -> void:
    if is_instance_valid(current_bg_scene) and current_bg_scene.has_node("StoryButton"):
        _animate_button(current_bg_scene.get_node("StoryButton"))
    
    _story_mode_active = true
    
    if topic_panel and topic_panel.visible:
        var t_tween = create_tween()
        t_tween.tween_property(topic_panel, "modulate:a", 0.0, 0.2)
        t_tween.tween_callback(func(): topic_panel.visible = false)
    
    if _ui_tween:
        _ui_tween.kill()
    _ui_tween = create_tween()
    _ui_tween.tween_property(ui_panel, "modulate:a", 0.0, 0.3)
    _ui_tween.tween_callback(func(): ui_panel.visible = false)
    
    if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
        current_bg_scene.set_ui_hidden(true)
    
    if chat_scene_instance == null:
        chat_scene_instance = Control.new()
        chat_scene_instance.name = "EmbeddedDialogueManager"
        chat_scene_instance.visible = false
        chat_scene_instance.mouse_filter = Control.MOUSE_FILTER_IGNORE
        chat_scene_instance.set_script(load("res://scripts/dialogue/dialogue_manager.gd"))
        chat_scene_instance.ui_panel_path = NodePath("../DialoguePanel")
        chat_scene_instance.dialogue_panel_path = NodePath("../DialoguePanel")
        chat_scene_instance.audio_player_path = NodePath("../MainTTSPlayer")
        chat_scene_instance.click_blocker_path = NodePath("")
        chat_scene_instance.character_layer_path = NodePath("")
        chat_scene_instance.free_chat_info_layer_path = NodePath("")
        add_child(chat_scene_instance)
        move_child(chat_scene_instance, -1)
        chat_scene_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        chat_scene_instance.chat_closed.connect(_on_chat_closed)
        
    chat_scene_instance.show_panel()
    if bgm.playing:
        bgm.stop()

func _on_chat_closed() -> void:
    _story_mode_active = false
    
    if dialogue_panel and dialogue_panel.visible:
        var d_tween = create_tween()
        d_tween.tween_property(dialogue_panel, "modulate:a", 0.0, 0.2)
        d_tween.tween_callback(func(): dialogue_panel.visible = false)
    
    if _ui_tween:
        _ui_tween.kill()
    ui_panel.visible = true
    ui_panel.modulate.a = 0.0
    _ui_tween = create_tween()
    _ui_tween.tween_property(ui_panel, "modulate:a", 1.0, 0.3)
    
    if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
        current_bg_scene.set_ui_hidden(false)
    
    if not bgm.playing:
        bgm.play()

func _on_history_pressed() -> void:
    if _story_mode_active:
        return
    if history_panel_instance == null:
        var HistoryPanelObj = load("res://scenes/ui/history/history_panel.tscn")
        history_panel_instance = HistoryPanelObj.instantiate()
        add_child(history_panel_instance)
        history_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        
        # We need to hook up the close button of history panel manually if it doesn't self-close
        var close_btn = history_panel_instance.get_node_or_null("HistoryTopBar/HistoryCloseButton")
        if close_btn:
            close_btn.pressed.connect(func(): history_panel_instance.hide())
            
    history_panel_instance.show()
    _populate_history_ui()

func _populate_history_ui() -> void:
    if not history_panel_instance: return
    var history_vbox = history_panel_instance.get_node_or_null("ScrollContainer/VBoxContainer")
    if not history_vbox: return
    
    # 清空现有子节点
    for child in history_vbox.get_children():
        child.queue_free()
        
    var HISTORY_ITEM_SCENE = load("res://scenes/ui/history/history_item.tscn")
    var messages = GameDataManager.history.get_messages_by_type("main_chat")
    for msg in messages:
        var item = HISTORY_ITEM_SCENE.instantiate()
        history_vbox.add_child(item)
        item.setup(msg)
        item.play_voice_requested.connect(_play_cached_voice)
        
    # 延迟一帧等待容器布局完成，然后滚动到底部
    if is_inside_tree():
        await get_tree().process_frame
    var scroll = history_panel_instance.get_node_or_null("ScrollContainer")
    if scroll:
        var v_scroll = scroll.get_v_scroll_bar()
        v_scroll.value = v_scroll.max_value

func _play_cached_voice(cache_key: String) -> void:
    var cache_path = "user://tts_cache/" + cache_key + ".mp3"
    if FileAccess.file_exists(cache_path):
        var file = FileAccess.open(cache_path, FileAccess.READ)
        if file:
            var data = file.get_buffer(file.get_length())
            var stream = AudioStreamMP3.new()
            stream.data = data
            if audio_player:
                audio_player.stream = stream
                audio_player.play()
    else:
        print("未找到语音缓存: ", cache_key)

func _on_close_requested() -> void:
    pass

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        var desktop_pet = get_tree().root.get_node_or_null("DesktopPet")
        if is_instance_valid(desktop_pet) and desktop_pet.visible:
            # Godot 4 中，主场景是 Control 时，我们应该隐藏对应的 Window
            get_tree().root.hide()
        else:
            get_tree().quit()

var camera_panel_instance = null

func _on_camera_pressed() -> void:
    _animate_button(camera_button)
    if camera_panel_instance == null:
        var CameraPanelObj = load("res://scenes/ui/mobile/camera_panel.tscn")
        camera_panel_instance = CameraPanelObj.instantiate()
        get_tree().get_root().add_child(camera_panel_instance)
        camera_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        
        get_tree().get_root().move_child(camera_panel_instance, -1)
        
    camera_panel_instance.show_panel()
    
    if _ui_tween:
        _ui_tween.kill()
    _ui_tween = create_tween()
    _ui_tween.tween_property(ui_panel, "modulate:a", 0.0, 0.3)
    _ui_tween.tween_callback(func(): ui_panel.visible = false)
    
    if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
        current_bg_scene.set_ui_hidden(true)
        
    if camera_panel_instance.has_signal("camera_closed") and not camera_panel_instance.camera_closed.is_connected(_on_camera_closed):
        camera_panel_instance.camera_closed.connect(_on_camera_closed)

func _on_camera_closed() -> void:
    if _ui_tween:
        _ui_tween.kill()
    ui_panel.visible = true
    _ui_tween = create_tween()
    _ui_tween.tween_property(ui_panel, "modulate:a", 1.0, 0.3)
    
    if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
        current_bg_scene.set_ui_hidden(false)

func _on_affection_pressed() -> void:
    _animate_button(affection_button)
    var was_visible = false
    if affection_panel_instance == null:
        var AffectionPanelObj = load("res://scenes/ui/story/affection_panel.tscn")
        affection_panel_instance = AffectionPanelObj.instantiate()
        ui_panel.add_child(affection_panel_instance)
        was_visible = false # 初次实例化，视为原本是隐藏的
    else:
        was_visible = affection_panel_instance.visible
        
    if not was_visible:
        # 修改为显示在按钮下方靠右位置
        var button_width = affection_button.size.x
        var panel_size = affection_panel_instance.size
        
        # 强制刷新一下 panel size
        affection_panel_instance.reset_size()
        
        affection_panel_instance.position = Vector2(
            affection_button.position.x + button_width - affection_panel_instance.size.x, # 右对齐
            affection_button.position.y + affection_button.size.y + 10 # 下方偏移10
        )
        affection_panel_instance.show()
    else:
        affection_panel_instance.hide()

func _on_diary_pressed() -> void:
    _animate_button(diary_button)
    diary_panel.show_diary()

func _on_pomodoro_pressed() -> void:
    _animate_button(pomodoro_button)
    if pomodoro_panel_instance == null:
        var PomodoroPanelObj = load("res://scenes/ui/main/pomodoro_panel.tscn")
        pomodoro_panel_instance = PomodoroPanelObj.instantiate()
        add_child(pomodoro_panel_instance)
        pomodoro_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    pomodoro_panel_instance.show()

func _on_wardrobe_pressed() -> void:
    if is_instance_valid(wardrobe_button):
        _animate_button(wardrobe_button)
    if is_instance_valid(wardrobe_panel):
        wardrobe_panel.show()

func _apply_saved_outfit() -> void:
    if is_instance_valid(wardrobe_panel):
        if wardrobe_panel.outfits_data.is_empty():
            wardrobe_panel._load_data()
        _on_outfit_changed(GameDataManager.profile.current_outfit)

func _on_outfit_changed(new_id: String) -> void:
    print("[MainScene] 换装完成，当前服装 ID: ", new_id)
    # 替换背景里的立绘
    var bg_container = $BackgroundContainer
    if bg_container.get_child_count() > 0:
        var bg = bg_container.get_child(0)
        if bg and bg.has_node("LunaAni"):
            var luna_ani = bg.get_node("LunaAni")
            if is_instance_valid(luna_ani) and is_instance_valid(wardrobe_panel):
                # 从 wardrobe_panel 的数据中寻找新衣服的 sprite
                for outfit in wardrobe_panel.outfits_data:
                    if outfit.get("id") == new_id:
                        var sprite_path = outfit.get("sprite", "")
                        if sprite_path != "" and ResourceLoader.exists(sprite_path):
                            var res = load(sprite_path)
                            if res is SpriteFrames:
                                luna_ani.sprite_frames = res
                                luna_ani.play("default")
                            elif res is Texture2D:
                                var frames = SpriteFrames.new()
                                frames.add_animation("default")
                                frames.add_frame("default", res)
                                luna_ani.sprite_frames = frames
                                luna_ani.play("default")
                        break



func _on_location_selected(location_id: String):
    print("[MainScene] Transitioning to location: ", location_id)
    # The actual transition is currently handled inside world_map_scene.gd
    # But we can also handle hiding main UI here if needed

func show_diary_notification() -> void:
    var tween = create_tween().set_parallel(true)
    tween.tween_property(diary_notification, "position:x", 1280 - 300, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    tween.tween_property(diary_notification, "modulate:a", 1.0, 0.5)
    
    var out_tween = create_tween()
    out_tween.tween_interval(3.0)
    out_tween.tween_property(diary_notification, "position:x", 1300, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
    out_tween.parallel().tween_property(diary_notification, "modulate:a", 0.0, 0.5)

func _on_hide_ui_pressed() -> void:
    _animate_button(hide_ui_button)
    if _ui_tween:
        _ui_tween.kill()
    _ui_tween = create_tween()
    _ui_tween.tween_property(ui_panel, "modulate:a", 0.0, 0.3)
    _ui_tween.tween_callback(func(): ui_panel.visible = false)
    
    if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
        current_bg_scene.set_ui_hidden(true)

func _unhandled_input(event: InputEvent) -> void:
    if _story_mode_active:
        if not (event is InputEventKey and event.pressed and event.keycode == KEY_F12):
            return
    if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
        var root = get_tree().root
        var debug_panel = root.get_node_or_null("GlobalDebugPanel")
        if debug_panel == null:
            var DebugPanelObj = load("res://scenes/ui/story/debug_panel.tscn")
            debug_panel = DebugPanelObj.instantiate()
            debug_panel.name = "GlobalDebugPanel"
            root.add_child(debug_panel)
            debug_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
            
            # 如果当前是主场景，连上信号
            debug_panel.stage_changed.connect(func(stage: int):
                GameDataManager.profile.force_set_stage(stage)
                GameDataManager.history.messages.clear()
                GameDataManager.history.save_history()
                print("【Debug】强制切换情感阶段至：" + str(stage))
            )
            debug_panel.show_panel() # Instantiate and show directly
        elif debug_panel.visible:
            debug_panel.hide()
        else:
            debug_panel.show_panel()
        get_viewport().set_input_as_handled()
        return
        
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        # 如果手机界面存在且正在显示相机，不要显示UI
        if camera_panel_instance and camera_panel_instance.visible:
            return
            
        # 如果手机界面正在显示，不要因为点击而恢复UI
        if mobile_interface_instance and mobile_interface_instance.visible:
            return
            
        # 检查是否需要收起互动组
        if interact_group and interact_group.visible and interact_group.modulate.a > 0.99:
            var tween = create_tween()
            tween.tween_property(interact_group, "modulate:a", 0.0, 0.2)
            tween.tween_callback(func(): interact_group.visible = false)
            
            if is_instance_valid(current_bg_scene) and current_bg_scene.has_node("InteractTriggerButton"):
                var btn = current_bg_scene.get_node("InteractTriggerButton")
                btn.visible = true
                var b_tween = create_tween()
                b_tween.tween_property(btn, "modulate:a", 1.0, 0.3)
            
            get_viewport().set_input_as_handled()
            return
            
        if not ui_panel.visible or ui_panel.modulate.a < 0.99:
            get_viewport().set_input_as_handled()
            if _ui_tween:
                _ui_tween.kill()
            ui_panel.visible = true
            _ui_tween = create_tween()
            _ui_tween.tween_property(ui_panel, "modulate:a", 1.0, 0.3)
            
            if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
                current_bg_scene.set_ui_hidden(false)
            
            if topic_panel and topic_panel.visible:
                var t_tween = create_tween()
                t_tween.tween_property(topic_panel, "modulate:a", 0.0, 0.3)
                t_tween.tween_callback(func(): topic_panel.visible = false)
            
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
        # 如果话题面板正在显示，右键点击则隐藏它并返回主界面UI
        if topic_panel and topic_panel.visible:
            get_viewport().set_input_as_handled()
            var t_tween = create_tween()
            t_tween.tween_property(topic_panel, "modulate:a", 0.0, 0.3)
            t_tween.tween_callback(func(): topic_panel.visible = false)
            
            if _ui_tween:
                _ui_tween.kill()
            ui_panel.visible = true
            _ui_tween = create_tween()
            _ui_tween.tween_property(ui_panel, "modulate:a", 1.0, 0.3)
            
            if is_instance_valid(current_bg_scene) and current_bg_scene.has_method("set_ui_hidden"):
                current_bg_scene.set_ui_hidden(false)
func _on_character_switched(char_id: String) -> void:
    # 角色切换后更新主界面的面板（特别是数值显示）
    if stats_panel and stats_panel.has_method("_update_ui"):
        stats_panel._update_ui()
        
    if top_status_panel and top_status_panel.has_method("_update_ui"):
        top_status_panel._update_ui()
    
    # 更新右上角的 AffectionPanel
    if is_instance_valid(affection_panel_instance) and affection_panel_instance.has_method("update_ui"):
        affection_panel_instance.update_ui()
        
    if chat_button and GameDataManager.profile:
        chat_button.text = "与 " + GameDataManager.profile.char_name + " 聊天"
        
    # 注意：ChatScene 的更新由它自己内部监听信号处理

func _animate_button(btn: Button) -> void:
    if btn == null:
        return
    btn.pivot_offset = btn.size / 2.0
    var tween = create_tween()
    tween.tween_property(btn, "scale", Vector2(0.9, 0.9), 0.05)
    tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.05)
    tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.05)
