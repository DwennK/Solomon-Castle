class_name LegacyEnglish
extends RefCounted

# Translate display-only fields in old saves without changing item identity or stats.
const CHECKPOINTS: Dictionary = {
	"Retour au village":"Back to the village", "Point de reprise":"Checkpoint", "Ancien point de reprise":"Previous checkpoint",
	"Première magie apprise":"First spell learned", "Étage suivant":"Next floor",
	"Retour par le portail":"Return through portal", "Arrivée dans l’étage":"Floor entry"
}
const ITEM_WORDS: Dictionary = {
	"Bâton de cristal":"Crystal Staff", "Bâton de frêne":"Ash Staff", "Bâton d’os":"Bone Staff",
	"Anneau d’onyx":"Onyx Ring", "Anneau d’argent":"Silver Ring", "Anneau de cuivre":"Copper Ring",
	"de braise":"of Embers", "de lucidité":"of Clarity", "de l’aube":"of Dawn",
	"du pèlerin":"of the Pilgrim", "du vif-éclair":"of Swift Lightning", "des os":"of Bones",
	"des étoiles":"of Stars", "de sobriété":"of Restraint", "du rempart":"of the Rampart", "de la source":"of the Spring"
}

static func normalize(saved: Dictionary) -> void:
	if saved.is_empty(): return
	var info: Dictionary = saved.get("checkpoint_info",{})
	if info.has("reason"): info.reason = CHECKPOINTS.get(info.reason,info.reason)
	for key: String in ["inventory","shop"]:
		for item: Dictionary in saved.get(key,[]): translate_item(item)
	for floor_data: Dictionary in saved.get("floors",{}).values():
		for drop: Dictionary in floor_data.get("loot",[]):
			if drop.get("item") is Dictionary: translate_item(drop.item)

static func translate_item(item: Dictionary) -> void:
	var title: String = item.get("name","")
	if title.begins_with("Bâton · ") or title.begins_with("Anneau · "):
		item.name = Equipment.item_name(item.slot,item.bonuses)
		return
	for old: String in ITEM_WORDS: title = title.replace(old,ITEM_WORDS[old])
	if item.has("name"): item.name = title
