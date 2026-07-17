# THE ODYSSEY: ARCHITECTURE

**This document is the constitution. Both agents read it. Neither agent edits it without the human's explicit approval.**

Engine: Godot 4.6.1
Renderer: Forward+
Language: GDScript only. No C#, no GDExtension, no C++ modules.
Target: PC (Windows primary), keyboard + mouse, gamepad support desired but not blocking.
Repo root (main worktree): `C:/Users/yalam/Documents/the-odyssey`

---

## 0. SCOPE CONTROL (READ THIS FIRST)

**This document specifies ONE island: Lanka. Nothing else.**

The game has six islands planned. Five of them do not have design documents yet and **must not be invented, stubbed with content, or speculatively built.**

When the Lanka milestone is complete:

1. Stop.
2. Do not begin work on any other island.
3. Do not invent the departure voyage, the ocean crossing, the next island's geography, or any element powers.
4. Output a message to the human that says: *"Lanka milestone complete. Request the next island document."*

**The departure from Lanka is a stub.** When all five Setu components are collected, the ship assembles, a cutscene placeholder plays, and the game returns to a "TO BE CONTINUED" screen. That is the entire ending of the current build.

**Anti-scope rules:**
- Do not implement element bending. Nau has no powers on Lanka. Build the hook, not the feature (see §6).
- Do not implement combat. There is no combat on Lanka, ever.
- Do not implement a clothing or equipment system. It is cut from the game.
- Do not implement a stamina meter. It is cut from the game.
- Do not implement sailing, the ocean crossing, or Setu upgrades. Build the data slots only.
- Do not add mechanics that are not in this document. If you think something is missing, say so and stop. Do not build it.

---

## 1. THE GAME

A drowned world. A rising ocean has swallowed nearly everything.

The hero, **Nau**, falls out of the sky with no memory and wakes on **Lanka**, the last island still fully above water. Lanka is a burnt city on a mesa. It is still smoldering.

Nau does not know it, but he did this. He crossed the ocean by threatening it into parting, built a bridge called **Setu**, took Lanka and burned it. The sea learned his name that day. When it took everything back, the bridge broke and the water rose over the world.

To leave, Nau salvages five pieces of the broken bridge and rebuilds them into a boat, also called Setu. The bridge that carried an army becomes a boat that carries one man home.

**Home is Ithaya.** It is at the bottom of the ocean. It is also the final boss arena. (Out of scope. Context only.)

### Names and terms

| Term | Meaning |
|---|---|
| **Nau** | The hero. Hooded, masked, muscular. Never shows his face. |
| **Lanka** | The tutorial island. A burnt city on a mesa. |
| **Setu** | The bridge Nau built, now broken. Also the boat he rebuilds from it. |
| **Vela** | The one waiting for him. Bound at the bottom of the sea. (Out of scope.) |
| **Ravuna** | The Ten-Fathom King. The thing in the water. (Out of scope.) |
| **Ithaya** | Home. Underwater. (Out of scope.) |
| **The drowned** | Nau's own dead crew. They come out of the water. Unkillable. |
| **Keffer** | A living scavenger on Lanka. Terrified of Nau. Gives food. |
| **Cairn** | Optional single-room physics puzzle chamber. Yields a heart piece. |

### Tone

Ash, salt, wet stone, low sun through smoke. The island is a crime scene the player does not yet know they committed. Nothing on Lanka should feel triumphant.

---

## 2. THE PILLARS (non-negotiable)

1. **Nau is powerless on Lanka.** No weapons, no bending, no combat. He runs, climbs, carries, hides, and thinks.
2. **Fire is a physical system, not a power.** It spreads, it consumes fuel, it makes updrafts, it hurts. Nau interacts with it using objects. He does not command it.
3. **The ocean is the wall.** No invisible barriers. Walking into the sea kills you. The world is the gate.
4. **No stamina meter.** Climbing is limited by surface material, not by a bar (see §5).
5. **Density over size.** Every 60 seconds of walking must contain something. If a region cannot be filled, shrink it.
6. **Diegetic UI wherever possible.** Hearts are the only permanent HUD element.

