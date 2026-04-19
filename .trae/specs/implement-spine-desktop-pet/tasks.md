# Tasks

- [x] Task 1: Install spine-godot GDExtension: Download the official `spine-godot` GDExtension zip for Godot 4.x, extract the `bin/` folder to the project root, and ensure the `.gdextension` file is correctly recognized by Godot.
  - [x] SubTask 1.1: Fetch the GDExtension zip from Esoteric Software's official source (e.g., via a Python script or cURL).
  - [x] SubTask 1.2: Extract the zip to the project's `bin/` folder.

- [x] Task 2: Configure Spine Resources: Setup the `SpineAtlasResource` and `SpineSkeletonFileResource` for the `xuyuan` asset.
  - [x] SubTask 2.1: Ensure Godot imports `100001_hugen_xuyuan.atlas`, `.skel`, and `.png` correctly after restarting the editor or refreshing resources.
  - [x] SubTask 2.2: Create a `.tres` file for the `SpineSkeletonDataResource` linking the `.skel` and `.atlas`.

- [x] Task 3: Update `desktop_pet.tscn`: Replace the static image with the Spine animation node.
  - [x] SubTask 3.1: Open `desktop_pet.tscn`. Replace `TextureRect` ("PetImage") with a `Control` node ("PetContainer") that has `size_flags_vertical = 3` and `size_flags_stretch_ratio = 1.5`.
  - [x] SubTask 3.2: Add a `SpineSprite` node as a child of "PetContainer" and set its `skeleton_data_res` to the resource created in Task 2.
  - [x] SubTask 3.3: Adjust the `SpineSprite` position/scale to fit within the `PetContainer`.

- [x] Task 4: Update `desktop_pet.gd`: Add logic to play the default animation.
  - [x] SubTask 4.1: Retrieve the `SpineSprite` reference in `_ready()`.
  - [x] SubTask 4.2: Add logic to play a default looping animation (e.g., "idle" or the first available animation).

# Task Dependencies
- Task 2 depends on Task 1
- Task 3 depends on Task 2
- Task 4 depends on Task 3
