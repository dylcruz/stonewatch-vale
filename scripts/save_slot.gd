class_name ValeSaveSlot
extends RefCounted

const VERSION := 1
const MAX_BYTES := 256 * 1024
const PLAYER_PATH := "user://stonewatch-slot.save"

var path: String

func _init(slot_path: String = PLAYER_PATH) -> void:
	path = ProjectSettings.globalize_path(slot_path)

func exists() -> bool:
	return FileAccess.file_exists(path)

func read() -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 8 or file.get_length() > MAX_BYTES:
		return {}
	var decoded: Variant = bytes_to_var(file.get_buffer(file.get_length()))
	if not decoded is Dictionary or decoded.get("version") != VERSION:
		return {}
	var snapshot: Variant = decoded.get("snapshot")
	return snapshot if snapshot is Dictionary else {}

func write(snapshot: Dictionary) -> Error:
	var encoded := var_to_bytes({"version": VERSION, "snapshot": snapshot})
	if encoded.size() > MAX_BYTES:
		return ERR_OUT_OF_MEMORY
	var pending := "%s.%s.pending" % [path, OS.get_process_id()]
	var file := FileAccess.open(pending, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var written := file.store_buffer(encoded)
	file.flush()
	var error := file.get_error()
	file.close()
	if written and error == OK:
		error = DirAccess.rename_absolute(pending, path)
	elif error == OK:
		error = ERR_FILE_CANT_WRITE
	if error != OK:
		DirAccess.remove_absolute(pending)
	return error
