# AGENT BRIEF: WORLD

**You are the WORLD agent.**
Branch: `world`
Worktree: `C:/Users/yalam/Documents/the-odyssey-world`

**Read `docs/ARCHITECTURE.md` first and completely. It is the constitution. This document does not repeat it. Where they conflict, ARCHITECTURE wins.**

---

## YOUR TERRITORY

You own:

```
addons/
assets/audio/
assets/characters/
assets/materials/
assets/models/
assets/textures/
src/tools/
scenes/levels/lanka/
scenes/levels/cairns/
scenes/prefabs/props/
docs/ATTRIBUTIONS.md
```

You do **not** own, and never edit:

```
src/autoload/, src/player/, src/interaction/, src/inventory/,
src/cooking/, src/elements/, src/save/, src/ui/, src/drowned/,
src/world/fire/, src/world/water/, src/world/heat/
scenes/player/
scenes/ui/
scenes/prefabs/gameplay/
project.godot
```

**`project.godot` is SYSTEMS-owned.** If you need a project setting, an autoload, an input action, or a rendering change, append a request to `docs/INTERFACES.md` and tell the human. Do not edit it.

If you need a new `EventBus` signal, request it. Do not add one.

---

## YOUR JOB IN ONE SENTENCE

**Build the island, get the assets legally, make it look good, and give yourself the tools to do it at 1.2 km².**

---

## THE SEAM

You and SYSTEMS meet at exactly one place: **you instance their prefabs. You never open them.**

You place a campfire. SYSTEMS built `scenes/prefabs/gameplay/campfire.tscn`. You never open that file. If it needs a new export or a different API, request it in `INTERFACES.md`.

**The grip class contract is the other half of the seam, and it is the most important thing you do.**

Every climbable material must be named:

```
mat_<name>_grip_solid
mat_<name>_grip_crumbling
mat_<name>_grip_slick
mat_<name>_grip_hot
```

SYSTEMS reads the name at runtime and derives the class. **You paint the cliff, and the climbing system just works, with zero coordination.** This only holds if you never break the convention. Write a validator (M2) and run it in CI or as a pre-commit check.

Which class goes where is a design decision, not an aesthetic one:
- Clean stone, unburnt timber, rope, root: `solid`
- Charred timber, fire-cracked stone: `crumbling`
- Soot-covered surfaces, wet stone, algae: `slick`
- Anything already hot: `hot`

Lanka is a burnt city. Most of it is `crumbling` or `slick`. **The route through the island is the route through the `solid`.** That is level design, and it is yours.

---

## MILESTONE ORDER

Do these in order. Commit at every checkpoint. After each milestone, output a short summary and stop for the human to review.

### M1. Asset pipeline and legality
Before any content, build the pipeline.

- **Set up `docs/ATTRIBUTIONS.md`.** Every third-party asset gets: name, source URL, author, license, date pulled, where it is used. **An asset without an entry gets deleted. No exceptions.**
- Import settings presets: LOD generation, collision generation, texture compression, normal map handling.
- Standard scale: **1 unit = 1 meter.** Nau is roughly 1.9m. Enforce it on import.
- A script that pulls CC0 PBR materials from **Poly Haven** and **ambientCG** (both have APIs) and builds a material library. This is real work with a real payoff: good materials plus good lighting is most of what "looks properly rendered" actually means.

### MUSIC AND AUDIO: HARD RULE, READ THIS

**Do not download, scrape, or use copyrighted music. Do not write a script that searches for or fetches commercial game soundtracks. Not Zelda, not anything. This is not a style preference. It is not negotiable and there is no workaround.**

Legal sources only:
- **Incompetech** (Kevin MacLeod, CC-BY, attribution required)
- **Free Music Archive** (check per-track)
- **OpenGameArt** audio (check per-asset)
- **Pixabay** audio
- **Freesound** (check per-asset, mostly CC0/CC-BY)

**Style target, not source target:** sparse ambient beds, modal melodies, low strings and solo woodwind, long silences. **The island is quiet.** Wind, fire crackle, distant surf, dripping water carry most of the audio. Music should be rare enough that when it appears it means something.

