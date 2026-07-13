extends Node
class_name QwenASRClient

signal transcribe_completed(text: String)
signal transcribe_failed(err: String)

@export var record_bus := "Record"
@export var audio_effect_capture_index := 0

var _is_recording: bool = false
var _accumulated_frames: PackedVector2Array
var _mutex: Mutex

@onready var _idx := AudioServer.get_bus_index(record_bus)
@onready var _effect_capture := (
    AudioServer.get_bus_effect(_idx, audio_effect_capture_index) as AudioEffectCapture
)

func _ready() -> void:
    _mutex = Mutex.new()

func _process(delta: float) -> void:
    if _is_recording and _effect_capture:
        var frames = _effect_capture.get_frames_available()
        if frames > 0:
            _mutex.lock()
            _accumulated_frames.append_array(_effect_capture.get_buffer(frames))
            _mutex.unlock()

func start_recording() -> void:
    _is_recording = true
    if _effect_capture:
        _effect_capture.clear_buffer()
        
    _mutex.lock()
    _accumulated_frames.clear()
    _mutex.unlock()

func stop_recording() -> void:
    if _effect_capture:
        var frames = _effect_capture.get_frames_available()
        if frames > 0:
            _mutex.lock()
            _accumulated_frames.append_array(_effect_capture.get_buffer(frames))
            _mutex.unlock()
            
    _is_recording = false
    
    var final_frames: PackedVector2Array
    _mutex.lock()
    final_frames = _accumulated_frames.duplicate()
    _mutex.unlock()
    
    if final_frames.size() > 0:
        _send_to_qwen(final_frames)
    else:
        transcribe_failed.emit("No audio recorded")

func _send_to_qwen(frames: PackedVector2Array) -> void:
    var config = GameDataManager.config
    var api_key = config.qwen_asr_api_key

    if not _uses_official_ai() and api_key.is_empty():
        transcribe_failed.emit("请配置千问ASR的 API Key (DashScope)")
        return
    
    # 1. 音频转换
    var target_rate = 16000
    var source_rate = int(AudioServer.get_mix_rate())
    var step = float(source_rate) / target_rate
    
    var pcm_data = PackedByteArray()
    var i = 0.0
    var max_amplitude = 0.0
    while i < frames.size():
        var idx = int(i)
        if idx >= frames.size(): break
        var mixed = (frames[idx].x + frames[idx].y) * 0.5 * 5.0
        max_amplitude = max(max_amplitude, abs(mixed))
        var pcm16 = int(clamp(mixed * 32767.0, -32768.0, 32767.0))
        pcm_data.append(pcm16 & 0xFF)
        pcm_data.append((pcm16 >> 8) & 0xFF)
        i += step
    
    var duration_sec = pcm_data.size() / (16000.0 * 2.0)
    print("[QwenASR] 录音时长: %.2f 秒, PCM大小: %d 字节, 最大振幅: %.4f" % [duration_sec, pcm_data.size(), max_amplitude])
    
    if max_amplitude < 0.01:
        print("[QwenASR] 警告: 录音声音极小，可能完全是静音！请检查麦克风设置！")
    
    if duration_sec < 0.5:
        transcribe_failed.emit("录音时间太短，请长按说话！")
        return
        
    var stream = AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = 16000
    stream.stereo = false
    stream.data = pcm_data
    
    var temp_path = "user://qwen_asr_temp.wav"
    stream.save_to_wav(temp_path)
    
    var wav_bytes = FileAccess.get_file_as_bytes(temp_path)
    var base64_audio = Marshalls.raw_to_base64(wav_bytes)

    _send_audio_request(base64_audio)

func _send_audio_request(base64_audio: String, auth_retried: bool = false) -> void:
    if _uses_official_ai() and not await OfficialAuthManager.ensure_valid_access_token():
        transcribe_failed.emit("登录状态已失效，请重新登录后使用官方语音识别。")
        return

    var http = HTTPRequest.new()
    add_child(http)
    http.timeout = 90.0
    http.request_completed.connect(_on_http_completed.bind(http, base64_audio, auth_retried))

    var url: String
    var headers: PackedStringArray = ["Content-Type: application/json"]
    var body: Dictionary
    if _uses_official_ai():
        url = GameDataManager.config.official_ai_gateway_url.trim_suffix("/") + "/asr/transcriptions"
        headers.append("Authorization: Bearer " + GameDataManager.config.official_access_token)
        body = {"audio_base64": base64_audio}
    else:
        url = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
        headers.append("Authorization: Bearer " + GameDataManager.config.qwen_asr_api_key)
        body = {
            "model": "qwen3-asr-flash",
            "messages": [{
                "role": "user",
                "content": [{"type": "input_audio", "input_audio": "data:audio/wav;base64," + base64_audio}]
            }]
        }

    var request_error: Error = http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
    if request_error != OK:
        http.queue_free()
        transcribe_failed.emit("语音识别请求发送失败，错误码：%d" % request_error)

func _on_http_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, base64_audio: String, auth_retried: bool) -> void:
    http.queue_free()

    if result != HTTPRequest.RESULT_SUCCESS:
        transcribe_failed.emit("网络请求失败")
        return

    if response_code == 401 and _uses_official_ai() and not auth_retried:
        if await OfficialAuthManager.force_refresh_access_token():
            _send_audio_request(base64_audio, true)
        else:
            transcribe_failed.emit("登录状态已失效，请重新登录后使用官方语音识别。")
        return

    var body_str = body.get_string_from_utf8()
    print("[QwenASR] 最终返回: ", body_str)
    
    if response_code != 200:
        transcribe_failed.emit("HTTP 错误: " + body_str)
        return
        
    var json = JSON.parse_string(body_str)
    if not json:
        transcribe_failed.emit("解析失败")
        return
    
    if json.has("choices") and json.choices.size() > 0:
        var text = json.choices[0].message.content
        if text == null or text == "":
            transcribe_failed.emit("未识别到语音")
        else:
            transcribe_completed.emit(text)
    else:
        transcribe_failed.emit("错误: 返回格式异常")

func _uses_official_ai() -> bool:
    return GameDataManager.config != null and GameDataManager.config.ai_service_mode == ConfigResource.AI_SERVICE_OFFICIAL
