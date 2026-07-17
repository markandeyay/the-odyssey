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

The profiler forces a 1920 by 1080 Forward+ output with VSync and the frame cap disabled, warms each district, then writes frame-time, draw, primitive, texture-memory, buffer-memory, and video-memory results under `res://.godot/review/m8/`. Pass a district id such as `ember_quarter` for an isolated run or `reverse` to expose order-dependent behavior. Native rendering is the default; `scale_85` verifies the requested integrated 1080p bilinear quality tier, while `scale_85 fsr` remains available as a diagnostic.

Final 85 percent bilinear results on Intel Graphics using D3D12 Forward+, after 1,200 warmup frames and 240 measured frames per isolated district:

| District | Average ms | P95 ms | Average FPS | Max draws |
|---|---:|---:|---:|---:|
| Shallows | 8.237 | 8.945 | 121.4 | 17 |
| Terraces | 16.099 | 17.588 | 62.1 | 22 |
| Ember Quarter | 15.667 | 16.981 | 63.8 | 23 |
| Cistern | 13.209 | 14.511 | 75.7 | 20 |
| Spine | 13.433 | 14.584 | 74.4 | 18 |
| Dark | 12.730 | 13.621 | 78.6 | 4 |

Peak texture memory was 153,780,224 bytes against a 192 MiB cap. Peak video memory was 278,855,680 bytes against a 384 MiB cap. The unoptimized sustained Ember baseline was 24.287 ms, 41.2 FPS, and 652 draws.
