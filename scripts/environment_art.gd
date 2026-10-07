class_name EnvironmentArt
extends RefCounted
## One camera, one material palette; atlas bounds measured from the generated alpha.
const FLOORS: Array[Texture2D] = [preload("res://assets/art/dungeon_v5/limestone-floor.png"),preload("res://assets/art/dungeon_v5/slate-floor.png"),preload("res://assets/art/dungeon_v5/brick-floor.png")]
const INLAY: Texture2D = preload("res://assets/art/dungeon_v5/inlay-floor.png")
const MASONRY: Texture2D = preload("res://assets/art/dungeon_v5/wall-masonry.png")
const FURNITURE: Texture2D = preload("res://assets/art/dungeon_v5/furniture.png")
const ARCHITECTURE: Texture2D = preload("res://assets/art/dungeon_v5/architecture.png")
const PROPS: Texture2D = preload("res://assets/art/dungeon_v5/interactables.png")
const STAIRS: Texture2D = preload("res://assets/art/dungeon_v5/stairs.png")
const FURNITURE_REGIONS: Array[Rect2] = [Rect2(72,198,422,303),Rect2(559,104,419,396),Rect2(1070,126,412,378),Rect2(44,678,481,276),Rect2(552,570,434,377),Rect2(1050,703,450,263)]
const ARCHITECTURE_REGIONS: Array[Rect2] = [Rect2(256,38,148,569),Rect2(764,37,298,568),Rect2(205,674,251,499),Rect2(752,656,331,538)]
const PROP_REGIONS: Array[Rect2] = [Rect2(71,184,515,377),Rect2(690,55,496,506),Rect2(116,636,420,549),Rect2(728,652,417,522)]
static var cache: Dictionary = {}

static func region(texture: Texture2D,rect: Rect2) -> AtlasTexture:
	var key: String = texture.resource_path+str(rect)
	if not cache.has(key):
		var result: AtlasTexture = AtlasTexture.new()
		result.atlas = texture; result.region = rect; result.filter_clip = true
		cache[key] = result
	return cache[key]

static func furniture(index: int) -> Texture2D:
	return region(FURNITURE,FURNITURE_REGIONS[index])

static func architecture(index: int) -> Texture2D:
	return region(ARCHITECTURE,ARCHITECTURE_REGIONS[index])

static func prop(kind: String,opened: bool = false) -> Texture2D:
	if kind=="stairs": return region(STAIRS,Rect2(340,109,575,958))
	var index: int = {"chest":1 if opened else 0,"urn":2,"torch":3}.get(kind,-1)
	return region(PROPS,PROP_REGIONS[index]) if index>=0 else null
