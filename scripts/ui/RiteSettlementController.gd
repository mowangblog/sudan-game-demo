# RiteSettlementController.gd
# Drives active rite settlement one by one.

class_name RiteSettlementController
extends RefCounted

const SettlementScreen = preload("res://scripts/ui/SettlementScreen.gd")

var root: Control
var active_rites: Array
var reward_applier: RiteRewardApplier
var settle_sultan_used: bool = false
var _callbacks: Dictionary = {}

func setup(p_root: Control, p_active_rites: Array, p_reward_applier: RiteRewardApplier, callbacks: Dictionary) -> void:
	root = p_root
	active_rites = p_active_rites
	reward_applier = p_reward_applier
	_callbacks = callbacks


func start() -> void:
	if GameManager.is_game_over:
		_call("log", ["⚰️ 游戏已结束。"])
		_call("refresh")
		return
	if active_rites.size() == 0:
		_call("log", ["⚔ 无事发生，推进一天。"])
		active_rites.clear()
		TurnManager.next_day()
		_call("update_countdown")
		_call("refresh")
		if GameManager.is_game_over:
			_call("show_game_over")
		return
	settle_sultan_used = false
	_call("log", ["⚔ 开始结算 %d 个仪式..." % active_rites.size()])
	_settle_next(0)


func _settle_next(index: int) -> void:
	if index >= active_rites.size():
		_finish_all()
		return

	var active_rite = active_rites[index]
	if active_rite.get("insight", false) and active_rite.char.is_empty():
		_call("log", ["⚠ 「%s」缺少角色，跳过结算。" % active_rite.rite.get("name", "?")])
		_settle_next(index + 1)
		return

	if not active_rite.sultan_card.is_empty():
		settle_sultan_used = true

	var screen = SettlementScreen.new()
	root.add_child(screen)
	var reward_context = reward_applier.prepare_context(active_rite)
	screen.setup_and_show(active_rite.rite, active_rite.char, active_rite.sultan_card, "")
	screen.settlement_done.connect(func(result: Dictionary):
		_call("log", ["  结算：「%s」%s" % [result.rite.get("name", ""), "成功" if result.success else "失败"]])
		var notifications = reward_applier.apply_result(active_rite, result, reward_context)
		_call("show_toasts", [notifications])
		_settle_next(index + 1)
	)


func _finish_all() -> void:
	if settle_sultan_used:
		GameManager.consume_sultan_card(0)
		_call("log", ["🃏 苏丹卡已消耗。"])
	_call("restore_hand_cards")
	for active_rite in active_rites:
		if active_rite.rite.has("s2_gold") and active_rite.rite.get("insight_trigger", {}).get("subtype", "") == "LUXURY":
			if not active_rite.char.is_empty():
				GameManager.renovation_done = true
				_call("log", ["🏠 装修已完成！"])
	active_rites.clear()
	_call("reset_rite_btn_labels")
	TurnManager.next_day()
	_call("update_countdown")
	_call("log", ["✅ 所有仪式结算完毕。"])
	_call("refresh")
	if GameManager.is_game_over:
		_call("show_game_over")


func _call(name: String, args: Array = []) -> void:
	var cb = _callbacks.get(name, Callable())
	if cb.is_valid():
		cb.callv(args)
