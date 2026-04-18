# Tasks
- [x] Task 1: Fix narrator generation prompt to use dynamic character names.
  - [x] SubTask 1.1: Edit `scripts/templates/prompts/narrator_generation.txt` to replace "Luna" with `{{char_name}}`.
  - [x] SubTask 1.2: Ensure `prompt_manager.gd` handles the replacement correctly.
- [x] Task 2: Fix save migration logic to ensure per-character separation.
  - [x] SubTask 2.1: Edit `scripts/data/character_profile.gd`'s migration logic to rename the old `user://character_profile.json` after copy.
  - [x] SubTask 2.2: Edit `scripts/data/memory_manager.gd`'s migration logic to rename the old `user://player_memory.json` after copy.
- [x] Task 3: Create the new Archive Panel.
  - [x] SubTask 3.1: Create `scenes/ui/archive/archive_panel.tscn` and `scripts/ui/archive/archive_panel.gd`.
  - [x] SubTask 3.2: Implement character selection (e.g., OptionButton or TabBar) to load specific character data without modifying `GameDataManager.profile`.
  - [x] SubTask 3.3: Implement the "Personality Evolution" (性格演化) tab showing base personality vs current personality (ProgressBars or Labels).
  - [x] SubTask 3.4: Implement the "Memory Archive" (记忆库) tab showing core, emotion, habit, and bond memories.
- [x] Task 4: Integrate Archive Panel into the game.
  - [x] SubTask 4.1: Add "档案库" (Archive) button to `scenes/ui/main/main_scene.tscn` TopBar.
  - [x] SubTask 4.2: Connect the button in `scripts/ui/main/main_scene.gd` to show the `archive_panel.tscn`.
- [x] Task 5: Remove memory management from Debug Panel.
  - [x] SubTask 5.1: Edit `scenes/ui/chat/debug_panel.tscn` to remove the "记忆管理" tab.
  - [x] SubTask 5.2: Edit `scripts/ui/chat/debug_panel.gd` to remove related code.

# Task Dependencies
- [Task 3] depends on [Task 2]
- [Task 4] depends on [Task 3]
- [Task 5] can be done in parallel.
