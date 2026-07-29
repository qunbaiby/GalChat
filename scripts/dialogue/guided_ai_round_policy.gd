extends RefCounted


func should_close_after_round(current_round: int, max_rounds: int) -> bool:
	return max_rounds > 0 and current_round >= max_rounds