---

## 3. LANKA: GEOGRAPHY

**Size: approximately 1.2 km² (1100m x 1100m playable).** Roughly Great Plateau scale.

A mesa. Cliffs on all sides except the south, where the land slopes into tidal flats. The ocean surrounds it and kills.

### Districts

| District | Location | Role | Teaches |
|---|---|---|---|
| **The Shallows** | South, arrival | Tidal flats, wrecked hulls, the stumps of Setu marching out to sea and vanishing. Safe, open, gentle. Keffer lives here. | Movement, carry, the ocean-as-wall |
| **The Terraces** | West | Stepped farmland gone to ash. Dry irrigation channels, collapsed retaining walls. Vertical but forgiving. | Climbing, grip materials |
| **The Ember Quarter** | Center-east | The city proper. Still burning in patches. Timber frames, collapsed roofs, hot updrafts venting from street cracks. | Fire, heat, updrafts, the glider |
| **The Cistern** | Below the city | Lanka's water system. Dark, flooded, dripping. The only fresh water left. | Water, buoyancy, currents, light |
| **The Spine** | North, dominant | The tower. Visible from every point on the island. The thing you are always walking toward. | Convergence. The final climb. |
| **The Dark** | Beneath the Spine | Where the drowned are. | Crouch, stealth, terror |

**The Spine must be visible from everywhere.** It is the island's compass. Sightlines to it are a hard constraint on terrain authoring.

### Critical path

1. The Shallows (forced, arrival)
2. The Terraces / The Ember Quarter / The Cistern, in **any order**
3. The Spine (requires all three above)
4. The Dark (requires the Spine)
5. Setu assembles. Stub ending.

---

## 4. THE FIVE TRIALS

Five trials. Five components of Setu. Each teaches one thing.

| Trial | District | Teaches | Yields |
|---|---|---|---|
| **The Hold** | Shallows | Carry, stack, physics objects, inventory | **Hull** |
| **The Smolder** | Ember Quarter | Fire spread, fuel, updrafts, heat damage, glider | **Mast** |
| **The Cistern** | Cistern | Water, buoyancy, currents, dousing, carrying flame | **Sail** |
| **The Spine** | The tower, north | Climbing at scale. Convergence of all three above. | **Keel** |
| **The Dark** | Beneath the Spine | Crouch, stealth, evasion, the drowned | **Figurehead** |

**The Terraces are not a trial.** They are the climbing tutorial: a safe, forgiving vertical playground where the player learns to read grip classes before the Spine demands it. They hold Cairns, salvage, and ashroot. They gate nothing but skill.

**The Spine requires the other three trials to be complete**, and it must require them *physically*, not through a flag check. The route up the tower depends on:
- an object hauled up from the Shallows and stacked (Hold),
- a fire-lit updraft ridden with the glider (Smolder),
- a doused surface that converts a `HOT` section to something survivable (Cistern).

If the player finds a way to skip one of those, that is a level design bug, not a feature.

### The Figurehead

Carved with Vela's face. Nau carved it himself before he left. He does not remember doing it. Once mounted on Setu it speaks to him with her voice for the rest of the game. **It is not her.** On Lanka it speaks exactly once, at the moment of mounting, and then the build ends.

---

## 5. CLIMBING

**Climb anything. No stamina. Grip is a material property.**

Every surface has a **grip class**, driven by the material assigned to it:

| Grip class | Behavior | Where |
|---|---|---|
| `SOLID` | Hold indefinitely. | Clean stone, unburnt timber, rope, root |
| `CRUMBLING` | Holds ~2.5s, then the handhold fails and you fall. Visual: flaking, dust puffs. | Charred timber, fire-cracked stone |
| `SLICK` | Cannot grip at all. Slide off immediately. | Soot-covered surfaces, wet stone, algae |
| `HOT` | Grips fine, but deals contact damage per second. | Anything currently burning or recently burnt |

