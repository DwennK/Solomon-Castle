class_name Equipment
extends RefCounted

# Effect recipes adapted from the Equipment wiki; XP bonuses are excluded.
# Arrays denote inclusive integer rolls. Percentages are additive fractions.
const RECIPES: Dictionary = {
	"staff": [
		[
			{"flat_damage":[3,4]}, {"mana_recovery":0.75}, {"mana_recovery":0.9}, {"skill:shield":1}
		],
		[
			{"gold_bonus":5.0},
			{"skill:missile":1,"skill:multishot":1}, {"skill:missile":2,"skill:multishot":2},
			{"skill:fire":1,"skill:explode":1}, {"skill:fire":2,"skill:explode":2},
			{"skill:ice":1,"skill:chill":1}, {"skill:ice":2,"skill:chill":2},
			{"skill:lightning":1,"skill:chain":1}, {"skill:lightning":2,"skill:chain":2},
			{"skill:lightning":1,"skill:stun":1}, {"skill:lightning":2,"skill:stun":4},
			{"skill:fire":2,"flat_damage":4}, {"flat_damage":10}, {"flat_damage":15},
			{"flat_damage":1,"cast_speed":0.2}, {"flat_damage":4,"cast_speed":0.2},
			{"flat_damage":5,"cast_speed":0.2}, {"flat_damage":7,"cast_speed":0.2},
			{"flat_damage":[1,3],"resistance":0.45}, {"flat_damage":[1,4],"mana_recovery":0.25},
			{"skill:economy":2,"mana_recovery":0.2}
		],
		[
			{"gold_bonus":10.0},
			{"skill:missile":2,"skill:multishot":[1,2]}, {"skill:fire":2,"skill:explode":[1,2]},
			{"skill:ice":2,"skill:cone":1}, {"skill:ice":2,"skill:chill":[1,2]},
			{"skill:ice":2,"skill:freeze":2}, {"skill:lightning":1,"skill:stun":2},
			{"skill:lightning":2,"skill:chain":[1,2]},
			{"skill:fire":2,"skill:economy":[2,3]}, {"skill:ice":2,"skill:economy":[2,3]},
			{"skill:lightning":2,"skill:economy":[2,3]}, {"skill:missile":2,"skill:economy":[2,3]},
			{"flat_damage":5,"skill:economy":1}, {"flat_damage":6,"skill:economy":2},
			{"flat_damage":2,"cast_speed":0.5}, {"flat_damage":4,"cast_speed":0.5},
			{"flat_damage":[2,3],"cast_speed":1.0}, {"flat_damage":[3,4],"resistance":0.45},
			{"flat_damage":7,"resistance":0.45}, {"hp_recovery":10.0,"poison_resistance":0.75},
			{"hp_recovery":10.0,"resistance":0.25}, {"mana_recovery":2.0}, {"mana_recovery":3.5},
			{"grant:reach":1,"mana_recovery":1.0}, {"grant:meditation":1,"mana_recovery":1.0},
			{"grant:mental_focus":1,"flat_damage":3}, {"grant:mental_focus":1,"flat_damage":5},
			{"all_skills":1}, {"all_skills":2}, {"all_skills":3}
		]
	],
	"ring": [
		[
			{"flat_damage":2}, {"skill:lightning":1}, {"skill:potent":3},
			{"mana_recovery":0.2}, {"mana_recovery":0.75}
		],
		[
			{"skill:lightning":2}, {"skill:missile":2}, {"skill:fire":2}, {"skill:ice":2},
			{"skill:regen":2}, {"skill:chain":2},
			{"flat_damage":2,"cast_speed":0.1}, {"flat_damage":5,"cast_speed":0.1},
			{"cast_speed":1.5}, {"cast_speed":0.5,"grant:meditation":1},
			{"mana_recovery":0.25,"resistance":0.45},
			{"mana_recovery":0.5}, {"mana_recovery":1.0}, {"mana_recovery":2.0},
			{"poison_resistance":0.8}, {"poison_resistance":0.8,"hp_recovery":3.0},
			{"skill:mana":1,"mana_recovery":0.1}, {"skill:mana":2,"mana_recovery":0.2},
			{"skill:life":1,"hp_recovery":1.0}, {"skill:life":2,"hp_recovery":3.0}
		],
		[
			{"skill:freeze":[1,2]}, {"skill:circle":[1,2]}, {"skill:acid":[1,2]},
			{"skill:ring_fire":[1,2]}, {"skill:shield":[1,2]},
			{"flat_damage":[4,5],"mana_recovery":0.5}, {"mana_recovery":1.0,"skill:regen":1},
			{"mana_recovery":2.0}, {"skill:mana":2,"mana_recovery":0.25},
			{"skill:life":2,"hp_recovery":3.0}, {"all_skills":1}, {"all_skills":2}
		]
	]
}

const LABELS: Dictionary = {
	"flat_damage":"flat damage", "damage":"damage", "max_mana":"max. mana", "max_hp":"max. health",
	"mana_regen":"mana/s", "hp_regen":"health/s", "cast_speed":"cast speed", "cost_reduction":"mana efficiency",
	"speed":"speed", "resistance":"damage resistance", "mana_recovery":"mana regeneration",
	"hp_recovery":"health regeneration", "poison_resistance":"poison resistance",
	"gold_bonus":"gold found", "all_skills":"all learned skills"
}
const PERCENT: Array[String] = ["damage","cast_speed","cost_reduction","speed","resistance","mana_recovery","hp_recovery","poison_resistance","gold_bonus"]
const POWERS: Dictionary = {"reach":"Telekinesis", "meditation":"Meditation", "mental_focus":"Mental Focus"}

static func templates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot: String in RECIPES:
		for rarity: int in range(3):
			for i: int in range(RECIPES[slot][rarity].size()):
				result.append({"id":"%s_%d_%02d"%[slot,rarity,i],"slot":slot,"rarity":rarity,"bonuses":RECIPES[slot][rarity][i]})
	return result

static func roll(template: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var bonuses: Dictionary = {}
	for key: String in template.bonuses:
		var value: Variant = template.bonuses[key]
		bonuses[key] = rng.randi_range(int(value[0]),int(value[1])) if value is Array else value
	return bonuses

static func bonus_text(key: String, value: float) -> String:
	if key.begins_with("skill:"): return "%+d %s"%[int(value),Catalog.title(key.trim_prefix("skill:"))]
	if key.begins_with("grant:"):
		return ("Grants " if value>0 else "Removes ")+POWERS.get(key.trim_prefix("grant:"),key)
	return ("%+.0f %% "%(value*100) if key in PERCENT else ("%+d "%int(value) if value==floorf(value) else "%+.1f "%value))+LABELS.get(key,key)

static func item_name(slot: String, bonuses: Dictionary) -> String:
	var parts: Array[String] = []
	for key: String in bonuses: parts.append(bonus_text(key,float(bonuses[key])))
	return ("Staff" if slot=="staff" else "Ring")+" · "+" / ".join(parts)
