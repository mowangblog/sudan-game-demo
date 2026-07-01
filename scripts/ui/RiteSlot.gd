# RiteSlot.gd
# 仪式槽位 — 地图上接受拖入卡牌的区域
# 发出信号 card_dropped(data: Dictionary)

extends PanelContainer

signal card_dropped(data: Dictionary)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and not data.is_empty()


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var d: Dictionary = data
	card_dropped.emit(d)
