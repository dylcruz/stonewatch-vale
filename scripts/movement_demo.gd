extends Node3D

@onready var player: ValePlayer = $Player
@onready var camera: Camera3D = $Camera3D
@onready var marker: Node3D = $DestinationMarker
@onready var status: Label = $HUD/Panel/Margin/VBox/Status
const HOLD_UPDATE_INTERVAL := 0.1
const HOLD_DESTINATION_DISTANCE := 0.35

var marker_tween: Tween
var following_cursor := false
var hold_update_elapsed := 0.0
var cursor_position := Vector2.ZERO

func _ready() -> void:
	player.command_changed.connect(func(message: String): status.text = message)
	$HUD/Panel/Margin/VBox/UITest.pressed.connect(func(): status.text = "UI click received · movement command preserved")
	marker.hide()
	get_window().focus_exited.connect(_stop_following_cursor)
	get_viewport().mouse_exited.connect(_stop_following_cursor)

func _stop_following_cursor() -> void:
	following_cursor = false

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		cursor_position = event.position
	# Releases must end the gesture even when a Control consumes the event.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_stop_following_cursor()

func _physics_process(delta: float) -> void:
	if not following_cursor:
		return
	hold_update_elapsed += delta
	if hold_update_elapsed < HOLD_UPDATE_INTERVAL:
		return
	hold_update_elapsed = 0.0
	if get_viewport().get_visible_rect().has_point(cursor_position) and get_viewport().gui_get_hovered_control() == null:
		click_world(cursor_position, true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		following_cursor = true
		hold_update_elapsed = 0.0
		click_world(event.position)
		get_viewport().set_input_as_handled()

func click_world(screen_position: Vector2, held_update: bool = false) -> bool:
	var origin := camera.project_ray_origin(screen_position)
	var end := origin + camera.project_ray_normal(screen_position) * 250.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1 | 2 | 8)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider: Node3D = hit.collider
	if collider.is_in_group("move_targets") and not held_update:
		var direction := player.global_position - collider.global_position
		direction.y = 0
		if direction.length_squared() < 0.01:
			direction = Vector3.BACK
		var approach := collider.global_position + direction.normalized() * 1.35
		approach.y = 0
		if player.request_move(approach, collider):
			show_destination(player.destination)
			return true
	elif collider.is_in_group("walkable"):
		# Repath at a bounded rate, and leave a stable destination alone on arrival.
		var destination_offset := Vector2(hit.position.x - player.destination.x, hit.position.z - player.destination.z)
		if held_update and player.selected_target == null and destination_offset.length() < HOLD_DESTINATION_DISTANCE:
			return false
		if player.request_move(hit.position):
			show_destination(player.destination)
			return true
	return false

func show_destination(point: Vector3) -> void:
	if marker_tween:
		marker_tween.kill()
	marker.position = point + Vector3(0, 0.06, 0)
	marker.scale = Vector3.ONE
	marker.show()
	marker_tween = create_tween()
	marker_tween.tween_property(marker, "scale", Vector3.ONE * 0.65, 0.65)
	marker_tween.tween_callback(marker.hide)
