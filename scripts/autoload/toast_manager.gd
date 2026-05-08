extends CanvasLayer

@onready var container: VBoxContainer = $VBoxContainer

var toast_item_scene = preload("res://scenes/autoload/toast_item.tscn")
var system_toast_scene = preload("res://scenes/autoload/system_toast.tscn")

var stat_icons: Dictionary = {
	"intimacy": preload("res://assets/images/icons/ui/system/heart.svg"),
	"trust": preload("res://assets/images/icons/ui/stats/social.svg"),
	"openness": preload("res://assets/images/icons/ui/stats/aesthetics.svg"),
	"conscientiousness": preload("res://assets/images/icons/ui/stats/academic.svg"),
	"extraversion": preload("res://assets/images/icons/ui/stats/vitality.svg"),
	"agreeableness": preload("res://assets/images/icons/ui/stats/core_charm.svg"),
	"neuroticism": preload("res://assets/images/icons/ui/stats/core_intelligence.svg")
}

var stat_colors: Dictionary = {
	"intimacy": Color(0.9, 0.4, 0.5, 0.9),
	"trust": Color(0.3, 0.8, 0.4, 0.9),
	"openness": Color(0.2, 0.7, 0.8, 0.9),
	"conscientiousness": Color(0.2, 0.4, 0.8, 0.9),
	"extraversion": Color(0.9, 0.6, 0.2, 0.9),
	"agreeableness": Color(0.8, 0.8, 0.2, 0.9),
	"neuroticism": Color(0.6, 0.3, 0.8, 0.9)
}

func _ready() -> void:
	layer = 120 # High enough to be over everything

func show_toast(message: String, color: Color = Color(0.2, 0.2, 0.2, 0.8), icon: Texture2D = null) -> void:
	var item = toast_item_scene.instantiate()
	container.add_child(item)
	item.setup(message, color, icon)

func show_stat_toast(stat_id: String, message: String) -> void:
	var color = stat_colors.get(stat_id, Color(0.5, 0.5, 0.5, 0.9))
	var icon = stat_icons.get(stat_id, null)
	show_toast(message, color, icon)

func show_system_toast(message: String, color: Color = Color.WHITE) -> void:
	var item = system_toast_scene.instantiate()
	add_child(item)
	item.setup(message, color)