**This is the entire gate.** The burnt city is climbable in principle and hostile in practice. Route-finding means reading materials. Charwood fruit (heat resistance) opens `HOT` routes. Water doused on a surface converts `HOT` to `SLICK`, which is a tradeoff, not a solution.

**Ambient heat** is a separate volume-based system. The Ember Quarter has heat zones that damage over time regardless of contact. Heat rises, so vertical routes there are worse. Heat resistance food is the counter.

---

## 6. THE ELEMENT SYSTEM (HOOK ONLY, DO NOT IMPLEMENT)

Nau eventually bends fire, earth, air, and water, gained one per island across the four islands after Lanka. Each later gains a sub-element (metal from earth, lightning from fire, ice from water, flight from air).

**None of this exists on Lanka.** Nau has zero elements for this entire build.

**But the architecture must not have to be retrofitted.** Build:

- An `ElementSystem` autoload with an empty registry.
- An `Element` resource class with fields for id, name, sub-element list, unlock state.
- A player-facing API surface (`ElementSystem.has_element(id)`, `ElementSystem.unlock(id)`) that always returns false / does nothing on Lanka.
- Save data reserves the element unlock table.
- **No abilities. No input bindings. No VFX. No UI.**

If a puzzle on Lanka would be trivial with an element the player will later have, that is correct and intentional. Lanka is meant to be replayable with powers.

---

## 7. HEALTH, FOOD, COOKING

### Health
- **Hearts.** Start with **3**.
- **Heart pieces** from Cairns. **4 pieces = 1 container.**
- **8 Cairns on Lanka = exactly 2 containers.** Nau leaves Lanka with 5 hearts. This is exact. Do not add or remove Cairns.
- Damage sources: fire contact, ambient heat, falling, drowning, the drowned.
- Death is a **hard reset to last save. Nothing is lost. Nothing is dropped.**

### Autosave
- At **campfires** and on **notable quest completion** (trial completion, Cairn completion, first entry to a district).
- Campfires are cooking stations AND save points. Same object, two jobs.
- No manual save slots for now. One autosave slot.

### Food
Lanka is burnt. Food is scarce. **Exactly four ingredients.** Do not add more.

| Ingredient | Where | Raw | Cooked |
|---|---|---|---|
| **Tidepool shellfish** | The Shallows, in tidepools at low water | ½ heart | 2 hearts |
| **Ashroot** | The Terraces, dug from ash beds | ¼ heart | 1½ hearts |
| **Charwood fruit** | The Ember Quarter, growing inside the burn | ½ heart | 1 heart + **heat resistance, 90s** |
| **Blind fish** | The Cistern, caught in still water | ½ heart | 2 hearts, **cooks only on real flame** (must be carried up out of the Cistern) |

**Cooking rules:**
- Raw is weak. Cooked is strong. **Overcooked is charcoal and wasted.** There is a cook window.
- Cooking is a timed interaction at a campfire, not a menu. You put the thing on the fire and take it off.
- **Charwood fruit is the design centerpiece:** you must enter the fire to get the thing that lets you survive the fire.
- **No recipes. No combining. No buff stacking.** One ingredient, one fire, one result. Heat resistance is the only non-heal effect on Lanka.

---

## 8. INVENTORY

- **Hotbar: 10 slots.** Minecraft-style. Number keys 1-0, scroll wheel. Always visible.
- **Storage: 30 slots.** Opened with a key, closed with a key. Not a pause menu.
- Total 40 slots.
- **Stacking:** food stacks to 20. Salvage stacks to 20. Setu components do not stack and are unique key items held in a separate reserved area, not in the 40.
- **Physical carry is separate from inventory.** Large objects (crates, beams, barrels) are held in the world with two hands, not stored. You cannot climb while carrying. This is the Hold trial's whole design.

---

## 9. SALVAGE

- Found in wrecks, ruins, the Cistern, and the burn.
- **On Lanka, salvage has no use yet.** It is collected and stored on Setu.
- **Its purpose is Setu upgrades on later islands** (sail, hull, hold capacity, lantern). Those are out of scope.
- Build the data slots on Setu. Do not build the upgrade system.
- Roughly 3 salvage types: **timber, iron, canvas.** Enough for a UI to show three numbers.

