class_name ProgressionRules
extends RefCounted

const VERSION: int = 1
# Full regular clears, before optional trials and the small large-layout bonus.
const FLOOR_LEVELS: Array[float] = [1.0,4.4,6.7,8.8,11.0,13.8,16.5,19.0,22.0,25.0,28.0,31.0,33.5,36.0]
const THREAT: Dictionary = {"skeleton":1.0,"archer":1.25,"ghoul":1.7,"zombie":1.4,"sorcerer":2.0,"imp":1.5,"ghost":1.8,"knight":2.0}

static func threshold(level: int) -> float:
	return 32.0+level*19.0+pow(level,1.5)*2.0

static func total_xp(level: float) -> float:
	var total: float = 0.0
	for value: int in range(1,int(level)): total+=threshold(value)
	return total+(level-floorf(level))*threshold(int(level))

static func floor_budget(number: int) -> float:
	var index: int = clampi(number,1,13)
	return total_xp(FLOOR_LEVELS[index])-total_xp(FLOOR_LEVELS[index-1])

static func threat(enemy: Dictionary) -> float:
	if enemy.get("fragment",false): return 0.0
	return float(THREAT.get(enemy.kind,1.0))*(1.35 if enemy.get("elite",false) else 1.0)

static func prepare_floor(data: Dictionary) -> void:
	if int(data.get("xp_version",0))>=VERSION: return
	# Include dead records on migration: surviving monsters never inherit claimed XP.
	var regular: Array = []
	var bosses: Array = []
	var trials: Array = []
	for enemy: Dictionary in data.enemies:
		if enemy.get("trial",false): trials.append(enemy)
		elif enemy.id in ["boss","guardian"]: bosses.append(enemy)
		else: regular.append(enemy)
	var budget: float = ceilf(floor_budget(int(data.number))*(1.0+clampf((data.rooms.size()-8)*0.01,0.0,0.04)))
	var boss_share: float = 0.24 if not bosses.is_empty() else 0.0
	var weight: float = 0.0
	for enemy: Dictionary in regular: weight+=threat(enemy)
	for enemy: Dictionary in regular: enemy.xp_reward=budget*(1.0-boss_share)*threat(enemy)/maxf(1.0,weight)
	var boss_weight: float = 0.0
	for enemy: Dictionary in bosses: boss_weight+=2.0 if enemy.id=="boss" else 1.0
	for enemy: Dictionary in bosses: enemy.xp_reward=budget*boss_share*(2.0 if enemy.id=="boss" else 1.0)/boss_weight
	weight=0.0
	for enemy: Dictionary in trials: weight+=threat(enemy)
	for enemy: Dictionary in trials: enemy.xp_reward=budget*0.08*threat(enemy)/maxf(1.0,weight)
	data.xp_budget=budget
	data.xp_version=VERSION

static func health_multiplier(difficulty: int) -> float:
	return 1.0+0.12*clampi(difficulty,0,4)

static func damage_multiplier(difficulty: int) -> float:
	return 1.0+0.10*clampi(difficulty,0,4)

static func floor_health_multiplier(number: int, boss: bool) -> float:
	var depth: float = clampi(number,1,13)-1
	var late_depth: float = maxf(0,depth-3)
	return 1.0+late_depth*0.07 if boss else 1.0+depth*0.16+late_depth*late_depth*0.03
