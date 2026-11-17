@tool
extends SceneTree
## Run with --headless --path . --script res://tools/bake_navigation.gd
const WATCHPOST_SCENE := "res://scenes/watchpost_playtest.tscn"
const WATCHPOST_NAVIGATION := "res://scenes/vale/watchpost_navigation.tres"
const TOWN_SCENE := "res://scenes/stonewatch_vale.tscn"
const TOWN_NAVIGATION := "res://scenes/vale/town_navigation.tres"

func _initialize() -> void:
	bake.call_deferred()

func bake() -> void:
	var error := await bake_scene(WATCHPOST_SCENE, WATCHPOST_NAVIGATION)
	if error == OK:
		error = await bake_scene(TOWN_SCENE, TOWN_NAVIGATION)
	quit(error)

func bake_scene(scene_path: String, navigation_path: String) -> Error:
	var scene := load(scene_path) as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	# Let the authored CSG terrain build its meshes before parsing the colliders.
	await process_frame
	var region := world.get_node("NavigationRegion3D") as NavigationRegion3D
	region.bake_navigation_mesh(false)
	var polygons := region.navigation_mesh.get_polygon_count()
	var error := ERR_CANT_CREATE
	if polygons == 0:
		push_error("Navigation bake produced no polygons for " + scene_path)
	else:
		error = ResourceSaver.save(region.navigation_mesh, navigation_path)
	print("Navigation bake for ", scene_path, ": ", polygons, " polygons; save error: ", error)
	world.free()
	await process_frame
	return error
