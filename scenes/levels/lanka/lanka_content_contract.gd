extends RefCounted

const CAIRN_ROOT: String = "res://scenes/levels/cairns"

const CAIRNS: Array[Dictionary] = [
	{"id": &"shallows_hold_stack", "district_id": &"shallows", "mechanic": &"carry_stack", "path": CAIRN_ROOT + "/cairn_01_hold_stack.tscn", "position": Vector3(148.0, 12.6, -12.0)},
	{"id": &"shallows_counterweight", "district_id": &"shallows", "mechanic": &"carry_counterweight", "path": CAIRN_ROOT + "/cairn_02_counterweight.tscn", "position": Vector3(-162.0, 45.2, 116.0)},
	{"id": &"terraces_grip_route", "district_id": &"terraces", "mechanic": &"grip_route", "path": CAIRN_ROOT + "/cairn_03_grip_route.tscn", "position": Vector3(-116.0, -2.0, -103.0)},
	{"id": &"terraces_crumble_timing", "district_id": &"terraces", "mechanic": &"crumbling_timing", "path": CAIRN_ROOT + "/cairn_04_crumble_timing.tscn", "position": Vector3(128.0, 13.0, 104.0)},
	{"id": &"ember_fuel_line", "district_id": &"ember_quarter", "mechanic": &"fire_fuel", "path": CAIRN_ROOT + "/cairn_05_fuel_line.tscn", "position": Vector3(-132.0, 2.0, 112.0)},
	{"id": &"ember_updraft_crossing", "district_id": &"ember_quarter", "mechanic": &"updraft_glide", "path": CAIRN_ROOT + "/cairn_06_updraft_crossing.tscn", "position": Vector3(146.0, 3.0, -108.0)},
	{"id": &"cistern_current_gate", "district_id": &"cistern", "mechanic": &"water_current", "path": CAIRN_ROOT + "/cairn_07_current_gate.tscn", "position": Vector3(-82.0, -10.0, 62.0)},
	{"id": &"cistern_flame_crossing", "district_id": &"cistern", "mechanic": &"carry_flame", "path": CAIRN_ROOT + "/cairn_08_flame_crossing.tscn", "position": Vector3(82.0, -8.0, -61.0)},
]

const CREW_FRAGMENTS: Array[Dictionary] = [
	{"id": &"crew_aadi", "district_id": &"shallows", "position": Vector3(-72.0, 4.2, -42.0), "object": "split oar", "text": "Aadi counted every stroke. The sea stopped answering at dawn."},
	{"id": &"crew_baran", "district_id": &"shallows", "position": Vector3(88.0, -1.6, -86.0), "object": "salt-stiff rope", "text": "Baran tied the bridge to a shore that no longer exists."},
	{"id": &"crew_chaya", "district_id": &"shallows", "position": Vector3(-126.0, 27.3, 44.0), "object": "copper cup", "text": "Chaya saved the last fresh water for someone who never came back."},
	{"id": &"crew_devan", "district_id": &"shallows", "position": Vector3(138.0, 38.8, 92.0), "object": "bent nail", "text": "Devan built by torchlight while the water watched."},
	{"id": &"crew_esha", "district_id": &"terraces", "position": Vector3(-132.0, -4.0, 82.0), "object": "seed pouch", "text": "Esha carried seeds across the sea. Lanka gave her only ash."},
	{"id": &"crew_faris", "district_id": &"terraces", "position": Vector3(-42.0, 4.0, -106.0), "object": "stone hook", "text": "Faris climbed first and marked every hold for those behind him."},
	{"id": &"crew_giri", "district_id": &"terraces", "position": Vector3(52.0, 11.0, 94.0), "object": "broken sandal", "text": "Giri joked about the height until the wall moved beneath his hands."},
	{"id": &"crew_hari", "district_id": &"terraces", "position": Vector3(142.0, 16.0, -52.0), "object": "charred tally", "text": "Hari kept the names. The final line is burned away."},
	{"id": &"crew_ilan", "district_id": &"ember_quarter", "position": Vector3(-112.0, 3.0, -74.0), "object": "melted buckle", "text": "Ilan ran into the first fire because he heard someone calling."},
	{"id": &"crew_jaya", "district_id": &"ember_quarter", "position": Vector3(-28.0, 5.0, 88.0), "object": "blackened bell", "text": "Jaya rang the retreat. No one heard it over the roofs."},
	{"id": &"crew_kavi", "district_id": &"ember_quarter", "position": Vector3(72.0, 3.0, -82.0), "object": "glass bead", "text": "Kavi promised the smoke would clear before nightfall."},
	{"id": &"crew_lal", "district_id": &"ember_quarter", "position": Vector3(132.0, 6.0, 72.0), "object": "iron key", "text": "Lal locked the cistern and carried the key into the burn."},
	{"id": &"crew_manu", "district_id": &"cistern", "position": Vector3(-68.0, -18.0, -42.0), "object": "oilskin lantern", "text": "Manu's lantern went dark while the water was still rising."},
	{"id": &"crew_nilan", "district_id": &"cistern", "position": Vector3(4.0, -19.0, 52.0), "object": "fish hook", "text": "Nilan found living fish below a city already dead."},
	{"id": &"crew_omar", "district_id": &"cistern", "position": Vector3(72.0, -12.0, -24.0), "object": "sealed letter", "text": "Omar wrote home. The wax bears Nau's mark."},
	{"id": &"crew_priya", "district_id": &"spine", "position": Vector3(27.0, 43.0, 4.0), "object": "red thread", "text": "Priya followed the red thread upward until it ended in smoke."},
	{"id": &"crew_rahul", "district_id": &"spine", "position": Vector3(-24.0, 118.0, 6.0), "object": "climbing spike", "text": "Rahul drove one last spike and told the others not to look down."},
	{"id": &"crew_sena", "district_id": &"spine", "position": Vector3(18.0, 222.0, -9.0), "object": "wooden token", "text": "Sena reached the crown. He saw the bridge breaking from above."},
	{"id": &"crew_tarin", "district_id": &"dark", "position": Vector3(-54.0, 1.0, 18.0), "object": "rusted whistle", "text": "Tarin whistled in the dark. Something answered in his own voice."},
	{"id": &"crew_vasu", "district_id": &"dark", "position": Vector3(48.0, 1.0, 64.0), "object": "carved face", "text": "Vasu guarded the figurehead. He knew who had carved it."},
]

