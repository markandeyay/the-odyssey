# Odyssey World Tools

WORLD-owned Godot 4.6.1 editor tooling for authoring Lanka.

## Activation

The plugin is declared by `plugin.cfg`. Enabling it requires the open SYSTEMS
request in `docs/INTERFACES.md` because `project.godot` is SYSTEMS-owned.

## Scatter

Add an `OdysseyScatter3D`, assign one or more WORLD-owned prop scenes, and set
density, bounds, slope, altitude, scale, and collision-mask constraints. Rebuild
creates deterministic `MultiMeshInstance3D` children, grouped by source mesh.
Generated nodes carry `odyssey_scatter_generated` metadata and can be cleared
without affecting authored children.

Prop scenes are visual dressing only. The scatter tool uses the first
`MeshInstance3D` found in each source scene and does not reproduce gameplay
logic or collision from that scene.

## Terrain

Add an `OdysseyTerrain3D`, choose its odd grid resolution and meter dimensions,
then rebuild a flat terrain or import a PNG/EXR/HDR heightmap. Height samples are
stored in the scene as `PackedFloat32Array`, so 3D-view sculpt edits are authored
data rather than changes to imported source images.

The generated collision is on fixed physics layer 1 (`world`). Terrain is not
placed on layer 3 (`climbable`) automatically; climbable cliff meshes must obey
the grip material contract independently.

The included shader blends low, high, and steep albedo layers using world-space
triplanar projection, altitude, and slope.

## Budgets and validation

The dock can analyze the currently edited scene against profiles in
`src/tools/world_tooling/scene_budgets.cfg`. CI/headless validation uses:

```powershell
Godot_v4.6.1-stable_win64_console.exe --headless --path . `
  --script src/tools/world_tooling/validate_world_assets.gd
```

The headless test scene uses:

```powershell
Godot_v4.6.1-stable_win64_console.exe --headless --path . `
  scenes/test/world_tooling_test.tscn
```
