# AGENT BRIEF: SYSTEMS

**You are the SYSTEMS agent.**
Branch: `systems`
Worktree: `C:/Users/yalam/Documents/the-odyssey-systems`

**Read `docs/ARCHITECTURE.md` first and completely. It is the constitution. This document does not repeat it. Where they conflict, ARCHITECTURE wins.**

---

## YOUR TERRITORY

You own:

```
src/autoload/
src/player/
src/interaction/
src/inventory/
src/cooking/
src/elements/
src/save/
src/ui/
src/drowned/
src/world/fire/
src/world/water/
src/world/heat/
scenes/player/
scenes/ui/
scenes/prefabs/gameplay/
project.godot
```

You do **not** own, and never edit:

```
addons/
assets/**
src/tools/
scenes/levels/**
scenes/prefabs/props/
docs/ATTRIBUTIONS.md
```

If you need something in WORLD's territory, append a request to `docs/INTERFACES.md` and tell the human. Do not reach across.

---

## YOUR JOB IN ONE SENTENCE

**Build everything Nau does, everything that hurts him, and everything he carries. WORLD builds the island he does it on.**

---

## MILESTONE ORDER

Do these in order. Do not skip ahead. Commit at every checkpoint. After each milestone, output a short summary and stop for the human to review.

### M1. Foundation
- Autoloads: `EventBus`, `GameState`, `SaveSystem`, `Inventory`, `ElementSystem`, `AudioDirector`.
- Physics layers configured in `project.godot` exactly per ARCHITECTURE §19.
- Input map: move, look, jump, crouch, sprint, interact, drop, hotbar 1-0, hotbar scroll, open storage, glider.
- `EventBus` signals declared exactly per ARCHITECTURE §19. Nothing extra.
- A test scene: an empty box with a floor.
- GUT installed and a passing smoke test.

### M2. Player controller
- `CharacterBody3D`. Third person. Spring arm camera with collision.
- Run, walk, jump, crouch, fall, land. Coyote time. No stamina, ever.
- Locomotion is code-driven. **Root motion off.**
- Nau's mesh is referenced through an exported `PackedScene`, never a hardcoded path. Ask WORLD for a placeholder via `INTERFACES.md`; until it exists, use a capsule.
- Animation state machine wired against `SkeletonProfileHumanoid` bone names only.
- **The character contract in ARCHITECTURE §16 is law.** Nothing you write may assume a specific mesh.

### M3. Climbing
This is the island's core system. Get it right.
- Climb any surface on layer `climbable`.
- Grip class derived at runtime from **material name** per ARCHITECTURE §19. Do not invent a per-node grip property. WORLD paints materials; you read names.
  - `SOLID`: hold indefinitely.
  - `CRUMBLING`: hold ~2.5s, then the handhold fails and Nau falls. Telegraph it: dust, flaking, a hand slip, audio.
  - `SLICK`: cannot grip. Slide off on contact.
  - `HOT`: grips fine, contact damage per second.
- A surface currently on fire reports `HOT` regardless of its material name. The fire system overrides.
- Ledge grab, mantle, wall jump if you want it, but climbing is a route-reading puzzle, not a parkour toy.
- **Cannot climb while carrying a large object.** That is the Hold trial's whole design.
- GUT test: grip class derivation from a table of material names.

### M4. Interaction and carry
- Raycast-based interact prompt on layer `interactable`.
- **Carry** is separate from inventory. Large objects (layer `carryable`) are held in the world with two hands. `RigidBody3D` freeze on pickup, unfreeze on drop. Physical, not a menu item.
- Carrying: no climbing, no glider, reduced speed, obstructed camera.
- Stacking must work. You must be able to build a stair out of crates and stand on it. Test it.
- Small pickups go into inventory.

### M5. Inventory
- **10-slot hotbar.** Number keys 1-0, scroll wheel. Always on screen. Minecraft-style.
- **30-slot storage.** Toggle key. Not a pause menu, do not pause the game.
- Food stacks to 20. Salvage stacks to 20.
- Setu components are unique key items in a separate reserved area. Not in the 40.
- Item definitions are `Resource` files. Data driven. Not hardcoded.
- Salvage types: `timber`, `iron`, `canvas`. Collected, stored, unused on Lanka.
- GUT test: stacking, splitting, overflow, hotbar/storage transfer.

### M6. Health, death, save
- **Hearts. Start at 3.** Heart pieces, 4 to a container.
- Damage: fire contact, ambient heat, falls (above a threshold), drowning, the drowned.
- **Death is a hard reset to the last autosave. Nothing lost, nothing dropped.** No run-back penalty.
- Autosave triggers: campfire use, trial completion, Cairn completion, first entry to a district. Fire `autosave_requested` on `EventBus`.
- One autosave slot. No manual saves.
- Save data must include a reserved element unlock table (see M9), fragment count, Cairn completion, component acquisition, heart containers, inventory, position, district.
- GUT test: full save round-trip.

### M7. Fire
The most important system on the island and the biggest perf risk.
- Grid or cell based spread. Not per-object hacks.
- Fire consumes **fuel**. Objects on layer `flammable` have a fuel value. When fuel is gone, the fire dies and the object is charred, permanently.
- **A charred surface's grip class becomes `CRUMBLING`.** Fire is a level-design tool: burning something changes whether you can climb it.
- Fire spreads by proximity and by contact. It spreads faster upward.
- Fire produces **updrafts**: an `updraft` volume above a sufficiently large burn.
- Fire dies in water and under a doused surface.
- Fire damages on contact and radiates ambient heat.
- **Hard caps.** A hard cap on simultaneously burning cells and on live particle emitters, both exported and tunable. Profile it. If Lanka drops below 60 FPS because of fire, the fire system is wrong.
- Nau carries fire with a physical object (a brand). Carrying fire is loud and visible, which matters in The Dark.
- GUT test: spread rules, fuel exhaustion, char state transition.

