class_name SimulationRules
extends RefCounted

static func calculate_job_reward(base_reward: float, quality: float) -> float:
	return round(base_reward * clamp(quality, 0.0, 1.2))

static func calculate_production_units(elapsed_seconds: float, units_per_minute: float) -> int:
	if elapsed_seconds <= 0.0 or units_per_minute <= 0.0:
		return 0
	return int(floor(elapsed_seconds * units_per_minute / 60.0))

static func calculate_offline_income(seconds: float, jobs_per_hour: float, reward: float) -> float:
	return max(0.0, seconds) / 3600.0 * max(0.0, jobs_per_hour) * max(0.0, reward)

static func quality_after_process(quality: float, skill: float, modifier: float = 0.0) -> float:
	var result: float = quality + (skill - 1.0) * 0.035 + modifier
	return clamp(result, 0.45, 1.2)

static func station_status(queue_size: int, capacity: int, has_input: bool, has_worker: bool, is_machine: bool, output_blocked: bool) -> String:
	if output_blocked:
		return "BLOCKED"
	if queue_size > capacity:
		return "OVERLOADED"
	if not has_input and not has_worker and not is_machine:
		return "STARVED"
	if has_input and not has_worker and not is_machine:
		return "WAITING"
	if has_input or has_worker or is_machine:
		return "PROCESSING"
	return "IDLE"
