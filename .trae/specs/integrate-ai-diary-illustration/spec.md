# AI Diary Illustration Integration Spec

## Why
To enhance the user experience by automatically generating visually appealing, personalized illustrations for each diary entry, utilizing AI image generation (ChatGPT Image2) with a specific, consistent art style.

## What Changes
- Add a new prompt template `diary_illustration.txt` for generating image prompts.
- Create an Image Generation Client (e.g., `openai_image_client.gd`) to handle API calls to OpenAI's image generation endpoint.
- Modify the existing diary generation workflow to trigger image generation after the text is generated, respecting a new enable/disable toggle.
- Implement a robust retry mechanism (up to 3 times) with fallback to a placeholder image.
- Update the system settings UI to include a "ChatGPT Image2 API Key" input and an "Enable AI Illustration" toggle.
- Update the configuration data structure to securely store the new API key and toggle state.
- Update the diary database schema/logic to save the generated image URL, generation duration, prompt, and model version.
- Create unit and integration tests for the image generation workflow.

## Impact
- Affected specs: Diary Generation, System Settings, Data Persistence.
- Affected code:
  - `scripts/data/game_data_manager.gd` (config and history/database updates)
  - `scenes/ui/settings/settings_scene.tscn` & `.gd`
  - New file: `scripts/templates/prompts/diary_illustration.txt`
  - New file: `scripts/api/openai_image_client.gd`
  - Test files in a new or existing test directory.

## ADDED Requirements
### Requirement: AI Diary Illustration
The system SHALL automatically generate a 1024x1024 PNG illustration for new diary entries if the feature is enabled.
#### Scenario: Success case
- **WHEN** a diary entry is successfully generated and the AI illustration toggle is ON
- **THEN** the system requests an image using the OpenAI Image API, saves it to `user://diary_images/YYYY-MM-DD/diary_{diaryId}_{timestamp}.png`, and records the metadata in the database.

### Requirement: Art Style Enforcement
The system SHALL enforce a specific art style (Japanese healing flat illustration, soft rounded lines, macaron warm tones, no hard shadows, soft light diffusion, retro paper grain texture, slight noise texture, fairy tale style, low saturation) by appending these constraints to the prompt via the template.

### Requirement: Settings and API Key Management
The system SHALL allow users to configure the ChatGPT Image2 API Key and toggle the feature on/off in the settings UI.

### Requirement: Fault Tolerance
The system SHALL retry failed image generation requests up to 3 times. If all retries fail, it SHALL use a default placeholder image.

## MODIFIED Requirements
### Requirement: Diary Database Schema
The diary data structure SHALL include `image_url`, `image_generation_time`, `image_prompt`, and `image_model_version`.