---

## 10. THE DROWNED

- Nau's own dead crew. They followed him across the sea and he lost every one of them.
- **They exist only in The Dark**, beneath the Spine, at the very end of the island.
- **They cannot be hurt. There is no combat. Ever.**
- They hunt by sound and light. Crouching is quiet. Running is loud. Carrying fire is visible.
- The Dark is a stealth and panic sequence. It is Lanka's climax and it is terror, not a boss fight.
- **They never leave The Dark.** No wandering the island. No respawn pressure.
- Contact = damage and a knockback that separates you from your light source. Not instant death.

---

## 11. KEFFER

- A living scavenger. He lives under an overturned hull in the Shallows.
- **He is not a merchant. He sells nothing.** He is a Captain Toad.
- He gives Nau food. He gives one or two Cairn hints. He is the only living voice on Lanka.
- **He recognizes Nau and is quietly terrified of him, and never explains why.**
- Total content: maybe eight lines of dialogue and a food handout on a cooldown. He is an Easter egg with a heartbeat. Do not build him a quest chain.

---

## 12. THE DROWNED CREW FRAGMENTS

- **20 memory fragments** scattered across Lanka. Remains of Nau's men.
- Each yields a fragment: a name, an object, one or two lines of what happened.
- **Pure story reward.** No stats. No gates.
- They shift the ending of the game. (Out of scope, but the save data must count them.)
- This is the cheapest good content in the game: text and audio over geometry that already exists.

---

## 13. CAIRNS

- **Exactly 8.** Not 7, not 10.
- Small optional single-room physics puzzle chambers. Enter, solve, leave.
- Each tests one idea already taught by a trial. **No new mechanics inside a Cairn.**
- Reward: **1 heart piece.** 8 Cairns = 2 heart containers.
- Distribution: 2 Shallows, 2 Terraces, 2 Ember Quarter, 2 Cistern.
- Each Cairn is a separate scene, loaded on entry. They are not carved into the open world's geometry.

---

## 14. THE GLIDER

- A scrap of Setu's sail, found in the Ember Quarter partway through The Smolder.
- Rides updrafts. Slows falls. **Not a central mechanic.**
- No stamina cost (there is no stamina). It is limited by the availability of updrafts and by height.
- Do not build a flight game. It is a fall-management tool and an updraft payoff.

---

## 15. ART DIRECTION

**Target: stylized PBR.**

- Real materials, real lighting, real fog and volumetrics.
- Proportions pushed roughly 15% toward chunky: bigger hands, heavier boots, broader shoulders.
- Albedo slightly hand-painted rather than photoscanned. Reduce micro-detail, increase silhouette clarity.
- **Reference triangulation:** the human named Uncharted, Skylanders, and Smash Bros Brawl. Those do not agree. The point where they meet is **Sea of Thieves**. Also useful: Prince of Persia (2008), Overwatch environments.
- **Not cel-shaded. Not low-poly.**

### Nau

- **Hooded and masked at all times. His face is never visible. This is permanent and load-bearing.**
- Muscular, broad shouldered, heavy silhouette.
- Salt-stained cloth over dark leather. Everything a bit burnt.
- **Readable as a shape at 200m in fog.** That is the test.

### Palette

- Ash grey, wet black, bone white, ember orange, sea green.
- Ember orange is the only saturated color on the island and it is always danger or warmth. Never decoration.

### Lighting

- Low sun through smoke. Heavy volumetric fog. God rays through collapsed roofs.
- The Cistern is nearly black. Your light source is a real object you carry.
- This is where most of "looks properly rendered" actually lives. Prioritize the lighting and material work over mesh detail.

---

## 16. ASSET PIPELINE

**Path 1: free assets only. Zero budget.**

### Sources (all legal, all free)

