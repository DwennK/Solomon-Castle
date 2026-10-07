class_name SaveStore
extends RefCounted

const VERSION: int = 1
static var last_error: String = ""

static func write_save(path: String, payload: Dictionary) -> bool:
	last_error = ""
	var body: String = JSON.stringify(payload)
	var envelope: String = JSON.stringify({"version": VERSION, "sha256": body.sha256_text(), "body": body})
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Impossible d’écrire la sauvegarde."
		return false
	file.store_string(envelope)
	file.flush()
	file.close()
	if FileAccess.file_exists(path):
		# Preserve a valid backup, never replace it with corrupt bytes.
		if not _read_one(path).is_empty():
			var copy_error: Error = DirAccess.copy_absolute(path, path + ".bak")
			if copy_error != OK:
				last_error = "Impossible de créer la sauvegarde de secours."
				return false
	var error: Error = DirAccess.rename_absolute(path + ".tmp", path)
	if error != OK:
		last_error = "Impossible de finaliser la sauvegarde."
	return error == OK

static func _read_one(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK: return {}
	var wrapper: Variant = parser.data
	if not wrapper is Dictionary or wrapper.get("version", 0) != VERSION:
		return {}
	var body: Variant = wrapper.get("body", "")
	if not body is String or body.sha256_text() != wrapper.get("sha256", ""):
		return {}
	if parser.parse(body) != OK: return {}
	var result: Variant = parser.data
	return result if result is Dictionary else {}

static func read_save(path: String) -> Dictionary:
	last_error = ""
	var result: Dictionary = _read_one(path)
	if result.is_empty():
		result = _read_one(path + ".bak")
		last_error = "Sauvegarde principale endommagée : copie de secours restaurée." if not result.is_empty() else "Aucune sauvegarde valide. Vous pouvez commencer une nouvelle partie."
	return result