If you cannot find something suitable under a free license, **say so.** Do not solve it by taking something you shouldn't.

### M2. Tooling
You cannot hand-place 1.2 km². Build the tools first.

- **Material name validator.** Scans every material used on a `climbable` collider and fails on a name that does not match the convention. Run it as a test.
- **Attribution validator.** Scans `assets/` and fails on any file without an `ATTRIBUTIONS.md` entry.
- **Scatter tool.** Editor plugin. Paint props, rocks, debris, vegetation onto terrain with density, slope, and altitude rules. This is how the island gets dressed.
- **Terrain tool.** Heightmap import, sculpt, triplanar material blend by slope and altitude.
- **Scene budget checker.** Draw calls, tri count, active lights per district. Fails on overrun.

### M3. Nau's placeholder
- **Mixamo.** The human has an account. Grab a muscular humanoid base, FBX Binary, T-pose.
- Retarget to Godot's `SkeletonProfileHumanoid`.
- Animations from Mixamo: idle, walk, run, jump, fall, land, crouch, crouch-walk, climb up/left/right, ledge grab, mantle, carry idle, carry walk, glide, death. **FBX Binary, Without Skin, 30fps, no keyframe reduction.**
- **He is hooded and masked. His face is never visible. This is permanent and load-bearing.** Cover the head. If the base mesh has a face, it gets a mask over it. Do not ship a visible face.
- Muscular, broad shouldered, heavy silhouette. Salt-stained cloth over dark leather, everything a bit burnt.
- **Test: is he readable as a shape at 200m in fog?** If not, the silhouette is wrong.
- Attachment sockets per ARCHITECTURE §16: `Socket_RightHand`, `Socket_LeftHand`, `Socket_Back`, `Socket_Hip`. `BoneAttachment3D`.
- **Root motion off.**
- **This is a placeholder and will be replaced.** Do not couple anything to this specific mesh. The contract is the interface, not the model.

### M4. Terrain
- **Lanka is approximately 1.2 km² (1100m x 1100m playable).**
- A mesa. Cliffs on all sides except the south, which slopes into tidal flats.
- **Procedural base, authored landmarks.** At this scale you cannot hand-sculpt everything, and you should not try. Generate the base, then hand-author every place the player will actually stand.
- **Streaming is mandatory.** Do not build Lanka as one scene. Chunk it and stream by distance.
- **Hard constraint: the Spine must be visible from every point on the island.** It is the compass. There is no minimap. Sightlines to the Spine dictate terrain.
- LOD everything. Occlusion culling. `VisibleOnScreenNotifier3D` on expensive props.
- **Target: 60 FPS at 1080p on mid-range hardware.**

### M5. The districts
Build them in this order. They are described in ARCHITECTURE §3. Read it.

1. **The Shallows** (south, arrival). Tidal flats, wrecked hulls half-buried in sand, and **the stumps of Setu marching out into the water and vanishing.** That image is the first thing the player sees and it is the whole story in one shot. Safe, open, gentle. Keffer's overturned hull. Setu's build site. The ocean-as-wall: the player must be able to walk into the sea and be killed by it, with no invisible barrier anywhere.
2. **The Terraces** (west). Stepped farmland gone to ash. Dry irrigation channels, collapsed retaining walls. **The climbing gym.** Vertical but forgiving. Every grip class appears here, teaching by consequence. Ashroot grows here.
3. **The Ember Quarter** (center-east). The city proper, still burning in patches. Timber frames, collapsed roofs, **hot updrafts venting from cracks in the streets.** The fire playground. Constant ambient danger. Charwood fruit grows inside the burn: the player must enter the fire to get the thing that lets them survive the fire. Heat volumes stacked vertically, because heat rises.
4. **The Cistern** (below the city). Lanka's water system. **Nearly black.** Dark, flooded, dripping. The only fresh water left. The player's light is a real object they carry. Blind fish. Currents. Buoyancy.
5. **The Spine** (north). The tower. Dominant. Visible from everywhere. The convergence: the route up physically requires an object hauled from the Shallows, an updraft from the Smolder, and a doused surface from the Cistern. **If the player can skip one of those, that is a bug.**
6. **The Dark** (beneath the Spine). Where the drowned are. Separate streamed area, not open world. Terror.

