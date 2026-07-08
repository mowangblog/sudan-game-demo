# EventChecker.gd
# 事件触发检查器 — 检查事件条件的满足情况
# 从 MainScene 调用, 在每天开始时检测可触发事件

class_name EventChecker
extends RefCounted

var _triggered_ids: Array[String] = []

func check_conditions(event: Dictionary) -> bool:
	var tc: Dictionary = event.get("trigger_condition", {})
	var ttype: String = tc.get("type", "")
	
	match ttype:
		"random":
			var chance: float = tc.get("chance", 0.1)
			var min_day: int = tc.get("min_day", 1)
			if TurnManager.current_day < min_day:
				return false
			return randf() < chance
		
		"reputation":
			var rep_type: String = tc.get("reputation", "")
			var threshold: int = tc.get("threshold", 5)
			var current_val: int = ResourceManager.reputations.get(rep_type, 0)
			return current_val >= threshold
		
		_:
			# hold_card / insight / rite / character_idle — 暂不实现
			return false

func get_triggered_events() -> Array:
	var result: Array = []
	for event in DataManager.events:
		if event.get("one_time", false) and _triggered_ids.has(event.get("id", "")):
			continue
		if check_conditions(event):
			result.append(event.duplicate())
	
	result.sort_custom(func(a: Dictionary, b: Dictionary):
		var pa: int = a.get("priority", 3)
		var pb: int = b.get("priority", 3)
		return pa < pb
	)
	return result

func mark_triggered(event_id: String) -> void:
	if not _triggered_ids.has(event_id):
		_triggered_ids.append(event_id)