| Source | What | License |
|---|---|---|
| **Mixamo** | Rigged humanoid base + animations | Free with Adobe account, usable in games |
| **Poly Haven** | PBR materials, HDRIs, models | CC0, has an API |
| **ambientCG** | PBR materials | CC0, has an API |
| **Quaternius** | Stylized models | CC0 |
| **KayKit** | Stylized model kits | CC0 |
| **OpenGameArt** | Mixed | Check per-asset license |
| **Kenney** | Props, kits | CC0 |

### MUSIC AND AUDIO: HARD RULE

**Do not download, scrape, or use copyrighted music. This includes anything from Zelda or any other commercial game. Do not write scripts that search for or fetch commercial game soundtracks. This is not negotiable and it is not a style question.**

Legal sources only:
- **Incompetech** (Kevin MacLeod, CC-BY, requires attribution)
- **Free Music Archive** (check per-track license)
- **OpenGameArt** audio (check per-asset)
- **Pixabay** audio
- **Freesound** (check per-asset license, mostly CC0/CC-BY)

**Style target, not source target:** sparse ambient exploration beds, modal melodies, low strings and solo woodwind, long silences. The island is quiet. Wind, fire crackle, distant surf, dripping water carry most of the audio. Music should be rare enough that when it appears it means something.

**Every third-party asset gets an entry in `/docs/ATTRIBUTIONS.md`** with source URL, author, license, and date pulled. No exceptions. An asset without an attribution entry gets deleted.

### The character contract

**Nau's mesh is a placeholder and will be replaced.** Do not couple anything to a specific mesh. The contract:

- Skeleton conforms to Godot's `SkeletonProfileHumanoid`.
- Attachment sockets by `BoneAttachment3D`: `Socket_RightHand`, `Socket_LeftHand`, `Socket_Back`, `Socket_Hip`.
- Root motion off. Locomotion is code-driven.
- Material slots named, not indexed.
- The player scene references the mesh through an exported `PackedScene` field, not a hardcoded path.

Everything that touches Nau touches the contract, never the mesh.

---

## 17. PROJECT STRUCTURE

```
res://
├── addons/                 # editor plugins            [WORLD]
├── assets/
│   ├── audio/
│   │   ├── music/                                      [WORLD]
│   │   └── sfx/                                        [WORLD]
│   ├── characters/
│   │   ├── nau/                                        [WORLD]
│   │   └── drowned/                                    [WORLD]
│   ├── materials/                                      [WORLD]
│   ├── models/                                         [WORLD]
│   └── textures/                                       [WORLD]
├── docs/
│   ├── ARCHITECTURE.md     # this file                 [HUMAN]
│   ├── AGENT_SYSTEMS.md                                [HUMAN]
│   ├── AGENT_WORLD.md                                  [HUMAN]
│   ├── ATTRIBUTIONS.md                                 [WORLD]
│   └── INTERFACES.md       # append-only contract log  [BOTH]
├── src/
│   ├── autoload/                                       [SYSTEMS]
│   ├── player/                                         [SYSTEMS]
│   ├── interaction/                                    [SYSTEMS]
│   ├── inventory/                                      [SYSTEMS]
│   ├── cooking/                                        [SYSTEMS]
│   ├── elements/           # hook only                 [SYSTEMS]
│   ├── save/                                           [SYSTEMS]
│   ├── ui/                                             [SYSTEMS]
│   ├── drowned/                                        [SYSTEMS]
│   ├── world/              # runtime world systems     [SYSTEMS]
│   │   ├── fire/
│   │   ├── water/
│   │   └── heat/
│   └── tools/              # editor-time tooling       [WORLD]
├── scenes/
│   ├── player/             # player.tscn               [SYSTEMS]
│   ├── ui/                                             [SYSTEMS]
│   ├── prefabs/
│   │   ├── gameplay/       # campfire, pickups, etc.   [SYSTEMS]
│   │   └── props/          # dressing, no logic        [WORLD]
│   ├── levels/
│   │   ├── lanka/                                      [WORLD]
│   │   └── cairns/                                     [WORLD]
│   └── test/               # test scenes                [BOTH, own files]
└── tests/                  # GUT                       [BOTH, own files]
```