const SALVAGE: Array[Dictionary] = [
	{"id": &"salvage_timber_01", "district_id": &"shallows", "salvage_id": &"timber", "position": Vector3(-102.0, 11.8, -14.0)},
	{"id": &"salvage_timber_02", "district_id": &"shallows", "salvage_id": &"timber", "position": Vector3(118.0, 7.6, -34.0)},
	{"id": &"salvage_canvas_01", "district_id": &"shallows", "salvage_id": &"canvas", "position": Vector3(-138.0, 34.0, 71.0)},
	{"id": &"salvage_canvas_02", "district_id": &"shallows", "salvage_id": &"canvas", "position": Vector3(96.0, 40.4, 102.0)},
	{"id": &"salvage_iron_01", "district_id": &"terraces", "salvage_id": &"iron", "position": Vector3(-108.0, -3.0, -75.0)},
	{"id": &"salvage_iron_02", "district_id": &"terraces", "salvage_id": &"iron", "position": Vector3(32.0, 8.0, 84.0)},
	{"id": &"salvage_timber_03", "district_id": &"terraces", "salvage_id": &"timber", "position": Vector3(116.0, 14.0, -94.0)},
	{"id": &"salvage_iron_03", "district_id": &"ember_quarter", "salvage_id": &"iron", "position": Vector3(-92.0, 3.0, 54.0)},
	{"id": &"salvage_iron_04", "district_id": &"ember_quarter", "salvage_id": &"iron", "position": Vector3(74.0, 3.0, -54.0)},
	{"id": &"salvage_timber_04", "district_id": &"ember_quarter", "salvage_id": &"timber", "position": Vector3(-42.0, 3.0, -96.0)},
	{"id": &"salvage_timber_05", "district_id": &"ember_quarter", "salvage_id": &"timber", "position": Vector3(124.0, 3.0, 96.0)},
	{"id": &"salvage_canvas_03", "district_id": &"ember_quarter", "salvage_id": &"canvas", "position": Vector3(26.0, 4.0, 66.0)},
	{"id": &"salvage_iron_05", "district_id": &"cistern", "salvage_id": &"iron", "position": Vector3(-72.0, -18.0, 26.0)},
	{"id": &"salvage_iron_06", "district_id": &"cistern", "salvage_id": &"iron", "position": Vector3(62.0, -18.0, -46.0)},
	{"id": &"salvage_canvas_04", "district_id": &"cistern", "salvage_id": &"canvas", "position": Vector3(22.0, -12.0, 58.0)},
	{"id": &"salvage_timber_06", "district_id": &"spine", "salvage_id": &"timber", "position": Vector3(-28.0, 68.0, -4.0)},
	{"id": &"salvage_timber_07", "district_id": &"spine", "salvage_id": &"timber", "position": Vector3(24.0, 168.0, 4.0)},
	{"id": &"salvage_canvas_05", "district_id": &"dark", "salvage_id": &"canvas", "position": Vector3(-78.0, 1.0, -56.0)},
]

