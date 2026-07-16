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

### [2026-07-16] FROM: SYSTEMS TO: WORLD
**Request:** A placeholder rigged character scene for Nau, delivered under `assets/characters/nau/` (e.g. `assets/characters/nau/nau_placeholder.tscn`).
**Why:** The M2 player controller mounts the character mesh through an exported `PackedScene` per the character contract (ARCHITECTURE §16). Until this exists the player is a capsule, which works but cannot exercise animation or sockets.
**Proposed API:** A `PackedScene` whose root contains: a `Skeleton3D` conforming to `SkeletonProfileHumanoid`; `BoneAttachment3D` sockets named `Socket_RightHand`, `Socket_LeftHand`, `Socket_Back`, `Socket_Hip`; named material slots; an `AnimationPlayer` with any subset of clips named `idle`, `walk`, `run`, `sprint`, `jump`, `fall`, `land`, `crouch_idle`, `crouch_walk` (missing clips are safely ignored; loops for idle/walk/run/sprint/crouch_*). Root motion off. A Mixamo base + Mixamo clips retargeted to the humanoid profile satisfies all of this.
**Blocking:** no
**Status:** OPEN

### [2026-07-16] FROM: SYSTEMS TO: WORLD
**Request:** Addendum to the Nau placeholder request above: the animation clip list now also includes `climb_idle` and `climb_move` (M3 climbing). Same rules — any subset is fine, missing clips are ignored.
**Why:** The climbing controller drives these two states while attached to a wall.
**Proposed API:** Clip names exactly as listed, looping.
**Blocking:** no
**Status:** OPEN

### [2026-07-16] FROM: SYSTEMS TO: WORLD
**Request:** When you build Cairn scenes and district volumes, emit the existing EventBus signals exactly once per event and nothing more: `cairn_completed(cairn_id)` on solve, `district_entered(district_id)` on entry, `trial_completed(trial_id)` / `component_acquired(component_id)` / `fragment_found(fragment_id)` as applicable. Do not grant heart pieces or request autosaves yourself.
**Why:** M6 wires all of that on the SYSTEMS side: a new `cairn_completed` id grants the heart piece (4 = container, 8 Cairns = exactly 2 containers) and requests the autosave; first `district_entered` per district autosaves; `trial_completed` autosaves. Duplicate emissions with the same id are safely ignored, but the id must be stable per Cairn/district/trial.
**Proposed API:** Stable `StringName` ids, e.g. `&"cairn_shallows_1"`, `&"the_terraces"`, `&"the_hold"`.
**Blocking:** no
**Status:** OPEN

### [2026-07-16] FROM: SYSTEMS TO: WORLD
**Request:** To make level geometry burnable (M7): instance `scenes/prefabs/gameplay/fire_grid.tscn` exactly once per streamed level scene, and give each burnable prop a `Flammable` child node (script `res://src/world/fire/flammable.gd`), with the prop's body on physics layer `flammable` (11). Do not script fire behavior yourself.
**Why:** Fire is cell-based and grid-owned. The `Flammable` component self-registers with the grid; exports: `fuel` (cell-seconds of burn), `size` (world-space burnable extents around the prop origin; rotation ignored), `mobile` (single following cell, for carryable props). Burning/charred grip overrides (`HOT`/`CRUMBLING`) happen automatically through the existing group seam in `Grip`. Updraft volumes vent automatically above burns of 6+ cells. Placing a campfire is M10 and will be its own prefab.
**Proposed API:** As above. Ignition sources: `FireGrid.ignite_at(position)` from level scripting is allowed; everything else spreads on its own.
**Blocking:** no
**Status:** OPEN
