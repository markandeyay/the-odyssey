extends RefCounted

const ContentContract: Script = preload("res://scenes/levels/lanka/lanka_content_contract.gd")
const DistrictContract: Script = preload("res://scenes/levels/lanka/lanka_district_contract.gd")
const EXPECTED_CAIRN_DISTRIBUTION: Dictionary = {
	&"shallows": 2,
	&"terraces": 2,
	&"ember_quarter": 2,
	&"cistern": 2,
}
const EXPECTED_INGREDIENT_TYPES: PackedStringArray = [
	"ashroot", "blind_fish", "charwood_fruit", "tidepool_shellfish",
]
const EXPECTED_SALVAGE_TYPES: PackedStringArray = ["canvas", "iron", "timber"]


func validate_repository() -> Array[String]:
	var issues: Array[String] = []
	_validate_contract_counts(issues)
	_validate_cairn_scenes(issues)
	_validate_open_world_placements(issues)
	return issues


func _validate_contract_counts(issues: Array[String]) -> void:
	if ContentContract.CAIRNS.size() != 8:
		issues.append("M6 must define exactly eight Cairns")
	if ContentContract.CREW_FRAGMENTS.size() != 20:
		issues.append("M6 must define exactly twenty crew fragments")
	if ContentContract.KEFFER_DIALOGUE.size() != 8:
		issues.append("Keffer must have exactly eight dialogue lines")
	var distribution: Dictionary = {}
	for cairn: Dictionary in ContentContract.CAIRNS:
		var district_id: StringName = cairn.get("district_id", &"") as StringName
		distribution[district_id] = int(distribution.get(district_id, 0)) + 1
	if distribution != EXPECTED_CAIRN_DISTRIBUTION:
		issues.append("Cairn distribution must be 2 Shallows, 2 Terraces, 2 Ember Quarter, 2 Cistern")
	var ingredient_types: PackedStringArray = _unique_field(ContentContract.INGREDIENTS, "ingredient_id")
	if ingredient_types != EXPECTED_INGREDIENT_TYPES:
		issues.append("ingredient types must be exactly ashroot, blind_fish, charwood_fruit, tidepool_shellfish")
	var salvage_types: PackedStringArray = _unique_field(ContentContract.SALVAGE, "salvage_id")
	if salvage_types != EXPECTED_SALVAGE_TYPES:
		issues.append("salvage types must be exactly canvas, iron, timber")


func _validate_cairn_scenes(issues: Array[String]) -> void:
	var actual_paths: PackedStringArray = PackedStringArray()
	var directory: DirAccess = DirAccess.open(ContentContract.CAIRN_ROOT)
	if directory == null:
		issues.append("unable to open Cairn scene directory")
		return
	for filename: String in directory.get_files():
		if filename.get_extension().to_lower() == "tscn":
			actual_paths.append(ContentContract.CAIRN_ROOT.path_join(filename))
	actual_paths.sort()
	var expected_paths: PackedStringArray = PackedStringArray()
	for data: Dictionary in ContentContract.CAIRNS:
		expected_paths.append(str(data["path"]))
	expected_paths.sort()
	if actual_paths != expected_paths:
		issues.append("Cairn scene directory must contain exactly the eight contracted scenes")
	var reward_total: int = 0
	for data: Dictionary in ContentContract.CAIRNS:
		var path: String = str(data["path"])
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			issues.append("%s: unable to load Cairn scene" % path)
			continue
		var root: Node3D = packed.instantiate() as Node3D
		if root == null:
			issues.append("%s: Cairn root must be Node3D" % path)
			continue
		if root.get_meta(&"cairn_id", &"") != data["id"]:
			issues.append("%s: cairn_id metadata is incorrect" % path)
		if root.get_meta(&"district_id", &"") != data["district_id"]:
			issues.append("%s: source district metadata is incorrect" % path)
		if root.get_meta(&"taught_mechanic", &"") != data["mechanic"]:
			issues.append("%s: Cairn introduces an uncontracted mechanic" % path)
		if not bool(root.get_meta(&"single_room", false)):
			issues.append("%s: Cairn must remain a single room" % path)
		var reward_amount: int = int(root.get_meta(&"heart_piece_reward", 0))
		reward_total += reward_amount
		if reward_amount != 1:
			issues.append("%s: Cairn must reward exactly one heart piece" % path)
		var rewards: Array[Marker3D] = _sockets_of_type(root, &"heart_piece_reward")
		if rewards.size() != 1 or int(rewards[0].get_meta(&"heart_piece_amount", 0)) != 1:
			issues.append("%s: Cairn must expose exactly one one-piece reward socket" % path)
		if root.get_node_or_null("RouteMarkers/Entry") == null or root.get_node_or_null("RouteMarkers/Exit") == null:
			issues.append("%s: Cairn entry/exit route markers are incomplete" % path)
		root.free()
	if reward_total != 8 or reward_total / 4 != 2:
		issues.append("eight Cairns must total eight pieces and exactly two heart containers")


