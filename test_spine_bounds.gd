@tool
extends SceneTree

func _init():
	print("--- BEGIN TEST ---")
	var scene = load("res://scenes/ui/desktop_pet/desktop_pet.tscn")
	var instance = scene.instantiate()
	
	# wait a frame or so
	var pet = instance.get_node("Control/PetContainer/SpineSprite")
	if pet:
		print("Found pet: ", pet)
		print("Pet position: ", pet.position)
		print("Pet scale: ", pet.scale)
	else:
		print("Pet not found")
	
	quit()
