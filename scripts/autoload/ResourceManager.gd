# ResourceManager.gd
# AutoLoad 资源管理器 — 管理三层资源系统
# 层级1: 金币（唯一经济货币）
# 层级2: 五声望计数器（善名/恶名/权势/侠名/灵视）
# 层级3: 情报卡牌（以卡牌形式存在，由 CardManager 管理）

extends Node

## === 经济资源 ===
var gold: int = 20                     # [PLACEHOLDER] 初始金币

## === 声望计数器 ===
# 五声望 + 金骰子数量
var reputations: Dictionary = {
	"good": 0,       # 善名 — 阈值: 3(复制), 10(复原), 20(净化之火)
	"evil": 0,       # 恶名 — 阈值: 3(挑战), 5(裁决), 10(暗杀), 20(拥抱黑暗)
	"power": 0,      # 权势 — 阈值: 5(上朝), 9(联动侠名)
	"hero": 0,       # 侠名 — 阈值: 3, 6, 9, 10, 20
	"spirit": 0      # 灵视 — 阈值: 2(心灵之战), 3(幻痛)
}

var gold_dice: int = 3                 # 金骰子 — 检定后每颗+1成功

func reset() -> void:
	gold = 20
	gold_dice = 3
	reputations = {
		"good": 0, "evil": 0, "power": 0, "hero": 0, "spirit": 0
	}


## === 五声望阈值表（已验证原版数据） ===
const REPUTATION_THRESHOLDS: Dictionary = {
	"good":    [3, 10, 20],
	"evil":    [3, 5, 10, 20],
	"power":   [5, 9],
	"hero":    [3, 6, 9, 10, 20],
	"spirit":  [2, 3]
}

## === 便捷属性访问（给 UI 使用） ===
var good_reputation: int:
	get: return reputations.good
var evil_reputation: int:
	get: return reputations.evil
var power: int:
	get: return reputations.power
var hero_reputation: int:
	get: return reputations.hero
var spirit: int:
	get: return reputations.spirit


## === 金币操作 ===
func modify_gold(delta: int) -> void:
	gold = max(0, gold + delta)
	EventBus.gold_changed.emit(gold, delta)

func add_gold(delta: int) -> void:
	modify_gold(delta)

func has_gold(amount: int) -> bool:
	return gold >= amount

func spend_gold(amount: int) -> bool:
	if has_gold(amount):
		modify_gold(-amount)
		return true
	return false


## === 声望便捷操作 ===
func add_power(delta: int) -> void:
	modify_reputation("power", delta)


## === 声望操作 ===
func modify_reputation(type: String, delta: int) -> void:
	assert(type in reputations, "Unknown reputation type: %s" % type)
	var old_value = reputations[type]
	reputations[type] = max(0, reputations[type] + delta)
	EventBus.reputation_changed.emit(type, reputations[type])

	# 检查是否越过阈值
	_check_thresholds(type, old_value, reputations[type])


func _check_thresholds(type: String, old_val: int, new_val: int) -> void:
	if not type in REPUTATION_THRESHOLDS:
		return
	var thresholds = REPUTATION_THRESHOLDS[type]
	for threshold in thresholds:
		if old_val < threshold and new_val >= threshold:
			EventBus.reputation_threshold_reached.emit(type, threshold)


func get_reputation(type: String) -> int:
	return reputations.get(type, 0)


## === 金骰子操作 ===
func modify_gold_dice(delta: int) -> void:
	gold_dice = max(0, gold_dice + delta)

func use_gold_dice(count: int) -> int:
	# 返回实际使用的数量
	var actual = min(count, gold_dice)
	gold_dice -= actual
	return actual


## === 善名/恶名互斥检查 ===
# 触发善名神迹时，恶名必须 < 3
func can_trigger_good_miracle() -> bool:
	return reputations.evil < 3
