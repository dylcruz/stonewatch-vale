@tool
extends SceneTree
## Run with --headless --path . --script res://tools/bake_navigation.gd
func _initialize() -> void:
	bake.call_deferred()

func bake() -> void:
	var scene := load("res://scenes/movement_demo.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	var region := world.get_node("NavigationRegion3D") as NavigationRegion3D
	region.bake_navigation_mesh(false)
	if region.navigation_mesh.get_polygon_count() == 0:
		push_error("Navigation bake produced no polygons; scene was not saved")
		quit(1)
		return
	var packed := PackedScene.new()
	var error := packed.pack(world)
	if error == OK:
		error = ResourceSaver.save(packed, "res://scenes/movement_demo.tscn")
	print("Navigation bake: ", region.navigation_mesh.get_polygon_count(), " polygons; save error: ", error)
	world.free()
	await process_frame
	quit(error)
