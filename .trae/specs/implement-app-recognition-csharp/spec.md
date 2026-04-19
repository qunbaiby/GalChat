# Implement App Recognition via C# EnumWindows Spec

## Why
The previous implementations for recognizing the active application failed reliably (often returning empty strings or getting stuck on the desktop pet's own window due to transparent click-through issues). We need a robust, native Windows solution based on the provided PDF guide using C# P/Invoke with `EnumWindows` to reliably identify what application the user is currently using, enabling the desktop pet to interact proactively.

## What Changes
- Restore C# (.NET) support to the Godot project (`project.godot`, `.csproj`, `.sln`).
- Create a `WindowDetector.cs` script using `user32.dll` APIs (`EnumWindows`, `IsWindowVisible`, `GetWindowText`, `GetWindowThreadProcessId`).
- Implement logic to find the top-most valid external application window (filtering out Godot's PID and system windows like "Program Manager").
- Integrate `WindowDetector` into `desktop_pet.gd`.
- Re-implement the proactive chat logic: when the user focuses on an external app for a set duration, the pet makes a character-appropriate comment about it.

## Impact
- Affected specs: App Recognition, Proactive Chat
- Affected code: 
  - `project.godot`
  - `GalChat.csproj` / `GalChat.sln`
  - `scripts/csharp/WindowDetector.cs` (new)
  - `scripts/ui/desktop_pet/desktop_pet.gd` (modified)

## ADDED Requirements
### Requirement: Reliable Active Window Detection
The system SHALL use `EnumWindows` to scan top-level windows in Z-order and identify the active user application, ignoring the Godot process and hidden system windows.

#### Scenario: Success case
- **WHEN** the user switches to an external application (e.g., Chrome) and stays for a specified time.
- **THEN** the pet detects the application, categorizes it (e.g., "Web Browser"), and triggers a proactive chat prompt.

## MODIFIED Requirements
### Requirement: Proactive Chat Trigger
The proactive chat timer SHALL reset upon window change and trigger a character-specific response after a continuous focus duration.
