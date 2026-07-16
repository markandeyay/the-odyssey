# Odyssey Asset Pipeline

This M1 toolchain imports legal CC0 PBR materials and applies portable Godot
import policy without changing `project.godot`.

## Material acquisition

Run the pipeline with Godot 4.6.1:

```powershell
Godot_v4.6.1-stable_win64_console.exe --headless --path . `
  --script src/tools/asset_pipeline/material_pipeline.gd -- `
  --provider=poly_haven --asset=aerial_rocks_04 --resolution=2k --grip=solid
```

Supported providers are `poly_haven` and `ambient_cg`. Resolution may be `1k`,
`2k`, or `4k`; grip must be `solid`, `crumbling`, `slick`, or `hot`.

The pipeline:

1. Fetches provider metadata using an identifying user agent.
2. Accepts only a provider manifest explicitly marked `CC0`.
3. Stages downloads outside `res://` and validates hashes when supplied.
4. Installs normalized PBR maps under `assets/materials/library/`.
5. Builds a grip-compliant `StandardMaterial3D` resource.
6. Appends a complete entry to `docs/ATTRIBUTIONS.md`.

An existing asset directory is never overwritten. Remove an obsolete asset and
its attribution entry deliberately before replacing it.

Poly Haven's assets are CC0, but its live API has separate usage terms. Confirm
that the project's use of the API complies with those terms before using it for
commercial-scale or bulk acquisition. ambientCG downloads are also restricted
to explicitly CC0 material records by this tool.

## Import policy

Godot creates a `.import` sidecar when it first sees a source asset. Apply the
portable Odyssey defaults after that initial scan:

```powershell
Godot_v4.6.1-stable_win64_console.exe --headless --path . `
  --script src/tools/asset_pipeline/apply_import_presets.gd
```

The script updates only sidecars adjacent to WORLD-owned source assets. It
enables mesh LODs, tangents, shadow meshes, texture mipmaps, VRAM compression,
and normal-map detection. It also assigns the scene post-import hook.

Optional per-model settings live beside the model as
`<model_filename>.odyssey_import.cfg`:

```ini
[scale]
source_units_per_meter=1.0
expected_height_m=0.0

[collision]
mode="trimesh"
```

`source_units_per_meter` enforces the project contract of one Godot unit per
meter. `expected_height_m` enables an additional size check; Nau's future
placeholder profile should set it to `1.9`. Collision mode is `none`, `trimesh`,
or `convex`. Collision generation is opt-in because blindly colliding every mesh
would create expensive and incorrect shapes.

Godot ignores unknown source files, so the `.odyssey_import.cfg` profile is safe
to keep beside its model. Reimport the model after changing its profile.
