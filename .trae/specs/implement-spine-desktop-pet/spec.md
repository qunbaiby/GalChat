# Implement Spine Desktop Pet Spec

## Why
The current desktop pet uses a static image (`Q_desktop.png`). The user wants to replace this with a dynamic, interactive Spine animation to make the pet more lively and engaging. We will integrate the provided Spine asset (`e:\GalChat_APP\assets\spine\xuyuan`) into the desktop pet scene.

## What Changes
- **Install Spine-Godot Runtime**: Download and install the official `spine-godot` GDExtension into the project to support Spine animations without requiring a custom engine build.
- **Import Spine Assets**: Configure the Spine resources (Atlas and Skeleton Data) for the `xuyuan` asset.
- **Update Scene**: Modify `desktop_pet.tscn` to replace the `TextureRect` (`PetImage`) with a `SpineSprite` node (nested in a `Control` container to maintain UI layout).
- **Update Script**: Modify `desktop_pet.gd` to initialize the `SpineSprite` and play the default animation (e.g., "idle").

## Impact
- Affected specs: Desktop Pet Visuals
- Affected code:
  - `scenes/ui/desktop_pet/desktop_pet.tscn`
  - `scripts/ui/desktop_pet/desktop_pet.gd`
  - `project.godot` (will register the GDExtension)

## ADDED Requirements
### Requirement: Spine Animation Support
The system SHALL render a Spine animation for the desktop pet instead of a static image.

#### Scenario: Success case
- **WHEN** the desktop pet window is launched
- **THEN** the pet renders using the `xuyuan` Spine asset and plays its default animation loop.

## MODIFIED Requirements
### Requirement: Pet UI Layout
The pet's visual node MUST integrate correctly within the existing `VBoxContainer` UI layout. Since `SpineSprite` is a `Node2D`, it MUST be wrapped in a `Control` node with appropriate sizing flags to act as a placeholder.
