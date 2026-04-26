class_name LocalWhisperASR
extends SpeechToText

signal transcribe_partial(text: String)
signal transcribe_completed(text: String)
signal transcribe_failed(err: String)

@export var initial_prompt: String = "以下是普通话的句子。"
@export var record_bus := "Record"
@export var audio_effect_capture_index := 0

var _accumulated_frames: PackedVector2Array
var _thread: Thread
var _is_recording: bool = false
var _mutex: Mutex

@onready var _idx := AudioServer.get_bus_index(record_bus)
@onready var _effect_capture := (
    AudioServer.get_bus_effect(_idx, audio_effect_capture_index) as AudioEffectCapture
)

func _ready() -> void:
    if Engine.is_editor_hint():
        return
    _mutex = Mutex.new()
    if language_model == null:
        language_model = ResourceLoader.load("res://addons/godot_whisper/models/ggml-base.bin", "WhisperResource")
    if language_model == null:
        push_warning("LocalWhisperASR: language_model is not set. Please download a Whisper model (.bin) and set it.")

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        _is_recording = false
        if _thread and _thread.is_alive():
            _thread.wait_to_finish()

func _process(delta: float) -> void:
    if _is_recording and _effect_capture:
        var frames = _effect_capture.get_frames_available()
        if frames > 0:
            if _mutex == null:
                _mutex = Mutex.new()
            _mutex.lock()
            _accumulated_frames.append_array(_effect_capture.get_buffer(frames))
            _mutex.unlock()

func start_recording() -> void:
    if language_model == null:
        call_deferred("emit_signal", "transcribe_failed", "Language model not configured")
        return
        
    # Initialize the model context if not already done by SpeechToText
    if not has_method("is_model_loaded") or not call("is_model_loaded"):
        # The underlying C++ module requires the model to be explicitly loaded/initialized
        # before any transcribe operations can occur.
        # Check if we can trigger initialization by assigning the language_model again.
        if language_model:
            var current_model = language_model
            language_model = null
            language_model = current_model
        
    _is_recording = true
    if _effect_capture:
        _effect_capture.clear_buffer()
        
    if _mutex == null:
        _mutex = Mutex.new()
        
    _mutex.lock()
    _accumulated_frames.clear()
    _mutex.unlock()
    
    if _thread and _thread.is_alive():
        _thread.wait_to_finish()

func stop_recording() -> void:
    if _effect_capture:
        var frames = _effect_capture.get_frames_available()
        if frames > 0:
            if _mutex == null:
                _mutex = Mutex.new()
            _mutex.lock()
            _accumulated_frames.append_array(_effect_capture.get_buffer(frames))
            _mutex.unlock()
            
    _is_recording = false
    
    if _thread and _thread.is_alive():
        _thread.wait_to_finish()
        
    _thread = Thread.new()
    _thread.start(_process_audio_thread)

func _process_audio_thread() -> void:
    _mutex.lock()
    var final_frames = _accumulated_frames.duplicate()
    _mutex.unlock()
    
    if final_frames.size() > 0:
        var text = _transcribe_frames(final_frames)
        if text.is_empty():
            call_deferred("emit_signal", "transcribe_failed", "Recognized text is empty")
        else:
            call_deferred("emit_signal", "transcribe_completed", text)
    else:
        call_deferred("emit_signal", "transcribe_failed", "No audio recorded")

