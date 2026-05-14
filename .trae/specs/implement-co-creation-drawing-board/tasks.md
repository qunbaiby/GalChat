# Tasks
- [x] Task 1: Create Drawing Board UI (`drawing_board_panel.tscn` and `.gd`)
  - [x] SubTask 1.1: Implement Line2D based drawing mechanism (mouse down/drag to draw lines).
  - [x] SubTask 1.2: Implement `SubViewport` to capture the drawing area and export to Base64 image.
  - [x] SubTask 1.3: Add UI buttons for "清空画板" (Clear) and "指导 Luna" (Guide Luna).
- [x] Task 2: Implement Image-to-Image API Request
  - [x] SubTask 2.1: In `deepseek_client.gd`, add `send_image_to_image_request(base64_image, prompt)`.
  - [x] SubTask 2.2: Parse the response to extract the image URL or Base64, download it, and emit a success signal.
- [x] Task 3: Integrate with Game Flow
  - [x] SubTask 3.1: Add a "共创画板" (Co-Create) button in `main_scene.tscn` or `desktop_pet.tscn`.
  - [x] SubTask 3.2: Connect the Drawing Board's submit action to the API request, showing a loading state ("Luna正在认真画画...").
  - [x] SubTask 3.3: On completion, display the final image and Luna's dialogue feedback.

# Task Dependencies
- [Task 3] depends on [Task 1] and [Task 2]
