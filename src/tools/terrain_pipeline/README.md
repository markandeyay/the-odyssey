# Lanka Terrain Pipeline

M4 builds Lanka as a deterministic 1100 m by 1100 m height field split into a 5 by 5 grid of 220 m stream chunks. The production scene, `res://scenes/levels/lanka/lanka.tscn`, starts with no terrain resident. Its streaming script requests nearby chunk scenes asynchronously and keeps the Spine blockout loaded as the island-wide navigation landmark.

Generate the owned terrain scenes after changing the height model or contract:

```powershell
godot --headless --path . --script res://src/tools/terrain_pipeline/build_lanka_terrain.gd
```

Run the M4 checks:

```powershell
godot --headless --path . --script res://src/tools/terrain_pipeline/tests/test_height_model.gd
godot --headless --path . --script res://src/tools/terrain_pipeline/validate_lanka_terrain.gd
godot --headless --path . --script res://src/tools/terrain_pipeline/tests/test_streaming.gd
```

`capture_lanka_blockout.gd` is a review harness. It loads every chunk only for a full-island image and is not part of the runtime level.

## M5 Districts

District scenes are generated independently so they remain reviewable and streamable. Run all six in the required build order:

```powershell
godot --headless --path . --script res://src/tools/terrain_pipeline/build_lanka_districts.gd
godot --headless --path . --script res://src/tools/terrain_pipeline/build_lanka_terrain.gd -- root_only
```

The four open-world district scenes stream separately from terrain. The full Spine is the only persistent district landmark. The Dark is excluded from open-world selection and must be loaded as a separate area by the SYSTEMS level host.

```powershell
godot --headless --path . --script res://src/tools/terrain_pipeline/validate_lanka_districts.gd
godot --headless --path . --script res://src/tools/terrain_pipeline/tests/test_district_streaming.gd
```

## M6 Content

M6 placement is generated into the six district scenes from one exact-count contract. Cairns remain separate scenes under `res://scenes/levels/cairns/`.

```powershell
godot --headless --path . --script res://src/tools/terrain_pipeline/build_lanka_districts.gd
godot --headless --path . --script res://src/tools/terrain_pipeline/build_lanka_content.gd
godot --headless --path . --script res://src/tools/terrain_pipeline/validate_lanka_content.gd
```

The content validator rejects extra Cairn scenes, incorrect heart-piece math, duplicate crew IDs, uncontracted ingredient or salvage types, and invalid Keffer merchant/dialogue state.

## M7 Visual System

M7 uses generated, shared visual resources so terrain, districts, Cairns, and persistent scenery remain reproducible. Build the persistent look and fire visual before rebuilding dependent scenes:

```powershell
godot --headless --path . --script res://src/tools/terrain_pipeline/build_lanka_look.gd
godot --headless --path . --script res://src/tools/terrain_pipeline/build_lanka_districts.gd
godot --headless --path . --script res://src/tools/terrain_pipeline/build_lanka_content.gd
godot --headless --path . --script res://src/tools/terrain_pipeline/build_lanka_terrain.gd
godot --headless --path . --script res://src/tools/terrain_pipeline/validate_lanka_visuals.gd
```

The persistent look owns only rendering: low sun, depth and volumetric fog, ocean scenery, and generated visual-only fire/smoke/heat nodes. Fire behavior remains SYSTEMS-owned. `capture_lanka_m7.gd` renders the production look for the full island and all six Lanka districts.

## M8 Performance

District generation retains individual collision bodies and hidden source meshes for grip-material queries, while repeated box and cylinder rendering is grouped into material-local `MultiMeshInstance3D` batches. Terrain retains two render LODs. Fire planes use hard visibility ranges, local lights do not cast shadows, and the low sun uses two shadow splits over a 460 m fog-limited range.

```powershell
godot --headless --path . --script res://src/tools/terrain_pipeline/validate_lanka_performance.gd
godot --path . --script res://src/tools/terrain_pipeline/profile_lanka_m8.gd -- sustained optimized
```

The profiler forces a native-scale 1920 by 1080 Forward+ output with VSync and the frame cap disabled, warms each district, then writes frame-time, draw, primitive, texture-memory, buffer-memory, and video-memory results under `res://.godot/review/m8/`. Pass a district id such as `ember_quarter` for an isolated run or `reverse` to expose order-dependent behavior. Ember Quarter and Cistern are profiled independently, matching their mutually exclusive vertical streaming boundary.

The §19 contract is native 1080p at render scale 1.0: the reference RTX 3060 target is a 60 FPS average with 1 percent lows above 45 FPS, while the Iris Xe development floor permits no frame above 33 ms. Render scale is a user setting and is never used to make either target pass.

Profile a real shipped-scene Ember-to-Cistern streaming transition separately from the steady-state harness:

```powershell
godot --path . --script res://src/tools/terrain_pipeline/profile_lanka_streaming.gd
```

## M9 Shipped-Scene Integration

The integration smoke test starts the real `lanka.tscn`, keeps its instanced Nau
as the streaming target, visits each open-world district through normal runtime
streaming, and loads the real separate Dark scene. It fails if any required
gameplay prefab is absent or inactive, or if the 20 placed fragments do not have
matching authored `FragmentDef` resources.

```powershell
godot --headless --path . --script res://src/tools/terrain_pipeline/tests/test_lanka_runtime.gd
```
