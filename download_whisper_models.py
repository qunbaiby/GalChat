import urllib.request
import os
import sys
import time

def reporthook(count, block_size, total_size):
    global start_time
    if count == 0:
        start_time = time.time()
        return
    duration = time.time() - start_time
    progress_size = count * block_size
    if duration > 0:
        speed = progress_size / (1024 * 1024 * duration)
    else:
        speed = 0
    
    if total_size > 0:
        percent = min(int(progress_size * 100 / total_size), 100)
        sys.stdout.write(f"\rDownloading... {percent}% - {progress_size / (1024*1024):.1f} MB / {total_size / (1024*1024):.1f} MB ({speed:.1f} MB/s)")
    else:
        sys.stdout.write(f"\rDownloading... {progress_size / (1024*1024):.1f} MB ({speed:.1f} MB/s)")
    sys.stdout.flush()

def download_model(url, filename):
    print(f"\n[INFO] Start downloading: {filename}")
    try:
        urllib.request.urlretrieve(url, filename, reporthook)
        print(f"\n[SUCCESS] Successfully downloaded: {filename}")
    except Exception as e:
        print(f"\n[ERROR] Failed to download {filename}: {e}")

target_dir = r"f:\GODOT游戏模板\aigame\gal-chat\addons\godot_whisper\models"
os.makedirs(target_dir, exist_ok=True)

# Use HF-Mirror to accelerate download in mainland China
base_url = "https://hf-mirror.com/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"
large_v3_url = "https://hf-mirror.com/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin"

# Download base model (small, fast ~140MB)
download_model(base_url, os.path.join(target_dir, "ggml-base.bin"))

# Download large-v3 model (very large ~3GB)
print("\n[NOTE] Starting to download the Large V3 model. This file is about 3.1 GB and might take a long time.")
download_model(large_v3_url, os.path.join(target_dir, "ggml-large-v3.bin"))
