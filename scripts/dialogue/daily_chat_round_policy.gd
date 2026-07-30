class_name DailyChatRoundPolicy
extends RefCounted


static func get_unavailable_reason(
	current_energy: int,
	energy_cost_per_round: int,
	current_minutes: int,
	minutes_per_round: int,
	cutoff_minutes: int
) -> String:
	if current_energy < maxi(0, energy_cost_per_round):
		return "energy"
	if current_minutes + maxi(0, minutes_per_round) >= maxi(0, cutoff_minutes):
		return "late"
	return ""
