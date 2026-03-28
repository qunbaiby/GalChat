extends Node
class_name DoubaoTTSService

# 豆包 (Volcengine) TTS 服务
# 负责处理文本到语音的 API 请求、缓存和音频数据处理

signal tts_success(audio_stream: AudioStream, text: String)
signal tts_failed(error_msg: String, text: String)

# 配置
var api_url: String = "https://openspeech.bytedance.com/api/v1/tts"
var app_id: String = ""
var access_token: String = "" # Bearer token
var cluster: String = "volcano_tts"

# 默认语音参数
var default_voice_type: String = "BV001_streaming" # 示例默认音色
var default_sample_rate: int = 24000
var default_encoding: String = "mp3"
var max_retries: int = 2
var retry_delay: float = 1.0

# 缓存路径
const CACHE_DIR = "user://tts_cache/"

func _ready():
    # 初始化缓存目录
    if not DirAccess.dir_exists_absolute(CACHE_DIR):
        DirAccess.make_dir_absolute(CACHE_DIR)

# 设置认证信息
func setup_auth(p_app_id: String, p_access_token: String, p_cluster: String = "volcano_tts"):
    app_id = p_app_id
    access_token = p_access_token
    cluster = p_cluster

# 合成语音
# text: 要转换的文本
# options: 可选参数字典 (voice_type, speed_ratio, volume_ratio, pitch_ratio)
func synthesize(text: String, options: Dictionary = {}):
    if text.strip_edges().is_empty():
        tts_failed.emit("Text is empty", text)
        return

    # 1. 检查缓存
    var cache_key = _generate_cache_key(text, options)
    var cache_path = CACHE_DIR + cache_key + "." + default_encoding
    
    if FileAccess.file_exists(cache_path):
        print("🔊 [DoubaoTTS] 命中缓存: ", text.left(10) + "...")
        var stream = _load_audio_from_file(cache_path)
        if stream:
            tts_success.emit(stream, text)
            return
        else:
            print("⚠️ [DoubaoTTS] 缓存文件加载失败，重新请求")

    # 2. 发起请求 (带重试机制)
    _start_request(text, options, cache_path, 0)

# 内部：发起请求
func _start_request(text: String, options: Dictionary, cache_path: String, attempt: int):
    var request_body = _build_request_body(text, options)
    # Volcengine TTS header format: Authorization: Bearer; <token>
    var headers = [
        "Authorization: Bearer; " + access_token,
        "Content-Type: application/json"
    ]
    
    print("🌐 [DoubaoTTS] 发起请求 (尝试 %d/%d): %s..." % [attempt + 1, max_retries + 1, text.left(10)])
    
    # 创建临时的 HTTPRequest 节点以支持并发
    var http = HTTPRequest.new()
    add_child(http)
    
    # 绑定回调，传递上下文
    http.request_completed.connect(
        func(result, response_code, response_headers, body): 
            _on_request_completed(result, response_code, response_headers, body, http, text, options, cache_path, attempt)
    )
    
    var error = http.request(api_url, headers, HTTPClient.METHOD_POST, JSON.stringify(request_body))
    if error != OK:
        http.queue_free()
        _handle_failure("HTTP Request failed to start: " + str(error), text, options, cache_path, attempt)

# 内部：处理请求完成
func _on_request_completed(result, response_code, headers, body, http_node: HTTPRequest, text: String, options: Dictionary, cache_path: String, attempt: int):
    http_node.queue_free() # 请求完成，清理节点
    
    if result != HTTPRequest.RESULT_SUCCESS:
        _handle_failure("HTTP Connection Error: " + str(result), text, options, cache_path, attempt)
        return
        
    if response_code != 200:
        var error_msg = "API Error: " + str(response_code) + " Body: " + body.get_string_from_utf8()
        _handle_failure(error_msg, text, options, cache_path, attempt)
        return

    # 解析响应
    var json = JSON.new()
    var parse_err = json.parse(body.get_string_from_utf8())
    if parse_err != OK:
        _handle_failure("JSON Parse Error", text, options, cache_path, attempt)
        return
        
    var response_data = json.data
    
    # 检查 API 返回的错误码
    if response_data.has("data"):
        var audio_base64 = response_data["data"]
        # 有些情况下 data 可能是 null 或空
        if audio_base64 == null or str(audio_base64).is_empty():
             var msg = response_data.get("message", "Unknown Error (Empty Data)")
             _handle_failure("API Service Error: " + msg, text, options, cache_path, attempt)
             return
             
        var audio_data = Marshalls.base64_to_raw(audio_base64)
        _save_and_emit_audio(audio_data, cache_path, text)
    else:
         var msg = response_data.get("message", "Unknown Error")
         _handle_failure("API Service Error: " + msg, text, options, cache_path, attempt)

# 内部：处理失败与重试
func _handle_failure(error_msg: String, text: String, options: Dictionary, cache_path: String, attempt: int):
    print("❌ [DoubaoTTS] 请求失败: ", error_msg)
    
    if attempt < max_retries:
        print("🔄 [DoubaoTTS] 准备重试 (%d/%d) in %s seconds..." % [attempt + 1, max_retries, retry_delay])
        await get_tree().create_timer(retry_delay).timeout
        _start_request(text, options, cache_path, attempt + 1)
    else:
        print("🚫 [DoubaoTTS] 重试次数耗尽，放弃请求")
        tts_failed.emit(error_msg, text)

# 构建请求体
func _build_request_body(text: String, options: Dictionary) -> Dictionary:
    var voice_type = options.get("voice_type", default_voice_type)
    var speed = options.get("speed_ratio", 1.0)
    var volume = options.get("volume_ratio", 1.0)
    var pitch = options.get("pitch_ratio", 1.0)
    
    return {
        "app": {
            "appid": app_id,
            "token": access_token, # 修复：使用变量而非字符串字面量
            "cluster": cluster
        },
        "user": {
            "uid": "godot_player"
        },
        "audio": {
            "voice_type": voice_type,
            "encoding": default_encoding,
            "speed_ratio": speed,
            "volume_ratio": volume,
            "pitch_ratio": pitch
        },
        "request": {
            "reqid": str(Time.get_unix_time_from_system()),
            "text": text,
            "operation": "query",
            "with_frontend": 1,
            "frontend_type": "unitTson"
        }
    }


func _save_and_emit_audio(audio_data: PackedByteArray, cache_path: String, text: String):
    # 保存缓存
    var file = FileAccess.open(cache_path, FileAccess.WRITE)
    if file:
        file.store_buffer(audio_data)
        file.close()
    
    # 加载并发送
    var stream = _load_audio_from_buffer(audio_data)
    if stream:
        tts_success.emit(stream, text)
    else:
        tts_failed.emit("Failed to create audio stream", text)

# 从文件加载音频流
func _load_audio_from_file(path: String) -> AudioStream:
    var file = FileAccess.open(path, FileAccess.READ)
    if not file:
        return null
    var data = file.get_buffer(file.get_length())
    return _load_audio_from_buffer(data)

# 从 buffer 加载音频流 (MP3)
func _load_audio_from_buffer(data: PackedByteArray) -> AudioStream:
    var stream = AudioStreamMP3.new()
    stream.data = data
    return stream

# 生成缓存 Key (MD5)
func _generate_cache_key(text: String, options: Dictionary) -> String:
    var key_str = text + str(options)
    return key_str.md5_text()

# 清除缓存
func clear_cache():
    var dir = DirAccess.open(CACHE_DIR)
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if not dir.current_is_dir():
                dir.remove(file_name)
            file_name = dir.get_next()
