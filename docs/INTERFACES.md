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
