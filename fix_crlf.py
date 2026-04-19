with open('f:/GODOT游戏模板/aigame/gal-chat/scenes/ui/desktop_pet/pet_body.tscn', 'rb') as f:
    content = f.read()
content = content.replace(b'\r\n', b'\n').replace(b'\r', b'\n').replace(b'\n', b'\r\n')
with open('f:/GODOT游戏模板/aigame/gal-chat/scenes/ui/desktop_pet/pet_body.tscn', 'wb') as f:
    f.write(content)
