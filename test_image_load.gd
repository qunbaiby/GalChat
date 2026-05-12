extends SceneTree
func _init():
    var img = Image.load_from_file("res://icon.svg")
    print("img: ", img)
    if img:
        print("Size: ", img.get_size())
    quit()