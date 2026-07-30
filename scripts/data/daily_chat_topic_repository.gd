class_name DailyChatTopicRepository
extends RefCounted

const DATA_PATH := "res://assets/data/interaction/daily_chat_topics.json"
const CATEGORY_KEYS := ["study", "life", "emotion"]
const FALLBACK_TOPICS := {
	"study": "最近学到了什么新东西？",
	"life": "今天有什么想和我聊的吗？",
	"emotion": "你现在心情怎么样？"
}

static func draw_topic_map(random: RandomNumberGenerator = null) -> Dictionary:
	var topic_data := _load_topic_data()
	var topic_random := random
	if topic_random == null:
		topic_random = RandomNumberGenerator.new()
		topic_random.randomize()
	var result := {}
	for category in CATEGORY_KEYS:
		result[category] = _draw_topic(topic_data.get(category, []), str(FALLBACK_TOPICS[category]), topic_random)
	return result

static func _load_topic_data() -> Dictionary:
	if not FileAccess.file_exists(DATA_PATH):
		push_error("日常话题数据库不存在：%s" % DATA_PATH)
		return {}
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("无法读取日常话题数据库：%s" % DATA_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("日常话题数据库格式无效：%s" % DATA_PATH)
		return {}
	return parsed as Dictionary

static func _draw_topic(raw_topics: Variant, fallback: String, random: RandomNumberGenerator) -> String:
	if not raw_topics is Array:
		return fallback
	var topics: Array[String] = []
	for raw_topic in raw_topics as Array:
		var topic := str(raw_topic).strip_edges()
		if topic != "":
			topics.append(topic)
	if topics.is_empty():
		return fallback
	return topics[random.randi_range(0, topics.size() - 1)]