### M8. Water and heat
- **Water:** the Cistern only. Buoyancy, currents (force volumes), dousing (extinguish fire, convert `HOT` to `SLICK`), swimming, drowning with a breath timer.
- The ocean is **not** this system. The ocean is a kill volume with waves on it. Do not build the ocean as playable water.
- **Ambient heat:** volumes on layer `heat`. Damage over time. Heat rises, so WORLD will stack them vertically in the Ember Quarter. Heat resistance (from charwood fruit) negates it for 90s.
- Both systems are placed by WORLD as volumes. You build the volumes and their behavior. WORLD places them.

### M9. Element system hook (DO NOT BUILD ELEMENTS)
- `ElementSystem` autoload with an empty registry.
- An `Element` resource class: id, display name, sub-element list, unlock state.
- API: `has_element(id) -> bool` (always false), `unlock(id)`, `get_unlocked() -> Array`.
- Save data reserves the unlock table.
- **No abilities. No input bindings. No VFX. No UI. Nau has zero elements on Lanka.**
- This exists so that four islands from now nobody has to retrofit an architecture. That is all.

### M10. Cooking
- Campfire prefab. **Cooks AND autosaves. Same object, two jobs.**
- Cooking is a **timed physical interaction**, not a menu. Put the thing on the fire. Take it off. There is a cook window.
- Three states: `RAW`, `COOKED`, `BURNT`. Burnt is charcoal and is wasted.
- Exactly four ingredients per ARCHITECTURE §7. Do not add a fifth.
- **No recipes. No combining. No buff stacking.** One ingredient, one fire, one result.
- Charwood fruit cooked grants heat resistance, 90s. That is the only non-heal effect on Lanka.
- Blind fish only cook on a real flame, not on embers. The player must carry them up out of the Cistern.
- GUT test: cook state machine, timing windows, buff duration.

### M11. The drowned
- **Only in The Dark. Never on the surface. Never anywhere else.**
- **Cannot be hurt. There is no combat. There is no attack input. Do not build one.**
- Hunt by **sound** (layer `sound`, `sound_emitted` on `EventBus`) and **light** (carried fire is visible at range).
- Crouch is quiet. Walk is audible near. Run is loud. Carrying a brand is a beacon.
- Contact: damage plus a knockback that separates Nau from his light source. **Not instant death.** Losing your light in the dark with them is the scare.
- Hiding: they lose track if you break line of sight and go quiet.
- The Dark is a stealth and panic sequence. Build it as terror. It is Lanka's climax.

### M12. UI
- **Hearts. That is the only permanent HUD element.**
- Hotbar, always visible.
- Storage panel, toggled.
- Interact prompt.
- Heat resistance indicator, diegetic if you can manage it.
- Breath meter, only while underwater.
- Fragment reader for the crew memories.
- **No minimap. No quest log. No compass.** The Spine is the compass and it is visible from everywhere.
- Everything else is diegetic or absent.

### M13. Glider
- A scrap of Setu's sail. Found in the Ember Quarter, partway through The Smolder.
- Rides updrafts. Slows falls. No stamina cost, because there is no stamina.
- Limited by updraft availability and height, nothing else.
- **Not a central mechanic. Do not build a flight game.** It is a fall-management tool and the payoff for making a big fire.
- Cannot glide while carrying.

### M14. Setu and the stub ending
- Setu is a scene in the Shallows with five component slots and three salvage counters (timber, iron, canvas).
- Components mount visibly as they are acquired. The boat assembles in front of the player over the course of the island.
- On the fifth component (Figurehead, from The Dark): it mounts, **it speaks exactly once with Vela's voice**, and then the screen goes to **"TO BE CONTINUED."**
- **Do not build the voyage. Do not build the ocean crossing. Do not build Setu upgrades. Do not invent the next island.**
- Salvage counters display. They do nothing. That is correct.

---

## WHEN LANKA IS DONE

Check every box in ARCHITECTURE §21. Then output:

> **Lanka milestone complete. Request the next island document.**

And stop. Do not start the next island. Do not speculate about it. Do not build the crossing.

---

## THINGS THAT WILL TEMPT YOU. DO NOT.

- Adding a stamina bar because climbing feels unlimited. **It is gated by materials. That is the design.**
- Adding a weapon or an attack because the drowned are frustrating. **They are supposed to be.**
- Adding a fifth ingredient or a recipe system. **Scarcity is the point.**
- Adding a minimap because the island is big. **The Spine is the compass.**
- Building element abilities because the hook is right there. **Nau is powerless. That is the story.**
- Editing a `.tscn` in `scenes/levels/` to fix a placement bug. **That is WORLD's file. Request it in `INTERFACES.md`.**
- Editing anything in `assets/`. **Not yours.**
- Building the departure voyage because the ending feels abrupt. **It is supposed to be abrupt. It is a stub.**

If you believe something is genuinely missing from the design, **say so and stop.** Do not build it and ask forgiveness. The human is designing this game, not you.
