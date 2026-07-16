# Nau M3 Character Pipeline

This pipeline keeps Nau's replaceable visual separate from the SYSTEMS-owned
player scene. The runtime contract is `res://assets/characters/nau/nau_visual.tscn`;
the FBX files below are editable source inputs, not hardcoded gameplay dependencies.

## Mixamo downloads

Download from Adobe Mixamo using the filenames in `mixamo_manifest.json`.

1. Select a muscular, broad-shouldered humanoid. Download the T-pose as **FBX
   Binary**, **With Skin**, at **30 FPS**, with **no keyframe reduction**. Rename
   it to `nau_base.fbx`.
2. Download all 17 animations as **FBX Binary**, **Without Skin**, **30 FPS**,
   **no keyframe reduction**, and **In Place**. Rename each file to its manifest
   filename. Do not approximate a missing clip by silently duplicating another.
3. Place the base at
   `assets/characters/nau/source/mixamo/base/nau_base.fbx` and animations at
   `assets/characters/nau/source/mixamo/animations/`.
4. Add the selected character and animations to `docs/ATTRIBUTIONS.md` before
   committing any FBX. Record Adobe Mixamo as the source and link its current
   usage terms. An unattributed file must be deleted.

## Godot 4.6 import

Use ufbx. In Advanced Import Settings, assign a `BoneMap` using
`SkeletonProfileHumanoid`. The ready-to-assign resource is
`mixamo_humanoid_bone_map.tres`; its mappings are generated from the manifest.
Apply the same map to the base and every animation. Rename mapped bones and make
the Skeleton node unique as `NauSkeleton`; remove non-bone,
unimportant-position, and unmapped tracks from animation-library imports;
normalize position tracks; and overwrite axes. The base must remain a T-pose,
so silhouette fixing is not expected.

Set animation baking to 30 FPS. Locomotion remains code-driven: no clip may
contain horizontal root displacement. Preserve source `.import` files because
they contain the retarget settings. Disable animation import on the T-pose base;
enable it on each animation FBX.

The assembled visual must:

- be `1.9m +/- 0.15m` tall,
- contain one humanoid `Skeleton3D`,
- expose the four exact `BoneAttachment3D` socket names in the manifest,
- use named material resources rather than surface indices,
- contain visible `NauHood` and `NauMask` geometry that fully covers the face,
- expose all 17 canonical animation names, and
- remain legible as a broad, heavy silhouette in the 200m Lanka fog test.

Open `nau_silhouette_preview.tscn` to perform the fog test. Its camera defaults
to 200m with an 8-degree telephoto inspection FOV and the inspector can reduce
the distance for diagnosis; acceptance is always judged at 200m. Distances
below 100m use a 22.5-degree FOV for close material and face-cover inspection.

Run the source-independent contract tests with:

```powershell
godot --headless --path . --script res://src/tools/character_pipeline/tests/test_character_pipeline.gd
```

After the attributed FBX inputs and assembled visual exist, run the strict gate:

```powershell
godot --headless --path . --script res://src/tools/character_pipeline/validate_nau_character.gd
```
