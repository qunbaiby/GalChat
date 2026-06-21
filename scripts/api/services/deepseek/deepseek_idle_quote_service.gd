extends RefCounted

const IDLE_QUOTE_CONFIG_PATH := "res://assets/data/interaction/idle_quote_config.json"

var _idle_quote_config_cache: Dictionary = {}
var _idle_quote_config_loaded: bool = false
var _request_options: Dictionary = {}

func _resolve_idle_quote_time_context() -> Dictionary:
	var story_time_manager = GameDataManager.story_time_manager
	var current_hour: int = 8
	var period_label: String = "上午"
	if story_time_manager:
		current_hour = int(story_time_manager.current_hour)
		period_label = str(story_time_manager.current_period)
	if current_hour >= 5 and current_hour < 12:
		return {
			"bucket": "早",
			"hour": current_hour,
			"period": period_label,
			"guidance": "现在偏早段，适合聊刚醒来、早餐、出门前、打起精神、今天想怎么开始。"
		}
	if current_hour >= 12 and current_hour < 18:
		return {
			"bucket": "午",
			"hour": current_hour,
			"period": period_label,
			"guidance": "现在偏午段，适合聊午饭、犯困、学习或工作进度、下午的疲惫感、想偷懒一下。"
		}
	return {
		"bucket": "晚",
		"hour": current_hour,
		"period": period_label,
		"guidance": "现在偏晚段，适合聊放松、陪伴、晚饭、夜色、收尾、别太晚睡。"
	}

func _resolve_idle_quote_weather_context() -> Dictionary:
	var weather_desc: String = "晴天"
	if GameDataManager.story_time_manager and GameDataManager.story_time_manager.has_method("get_story_weather_desc"):
		weather_desc = str(GameDataManager.story_time_manager.get_story_weather_desc())
	var guidance := "天气明朗，适合轻松、舒展、带一点晒太阳或出门心情的闲聊。"
	match weather_desc:
		"多云":
			guidance = "天气有些发灰但不沉重，适合聊发呆、慢下来、想和你多待一会儿。"
		"阴天":
			guidance = "天气偏闷偏压，适合聊赖着、犯懒、需要陪伴、想被哄一哄。"
		"有雾":
			guidance = "空气朦胧，适合聊安静、贴近、小声提醒、像悄悄凑近一样的陪伴感。"
		"雨天":
			guidance = "下雨时适合聊带伞、潮湿、窝着休息、想被关心，语气可以更柔一点。"
		"雷雨":
			guidance = "天气有压迫感，适合聊担心、黏人一点、想确认你在不在身边。"
		"雪天":
			guidance = "天气偏冷，适合聊取暖、手冷、围巾、一起窝着或看雪。"
	return {
		"desc": weather_desc,
		"guidance": guidance
	}

func _resolve_idle_quote_stage_guidance(profile: CharacterProfile, stage_conf: Dictionary) -> String:
	var stage_index: int = int(profile.current_stage)
	if stage_index <= 2:
		return "当前关系还偏克制，主动但不要过火，更多是试探、自然问候、轻轻关心。"
	if stage_index <= 4:
		return "当前关系正在升温，可以更熟稔一点，带点分享欲、依赖感或软软的玩笑。"
	if stage_index <= 6:
		return "当前关系已经比较亲近，可以自然撒娇、轻微吃味、示弱或表达想陪着你。"
	return "当前关系已经非常亲密，可以明显表现占有欲、依恋感、默契感和只有你们懂的小亲昵。"

func _resolve_idle_quote_mood_guidance(mood_id: String, mood_name: String) -> String:
	match mood_id:
		"happy", "joy", "excited":
			return "当前心情偏高，语气可以更轻快、俏皮、亮一点。"
		"sad", "down", "melancholy":
			return "当前心情偏低，语气可以更轻、更软，像想找你靠一下。"
		"angry", "annoyed", "irritated":
			return "当前心情有点别扭，允许轻微吐槽或闹小脾气，但不要真的尖锐。"
		"shy", "bashful":
			return "当前心情偏害羞，语气可以欲言又止、绕一点，但仍然自然。"
		"tired", "sleepy":
			return "当前心情偏疲惫，适合聊困、累、想偷懒、想让你陪一下。"
		_:
			return "当前心情是%s，语气要贴合这种状态，不要像机械问候。" % mood_name

