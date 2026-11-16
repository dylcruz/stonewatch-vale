extends MultiMeshInstance3D
## A view of the remaining navigation route; it never sends movement commands.

@export var subject: ValePlayer
@export var enabled := true
@export_range(0.2, 2.0, 0.05) var spacing := 0.65
@export var height_offset := 0.04

var requested_path := PackedVector3Array()

func _ready() -> void:
	# Each scene instance owns its draw buffer, including in regression tests.
	multimesh = multimesh.duplicate()
	multimesh.visible_instance_count = 0
	subject.movement_path_changed.connect(_accept_path)

func _accept_path(path: PackedVector3Array) -> void:
	requested_path = path

func _process(_delta: float) -> void:
	if not enabled or not subject.moving:
		multimesh.visible_instance_count = 0
		return
	var path := subject.agent.get_current_navigation_path()
	var path_index := subject.agent.get_current_navigation_path_index()
	# A new command can arrive before the agent updates its internal path.
	# Use its already validated route during that first frame, never the old one.
	if path.is_empty() or path[path.size() - 1].distance_to(subject.destination) > 0.15:
		path = requested_path
		path_index = 1
	var remaining := PackedVector3Array([subject.global_position])
	for i in range(path_index, path.size()):
		remaining.append(path[i])
	var dots := PackedVector3Array()
	var distance_to_dot := 0.0
	# Anchor spacing at the destination, so dots stay in place as we walk.
	for i in range(remaining.size() - 1, 0, -1):
		var start := remaining[i]
		var end := remaining[i - 1]
		var length := start.distance_to(end)
		if length < 0.001:
			continue
		while distance_to_dot <= length:
			var point := start.lerp(end, distance_to_dot / length)
			if point.distance_to(subject.global_position) > 0.4:
				dots.append(point + Vector3.UP * height_offset)
			distance_to_dot += spacing
		distance_to_dot -= length
	if dots.size() > multimesh.instance_count:
		# Grow infrequently; drawing a long route still uses one MultiMesh.
		multimesh.instance_count = nearest_po2(dots.size())
	for i in dots.size():
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, to_local(dots[i])))
	multimesh.visible_instance_count = dots.size()