### M6. Content placement
- **Exactly 8 Cairns.** Not 7, not 10. **8 Cairns = 32 heart pieces = 2 containers = Nau leaves Lanka with 5 hearts. This math is exact.**
  - Distribution: 2 Shallows, 2 Terraces, 2 Ember Quarter, 2 Cistern.
  - Each is a **separate scene**, loaded on entry. Not carved into open-world geometry.
  - Single room. One idea. **No new mechanics inside a Cairn.** It tests something a trial already taught.
- **20 crew fragments.** Remains of Nau's men, scattered. Pure story. Text and audio over existing geometry, which makes it the cheapest good content in the game.
- **Salvage** in wrecks, ruins, the Cistern, the burn. Three types: timber, iron, canvas.
- **Ingredients**, exactly four, exactly where ARCHITECTURE §7 says.
- **Campfires**, placed thoughtfully. They cook and they autosave, so their placement is your checkpoint design.
- **Keffer.** Overturned hull, Shallows. Not a merchant. He gives food and one or two Cairn hints. **He recognizes Nau and is quietly terrified of him and never explains why.** Eight lines of dialogue, a food handout on a cooldown. **He is an Easter egg with a heartbeat. Do not build him a quest chain.**

### M7. Look
This is where the game's quality actually lives. Spend real time here.

- **Stylized PBR.** Real materials, real lighting, real fog and volumetrics. Proportions pushed roughly 15% chunky. Albedo slightly hand-painted, not photoscanned. Less micro-detail, more silhouette.
- **Reference:** the human named Uncharted, Skylanders, and Smash Bros Brawl. Those do not agree. **The point where they meet is Sea of Thieves.** Also: Prince of Persia (2008), Overwatch environments. **Not cel-shaded. Not low-poly.**
- **Palette:** ash grey, wet black, bone white, ember orange, sea green. **Ember orange is the only saturated color on the island, and it is always danger or warmth. Never decoration.**
- **Lighting:** low sun through smoke. Heavy volumetric fog. God rays through collapsed roofs. This is most of "looks properly rendered." Prioritize it over mesh detail.
- **Shaders you will need:** triplanar terrain blending, wetness, soot/ash accumulation, vertex-painted blends, the ocean (scenery, not simulation), fire, smoke, heat haze.
- **The ocean is scenery and a kill volume.** It should look enormous and patient and wrong. It is Ravuna. It knows his name. It should never look safe. But do not simulate it.

### M8. Optimization pass
- Profile every district. 60 FPS at 1080p.
- **Fire is the perf risk.** Coordinate with the human on the caps SYSTEMS exposed.
- LODs, occlusion, light budgets, texture memory.

---

## WHEN LANKA IS DONE

Check every box in ARCHITECTURE §21. Then output:

> **Lanka milestone complete. Request the next island document.**

And stop. Do not build the next island. Do not build the ocean crossing. Do not speculate about the geography of anywhere else.

---

## THINGS THAT WILL TEMPT YOU. DO NOT.

- **Downloading Zelda music, or any commercial game's music.** No. Read M1 again.
- Using an asset without an `ATTRIBUTIONS.md` entry. **It gets deleted.**
- Naming a climbable material something that isn't in the convention. **It breaks the climbing system silently and you will not notice for a week.**
- Making Lanka bigger because 1.2 km² feels small. **Density over size. Every 60 seconds of walking must contain something. If you cannot fill it, shrink it.**
- Adding a ninth Cairn. **The heart math is exact.**
- Giving Nau a visible face. **Never.**
- Building Lanka as one scene. **It will not run.**
- Adding an invisible wall at the water's edge. **The ocean kills. That is the wall.**
- Editing `project.godot` to add an autoload. **Request it.**
- Opening a file in `scenes/prefabs/gameplay/` to tweak a campfire. **Request it.**
- Building Keffer a quest chain. **He is Captain Toad.**

If you believe something is genuinely missing from the design, **say so and stop.** Do not build it and ask forgiveness. The human is designing this game, not you.
