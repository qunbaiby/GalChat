import re

def check_file(path):
    try:
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
            lines = content.split('\n')
            for i, line in enumerate(lines):
                if line.startswith('[') and not line.endswith(']'):
                    print(f"Line {i+1}: Unclosed bracket -> {line}")
                if line.count('"') % 2 != 0:
                    print(f"Line {i+1}: Unclosed quote -> {line}")
        print("Check completed.")
    except Exception as e:
        print(f"Error reading file: {e}")

check_file('f:/GODOT游戏模板/aigame/gal-chat/scenes/ui/desktop_pet/desktop_pet.tscn')
