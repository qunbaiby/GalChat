class_name TTSAdapter
extends Node

# 语音合成成功后发出，附带生成的音频流和对应的文本
signal tts_success(audio_stream: AudioStream, text: String)

# 语音合成失败时发出，附带错误信息和对应的文本
signal tts_failed(error_msg: String, text: String)

# 子类必须实现的接口：发起合成请求
# text: 需要合成的文本
# options: 额外参数，例如 voice_type, emotion, speed_ratio 等
func synthesize(text: String, options: Dictionary = {}) -> void:
	push_error("TTSAdapter: synthesize() must be overridden by subclass")

# 子类可选实现的接口：初始化或更新认证信息
func setup_auth(config: Dictionary) -> void:
	pass

# 子类可选实现的接口：清理缓存
func clear_cache() -> void:
	pass
