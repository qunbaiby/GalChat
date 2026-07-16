@tool
extends RefCounted

const CURRENT_VERSION := 1

const DOMAIN_LABELS := {
	"fixed_story": "固定剧情",
	"mobile_chat": "手机固定消息",
	"guide_flows": "Guide Flow",
	"story_time": "剧情日程",
	"map_data": "地图数据",
	"event_registry": "Event Registry"
}


static func identify(path: String, data: Dictionary) -> String:
	var normalized := path.replace("\\", "/")
	if normalized.contains("/story/scripts/main/") or normalized.contains("/story/scripts/events/"):
		return "fixed_story" if data.has("script_id") and data.has("chapters") else ""
	if normalized.contains("/mobile/fixed_chats/"):
		return "mobile_chat" if data.has("id") and data.has("messages") else ""
	if normalized.ends_with("/guide_flows.json"):
		return "guide_flows" if data.has("guides") else ""
	if normalized.ends_with("/story_time.json"):
		return "story_time" if data.has("daily_data") else ""
	if normalized.ends_with("/map_data.json"):
		return "map_data" if data.has("locations") else ""
	if normalized.ends_with("/event_registry.json"):
		return "event_registry" if data.has("events") else ""
	return ""


static func label(domain: String) -> String:
	return str(DOMAIN_LABELS.get(domain, domain))


static func migrate_to_current(domain: String, data: Dictionary) -> Dictionary:
	if not DOMAIN_LABELS.has(domain):
		return {"ok": false, "error": "不支持的 Schema 领域：%s" % domain}
	var migrated := data.duplicate(true)
	migrated["schema_version"] = CURRENT_VERSION
	return {
		"ok": true,
		"data": migrated,
		"steps": [{
			"id": "%s_v0_to_v1" % domain,
			"from_version": 0,
			"to_version": CURRENT_VERSION,
			"summary": "添加顶层 schema_version"
		}],
		"changes": [{"op": "add", "path": "/schema_version", "before": null, "after": CURRENT_VERSION}]
	}