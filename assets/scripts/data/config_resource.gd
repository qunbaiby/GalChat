class_name ConfigResource
extends Resource

var api_key: String = ""
var model: String = "deepseek-chat"
var temperature: float = 0.7
var max_tokens: int = 2048
var ai_mode_enabled: bool = true

# 语音相关配置
var doubao_app_id: String = "2557182005"
var doubao_token: String = "vtuoxQuuStbX442IL3ZhvH4QptGlfepf"
var doubao_cluster: String = "volcano_tts"
var doubao_voice_type: String = "ICL_zh_female_bingruoshaonv_tob"
var voice_enabled: bool = true

const CONFIG_PATH = "user://config.json"

func save_config() -> void:
    var data = {
        "api_key": api_key,
        "model": model,
        "temperature": temperature,
        "max_tokens": max_tokens,
        "ai_mode_enabled": ai_mode_enabled,
        "doubao_app_id": doubao_app_id,
        "doubao_token": doubao_token,
        "doubao_cluster": doubao_cluster,
        "doubao_voice_type": doubao_voice_type,
        "voice_enabled": voice_enabled
    }
    var file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data, "\t"))
        file.close()

func load_config() -> void:
    if FileAccess.file_exists(CONFIG_PATH):
        var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
        var content = file.get_as_text()
        file.close()
        
        var json = JSON.new()
        var error = json.parse(content)
        if error == OK:
            var data = json.get_data()
            if data is Dictionary:
                api_key = data.get("api_key", api_key)
                model = data.get("model", model)
                temperature = data.get("temperature", temperature)
                max_tokens = data.get("max_tokens", max_tokens)
                ai_mode_enabled = data.get("ai_mode_enabled", ai_mode_enabled)
                doubao_app_id = data.get("doubao_app_id", doubao_app_id)
                doubao_token = data.get("doubao_token", doubao_token)
                doubao_cluster = data.get("doubao_cluster", doubao_cluster)
                doubao_voice_type = data.get("doubao_voice_type", doubao_voice_type)
                voice_enabled = data.get("voice_enabled", voice_enabled)