func _transcribe_frames(frames: PackedVector2Array) -> String:
    # 降采样或格式转换到 Whisper 所需格式 (16000Hz 采样率)
    var resampled := resample(frames, SpeechToText.SRC_SINC_FASTEST)
    if resampled.size() <= 0:
        return ""
        
    # 音频标准化 (Volume Normalization)
    var max_amp: float = 0.0
    for i in range(resampled.size()):
        var amp = abs(resampled[i])
        if amp > max_amp:
            max_amp = amp
            
    # 如果最大音量非常小（接近纯静音），直接当做无语音处理
    if max_amp < 0.01:
        return ""
            
    if max_amp > 0.0:
        var gain: float = 0.8 / max_amp
        gain = min(gain, 15.0)
        if gain > 1.1:
            for i in range(resampled.size()):
                resampled[i] *= gain
                
    # 动态计算 audio_ctx 以优化速度。根据音频长度估算，同时给定一个安全的下限(512)
    var total_time: float = (resampled.size() as float) / SpeechToText.SPEECH_SETTING_SAMPLE_RATE
    var audio_ctx: int = int(total_time * 1500.0 / 30.0 + 128.0)
    audio_ctx = clampi(audio_ctx, 512, 1500)
    
    var tokens := transcribe(resampled, initial_prompt, audio_ctx)
    if tokens.is_empty():
        return ""
        
    var full_text: String = ""
    if tokens.size() > 0 and typeof(tokens[0]) == TYPE_STRING:
        full_text = tokens.pop_front()
        
    var text := full_text
    
    # 提取并拼接可能因 max_tokens 限制而遗留在字典中的额外字符碎片
    if tokens.size() > 0:
        var fragment = ""
        for token in tokens:
            if typeof(token) == TYPE_DICTIONARY and token.has("text"):
                var token_text = token["text"] as String
                if not token_text in text:
                    fragment += token_text
        text += fragment
                
    # 清理占位符
    text = text.replace("�", "")
    text = _filter_english_gibberish(text)
    text = _remove_special_characters(text)
    text = _remove_repetitions(text) # 重新启用去重算法，调整为仅处理长句幻觉，避免误伤
    return text.strip_edges()

func _remove_repetitions(text: String) -> String:
    if text.length() < 10:
        return text
        
    # 处理完美的短句重复（例如"这是测试这是测试"，至少重复长度为4）
    # 但我们增加一个限制：如果只有短短几个字的重复，且总长度很短，可能是玩家口吃，保留。
    # 只有当重复模式占据了整个句子的大部分时，才认为是幻觉。
    for i in range(text.length()):
        for length in range(4, (text.length() - i) / 2 + 1):
            var sub = text.substr(i, length)
            var next_sub = text.substr(i + length, length)
            if sub == next_sub:
                # 如果这个重复直接一直重复到了句子结尾，或者是超过 8 个字的超长重复，基本断定是幻觉
                if i + length * 2 >= text.length() - 2 or length >= 8:
                    return text.substr(0, i + length).strip_edges()
                
    # 进阶去重：处理不完美的超长句幻觉重复
    # 如：“...你说过的话,那我到底说什么了呢?然想起我们第一次看《晚》时你说过的话,那我到底说什么了呢?”
    # 门槛提高：只有超过 12 个字以上的一模一样的长段落再次出现，才被认为是 AI 陷入了 fallback 循环
    var min_match_len = 12
    if text.length() >= min_match_len * 2:
        for i in range(text.length() - min_match_len):
            for length in range(min_match_len, text.length() - i):
                var pattern = text.substr(i, length)
                var remaining_text = text.substr(i + length)
                
                var duplicate_idx = remaining_text.find(pattern)
                if duplicate_idx != -1:
                    # 我们就在第二次出现的地方把整个字符串切断
                    return text.substr(0, i + length + duplicate_idx).strip_edges()
                
    return text

func _filter_english_gibberish(text: String) -> String:
    # 当模型没听清时，极有可能会强行输出像 "ni shi shei" 或一些无意义的英文字符。
    # 如果全句中中文字符占比过低，我们直接当作未识别丢弃。
    var chinese_char_count = 0
    var total_letters = 0
    
    for i in range(text.length()):
        var c = text.unicode_at(i)
        if c >= 0x4E00 and c <= 0x9FFF:
            chinese_char_count += 1
        elif (c >= 65 and c <= 90) or (c >= 97 and c <= 122):
            total_letters += 1
            
    if chinese_char_count == 0 and total_letters > 0:
        return ""
        
    return text

func _remove_special_characters(message: String) -> String:
    var special_characters := [
        {"start": "[", "end": "]"}, {"start": "<", "end": ">"}, {"start": "♪", "end": "♪"}
    ]
    for special_character in special_characters:
        while message.find(special_character["start"]) != -1:
            var begin_character := message.find(special_character["start"])
            var end_character := message.find(special_character["end"])
            if end_character != -1:
                message = message.substr(0, begin_character) + message.substr(end_character + 1)

    var hallucinatory_character := [". you.", "你。", "。你。"]
    for special_character in hallucinatory_character:
        while message.find(special_character) != -1:
            var begin_character := message.find(special_character)
            var end_character := begin_character + len(special_character)
            message = message.substr(0, begin_character) + message.substr(end_character)
    return message
