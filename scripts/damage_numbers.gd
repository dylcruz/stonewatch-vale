extends Node3D
## Each hit follows the actor while it rises and fades.

@export var hit_color := Color("#ffe29a")

func show_damage(amount: int) -> void:
	if amount <= 0:
		return
	for previous: Label3D in get_children():
		previous.offset.y += 44.0
	var number := Label3D.new()
	number.text = str(amount)
	number.modulate = hit_color
	number.font_size = 40
	number.pixel_size = 0.022
	number.outline_size = 8
	number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	number.no_depth_test = true
	add_child(number)
	var animation := number.create_tween().set_parallel(true)
	animation.tween_property(number, "position:y", 1.6, 0.95)
	animation.tween_property(number, "modulate:a", 0.0, 0.45).set_delay(0.5)
	animation.tween_property(number, "outline_modulate:a", 0.0, 0.45).set_delay(0.5)
	animation.chain().tween_callback(number.queue_free)