const INGREDIENTS: Array[Dictionary] = [
	{"id": &"shellfish_01", "district_id": &"shallows", "ingredient_id": &"tidepool_shellfish", "position": Vector3(-82.0, -4.5, -112.0)},
	{"id": &"shellfish_02", "district_id": &"shallows", "ingredient_id": &"tidepool_shellfish", "position": Vector3(-34.0, -4.5, -136.0)},
	{"id": &"shellfish_03", "district_id": &"shallows", "ingredient_id": &"tidepool_shellfish", "position": Vector3(18.0, -4.4, -124.0)},
	{"id": &"shellfish_04", "district_id": &"shallows", "ingredient_id": &"tidepool_shellfish", "position": Vector3(72.0, -4.3, -142.0)},
	{"id": &"shellfish_05", "district_id": &"shallows", "ingredient_id": &"tidepool_shellfish", "position": Vector3(116.0, -3.8, -108.0)},
	{"id": &"shellfish_06", "district_id": &"shallows", "ingredient_id": &"tidepool_shellfish", "position": Vector3(148.0, -2.9, -76.0)},
	{"id": &"ashroot_01", "district_id": &"terraces", "ingredient_id": &"ashroot", "position": Vector3(-118.0, -5.0, -82.0)},
	{"id": &"ashroot_02", "district_id": &"terraces", "ingredient_id": &"ashroot", "position": Vector3(-72.0, 0.0, -49.0)},
	{"id": &"ashroot_03", "district_id": &"terraces", "ingredient_id": &"ashroot", "position": Vector3(-26.0, 5.0, -16.0)},
	{"id": &"ashroot_04", "district_id": &"terraces", "ingredient_id": &"ashroot", "position": Vector3(20.0, 10.0, 17.0)},
	{"id": &"ashroot_05", "district_id": &"terraces", "ingredient_id": &"ashroot", "position": Vector3(66.0, 15.0, 50.0)},
	{"id": &"ashroot_06", "district_id": &"terraces", "ingredient_id": &"ashroot", "position": Vector3(112.0, 20.0, 83.0)},
	{"id": &"charwood_01", "district_id": &"ember_quarter", "ingredient_id": &"charwood_fruit", "position": Vector3(-57.0, 2.0, -68.0)},
	{"id": &"charwood_02", "district_id": &"ember_quarter", "ingredient_id": &"charwood_fruit", "position": Vector3(68.0, 2.0, -68.0)},
	{"id": &"charwood_03", "district_id": &"ember_quarter", "ingredient_id": &"charwood_fruit", "position": Vector3(-58.0, 2.0, 52.0)},
	{"id": &"charwood_04", "district_id": &"ember_quarter", "ingredient_id": &"charwood_fruit", "position": Vector3(70.0, 2.0, 52.0)},
	{"id": &"charwood_05", "district_id": &"ember_quarter", "ingredient_id": &"charwood_fruit", "position": Vector3(136.0, 2.0, 56.0)},
	{"id": &"blind_fish_01", "district_id": &"cistern", "ingredient_id": &"blind_fish", "position": Vector3(-65.0, -18.0, 38.0)},
	{"id": &"blind_fish_02", "district_id": &"cistern", "ingredient_id": &"blind_fish", "position": Vector3(-23.0, -18.0, -32.0)},
	{"id": &"blind_fish_03", "district_id": &"cistern", "ingredient_id": &"blind_fish", "position": Vector3(19.0, -18.0, 38.0)},
	{"id": &"blind_fish_04", "district_id": &"cistern", "ingredient_id": &"blind_fish", "position": Vector3(61.0, -18.0, -32.0)},
]

const CAMPFIRES: Array[Dictionary] = [
	{"id": &"camp_shallows_arrival", "district_id": &"shallows", "position": Vector3(-38.0, 1.6, 62.0)},
	{"id": &"camp_shallows_keffer", "district_id": &"shallows", "position": Vector3(-112.0, 38.3, 84.0)},
	{"id": &"camp_terraces_lower", "district_id": &"terraces", "position": Vector3(-112.0, -3.0, 12.0)},
	{"id": &"camp_terraces_upper", "district_id": &"terraces", "position": Vector3(118.0, 15.0, 16.0)},
	{"id": &"camp_ember_west", "district_id": &"ember_quarter", "position": Vector3(-128.0, 3.0, -18.0)},
	{"id": &"camp_ember_east", "district_id": &"ember_quarter", "position": Vector3(144.0, 3.0, 18.0)},
	{"id": &"camp_cistern_landing", "district_id": &"cistern", "position": Vector3(74.0, 58.0, 54.0)},
	{"id": &"camp_spine_base", "district_id": &"spine", "position": Vector3(38.0, 2.0, -46.0)},
]

const KEFFER_DIALOGUE: Array[String] = [
	"You're awake.",
	"No. Stay there. I can throw it.",
	"The shellfish are safe when the water pulls back.",
	"Two old Cairns open from this shore. I never went far inside.",
	"The tower is where you left it.",
	"You don't remember me.",
	"Good.",
	"Take it. Please.",
]


static func entries_for_district(entries: Array[Dictionary], district_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in entries:
		if entry.get("district_id", &"") == district_id:
			result.append(entry)
	return result
