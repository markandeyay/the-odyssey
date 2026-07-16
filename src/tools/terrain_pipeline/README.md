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
