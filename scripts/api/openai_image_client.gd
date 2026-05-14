class_name OpenAIImageClient
extends Node

signal image_generated(diary_id: String, local_path: String, metadata: Dictionary)
signal image_generation_failed(diary_id: String, error_msg: String)

const API_URL = "https://api.openai.com/v1/images/generations"
const MAX_RETRIES = 3

func generate_diary_illustration(diary_id: String, prompt: String) -> void:
    _generate_async(diary_id, prompt)

func _generate_async(diary_id: String, prompt: String) -> void:
    var start_time = Time.get_ticks_msec()
    
    if GameDataManager.config and not GameDataManager.config.image_generation_enabled:
        image_generation_failed.emit.call_deferred(diary_id, "Image generation is disabled in settings.")
        return
        
    var api_key = ""
    var model = "dall-e-2"
    
    if GameDataManager.config and "openai_image_api_key" in GameDataManager.config:
        api_key = GameDataManager.config.openai_image_api_key
        
    if api_key.is_empty():
        image_generation_failed.emit.call_deferred(diary_id, "OpenAI Image API Key未设置，请在设置中配置。")
        return
        
    var request_data = {
        "model": model,
        "prompt": prompt,
        "n": 1,
        "size": "1024x1024",
        "response_format": "url"
    }
    
    var headers = [
        "Content-Type: application/json",
        "Authorization: Bearer " + api_key
    ]
    
    var image_url = ""
    var success = false
    var error_message = ""
    
    var http_request = HTTPRequest.new()
    add_child(http_request)
    
    # 1. 请求 API (带重试)
    for attempt in range(MAX_RETRIES):
        var err = http_request.request(API_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(request_data))
        if err != OK:
            error_message = "无法发起 API 请求: %d" % err
            await get_tree().create_timer(1.0).timeout
            continue
            
        var response = await http_request.request_completed
        var result = response[0]
        var response_code = response[1]
        var body = response[3]
        
        if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
            var json = JSON.new()
            if json.parse(body.get_string_from_utf8()) == OK:
                var res_dict = json.data
                if res_dict.has("data") and res_dict["data"].size() > 0 and res_dict["data"][0].has("url"):
                    image_url = res_dict["data"][0]["url"]
                    success = true
                    break
                    
        error_message = "API 请求失败. HTTP 状态码: %d" % response_code
        if body.size() > 0:
            var body_str = body.get_string_from_utf8()
            if body_str.length() < 200:
                error_message += " 详情: " + body_str
            else:
                error_message += " 详情: " + body_str.substr(0, 200) + "..."
                
        if attempt < MAX_RETRIES - 1:
            await get_tree().create_timer(2.0).timeout
            
    if not success or image_url.is_empty():
        http_request.queue_free()
        image_generation_failed.emit.call_deferred(diary_id, error_message)
        return
        
    # 2. 下载图像 (带重试)
    var img_download_success = false
    var img_body = PackedByteArray()
    
    for attempt in range(MAX_RETRIES):
        var err = http_request.request(image_url, ["User-Agent: GodotEngine/4.5"], HTTPClient.METHOD_GET)
        if err != OK:
            error_message = "无法发起图像下载请求: %d" % err
            await get_tree().create_timer(1.0).timeout
            continue
            
        var response = await http_request.request_completed
        var result = response[0]
        var response_code = response[1]
        var body = response[3]
        
        if result == HTTPRequest.RESULT_SUCCESS and response_code == 200 and body.size() > 0:
            img_body = body
            img_download_success = true
            break
            
        error_message = "图像下载失败. HTTP 状态码: %d" % response_code
        if attempt < MAX_RETRIES - 1:
            await get_tree().create_timer(2.0).timeout
            
    http_request.queue_free()
    
    if not img_download_success:
        image_generation_failed.emit.call_deferred(diary_id, error_message)
        return
        
    # 3. 解析与保存图像
    var image = Image.new()
    var load_err = ERR_FILE_CORRUPT
    
    # 魔术字节探测: JPEG FF D8 FF
    if img_body.size() > 3 and img_body[0] == 0xFF and img_body[1] == 0xD8 and img_body[2] == 0xFF:
        load_err = image.load_jpg_from_buffer(img_body)
    # 魔术字节探测: PNG 89 50 4E 47
    elif img_body.size() > 4 and img_body[0] == 0x89 and img_body[1] == 0x50 and img_body[2] == 0x4E and img_body[3] == 0x47:
        load_err = image.load_png_from_buffer(img_body)
    # 魔术字节探测: WEBP RIFF ... WEBP
    elif img_body.size() > 12 and img_body[0] == 0x52 and img_body[1] == 0x49 and img_body[2] == 0x46 and img_body[3] == 0x46:
        load_err = image.load_webp_from_buffer(img_body)
    else:
        # 退退而求其次: 按顺序暴力盲猜
        load_err = image.load_png_from_buffer(img_body)
        if load_err != OK:
            load_err = image.load_jpg_from_buffer(img_body)
            if load_err != OK:
                load_err = image.load_webp_from_buffer(img_body)
                
    if load_err != OK or image.is_empty():
        image_generation_failed.emit.call_deferred(diary_id, "无法解析下载的图像数据 (大小: " + str(img_body.size()) + "). Error Code: " + str(load_err))
        return
                
    var time_dict = Time.get_datetime_dict_from_system()
    var date_str = "%04d-%02d-%02d" % [time_dict.year, time_dict.month, time_dict.day]
    var timestamp = int(Time.get_unix_time_from_system())
    
    var dir_path = "user://generated_images/" + date_str
    if not DirAccess.dir_exists_absolute(dir_path):
        var dir_err = DirAccess.make_dir_recursive_absolute(dir_path)
        if dir_err != OK:
            image_generation_failed.emit.call_deferred(diary_id, "无法创建目录: " + dir_path)
            return
            
    var file_name = "img_%s_%d.png" % [diary_id, timestamp]
    var file_path = dir_path + "/" + file_name
    
    # 保存为 PNG 并压缩
    var save_err = image.save_png(file_path)
    if save_err != OK:
        image_generation_failed.emit.call_deferred(diary_id, "保存 PNG 文件失败: %d" % save_err)
        return
        
    var duration = (Time.get_ticks_msec() - start_time) / 1000.0
    var metadata = {
        "duration": duration,
        "prompt": prompt,
        "model": model
    }
    
    image_generated.emit.call_deferred(diary_id, file_path, metadata)
