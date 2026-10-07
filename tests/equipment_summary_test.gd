extends Node

var errors: Array[String] = []
var checks: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: errors.append(message);push_error(message)

func gear(bonuses: Dictionary, slot: String = "staff") -> Dictionary:
	State.run.serial += 1
	var item: Dictionary = {"uid":"compact_%d" % State.run.serial,"name":"Test","slot":slot,"rarity":2,"bonuses":bonuses,"price":300}
	State.run.inventory.append(item)
	return item

func summary(item: Dictionary, slot: String = "staff", remove: bool = false) -> Dictionary:
	var original: String = JSON.stringify(State.run)
	var result: Dictionary = EquipmentPreview.compact(EquipmentPreview.compare(item.uid,slot,remove))
	check(JSON.stringify(State.run)==original,"Compact preview preserves live state")
	return result

func has(rows: Array, title: String, part: String = "") -> bool:
	return rows.any(func(row: Dictionary)->bool:return row.title==title and (part.is_empty() or row.text.contains(part)))

func _ready() -> void:
	if not State.qa: get_tree().quit(1);return
	State.fresh(780)
	State.learn("lightning");State.run.active="lightning"
	var staff: Dictionary = gear({"skill:lightning":2,"skill:chain":2})
	var s: Dictionary = summary(staff)
	check(has(s.metrics,"Damage / second") and has(s.metrics,"Spell cost"),"Shows actual damage and mana tradeoff")
	check(has(s.effects,"Chain targets","+2"),"Chain synergy is visible without opening details")
	check(s.metrics.size()==2 and s.effects.size()==1,"Simple lightning item stays compact")
	check(s.metrics[1].gain==false,"Higher mana consumption is a loss despite a positive delta")
	State.learn("fire");State.run.active="fire"
	s=summary(staff)
	check(not has(s.effects,"Chain targets") and not has(s.metrics,"Damage / second"),"Inactive lightning does not flood the active fire summary")
	var fire: Dictionary = gear({"skill:explode":2,"skill:embers":1})
	s=summary(fire)
	check(has(s.effects,"Explosion radius") and has(s.effects,"Embers per impact","+3"),"Explosion and embers surface as real effects")
	State.learn("missile");State.learn("fire_missile");State.run.active="fire_missile"
	s=summary(fire)
	check(not has(s.effects,"Explosion radius") and not has(s.effects,"Embers per impact"),"Frozen fusion never claims elemental equipment synergy")
	check(has(s.effects,"Current fusion","Snapshot ranks"),"Frozen fusion explains why ranks do not apply")
	s=summary(gear({"flat_damage":7,"cast_speed":0.5}))
	check(has(s.metrics,"Damage / second") and not has(s.effects,"Current fusion"),"General bonuses still improve fusion without an irrelevant warning")
	State.fresh(781);State.learn("missile");State.learn("shield")
	var meditation: Dictionary = gear({"grant:meditation":1,"mana_recovery":1.0},"ring")
	s=summary(meditation,"ring1")
	check(has(s.effects,Catalog.title("meditation"),"×4"),"Meditation explains its benefit")
	State.equip(meditation.uid,"ring1")
	s=summary(gear({"grant:meditation":1},"ring"),"ring2")
	check(has(s.effects,Catalog.title("meditation"),"does not stack"),"Duplicate powers have no fake gain")
	s=summary(meditation,"ring1",true)
	check(has(s.effects,Catalog.title("meditation"),"Power lost"),"Removing meditation exposes power loss")
	check(has(s.metrics,"Mana regeneration","−"),"Removal exposes lost regeneration")
	var focus: Dictionary = gear({"grant:mental_focus":1},"ring")
	State.equip(focus.uid,"ring2")
	s=summary(focus,"ring2",true)
	check(has(s.effects,Catalog.title("focus"),"Power lost") and not has(s.effects,Catalog.title("shield")+" · cooldown"),"Losing focus warns once without duplicating each ritual cooldown")
	State.fresh(782);State.learn("missile");State.run.skills.resist=12;State.run.skills.economy=9
	s=summary(gear({"resistance":0.45,"skill:economy":2}))
	check(has(s.effects,"Capped bonuses") and not has(s.metrics,"Protection"),"Caps are explained without invented protection")
	State.fresh(783);State.learn("teleport");State.learn("freeze")
	s=summary(gear({"skill:shield":2}))
	check(has(s.effects,Catalog.title("shield"),"occupied"),"Blocked granted ritual remains visible")
	State.run.level=20
	var granted: Dictionary=gear({"skill:lightning":1,"skill:shield":2})
	State.equip(granted.uid,"staff")
	s=summary(granted,"staff",true)
	check(has(s.effects,Catalog.title("lightning"),"Spell lost") and has(s.effects,Catalog.title("shield"),"Spell lost"),"Lost temporary spells are always explicit")
	check(has(s.effects,"Active magic","No magic"),"No remaining active spell is called out")
	State.fresh(784)
	for id: String in ["fire","lightning","missile","ice","life","mana","regen","power","rush"]: State.learn(id)
	State.run.active="missile"
	State.equip(gear({"hp_recovery":3.0,"resistance":0.45,"poison_resistance":0.8,"gold_bonus":0.5}).uid,"staff")
	s=summary(gear({"all_skills":2}))
	check(has(s.metrics,"Protection","−") and has(s.metrics,"Poison protection","−") and has(s.metrics,"Gold found","−") and has(s.metrics,"Health regeneration","−"),"Important losses survive the four-metric gain budget")
	check(s.extra_metrics>0,"Less important positive metrics remain in full details")
	var report: Dictionary={"checks":checks,"errors":errors}
	DirAccess.make_dir_recursive_absolute("res://outputs")
	var file: FileAccess=FileAccess.open("res://outputs/equipment-summary-tests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("EQUIPMENT_SUMMARY ",JSON.stringify(report))
	get_tree().quit(0 if errors.is_empty() else 1)
