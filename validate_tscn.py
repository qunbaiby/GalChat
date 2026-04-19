import sys

def validate_tscn(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    errors = []
    
    # Check quotes
    lines = content.split('\n')
    for i, line in enumerate(lines):
        if line.count('"') % 2 != 0:
            errors.append(f"Line {i+1}: Unbalanced quotes -> {line}")
        if line.startswith('[') and not line.endswith(']'):
            errors.append(f"Line {i+1}: Unclosed bracket -> {line}")
            
    if errors:
        for err in errors:
            print(err)
        return False
    else:
        print("Basic TSCN syntax seems OK.")
        return True

if not validate_tscn('f:/GODOT游戏模板/aigame/gal-chat/scenes/ui/desktop_pet/desktop_pet.tscn'):
    sys.exit(1)
