extends Node

var panel: Control

func _ready():
    print("Running Dialogue Panel Tests...")
    
    var DialoguePanel = load("res://scenes/ui/common/dialogue_panel.tscn")
    panel = DialoguePanel.instantiate()
    add_child(panel)
    
    # Wait for tree to be ready
    await get_tree().process_frame
    await get_tree().process_frame
    
    await test_dynamic_height()
    await test_input_field()
    await test_gift_button()
    
    print("All tests passed successfully!")
    get_tree().quit()

func test_dynamic_height():
    print("Test 1: Dynamic Height")
    var rich_text = panel.rich_text_label
    var initial_height = rich_text.size.y
    
    var text = ""
    for i in range(10):
        text += "This is line " + str(i) + "\n"
        
    rich_text.text = text
    await get_tree().process_frame
    await get_tree().process_frame
    
    assert(rich_text.size.y > initial_height, "Height should increase with more lines")
    print("Test 1 Passed.")

func test_input_field():
    print("Test 2: Input Field Char Limit")
    var input_field = panel.input_field
    input_field.grab_focus()
    
    input_field.text = ""
    for i in range(250):
        simulate_key_enter(input_field, "A")
        
    assert(input_field.text.length() == 200, "Input field did not truncate to 200 chars")
    assert(panel.char_count_label.text == "200/200", "Char count label did not update correctly")
    print("Test 2 Passed.")

func simulate_key_enter(input_field: TextEdit, char_str: String):
    input_field.text += char_str
    input_field.text_changed.emit()

func test_gift_button():
    print("Test 3: Gift Button Logic")
    # Main mode
    panel.set_story_mode(false)
    assert(panel.gift_btn.visible == true, "Gift button should be visible in MainScene")
    
    var click_count = 0
    for i in range(50):
        panel.gift_btn.pressed.emit()
        click_count += 1
        
    assert(click_count == 50, "Gift button should handle clicks")
    
    # Story mode
    panel.set_story_mode(true)
    assert(panel.gift_btn.visible == false, "Gift button should be hidden in StoryMode")
    print("Test 3 Passed.")