func _validate_open_world_placements(issues: Array[String]) -> void:
	var roots: Array[Node3D] = []
	for district_id: StringName in [&"shallows", &"terraces", &"ember_quarter", &"cistern", &"spine", &"dark"]:
		var path: String = _district_path(district_id)
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			issues.append("%s: unable to load M6 placement host" % path)
			continue
		roots.append(packed.instantiate() as Node3D)
	var cairn_markers: Array[Marker3D] = _all_sockets(roots, &"cairn_entrance")
	var fragment_markers: Array[Marker3D] = _all_sockets(roots, &"crew_fragment")
	var salvage_markers: Array[Marker3D] = _all_sockets(roots, &"salvage_pickup")
	var ingredient_markers: Array[Marker3D] = _all_sockets(roots, &"ingredient_pickup")
	var campfire_markers: Array[Marker3D] = _all_sockets(roots, &"campfire")
	var keffer_markers: Array[Marker3D] = _all_sockets(roots, &"keffer_interaction")
	_validate_marker_set(cairn_markers, ContentContract.CAIRNS, &"cairn_id", "Cairn entrances", issues)
	_validate_marker_set(fragment_markers, ContentContract.CREW_FRAGMENTS, &"fragment_id", "crew fragments", issues)
	_validate_marker_set(salvage_markers, ContentContract.SALVAGE, &"placement_id", "salvage placements", issues)
	_validate_marker_set(ingredient_markers, ContentContract.INGREDIENTS, &"placement_id", "ingredient placements", issues)
	_validate_marker_set(campfire_markers, ContentContract.CAMPFIRES, &"checkpoint_id", "campfires", issues)
	for marker: Marker3D in cairn_markers:
		if not FileAccess.file_exists(str(marker.get_meta(&"target_scene_path", ""))):
			issues.append("%s targets a missing Cairn scene" % marker.name)
	for marker: Marker3D in fragment_markers:
		if str(marker.get_meta(&"memory_object", "")).is_empty() or str(marker.get_meta(&"memory_text", "")).is_empty():
			issues.append("%s lacks its pure story payload" % marker.name)
	for marker: Marker3D in salvage_markers:
		if str(marker.get_meta(&"salvage_id", "")) not in EXPECTED_SALVAGE_TYPES:
			issues.append("%s uses an invalid salvage type" % marker.name)
	for marker: Marker3D in ingredient_markers:
		if str(marker.get_meta(&"ingredient_id", "")) not in EXPECTED_INGREDIENT_TYPES:
			issues.append("%s uses an invalid ingredient type" % marker.name)
	if keffer_markers.size() != 1:
		issues.append("Lanka must contain exactly one Keffer interaction")
	else:
		var keffer: Marker3D = keffer_markers[0]
		var lines: Array = keffer.get_meta(&"dialogue_lines", []) as Array
		if lines.size() != 8:
			issues.append("Keffer interaction must expose exactly eight lines")
		if bool(keffer.get_meta(&"is_merchant", true)):
			issues.append("Keffer must never be a merchant")
		if keffer.get_meta(&"handout_item_id", &"") != &"tidepool_shellfish":
			issues.append("Keffer handout must use an existing Lanka food")
		if float(keffer.get_meta(&"handout_cooldown_s", 0.0)) <= 0.0:
			issues.append("Keffer food handout must have a cooldown")
	for root: Node3D in roots:
		root.free()


func _validate_marker_set(
	markers: Array[Marker3D], entries: Array[Dictionary], marker_key: StringName,
	label: String, issues: Array[String]
) -> void:
	if markers.size() != entries.size():
		issues.append("%s count is %d, expected %d" % [label, markers.size(), entries.size()])
	var actual_ids: Dictionary = {}
	for marker: Marker3D in markers:
		var id_value: StringName = marker.get_meta(marker_key, &"") as StringName
		if id_value == &"" or actual_ids.has(id_value):
			issues.append("%s contains a missing or duplicate ID" % label)
		actual_ids[id_value] = true
	for entry: Dictionary in entries:
		var contract_key: String = "id"
		if marker_key == &"placement_id":
			contract_key = "id"
		if not actual_ids.has(entry[contract_key]):
			issues.append("%s is missing contracted ID %s" % [label, entry[contract_key]])


func _district_path(district_id: StringName) -> String:
	if district_id == &"spine":
		return DistrictContract.SPINE_PATH
	if district_id == &"dark":
		return DistrictContract.DARK_PATH
	return DistrictContract.district_path(district_id)


func _all_sockets(roots: Array[Node3D], socket_type: StringName) -> Array[Marker3D]:
	var result: Array[Marker3D] = []
	for root: Node3D in roots:
		result.append_array(_sockets_of_type(root, socket_type))
	return result


func _sockets_of_type(root: Node, socket_type: StringName) -> Array[Marker3D]:
	var result: Array[Marker3D] = []
	_collect_sockets(root, socket_type, result)
	return result


func _collect_sockets(root: Node, socket_type: StringName, output: Array[Marker3D]) -> void:
	if root is Marker3D and root.get_meta(&"socket_type", &"") == socket_type:
		output.append(root as Marker3D)
	for child: Node in root.get_children():
		_collect_sockets(child, socket_type, output)


func _unique_field(entries: Array[Dictionary], field: String) -> PackedStringArray:
	var values: Dictionary = {}
	for entry: Dictionary in entries:
		values[str(entry.get(field, ""))] = true
	var result: PackedStringArray = PackedStringArray()
	for value: Variant in values:
		result.append(str(value))
	result.sort()
	return result
