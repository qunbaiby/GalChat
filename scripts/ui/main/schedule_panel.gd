extends Control

@onready var todo_input: LineEdit = $Panel/MarginContainer/VBoxContainer/TodoSection/HBoxContainer/TodoInput
@onready var add_todo_btn: Button = $Panel/MarginContainer/VBoxContainer/TodoSection/HBoxContainer/AddButton
@onready var todo_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TodoSection/ScrollContainer/TodoList

@onready var close_btn: Button = $Panel/CloseButton

func _ready() -> void:
    add_todo_btn.pressed.connect(_on_add_todo)
    todo_input.text_submitted.connect(func(_text): _on_add_todo())
    close_btn.pressed.connect(queue_free)
    
    _render_todos()

func _on_add_todo() -> void:
    var text = todo_input.text.strip_edges()
    if text.is_empty(): return
    
    var todo_item = {
        "text": text,
        "done": false
    }
    GameDataManager.pomodoro_data["todos"].append(todo_item)
    GameDataManager.save_pomodoro_data()
    
    todo_input.text = ""
    _render_todos()

func _render_todos() -> void:
    for child in todo_list.get_children():
        child.queue_free()
        
    var todos = GameDataManager.pomodoro_data["todos"]
    for i in range(todos.size()):
        var t = todos[i]
        var hbox = HBoxContainer.new()
        
        var cb = CheckBox.new()
        cb.button_pressed = t["done"]
        cb.toggled.connect(func(pressed): _on_todo_toggled(i, pressed))
        
        var lbl = Label.new()
        lbl.text = t["text"]
        lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        if t["done"]:
            lbl.modulate = Color(0.6, 0.6, 0.6)
            
        var del_btn = Button.new()
        del_btn.text = "X"
        del_btn.pressed.connect(func(): _on_todo_delete(i))
        
        hbox.add_child(cb)
        hbox.add_child(lbl)
        hbox.add_child(del_btn)
        
        todo_list.add_child(hbox)

func _on_todo_toggled(idx: int, pressed: bool) -> void:
    GameDataManager.pomodoro_data["todos"][idx]["done"] = pressed
    GameDataManager.save_pomodoro_data()
    _render_todos()

func _on_todo_delete(idx: int) -> void:
    GameDataManager.pomodoro_data["todos"].remove_at(idx)
    GameDataManager.save_pomodoro_data()
    _render_todos()
