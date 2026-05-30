extends PanelContainer

@onready var desc_label: Label = $Margin/DescLabel
var _pending_description: String = ""

func _ready() -> void:
    if _pending_description != "":
        desc_label.text = _pending_description

func setup(description: String) -> void:
    _pending_description = description
    if is_node_ready() and desc_label:
        desc_label.text = description
