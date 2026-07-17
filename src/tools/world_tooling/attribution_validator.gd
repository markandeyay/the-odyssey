extends RefCounted

const ASSET_ROOT: String = "res://assets"
const LEDGER_PATH: String = "res://docs/ATTRIBUTIONS.md"
const REQUIRED_FIELDS: PackedStringArray = [
	"Provider ID",
	"Source",
	"Author",
	"License",
	"Date pulled",
	"Repository path",
	"Godot material",
	"Lanka usage",
]


func validate_repository() -> Array[String]:
	var ledger_file: FileAccess = FileAccess.open(LEDGER_PATH, FileAccess.READ)
	if ledger_file == null:
		return ["Unable to read %s" % LEDGER_PATH]
	var ledger_text: String = ledger_file.get_as_text()
	ledger_file.close()
	var asset_files: PackedStringArray = PackedStringArray()
	_collect_files(ASSET_ROOT, asset_files)
	return validate(ledger_text, asset_files)


func validate(ledger_text: String, asset_files: PackedStringArray) -> Array[String]:
	var issues: Array[String] = []
	var entries: Array[Dictionary] = parse_entries(ledger_text, issues)
	var registered_paths: PackedStringArray = PackedStringArray()
	for entry: Dictionary in entries:
		_validate_entry(entry, issues)
		var repository_path: String = str(entry.get("Repository path", ""))
		if not repository_path.is_empty():
			registered_paths.append(_normalize_repository_path(repository_path))
	for asset_path: String in asset_files:
		if not _is_covered(asset_path.replace("\\", "/"), registered_paths):
			issues.append("%s has no ATTRIBUTIONS.md entry" % asset_path)
	for registered_path: String in registered_paths:
		if registered_path.ends_with("/"):
			if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(registered_path.trim_suffix("/"))):
				issues.append("Attribution path does not exist: %s" % registered_path)
		elif not FileAccess.file_exists(registered_path):
			issues.append("Attribution path does not exist: %s" % registered_path)
	return issues


func parse_entries(ledger_text: String, issues: Array[String]) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var current: Dictionary = {}
	var current_id: String = ""
	for line: String in ledger_text.split("\n"):
		if line.begins_with("<!-- asset:") and line.ends_with(" -->"):
			if not current.is_empty():
				issues.append("Nested attribution marker before closing %s" % current_id)
			current_id = line.trim_prefix("<!-- asset:").trim_suffix(" -->")
			current = {"_marker": current_id}
			continue
		if line.begins_with("<!-- /asset:") and line.ends_with(" -->"):
			var closing_id: String = line.trim_prefix("<!-- /asset:").trim_suffix(" -->")
			if current.is_empty() or closing_id != current_id:
				issues.append("Mismatched attribution closing marker: %s" % closing_id)
			else:
				entries.append(current)
			current = {}
			current_id = ""
			continue
		if current.is_empty() or not line.begins_with("|"):
			continue
		var columns: PackedStringArray = line.split("|", false)
		if columns.size() < 2:
			continue
		var field_name: String = columns[0].strip_edges()
		var field_value: String = columns[1].strip_edges()
		if field_name in REQUIRED_FIELDS:
			current[field_name] = field_value
	if not current.is_empty():
		issues.append("Unclosed attribution marker: %s" % current_id)
	return entries


func _validate_entry(entry: Dictionary, issues: Array[String]) -> void:
	var marker: String = str(entry.get("_marker", "<unknown>"))
	for field_name: String in REQUIRED_FIELDS:
		if str(entry.get(field_name, "")).is_empty():
			issues.append("Attribution %s is missing %s" % [marker, field_name])
	var source: String = str(entry.get("Source", ""))
	if "https://" not in source:
		issues.append("Attribution %s source must use HTTPS" % marker)
	var license: String = str(entry.get("License", ""))
	if "https://" not in license:
		issues.append("Attribution %s license must link to its terms" % marker)
	var date_value: String = str(entry.get("Date pulled", ""))
	var date_pattern: RegEx = RegEx.new()
	date_pattern.compile("^\\d{4}-\\d{2}-\\d{2}$")
	if date_pattern.search(date_value) == null:
		issues.append("Attribution %s date must be YYYY-MM-DD" % marker)


func _normalize_repository_path(markdown_value: String) -> String:
	return markdown_value.replace("`", "").strip_edges().replace("\\", "/")


func _is_covered(asset_path: String, registered_paths: PackedStringArray) -> bool:
	for registered_path: String in registered_paths:
		if registered_path.ends_with("/") and asset_path.begins_with(registered_path):
			return true
		if asset_path == registered_path:
			return true
	return false


func _collect_files(root_path: String, output: PackedStringArray) -> void:
	var directory: DirAccess = DirAccess.open(root_path)
	if directory == null:
		return
	for filename: String in directory.get_files():
		output.append(root_path.path_join(filename))
	for child: String in directory.get_directories():
		_collect_files(root_path.path_join(child), output)
