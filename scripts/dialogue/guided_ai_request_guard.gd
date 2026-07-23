extends RefCounted


static func matches(active_session_id: String, active_request_id: int, closing_started: bool, request_context: Dictionary) -> bool:
	if active_request_id <= 0 or int(request_context.get("request_id", 0)) != active_request_id:
		return false
	if str(request_context.get("session_id", "")) != active_session_id:
		return false
	var expected_kind := "closing" if closing_started else "normal"
	return str(request_context.get("request_kind", "")) == expected_kind