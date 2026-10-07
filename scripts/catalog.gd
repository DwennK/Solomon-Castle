extends Node

const INDEX = preload("res://scripts/content_index.gd")
var defs: Dictionary = {}
var groups: Dictionary = {}
var textures: Dictionary = {}

func _ready() -> void:
	for definition: ContentDefinition in INDEX.ALL:
		defs[definition.id] = definition
		if not groups.has(definition.kind):
			groups[definition.kind] = []
		groups[definition.kind].append(definition.id)

func definition(id: String) -> ContentDefinition:
	return defs.get(id)

func title(id: String) -> String:
	var d: ContentDefinition = definition(id)
	return d.title if d else id

func ids(kind: String) -> Array:
	return groups.get(kind, [])

func texture(id: String) -> Texture2D:
	if textures.has(id): return textures[id]
	var path: String = "res://assets/art/" + id + ".png"
	var v2_path: String = "res://assets/art/v2/" + id + ".png"
	if ResourceLoader.exists(v2_path): path = v2_path
	var result: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	textures[id] = result
	return result

func skill_texture(id: String) -> Texture2D:
	if ResourceLoader.exists("res://assets/art/v2/"+id+".png"): return texture(id)
	var d: ContentDefinition = definition(id)
	return texture(d.icon if d else id)