func _build_default_idle_quote_config() -> Dictionary:
	return {
		"categories": {
			"关心型": {
				"prompt_lines": [
					"像下意识关心对方现在状态的一句话。",
					"可以轻轻提醒吃饭、休息、别太累、别着凉。",
					"关心要自然，不要像照本宣科。"
				]
			},
			"撒娇型": {
				"prompt_lines": [
					"语气可以软一点、绕一点，像想让对方多哄一下。",
					"允许轻微任性，但不能幼稚做作。",
					"更像亲近之后不自觉露出来的小脾气。"
				]
			},
			"吐槽型": {
				"prompt_lines": [
					"可以带一点轻吐槽、碎碎念、拿现在状态开小玩笑。",
					"不要阴阳怪气，要像亲近时会有的小抱怨。",
					"吐槽里最好还是藏一点在意。"
				]
			},
			"陪伴型": {
				"prompt_lines": [
					"重点是陪着、在身边、和你一起待着的感觉。",
					"像安静相处时忽然冒出来的一句。",
					"不要太强事件性，更像日常陪伴。"
				]
			},
			"黏人型": {
				"prompt_lines": [
					"可以更明显表现舍不得你走、想贴近、想确认你在。",
					"语气要自然亲昵，不要油腻。",
					"要有一点只有关系足够近才会出现的依恋感。"
				]
			},
			"分享型": {
				"prompt_lines": [
					"像突然想把一个小感受、小发现、小念头说给对方听。",
					"可以更生活化一点，像顺口分享今天此刻的状态。",
					"重点是想和对方说，而不是汇报。"
				]
			}
		}
	}

