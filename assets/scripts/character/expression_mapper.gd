class_name ExpressionMapper
extends Resource

# Maps expression tags to actual asset paths or animation names
var expression_map: Dictionary = {
    "neutral": "res://assets/sprites/characters/ayrrha_neutral.png",
    "shy": "res://assets/sprites/characters/ayrrha_shy.png",
    "happy": "res://assets/sprites/characters/ayrrha_happy.png",
    "sad": "res://assets/sprites/characters/ayrrha_sad.png",
    "surprise": "res://assets/sprites/characters/ayrrha_surprise.png",
    "angry": "res://assets/sprites/characters/ayrrha_angry.png",
    "blush": "res://assets/sprites/characters/ayrrha_blush.png"
}

func get_expression_asset(expr: String) -> String:
    if expression_map.has(expr):
        return expression_map[expr]
    return expression_map["neutral"]
