extends Node

# 全局 TTS 管理器，负责统筹多种 TTS 后端（如 豆包、GPT-SoVITS、VITS 等）
# 作为 Autoload 单例运行，所有需要发声的模块直接调用此类

signal tts_success(audio_stream: AudioStream, text: String)
signal tts_failed(error_msg: String, text: String)

var current_adapter: TTSAdapter = null
var current_adapter_type: String = ""

func _ready():
	# 根据用户设置初始化 TTS 后端
	if GameDataManager.config and GameDataManager.config.tts_backend != "":
		set_adapter(GameDataManager.config.tts_backend)
	else:
		set_adapter("qwen_tts")

# 切换 TTS 适配器
func set_adapter(adapter_type: String) -> void:
	if adapter_type == current_adapter_type and current_adapter != null:
		return
		
	if current_adapter:
		current_adapter.queue_free()
		current_adapter = null
		
	current_adapter_type = adapter_type
	
	match adapter_type:
		"doubao":
			# 加载现有的 DoubaoTTSService（它现在应该继承自 TTSAdapter）
			var DoubaoAdapter = load("res://scripts/api/doubao_TTS_Service.gd") 
			if DoubaoAdapter:
				current_adapter = DoubaoAdapter.new()
		"qwen_tts":
			var QwenTTSAdapter = load("res://scripts/api/tts/qwen_tts_adapter.gd")
			if QwenTTSAdapter:
				current_adapter = QwenTTSAdapter.new()
		"gpt_sovits":
			# TODO: 预留给本地免费 GPT-SoVITS 的适配器
			print("[TTSManager] GPT-SoVITS adapter not implemented yet.")
		_:
			print("[TTSManager] Unknown adapter type: ", adapter_type)
			
	if current_adapter:
		add_child(current_adapter)
		
		# 绑定信号
		current_adapter.tts_success.connect(_on_adapter_success)
		current_adapter.tts_failed.connect(_on_adapter_failed)
		
		# 注入现有配置
		_setup_current_adapter_auth()

func _setup_current_adapter_auth() -> void:
	if current_adapter and GameDataManager.config:
		var config_dict = {
			"app_id": GameDataManager.config.doubao_app_id,
			"token": GameDataManager.config.doubao_token,
			"cluster": GameDataManager.config.doubao_cluster,
			"qwen_tts_api_key": GameDataManager.config.qwen_tts_api_key
		}
		current_adapter.setup_auth(config_dict)

# 外部调用的统一接口
func synthesize(text: String, options: Dictionary = {}) -> void:
	if not current_adapter:
		tts_failed.emit("No TTS adapter configured", text)
		return
		
	# 【动态情绪注入】：如果外部没有指定 emotion，自动注入当前角色的心情
	if not options.has("emotion") and GameDataManager.profile:
		options["emotion"] = GameDataManager.profile.current_expression
		
	# 兼容原有逻辑，注入当前的 voice_type 或 voice_seed
	if GameDataManager.profile and GameDataManager.config:
		var char_id = GameDataManager.config.current_character_id
		if current_adapter_type == "doubao":
			if not options.has("voice_type") and GameDataManager.config.character_voice_types.has(char_id):
				options["voice_type"] = GameDataManager.config.character_voice_types[char_id]
		elif current_adapter_type == "qwen_tts":
			if not options.has("voice_type") and GameDataManager.config.qwen_tts_voice_types.has(char_id):
				options["voice_type"] = GameDataManager.config.qwen_tts_voice_types[char_id]
			
	current_adapter.synthesize(text, options)

func clear_cache() -> void:
	if current_adapter:
		current_adapter.clear_cache()

# --- 内部回调转发 ---
func _on_adapter_success(stream: AudioStream, text: String) -> void:
	tts_success.emit(stream, text)

func _on_adapter_failed(err_msg: String, text: String) -> void:
	tts_failed.emit(err_msg, text)
