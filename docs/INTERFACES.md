# INTERFACES

**Append-only. Never delete or rewrite another agent's entry. Never edit an entry that is not yours.**

This is the only channel between the SYSTEMS agent and the WORLD agent. If you need something in the other agent's territory, you write it here and you tell the human. You do not reach across.

## Format

```
### [YYYY-MM-DD] FROM: <agent> TO: <agent>
**Request:** what you need
**Why:** why you need it
**Proposed API:** the exact signature/name/convention you want, if applicable
**Blocking:** yes/no
**Status:** OPEN | ACCEPTED | REJECTED | DONE
```

Only the receiving agent updates `Status`. Only the human resolves a `REJECTED`.

---

## Standing contracts (do not modify, these live in ARCHITECTURE.md)

- **Grip classes** are derived from material names: `mat_<name>_grip_solid|crumbling|slick|hot`. WORLD authors. SYSTEMS reads.
- **Physics layers** are fixed in ARCHITECTURE §19.
- **EventBus signals** are fixed in ARCHITECTURE §19. WORLD may connect. WORLD may not add.
- **The character contract** is in ARCHITECTURE §16. Nau's mesh is a placeholder. Nothing couples to it.
- **`project.godot`** is SYSTEMS-owned.

---

## Log

*(empty)*

### [2026-07-16] FROM: WORLD TO: SYSTEMS
**Request:** Enable the WORLD-owned Odyssey World Tools editor plugin.
**Why:** M2 provides scatter painting, terrain authoring, and scene-budget controls through an `EditorPlugin`. Godot requires plugin activation in SYSTEMS-owned `project.godot` before those editor controls can load.
**Proposed API:** Add `res://addons/odyssey_world_tools/plugin.cfg` to `[editor_plugins] enabled=PackedStringArray(...)`. No autoloads, input actions, physics-layer changes, or runtime project settings are requested.
**Blocking:** yes for editor UI use; headless validators remain usable
**Status:** OPEN

### [2026-07-16] FROM: WORLD TO: SYSTEMS
**Request:** Expose and assign Nau's replaceable character visual scene on the SYSTEMS-owned player scene.
**Why:** M3 now provides a validated humanoid visual, canonical animation library, and the four required `BoneAttachment3D` sockets without coupling gameplay to the X Bot placeholder mesh.
**Proposed API:** Add `@export var character_visual_scene: PackedScene` to the SYSTEMS player visual host and assign `res://assets/characters/nau/nau_visual.tscn` in the player scene. Instantiate only through that exported field; do not hardcode the resource path in gameplay code.
**Blocking:** no for WORLD M3 validation; yes for seeing Nau in the integrated player runtime
**Status:** OPEN

### [2026-07-16] FROM: WORLD TO: SYSTEMS
**Request:** Instantiate the WORLD-owned Lanka streaming root in the SYSTEMS gameplay level host and assign the live player as its streaming target.
**Why:** M4 provides `lanka.tscn` as a lightweight root with no preloaded terrain. Its threaded loader needs the player transform to select, load, and unload the 25 owned terrain chunks at runtime.
**Proposed API:** Instantiate `res://scenes/levels/lanka/lanka.tscn` under the SYSTEMS level host, retain the returned `Node3D`, then call `lanka.set_streaming_target(player_node)` after the player enters the tree. Do not instantiate the individual chunk scenes from SYSTEMS code.
**Blocking:** yes for integrated Lanka runtime traversal; no for WORLD M4 scene and streaming tests
**Status:** OPEN

### [2026-07-16] FROM: WORLD TO: SYSTEMS
**Request:** Enable root-viewport 3D occlusion culling in the SYSTEMS-owned project settings.
**Why:** M4 authors `OccluderInstance3D` coverage for the west, east, and north cliff bands and the persistent Spine, but Godot leaves root-viewport occlusion culling disabled by default.
**Proposed API:** Set `rendering/occlusion_culling/use_occlusion_culling=true` in `project.godot`. Retain Godot's default BVH quality and ray count until an integrated 1080p profile justifies tuning them.
**Blocking:** yes for M4 occluders to affect integrated runtime performance; no for distance LOD and chunk streaming
**Status:** OPEN

### [2026-07-16] FROM: WORLD TO: SYSTEMS
**Request:** Provide the gameplay prefabs required to replace WORLD-authored M5 district placement sockets.
**Why:** The M5 district scenes can own traversal geometry and deterministic placement, but ocean death, district entry, carryables, fire, heat, updrafts, interactive water, and drowned behavior are SYSTEMS-owned and no gameplay prefabs are present on the WORLD branch.
**Proposed API:** Provide WORLD-placeable `PackedScene` prefabs under `res://scenes/prefabs/gameplay/` for `ocean_kill_volume`, `district_trigger`, `carryable_object`, `fire_source`, `heat_volume`, `updraft_volume`, `water_volume`, `water_current`, and `drowned_spawn`. Volume prefabs need exported `size_m: Vector3`; directional prefabs need exported `direction: Vector3` and `strength: float`; triggers/spawns need exported `district_id: StringName` or `spawn_id: StringName`. WORLD scenes expose matching `Marker3D` nodes under `GameplaySockets` with metadata keys `socket_type`, `socket_size_m`, `direction`, `strength`, `district_id`, and `spawn_id` as applicable. Once the prefabs exist, WORLD will instance them at those sockets without opening or editing the prefab files.
**Blocking:** yes for functional M5 hazards and district events; no for WORLD-owned geometry, traversal, streaming, and scene validation
**Status:** OPEN

### [2026-07-16] FROM: WORLD TO: SYSTEMS
**Request:** Integrate The Dark as a separate sublevel entered after the Spine rather than adding it to Lanka's open-world stream selector.
**Why:** M5 provides `dark_district.tscn` as an enclosed terror sequence with drowned spawn and hiding sockets. The constitution requires it to be separately streamed, and player transfer plus drowned lifecycle are SYSTEMS-owned.
**Proposed API:** When the SYSTEMS-owned trial flow opens The Dark, instance `res://scenes/levels/lanka/districts/dark/dark_district.tscn` through the level host, place Nau at `RouteMarkers/Entry`, and unload it when the sequence exits. Do not add this path to `LankaDistrictContract.OPEN_WORLD_DISTRICTS`; the WORLD validator deliberately rejects that coupling.
**Blocking:** yes for entering and completing The Dark in the integrated build; no for WORLD M5 scene validation
**Status:** OPEN
