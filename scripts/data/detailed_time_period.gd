class_name DetailedTimePeriod
extends RefCounted

const LABELS := ["午夜", "深夜", "黎明", "清晨", "早晨", "上午", "中午", "午后", "下午", "黄昏", "晚上", "夜深"]


func get_label(hour: int) -> String:
	var period_index := floori(float(posmod(hour, 24)) / 2.0)
	return LABELS[period_index]