**The tag in brackets is the owning agent. An agent NEVER edits a file owned by the other agent.**

---

## 18. THE OWNERSHIP RULE (the most important rule in this document)

There are two agents working in two git worktrees on two branches.

- **SYSTEMS agent** (Claude Code, branch `systems`, folder `the-odyssey-systems`)
- **WORLD agent** (Codex, branch `world`, folder `the-odyssey-world`)

### Hard rules

1. **Never edit a file owned by the other agent.** Not to fix a bug. Not to add one line. If you need a change in their territory, write it into `docs/INTERFACES.md` as a request and tell the human.
2. **`.tscn` files do not merge.** They are text but they merge catastrophically. This is why ownership is absolute.
3. **`project.godot` is owned by the SYSTEMS agent.** Autoloads, input map, physics layers, rendering settings. If WORLD needs a project setting changed, it requests it via `INTERFACES.md`.
4. **Physics layers are defined once, in this document (§19), and never changed unilaterally.**
5. **`docs/INTERFACES.md` is append-only.** Never delete or rewrite another agent's entry.
6. **Commit constantly.** Small commits. Meaningful messages. The human merges.

### The seam

The two agents meet at exactly one place: **the world agent builds scenes that instance the systems agent's prefabs.**

WORLD places a campfire. SYSTEMS built the campfire. WORLD never opens `campfire.tscn`. If the campfire's API needs to change, WORLD asks in `INTERFACES.md`.

---

## 19. TECHNICAL CONTRACTS

These are fixed. Neither agent changes them without human approval.

### Physics layers

| Layer | Name | Purpose |
|---|---|---|
| 1 | `world` | Static terrain and architecture |
| 2 | `player` | Nau |
| 3 | `climbable` | Surfaces that report a grip class |
| 4 | `carryable` | Large physical objects |
| 5 | `interactable` | Anything with an interact prompt |
| 6 | `water` | Water volumes |
| 7 | `fire` | Burning things and fire damage volumes |
| 8 | `heat` | Ambient heat volumes |
| 9 | `drowned` | The drowned |
| 10 | `sound` | Sound propagation for the drowned's hearing |
| 11 | `flammable` | Objects fire can spread to |
| 12 | `updraft` | Updraft volumes |

### Autoloads (all SYSTEMS-owned)

| Name | Purpose |
|---|---|
| `GameState` | Run state, current district, flags |
| `SaveSystem` | Autosave, load, one slot |
| `EventBus` | Global signals. The only cross-system coupling allowed. |
| `ElementSystem` | Hook only. Always returns false on Lanka. |
| `AudioDirector` | Music beds, ambience, ducking |
| `Inventory` | 10 hotbar + 30 storage + key items |

### Grip class contract

A climbable surface exposes its grip class through the **material name**, not through per-node scripting.

```gdscript
# src/world/grip.gd  [SYSTEMS owns this]
class_name Grip
enum Class { SOLID, CRUMBLING, SLICK, HOT }
```

Material naming convention, enforced on both sides:

```
mat_<name>_grip_solid
mat_<name>_grip_crumbling
mat_<name>_grip_slick
mat_<name>_grip_hot
```

**WORLD authors materials with these names. SYSTEMS reads the name at runtime and derives the class.** This is the seam. It means WORLD can paint a cliff face and the climbing system Just Works with zero coordination.

`HOT` is dynamic: a surface that is currently on fire reports `HOT` regardless of its material name, via the fire system.

### EventBus signals (the shared vocabulary)

```gdscript
# src/autoload/event_bus.gd  [SYSTEMS owns this]

signal district_entered(district_id: StringName)
signal trial_completed(trial_id: StringName)
signal component_acquired(component_id: StringName)
signal cairn_completed(cairn_id: StringName)
signal fragment_found(fragment_id: StringName)
signal autosave_requested(reason: StringName)
signal player_died()
signal fire_started(position: Vector3)
signal fire_extinguished(position: Vector3)
signal sound_emitted(position: Vector3, loudness: float)
```

