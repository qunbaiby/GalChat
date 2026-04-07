extends Control

@onready var day_label: Label = $CenterContainer/VBoxContainer/DayLabel
@onready var activity_label: Label = $CenterContainer/VBoxContainer/ActivityLabel
@onready var result_label: Label = $CenterContainer/VBoxContainer/ResultLabel
@onready var next_button: Button = $CenterContainer/VBoxContainer/NextButton

var scheduled_activities: Array = []
var current_day: int = 1
var is_finished: bool = false

# 用于将英文属性名映射为中文展示
const STAT_NAME_MAP = {
	"physical_fitness": "身体素质",
	"vitality": "体能活力",
	"academic_quality": "学业素养",
	"knowledge_reserve": "知识储备",
	"social_eq": "社交情商",
	"creative_aesthetics": "创意审美",
	"energy_recovery": "恢复精力"
}

func _ready() -> void:
	next_button.pressed.connect(_on_next_pressed)

func start_execution(activities: Array) -> void:
	scheduled_activities = activities
	current_day = 1
	is_finished = false
	_show_current_day()

func _show_current_day() -> void:
	if current_day > scheduled_activities.size():
		_finish_execution()
		return
		
	var act_id = scheduled_activities[current_day - 1]
	var all_acts = GameDataManager.activity_manager.get_all_activities()
	var act_name = "未知课程"
	for a in all_acts:
		if a.id == act_id:
			act_name = a.name
			break
			
	day_label.text = "第 %d 天" % current_day
	activity_label.text = "正在执行：%s" % act_name
	result_label.text = ""
	next_button.text = "执行"
	
	# 这里只展示，不直接执行，玩家点击按钮后才执行并显示结果
	# 如果要点击就直接显示结果，可以把逻辑放在 _on_next_pressed 中。

func _on_next_pressed() -> void:
	if is_finished:
		queue_free() # 销毁面板，结束流程
		return
		
	if next_button.text == "执行":
		_execute_current_day()
	else:
		current_day += 1
		_show_current_day()

func _execute_current_day() -> void:
	var act_id = scheduled_activities[current_day - 1]
	var profile = GameDataManager.profile
	var res = GameDataManager.activity_manager.execute_activity(profile, act_id)
	
	if res.success:
		result_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
		var msg = "执行成功！\n"
		for stat_name in res.gained_stats.keys():
			var amount = res.gained_stats[stat_name]
			var zh_name = STAT_NAME_MAP.get(stat_name, stat_name)
			msg += "%s +%d  " % [zh_name, amount]
		result_label.text = msg
	else:
		result_label.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
		result_label.text = "执行失败：" + res.msg
		
	if current_day >= scheduled_activities.size():
		next_button.text = "完成"
		is_finished = true
	else:
		next_button.text = "下一天"

func _finish_execution() -> void:
	day_label.text = "本周安排"
	activity_label.text = "已全部执行完毕！"
	result_label.text = "辛苦了，好好休息一下吧~"
	next_button.text = "关闭"
	is_finished = true