func _ensure_idle_quote_config_loaded() -> void:
	if _idle_quote_config_loaded:
		return
	_idle_quote_config_loaded = true
	_idle_quote_config_cache = _build_default_idle_quote_config()
	if not FileAccess.file_exists(IDLE_QUOTE_CONFIG_PATH):
		return
	var file: FileAccess = FileAccess.open(IDLE_QUOTE_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data: Variant = json.get_data()
	if data is Dictionary:
		_idle_quote_config_cache = data

func _get_idle_quote_config() -> Dictionary:
	_ensure_idle_quote_config_loaded()
	return _idle_quote_config_cache

func _build_default_idle_quote_stage_profile(stage_index: int) -> Dictionary:
	if stage_index <= 2:
		return {
			"pick_count": 2,
			"weights": {
				"关心型": 4.8,
				"陪伴型": 4.5,
				"分享型": 3.2,
				"吐槽型": 1.3,
				"撒娇型": 0.8,
				"黏人型": 0.4
			}
		}
	if stage_index <= 4:
		return {
			"pick_count": 2,
			"weights": {
				"关心型": 4.4,
				"陪伴型": 4.0,
				"分享型": 3.0,
				"吐槽型": 2.3,
				"撒娇型": 1.8,
				"黏人型": 1.1
			}
		}
	if stage_index <= 6:
		return {
			"pick_count": 3,
			"weights": {
				"关心型": 3.5,
				"陪伴型": 3.4,
				"分享型": 2.2,
				"吐槽型": 2.4,
				"撒娇型": 3.3,
				"黏人型": 2.8
			}
		}
	return {
		"pick_count": 3,
		"weights": {
			"关心型": 2.8,
			"陪伴型": 3.2,
			"分享型": 1.8,
			"吐槽型": 2.2,
			"撒娇型": 4.1,
			"黏人型": 4.6
		}
	}

func _resolve_idle_quote_stage_profile(profile: CharacterProfile, stage_conf: Dictionary) -> Dictionary:
	var idle_profile_variant: Variant = stage_conf.get("idle_quote_profile", {})
	if idle_profile_variant is Dictionary and not (idle_profile_variant as Dictionary).is_empty():
		return idle_profile_variant
	return _build_default_idle_quote_stage_profile(int(profile.current_stage))

func _build_idle_quote_category_weights(stage_profile: Dictionary) -> Dictionary:
	var weights_variant: Variant = stage_profile.get("weights", {})
	return weights_variant if weights_variant is Dictionary else {}

func _pick_weighted_idle_quote_categories(profile: CharacterProfile, stage_conf: Dictionary, rng: RandomNumberGenerator, category_whitelist: Array[String] = []) -> Array[String]:
	var stage_profile: Dictionary = _resolve_idle_quote_stage_profile(profile, stage_conf)
	var weights: Dictionary = _build_idle_quote_category_weights(stage_profile)
	if not category_whitelist.is_empty():
		var allow_set: Dictionary = {}
		for category in category_whitelist:
			var key := str(category).strip_edges()
			if key != "":
				allow_set[key] = true
		var filtered_weights: Dictionary = {}
		for key in weights.keys():
			var final_key := str(key)
			if allow_set.has(final_key):
				filtered_weights[final_key] = weights[key]
		weights = filtered_weights
	var picked: Array[String] = []
	var target_count: int = int(stage_profile.get("pick_count", 2 if int(profile.current_stage) <= 3 else 3))
	if not category_whitelist.is_empty():
		target_count = mini(target_count, category_whitelist.size())
	var working_weights: Dictionary = weights.duplicate(true)
	for _i in range(target_count):
		var total_weight: float = 0.0
		for key in working_weights.keys():
			total_weight += float(working_weights[key])
		if total_weight <= 0.0:
			break
		var roll: float = rng.randf_range(0.0, total_weight)
		var cumulative: float = 0.0
		for key in working_weights.keys():
			cumulative += float(working_weights[key])
			if roll <= cumulative:
				picked.append(str(key))
				working_weights.erase(key)
				break
	if picked.is_empty():
		if not category_whitelist.is_empty():
			picked.append(str(category_whitelist[0]))
		else:
			picked.append("陪伴型")
	return picked

func pick_main_scene_bubble_categories(profile: CharacterProfile, rng: RandomNumberGenerator, category_whitelist: Array[String] = []) -> Array[String]:
	var stage_conf: Dictionary = profile.get_current_stage_config()
	return _pick_weighted_idle_quote_categories(profile, stage_conf, rng, category_whitelist)

func _build_idle_quote_category_prompts(category: String) -> Array[String]:
	var config: Dictionary = _get_idle_quote_config()
	var categories_variant: Variant = config.get("categories", {})
	if categories_variant is Dictionary:
		var categories: Dictionary = categories_variant
		if categories.has(category):
			var category_data_variant: Variant = categories.get(category, {})
			if category_data_variant is Dictionary:
				var category_data: Dictionary = category_data_variant
				var prompt_lines_variant: Variant = category_data.get("prompt_lines", [])
				if prompt_lines_variant is Array:
					var result: Array[String] = []
					for line_variant in prompt_lines_variant:
						var line_text: String = str(line_variant).strip_edges()
						if line_text != "":
							result.append(line_text)
					if not result.is_empty():
						return result
	return ["像生活里自然冒出来的一句闲聊。"]

func _build_idle_quote_random_pool(profile: CharacterProfile, stage_conf: Dictionary, rng: RandomNumberGenerator, time_context: Dictionary, weather_context: Dictionary, mood_id: String, mood_name: String, mood_guidance: String, stage_title: String, stage_guidance: String, category_whitelist: Array[String] = []) -> Dictionary:
	var selected_categories: Array[String] = _pick_weighted_idle_quote_categories(profile, stage_conf, rng, category_whitelist)
	var pool: Array[String] = [
		"轻轻打个招呼，但不要像客服问候。",
		"随口提一下现在这个时段最容易出现的小感受。",
		"像一起生活时突然冒出来的一句碎碎念。",
		"顺势表达一点想陪着玩家的念头。"
	]
	match str(time_context.get("bucket", "早")):
		"早":
			pool.append_array([
				"提一下刚醒、早餐、出门、赖床、清晨状态。",
				"可以像在催人打起精神，但要温柔自然。",
				"像早上见面时，下意识想先说的一句。"])
		"午":
			pool.append_array([
				"提一下午饭、午休、犯困、下午还有点长。",
				"可以像在关心玩家有没有偷偷摸鱼。",
				"像中段疲惫时，想给对方一点缓冲。"])
		"晚":
			pool.append_array([
				"提一下晚饭、放松、夜色、快收尾了。",
				"可以自然带一点陪伴感或舍不得你太晚休息。",
				"像夜里相处时不自觉放软的语气。"])
	match str(weather_context.get("desc", "晴天")):
		"晴天":
			pool.append_array(["带一点舒展、亮堂、想出门或想晒太阳的感觉。"])
		"多云":
			pool.append_array(["带一点慵懒、发呆、安静陪着你的感觉。"])
		"阴天":
			pool.append_array(["带一点犯懒、想被陪、心情低低的柔软感。"])
		"有雾":
			pool.append_array(["语气可以更贴近、更轻声，像在你耳边悄悄说。"])
		"雨天":
			pool.append_array(["带一点潮湿天气下的窝着、带伞、别淋到的关心。"])
		"雷雨":
			pool.append_array(["可以更黏人一点，像想确认你在。"])
		"雪天":
			pool.append_array(["带一点冷、想取暖、想靠近的感觉。"])
	if mood_name != "":
		pool.append("要体现当前心情“%s”。" % mood_name)
	pool.append(mood_guidance)
	pool.append("当前关系阶段是“%s”，%s" % [stage_title, stage_guidance])
	for category in selected_categories:
		pool.append("本次闲聊优先走“%s”。" % category)
		pool.append_array(_build_idle_quote_category_prompts(category))
	pool.shuffle()
	var selected_count: int = mini(6, pool.size())
	var selected: Array[String] = []
	for i in range(selected_count):
		selected.append(pool[i])
	return {
		"categories": selected_categories,
		"prompt_text": "\n- " + "\n- ".join(selected)
	}

func _build_scene_mode_category_whitelist(scene_mode: String, prompt_type: String) -> Array[String]:
	match scene_mode:
		"proactive_greeting":
			match prompt_type:
				"course":
					return ["关心型", "陪伴型", "分享型"]
				"daily":
					return ["陪伴型", "分享型", "吐槽型", "关心型"]
				_:
					return ["关心型", "陪伴型", "分享型"]
		_:
			return []

func set_request_options(options: Dictionary = {}) -> void:
	_request_options = options.duplicate(true)

func send_idle_quote_generation(client, char_id: String) -> void:
	var profile = GameDataManager.profile
	if not profile or profile.current_character_id != char_id:
		profile = CharacterProfile.new()
		profile.load_profile(char_id)
	var char_name: String = profile.char_name
	var personality: String = GameDataManager.personality_system.get_personality_summary(profile)
	var stage_conf: Dictionary = profile.get_current_stage_config()
	var stage_title: String = str(stage_conf.get("stageTitle", "陌生人"))
	var stage_desc: String = str(stage_conf.get("stageDesc", ""))
	var intimacy: float = float(profile.intimacy)
	var mood_data: Dictionary = GameDataManager.mood_system.get_macro_mood(profile.mood_value)
	var mood: String = str(mood_data.get("name", "平静"))
	var mood_id: String = str(mood_data.get("id", "calm"))
	var player_name: String = profile.player_title
	if player_name.is_empty():
		player_name = "指导人"
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var random_seed: int = rng.randi()
	var options := _request_options.duplicate(true)
	_request_options.clear()
	var scene_mode := str(options.get("scene_mode", "idle_chat")).strip_edges()
	if scene_mode == "":
		scene_mode = "idle_chat"
	var prompt_type := str(options.get("prompt_type", "")).strip_edges()
	var category_whitelist := _build_scene_mode_category_whitelist(scene_mode, prompt_type)
	var time_context: Dictionary = _resolve_idle_quote_time_context()
	var weather_context: Dictionary = _resolve_idle_quote_weather_context()
	var mood_guidance: String = _resolve_idle_quote_mood_guidance(mood_id, mood)
	var stage_guidance: String = _resolve_idle_quote_stage_guidance(profile, stage_conf)
	var idle_pool: Dictionary = _build_idle_quote_random_pool(profile, stage_conf, rng, time_context, weather_context, mood_id, mood, mood_guidance, stage_title, stage_guidance, category_whitelist)
	var random_pool_text: String = str(idle_pool.get("prompt_text", ""))
	var selected_categories: Array = idle_pool.get("categories", [])
	var is_proactive_greeting := scene_mode == "proactive_greeting"
	var scene_desc := "这是主场景里的挂机闲聊气泡，不是正式剧情开场，而是一句自然飘出来的陪伴式碎碎念。"
	var mode_guidance := "这次更偏向挂机闲聊，所以要像陪伴中的自然碎碎念，不要像专门打招呼，也不要像剧情推进台词。"
	var task_desc := "请根据你的性格、情感阶段、当前心情、当前时段和天气，对【%s】说一句简短的话，比如倾诉心事、撒娇、吐槽、关心、碎碎念或者轻声搭话。\n" % player_name
	var user_request := "请随机对我说一句符合你人设的话，务必保证每次都截然不同！"
	if is_proactive_greeting:
		scene_desc = "这是玩家刚进入主场景时的主动问候气泡，你要先开口，但仍然要像日常陪伴里自然飘出来的一句问候。"
		mode_guidance = "这次是进入主场景后的主动问候，只要轻轻开个头就够，不要展开成长对话，也不要提历史聊天。"
		task_desc = "请根据你的性格、情感阶段、当前心情、当前时段和天气，先主动对【%s】说一句自然问候，起到轻量开场和陪伴作用。\n" % player_name
		user_request = "请先主动和我打一句自然的招呼，只输出一句。"
	var bubble_guidance_lines: Array[String] = [
		"当前主场景时段：%s（%02d点，%s）。" % [str(time_context.get("bucket", "早")), int(time_context.get("hour", 8)), str(time_context.get("period", "上午"))],
		"当前剧情天气：%s。" % str(weather_context.get("desc", "晴天")),
		"时段引导：%s" % str(time_context.get("guidance", "")),
		"天气引导：%s" % str(weather_context.get("guidance", "")),
		"心情引导：%s" % mood_guidance,
		"关系引导：%s" % stage_guidance,
		"本次优先子类：%s" % " / ".join(PackedStringArray(selected_categories)),
		mode_guidance
	]
	var shared_strategy: String = GameDataManager.prompt_manager.build_main_scene_bubble_strategy_block(
		profile,
		scene_desc,
		bubble_guidance_lines
	)
	var system_prompt := "【系统设定】\n"
	system_prompt += "你扮演的角色是：%s。\n" % char_name
	system_prompt += "你的性格特征是：%s。\n" % personality
	system_prompt += "对话对象是【%s】。\n" % player_name
	system_prompt += shared_strategy + "\n"
	system_prompt += "【随机灵感池】%s\n" % random_pool_text
	system_prompt += "【任务要求】\n"
	system_prompt += task_desc
	system_prompt += "要求：\n"
	system_prompt += "1. 每次必须提供完全不同的随机对话，禁止重复以前的回答。优先围绕“本次优先子类”中的1到2种类型来写。\n"
	system_prompt += "2. 只输出一句纯粹的台词，不要任何动作描写（禁止使用括号），不要任何系统前缀。\n"
	system_prompt += "3. 字数优先控制在12到28字。\n"
	system_prompt += "4. 语气要自然、生活化，和主场景主动问候保持同一口吻体系。\n"
	system_prompt += "5. 不要生硬点名“现在是早上/天气是雨天”，而是让这些语境自然渗进话里。\n"
	system_prompt += "6. 不要读取、假设或延续任何历史对话上下文，这次只根据当前配置和随机灵感池开口。\n"
	system_prompt += "7. %s\n" % ("这是主场景开场问候，不要像正式剧情开场，也不要像任务提示。" if is_proactive_greeting else "这是常驻陪伴里的闲聊，不要像正式剧情开场，也不要像任务提示。")
	system_prompt += "[随机因子：%d]\n" % random_seed
	var api_messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": user_request}
	]
	var body = {
		"model": client.get_chat_model_id(),
		"messages": api_messages,
		"temperature": 0.85,
		"max_tokens": 100
	}
	if client.idle_quote_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		client.idle_quote_http.cancel_request()
	client.idle_quote_http.request(client._get_url(), client._get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func handle_idle_quote_completed(client, result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		client.idle_quote_failed.emit("网络请求失败 (HTTP " + str(response_code) + ")")
		return
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK:
		var response: Variant = json.get_data()
		if typeof(response) == TYPE_DICTIONARY and response.has("choices") and response["choices"].size() > 0:
			var quote: String = response["choices"][0]["message"]["content"].strip_edges()
			var regex := RegEx.new()
			regex.compile("（.*?）|\\(.*?\\)|\\[.*?\\]|\\*.*?\\*")
			quote = regex.sub(quote, "", true).strip_edges()
			quote = quote.replace("\"", "").replace("“", "").replace("”", "")
			client.idle_quote_completed.emit(quote)
			return
	client.idle_quote_failed.emit("返回数据解析失败")
