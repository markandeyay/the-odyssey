class_name UIPalette
extends RefCounted
## The HUD's shared look (M12, ARCHITECTURE §15): ash grey, wet black,
## bone white, ember orange, sea green. Ember orange is the only saturated
## color and it always means danger or warmth — hearts, low breath, heat —
## never decoration. Everything else stays desaturated and quiet.

const WET_BLACK: Color = Color(0.07, 0.075, 0.085)
const ASH_GREY: Color = Color(0.55, 0.55, 0.53)
const BONE_WHITE: Color = Color(0.93, 0.9, 0.84)
const EMBER_ORANGE: Color = Color(0.95, 0.42, 0.08)
const SEA_GREEN: Color = Color(0.25, 0.6, 0.52)


## Backdrop for panels: wet black, soft corners, a faint ash border.
static func panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(WET_BLACK, 0.88)
	style.border_color = Color(ASH_GREY, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	return style


## Hotbar / storage slot. Selection is marked in bone white, not ember —
## a selected slot is not danger.
static func slot_style(selected: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(WET_BLACK, 0.72 if selected else 0.55)
	style.border_color = Color(BONE_WHITE, 0.9) if selected else Color(ASH_GREY, 0.35)
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(2)
	return style
