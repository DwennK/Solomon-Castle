class_name DungeonLighting
extends Node2D
## Cached light meshes clipped to visible floor cells, below actors and combat warnings.
var dungeon: Dungeon
var clock: float = 0.0
var light_sources: Array[Dictionary] = []
var pools: Array[Dictionary] = []
var light_texture: GradientTexture2D

func _ready() -> void:
	var blend: CanvasItemMaterial = CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = blend
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,0.25,0.65,1.0])
	gradient.colors = PackedColorArray([Color(1,1,1,0.85),Color(1,1,1,0.55),Color(1,1,1,0.10),Color(1,1,1,0)])
	light_texture = GradientTexture2D.new()
	light_texture.gradient = gradient
	light_texture.width = 128; light_texture.height = 128
	light_texture.fill = GradientTexture2D.FILL_RADIAL
	light_texture.fill_from = Vector2(0.5,0.5); light_texture.fill_to = Vector2(1,0.5)
	light_sources = dungeon.interior.lights.duplicate(true)
	for source: Dictionary in light_sources: build_pool(source)

func build_pool(source: Dictionary) -> void:
	var radii: Vector2 = Vector2.ONE*float(source.radius)
	var center: Vector2 = source.pos
	if source.window:
		center += Vector2(28,86)
		radii = Vector2(140,240)
	var bounds: Rect2 = Rect2(center-radii,radii*2)
	var vertices: PackedVector3Array = PackedVector3Array()
	var uv: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var cells: Array[Vector2i] = []
	for cell: Vector2i in dungeon.cells:
		var tile: Rect2 = Rect2(Vector2(cell*64),Vector2(64,64))
		if not bounds.intersects(tile) or not dungeon.interior.source_reaches(source,tile.get_center()): continue
		var cut: Rect2 = tile.intersection(bounds)
		var offset: int = vertices.size()
		for p: Vector2 in [cut.position,Vector2(cut.end.x,cut.position.y),cut.end,Vector2(cut.position.x,cut.end.y)]:
			vertices.append(Vector3(p.x,p.y,0))
			uv.append((p-bounds.position)/bounds.size)
		indices.append_array(PackedInt32Array([offset,offset+1,offset+2,offset,offset+2,offset+3]))
		cells.append(cell)
	if vertices.is_empty(): return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_TEX_UV] = uv; arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	pools.append({"mesh":mesh,"source":source,"bounds":bounds,"cells":cells})

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	var view: Rect2 = get_viewport_rect().grow(40)
	var transform: Transform2D = get_global_transform_with_canvas()
	for pool: Dictionary in pools:
		if not (transform*pool.bounds).intersects(view): continue
		var source: Dictionary = pool.source
		var flicker: float = 1.0
		if not source.window and not State.options.reduced_effects: flicker = 0.98+sin(clock*2.7+source.pos.x)*0.012+sin(clock*4.1+source.pos.y)*0.008
		draw_mesh(pool.mesh,light_texture,Transform2D.IDENTITY,Color(source.color,float(source.energy)*flicker))
