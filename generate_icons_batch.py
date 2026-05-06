import os
import json
import urllib.request
import urllib.error

API_KEY = "ark-bc0f996a-e450-4b0e-9715-22dc0b07f3a6-03ba8"
API_URL = "https://ark.cn-beijing.volces.com/api/v3/images/generations"
MODEL = "doubao-seedream-5-0-260128"
SIZE = "2K"

# Path to json and images
JSON_PATH = r"e:\GalChat\GalChat\assets\data\interaction\activity\activities.json"
IMG_DIR = r"e:\GalChat\GalChat\assets\images\activities"

os.makedirs(IMG_DIR, exist_ok=True)

def generate_image(prompt, filename):
    print(f"[*] Generating image for: {prompt}")
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {API_KEY}"
    }
    data = {
        "model": MODEL,
        "prompt": prompt,
        "response_format": "url",
        "size": SIZE
    }
    req = urllib.request.Request(API_URL, data=json.dumps(data).encode('utf-8'), headers=headers, method='POST')
    try:
        with urllib.request.urlopen(req, timeout=120) as response:
            result = json.loads(response.read().decode('utf-8'))
            image_url = result['data'][0]['url']
            
            # Download the actual image
            img_req = urllib.request.Request(image_url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(img_req, timeout=120) as img_res:
                with open(filename, 'wb') as f:
                    f.write(img_res.read())
                    
            print(f"[+] Saved to {filename}")
            return True
    except urllib.error.HTTPError as e:
        error_info = e.read().decode('utf-8')
        print(f"[-] API Error: {error_info}")
        return False
    except Exception as e:
        print(f"[-] Failed for prompt '{prompt}': {e}")
        return False

with open(JSON_PATH, 'r', encoding='utf-8') as f:
    data = json.load(f)
    
def process_list(act_list):
    for act in act_list:
        act_id = act['id']
        act_name = act['name']
        filename = os.path.join(IMG_DIR, f"{act_id}.png")
        prompt = f"A minimalist flat vector icon for a university activity named '{act_name}'. Design style: a simple, colorful object placed in the center of a solid bright circular background with a subtle drop shadow underneath the object. Flat design, no outlines, clean vector art style, educational theme, solid beige or off-white background behind the circle, no text."
        if generate_image(prompt, filename):
            act['preview_image'] = f"res://assets/images/activities/{act_id}.png"
            act['icon_path'] = f"res://assets/images/activities/{act_id}.png"

print("Starting generation...")
process_list(data['activities'])
process_list(data['rest_activities'])

with open(JSON_PATH, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    
print("All done!")
