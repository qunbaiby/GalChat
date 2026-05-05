extends "res://scripts/script_engine/script_event.gd"

var var_name: String
var var_value

func _init(data: Dictionary) -> void:
    super(data)
    var_name = data.get("var_name", "")
    var_value = data.get("var_value", null)

func process_event(manager: Node) -> bool:
    print("[ScriptEngine] Set Variable: ", var_name, " = ", var_value)
    manager.emit_signal("on_variable_set", var_name, var_value)
    return false
