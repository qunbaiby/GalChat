# Tasks
- [x] Task 1: Configuration & Settings UI
  - [x] SubTask 1.1: Add `openai_image_api_key` and `enable_ai_diary_illustration` to the global configuration data structure (`GameDataManager.config`).
  - [x] SubTask 1.2: Update `settings_scene.tscn` and its script to include the new API key input (with masking/encryption logic matching others) and the enable toggle.
- [x] Task 2: Prompt Template
  - [x] SubTask 2.1: Create `scripts/templates/prompts/diary_illustration.txt` with instructions to extract English keywords and enforce the strict art style (Japanese healing, macaron tones, retro paper, etc.).
- [x] Task 3: Image Generation Client
  - [x] SubTask 3.1: Create `scripts/api/openai_image_client.gd` to interface with OpenAI DALL-E 2 (Image2) API.
  - [x] SubTask 3.2: Implement the 3-retry logic for network errors, empty returns, or formatting issues.
  - [x] SubTask 3.3: Implement image downloading, compression (ensure <2MB), and saving to `user://diary_images/YYYY-MM-DD/diary_{diaryId}_{timestamp}.png`.
- [x] Task 4: Diary Generation Integration
  - [x] SubTask 4.1: Modify the diary generation workflow to call the Image Generation Client if the feature is enabled.
  - [x] SubTask 4.2: Update the diary entry data model to store `image_url`, `generation_duration`, `image_prompt`, and `model_version`.
  - [x] SubTask 4.3: Handle the fallback logic to assign a default placeholder image if generation fails.
- [x] Task 5: Testing
  - [x] SubTask 5.1: Write unit tests for the prompt generation and image client retry logic.
  - [x] SubTask 5.2: Write integration tests covering success, invalid key, sensitive content, timeout, and retry exhaustion.

# Task Dependencies
- Task 3 depends on Task 1 and Task 2.
- Task 4 depends on Task 3.
- Task 5 depends on Task 3 and Task 4.