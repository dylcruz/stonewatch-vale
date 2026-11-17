@tool
extends SceneTree
## Run with --headless --path . --script res://tools/bake_navigation.gd
const ARENA_SCENE := "res://scenes/watchpost_arena.tscn"

func _initialize() -> void:
	bake.call_deferred()

func bake() -> void:
	var scene := load(ARENA_SCENE) as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	# Let the authored CSG terrain build its meshes before parsing the colliders.
	await process_frame
	var region := world.get_node("NavigationRegion3D") as NavigationRegion3D
	region.bake_navigation_mesh(false)
	if region.navigation_mesh.get_polygon_count() == 0:
		push_error("Navigation bake produced no polygons; scene was not saved")
		quit(1)
		return
	var packed := PackedScene.new()
	var error := packed.pack(world)
	if error == OK:
		error = ResourceSaver.save(packed, ARENA_SCENE)
	print("Navigation bake: ", region.navigation_mesh.get_polygon_count(), " polygons; save error: ", error)
	world.free()
	await process_frame
	quit(error)
