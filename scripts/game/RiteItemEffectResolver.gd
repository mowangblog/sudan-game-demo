class_name RiteItemEffectResolver
extends RefCounted

const INTEL_EFFECTS := {
	"战术": {"attribute": "com", "attribute_bonus": 1, "rerolls": 1},
	"秘密": {"attribute": "soc", "attribute_bonus": 1, "rerolls": 1},
	"洞察": {"attribute": "wis", "attribute_bonus": 1, "rerolls": 1},
	"机遇": {"attribute": "sur", "attribute_bonus": 1, "rerolls": 1},
	"内幕": {"attribute": "cha", "attribute_bonus": 1, "rerolls": 1},
	"预兆": {"attribute": "mag", "attribute_bonus": 1, "rerolls": 1},
	"秘氛": {"attribute": "ste", "attribute_bonus": 1, "rerolls": 1},
	"密教": {"attribute": "mag", "attribute_bonus": 2, "rerolls": 0},
}

const ATTR_LABELS := {
	"phy": "体魄",
	"com": "战斗",
	"sur": "生存",
	"soc": "社交",
	"cha": "魅力",
	"ste": "隐匿",
	"wis": "智慧",
	"mag": "魔力",
}

static func resolve(items: Array) -> Dictionary:
	var result := {
		"attribute_bonuses": {},
		"rerolls": 0,
		"descriptions": [],
	}
	for item in items:
		if not item is Dictionary:
			continue
		if _resource_type(item) != "intel":
			continue
		var name = item.get("name", "")
		var effect = INTEL_EFFECTS.get(name, {})
		if effect.is_empty():
			continue
		var multiplier = _quality_multiplier(item.get("quality", "STONE"))
		var count = max(1, item.get("count", 1))
		var attr = effect.get("attribute", "")
		var attr_bonus = effect.get("attribute_bonus", 0) * multiplier * count
		var rerolls = effect.get("rerolls", 0) * multiplier * count
		if attr != "" and attr_bonus > 0:
			result.attribute_bonuses[attr] = result.attribute_bonuses.get(attr, 0) + attr_bonus
		result.rerolls += rerolls
		result.descriptions.append("%s：%s+%d%s" % [
			name,
			ATTR_LABELS.get(attr, attr),
			attr_bonus,
			("，重投+%d" % rerolls) if rerolls > 0 else ""
		])
	return result


static func bonus_for_check(check: Dictionary, effects: Dictionary) -> int:
	var bonuses = effects.get("attribute_bonuses", {})
	if check.get("type", "solo") == "combined":
		var total = 0
		for attr in check.get("attributes", []):
			total += bonuses.get(attr, 0)
		return total
	return bonuses.get(check.get("attribute", ""), 0)


static func _resource_type(item: Dictionary) -> String:
	var resource_type = item.get("resource_type", "")
	if resource_type != "":
		return resource_type
	return "gold" if item.get("name", "") == "金币" else "intel"


static func _quality_multiplier(quality: String) -> int:
	match quality:
		"SILVER":
			return 3
		"COPPER", "BRONZE":
			return 2
		"GOLD":
			return 4
		_:
			return 1
