extends DeepSeekClient
class_name DoubaoChatClient

func _is_api_key_empty() -> bool:
	return GameDataManager.config.doubao_chat_api_key.is_empty()

func _get_headers() -> Array:
	var api_key = GameDataManager.config.doubao_chat_api_key
	return [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]

func _get_url() -> String:
	return "https://ark.cn-beijing.volces.com/api/v3/chat/completions"

func _get_stream_host() -> String:
	return "ark.cn-beijing.volces.com"

func _get_stream_path() -> String:
	return "/api/v3/chat/completions"
