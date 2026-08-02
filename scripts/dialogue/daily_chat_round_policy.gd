class_name DailyChatRoundPolicy
extends RefCounted


static func get_unavailable_reason(
	current_energy: int,
	session_energy_cost: int,
	current_minutes: int,
	session_minutes: int,
	cutoff_minutes: int
) -> String:
	if current_energy < maxi(0, session_energy_cost):
		return "energy"
	if current_minutes + maxi(0, session_minutes) >= maxi(0, cutoff_minutes):
		return "late"
	return ""
