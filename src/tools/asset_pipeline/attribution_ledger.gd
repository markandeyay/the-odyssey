extends RefCounted

const LEDGER_PATH: String = "res://docs/ATTRIBUTIONS.md"
const EMPTY_MARKER: String = "_No third-party assets have been added yet._"


func append(manifest: Dictionary, install_result: Dictionary, usage: String) -> Dictionary:
	var provider: String = str(manifest.get("provider", ""))
	var asset_id: String = str(manifest.get("asset_id", ""))
	var marker_id: String = "%s:%s" % [provider, asset_id]
	var begin_marker: String = "<!-- asset:%s -->" % marker_id
	var ledger: FileAccess = FileAccess.open(LEDGER_PATH, FileAccess.READ)
	if ledger == null:
		return _failure("Unable to read attribution ledger")
	var contents: String = ledger.get_as_text()
	ledger.close()
	if begin_marker in contents:
		return _failure("Attribution already exists for %s" % marker_id)
	contents = contents.replace(EMPTY_MARKER + "\n", "")
	var entry: String = _format_entry(manifest, install_result, usage, begin_marker, marker_id)
	var output: FileAccess = FileAccess.open(LEDGER_PATH, FileAccess.WRITE)
	if output == null:
		return _failure("Unable to update attribution ledger")
	output.store_string(contents.rstrip("\n") + "\n\n" + entry + "\n")
	output.close()
	return {"ok": true}


func _format_entry(
	manifest: Dictionary,
	install_result: Dictionary,
	usage: String,
	begin_marker: String,
	marker_id: String
) -> String:
	var name: String = _escape(str(manifest.get("name", manifest.get("asset_id", "Unknown asset"))))
	var lines: PackedStringArray = PackedStringArray([
		begin_marker,
		"### %s" % name,
		"",
		"| Field | Value |",
		"|---|---|",
		"| Provider ID | `%s` |" % _escape(marker_id),
		"| Source | %s |" % _markdown_link("Asset page", str(manifest.get("source_url", ""))),
		"| Author | %s |" % _escape(str(manifest.get("author", "Unknown"))),
		"| License | %s |" % _markdown_link(str(manifest.get("license", "Unknown")), str(manifest.get("license_url", ""))),
		"| Date pulled | %s |" % Time.get_date_string_from_system(),
		"| Repository path | `%s/` |" % _escape(str(install_result.get("asset_path", ""))),
		"| Godot material | `%s` |" % _escape(str(install_result.get("material_path", ""))),
		"| Lanka usage | %s |" % _escape(usage),
		"<!-- /asset:%s -->" % marker_id,
	])
	return "\n".join(lines)


func _markdown_link(label: String, url: String) -> String:
	if not url.begins_with("https://"):
		return _escape(label)
	return "[%s](%s)" % [_escape(label), url.replace(")", "%29")]


func _escape(value: String) -> String:
	return value.replace("|", "\\|").replace("\r", " ").replace("\n", " ")


func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
