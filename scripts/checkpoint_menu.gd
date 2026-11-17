extends Control

const TOWN := preload("res://scenes/stonewatch_vale.tscn")
const WATCHPOST := preload("res://scenes/watchpost_playtest.tscn")
const WATCHPOST_SLOT := "user://watchpost-playtest-slot.save"

@onready var new_game: Button = %NewGame
@onready var continue_game: Button = %Continue
@onready var message: Label = %Message

var slot: ValeSaveSlot
var gameplay_scene: PackedScene
var saved_checkpoint: Dictionary

func _ready() -> void:
	var watchpost := OS.is_debug_build() and "--watchpost-save" in OS.get_cmdline_user_args()
	if gameplay_scene == null:
		gameplay_scene = WATCHPOST if watchpost else TOWN
	if slot == null:
		slot = ValeSaveSlot.new(WATCHPOST_SLOT if watchpost else ValeSaveSlot.PLAYER_PATH)
	if gameplay_scene == WATCHPOST:
		%Title.text = "Watchpost Playtest"
	refresh_slot()
	new_game.pressed.connect(_new_game)
	continue_game.pressed.connect(_continue_game)
	if continue_game.disabled:
		new_game.grab_focus()
	else:
		continue_game.grab_focus()

func refresh_slot() -> void:
	var slot_exists := slot.exists()
	saved_checkpoint = slot.read() if slot_exists else {}
	continue_game.disabled = not _valid_checkpoint(saved_checkpoint)
	message.text = "No saved game" if not slot_exists else ""
	if slot_exists and continue_game.disabled:
		message.text = "Save could not be read. You can start a new game."

func _valid_checkpoint(data: Dictionary) -> bool:
	return data.get("experience") is int and data.get("level") is int \
		and data.get("owned_items") is PackedStringArray and data.get("weapon") is StringName \
		and data.get("armor") is StringName and data.get("quests") is Dictionary \
		and data.get("encounters") is Dictionary

func _new_game() -> void:
	if not continue_game.disabled:
		%ReplaceSave.popup_centered()
		return
	_start_fresh()

func _continue_game() -> void:
	refresh_slot()
	if not continue_game.disabled:
		_start_game(saved_checkpoint)

func _start_fresh() -> void:
	_start_game({})

func _start_game(snapshot: Dictionary) -> void:
	var world := gameplay_scene.instantiate()
	world.configure_checkpoint(slot, snapshot)
	var tree := get_tree()
	tree.root.add_child(world)
	tree.current_scene = world
	queue_free()