**WORLD may connect to these. WORLD may not add to them.** If WORLD needs a new signal, request in `INTERFACES.md`.

### Naming

- Files and directories: `snake_case`
- Classes: `PascalCase` with `class_name`
- Signals: past tense (`fire_started`), not `on_fire_start`
- Constants: `SCREAMING_SNAKE_CASE`
- Private: `_leading_underscore`
- Node names in scenes: `PascalCase`

### GDScript style

- Static typing everywhere. `var x: int = 0`, not `var x = 0`.
- Typed signals, typed exports, typed function signatures and returns.
- `@onready` for node refs. No `get_node()` in `_process`.
- Prefer composition (child nodes) over inheritance for behaviors.
- No `class_name` collisions. Check before adding one.

### Performance targets

- 60 FPS at 1080p on mid-range hardware.
- Lanka is 1.2km². **Streaming is mandatory.** Do not build it as one scene.
- Terrain LOD, mesh LOD, occlusion culling, `VisibleOnScreenNotifier3D` on expensive props.
- Fire is the perf risk. Budget it: hard cap on simultaneously burning cells, hard cap on fire particle emitters.

---

## 20. TESTING

- **GUT** (Godot Unit Testing) for logic.
- SYSTEMS writes tests for: inventory math, cooking state machine, grip class derivation, fire spread rules, save round-trip, heart/heart-piece math.
- WORLD writes tests for: material naming validation (every climbable material matches the convention), attribution completeness (every asset has an entry), scene budget checks.
- **Both agents write a test scene they can run headless.** Do not build a system you cannot test without the human.
- Every system must have at least one test against the shipped scene, not a
  synthetic one. A system that only passes against a mock is not built.
- The human playtests. Agents do not get to declare something feels good.

---

## 21. DEFINITION OF DONE FOR LANKA

### THE INTEGRATION GATE (blocks every other checkbox)

- [ ] scenes/levels/lanka/lanka.tscn runs on F5 with no errors.
- [ ] Nau spawns, the HUD renders, the player can walk.
- [ ] Every gameplay prefab SYSTEMS built is instanced in a shipped scene:
      player, HUD, campfires, fire grids, flammable props, water volumes,
      heat volumes, district triggers, drowned, Setu, component pickups,
      fragments, Cairn entrances.
- [ ] A shipped-scene smoke test exists that loads the real lanka.tscn with no
      mocks and no synthetic targets, and asserts each of the above is present
      and live at runtime. It runs in CI. No milestone closes while it fails.

**A unit test that builds its own world proves the unit works. It does not
prove the game exists. Any system tested only against a mock is unbuilt.**

The build is complete when:

- [ ] Nau spawns in the Shallows and can run, jump, crouch, climb, carry, glide.
- [ ] The ocean kills. No invisible walls anywhere.
- [ ] All five districts are traversable and dressed.
- [ ] All five trials are completable and yield their component.
- [ ] Fire spreads, consumes fuel, makes updrafts, and hurts.
- [ ] Water in the Cistern is interactive: buoyancy, currents, dousing.
- [ ] Grip classes work. Charred timber crumbles. Soot is unclimbable.
- [ ] Ambient heat damages in the Ember Quarter. Charwood fruit counters it.
- [ ] 4 ingredients forage, cook, over-cook, and heal.
- [ ] Campfires cook and autosave.
- [ ] 10-slot hotbar + 30-slot storage.
- [ ] 8 Cairns, each yielding a heart piece. Nau ends with 5 hearts.
- [ ] 20 crew fragments findable.
- [ ] Keffer exists and is afraid.
- [ ] The Dark: the drowned hunt by sound and light, cannot be hurt, and cannot be escaped except by hiding.
- [ ] Setu assembles from five components. Figurehead speaks once. "TO BE CONTINUED."
- [ ] 60 FPS at 1080p.
- [ ] `ATTRIBUTIONS.md` is complete and every asset is legal.

**Then stop and request the next island document.**
