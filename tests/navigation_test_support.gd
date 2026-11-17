extends RefCounted

static func wait_for_spawn(world: Node3D, player: ValePlayer) -> void:
	var tree := world.get_tree()
	var region := world.get_node("NavigationRegion3D") as NavigationRegion3D
	var map := player.agent.get_navigation_map()
	var region_id := region.get_rid()
	# The map can synchronize before this scene's baked region is published.
	for _frame in 600:
		var spawn := player.global_position
		if NavigationServer3D.map_get_iteration_id(map) > 0 \
			and NavigationServer3D.map_get_closest_point_owner(map, spawn) == region_id \
			and NavigationServer3D.map_get_closest_point(map, spawn).distance_to(spawn) < 0.55:
			return
		await tree.physics_frame
	push_error("Baked navigation did not synchronize at the player spawn")
	tree.quit(1)
	await tree.process_frame
