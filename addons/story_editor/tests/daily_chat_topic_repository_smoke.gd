extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	var repository = load("res://scripts/data/daily_chat_topic_repository.gd")
	_expect(repository != null, "无法加载固定日常话题库。")
	if repository == null:
		_finish()
		return
	var topic_data: Dictionary = repository._load_topic_data()
	for category in ["study", "life", "emotion"]:
		var category_topics: Array = topic_data.get(category, [])
		_expect(category_topics.size() >= 10, "%s 分类的固定话题数量不足。" % category)
	var random := RandomNumberGenerator.new()
	random.seed = 20260731
	for draw_index in range(30):
		var drawn_topics: Dictionary = repository.draw_topic_map(random)
		for category in ["study", "life", "emotion"]:
			_expect((topic_data.get(category, []) as Array).has(drawn_topics.get(category)), "第 %d 次抽取的 %s 话题不属于对应分类。" % [draw_index, category])
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("DAILY_CHAT_TOPIC_REPOSITORY_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("DAILY_CHAT_TOPIC_REPOSITORY_SMOKE: %s" % failure)
	quit(1)