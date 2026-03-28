class_name CharacterController
extends Node

var current_expression: String = "neutral"

func change_expression(expr: String) -> void:
    current_expression = expr
    print("Character expression changed to: ", expr)
    # TODO: Update Sprite2D / TextureRect or Spine/Live2D parameters
