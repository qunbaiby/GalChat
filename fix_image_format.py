import os
from PIL import Image

IMG_DIR = r"e:\GalChat\GalChat\assets\images\activities"

print(f"Checking images in {IMG_DIR}...")
for filename in os.listdir(IMG_DIR):
    if filename.endswith(".png"):
        filepath = os.path.join(IMG_DIR, filename)
        try:
            with Image.open(filepath) as img:
                print(f"{filename}: format={img.format}, size={img.size}, mode={img.mode}")
                # Convert and save to ensure it's a standard PNG
                img.convert('RGB').save(filepath, "PNG")
                print(f"  -> Re-saved {filename} as standard RGB PNG.")
        except Exception as e:
            print(f"Error processing {filename}: {e}")
            
print("Done!")
