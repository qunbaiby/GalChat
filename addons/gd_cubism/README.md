# GDCubism runtime package

This directory contains a project-local GDCubism v0.9.1 runtime package built
with Cubism SDK for Native 5-r.5.

## Supported package target

- Godot 4.3 or newer; validated by this project with Godot 4.6.3 Mono.
- Windows x86_64, single-precision Godot builds.
- GDScript is supported directly. The `cs` directory provides optional C#
  wrappers for Godot .NET projects.

The `.gdextension` file intentionally declares only the Windows x86_64
binaries present in this package. Do not claim support for Linux, macOS,
Android, iOS, or Web until their matching binaries and export dependencies
have been added and tested.

## Copying to another project

Copy the complete `addons/gd_cubism` directory without changing its relative
layout. At minimum, keep these runtime files:

- `gd_cubism.gdextension`
- `bin/libgd_cubism.windows.debug.x86_64.dll`
- `bin/libgd_cubism.windows.release.x86_64.dll`
- `bin/Live2DCubismCore.dll`
- `res/`
- `LICENSE.md`

Keep `cs/` when the target project uses the C# wrappers. The `example/`
directory is optional.

No `plugin.cfg` activation is required. Godot discovers the GDExtension from
`gd_cubism.gdextension`.

## Export safety

`gd_cubism.gdextension` declares `Live2DCubismCore.dll` in its Windows
`[dependencies]` section. Godot therefore exports the Core DLL next to the
game executable. The selected GDCubism debug or release DLL is exported by the
`[libraries]` section.

Live2D model manifests, moc files, motions, expressions, and prompt templates
are loaded from string paths at runtime. The host project's Windows export
preset must include `assets/live2d/**/*` and any equivalent runtime data paths;
scene dependency scanning alone is not sufficient.

Run the workspace task `Validate GDCubism Windows Export` before publishing a
Windows build. It performs an isolated release export and verifies that the
native extension and Core DLL are present and that the exported executable can
start.

## Rebuilding

The committed DLLs include compatibility changes made while building
GDCubism v0.9.1 against Cubism SDK for Native 5-r.5. The patched native source
is not included in this runtime package. Preserve these DLLs unless you have
the upstream source, the matching Cubism SDK, and a reproducible replacement
build.

See `docs/gd_cubism_setup_notes.md` in the host repository for project-specific
details.