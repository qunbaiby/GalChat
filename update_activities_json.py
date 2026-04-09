import json

path = "e:\\GalChat_APP\\assets\\data\\interaction\\activity\\activities.json"

with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

for act in data.get("activities", []):
    if "icon_path" in act:
        # Generate a placeholder preview image based on icon_path
        act["preview_image"] = act["icon_path"].replace("icons", "images").replace(".tres", ".png")
        # Ensure fallback
        if not act["preview_image"]:
             act["preview_image"] = ""
             
for act in data.get("rest_activities", []):
    if "icon_path" in act:
        # Generate a placeholder preview image based on icon_path
        act["preview_image"] = act["icon_path"].replace("icons", "images").replace(".tres", ".png")

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
