class_name ChatSplitHelper
extends RefCounted

static func get_paren_balance(s: String) -> int:
    var balance = 0
    for i in s.length():
        var ch = s[i]
        if ch == "(" or ch == "（":
            balance += 1
        elif ch == ")" or ch == "）":
            balance -= 1
    return balance

static func merge_incomplete_parentheses(parts: Array) -> Array:
    var merged: Array = []
    var temp_str := ""
    var temp_balance := 0
    for p in parts:
        var t := ""
        if typeof(p) == TYPE_STRING:
            t = String(p).strip_edges()
        else:
            continue
        if t == "":
            continue

        var b = get_paren_balance(t)
        if temp_str == "":
            temp_str = t
            temp_balance = b
            continue

        if temp_balance != 0 or b < 0:
            temp_str += " " + t
            temp_balance += b
        else:
            merged.append(temp_str)
            temp_str = t
            temp_balance = b

    if temp_str != "":
        merged.append(temp_str)
    return merged

static func strip_parentheses(text: String) -> String:
    var result = ""
    var balance = 0
    for i in text.length():
        var ch = text[i]
        if ch == "(" or ch == "（" or ch == "[" or ch == "【" or ch == "<" or ch == "《" or ch == "{" or ch == "｛":
            balance += 1
            continue
            
        if ch == ")" or ch == "）" or ch == "]" or ch == "】" or ch == ">" or ch == "》" or ch == "}" or ch == "｝":
            balance -= 1
            if balance < 0:
                balance = 0
            continue
            
        if balance <= 0:
            result += ch
            balance = 0
            
    # 去除多余的空格，避免标点之间留下空格
    return result.strip_edges().replace("  ", " ")

static func format_leading_action(text: String, color: String = "green") -> String:
    var clean_text := text.strip_edges()
    var color_tag_regex := RegEx.new()
    if color_tag_regex.compile("\\[/?color(?:=[^\\]]+)?\\]") == OK:
        clean_text = color_tag_regex.sub(clean_text, "", true)

    var action_regex := RegEx.new()
    if action_regex.compile("（[^（）]*）|\\([^()]*\\)") != OK:
        return clean_text

    var first_action_match := action_regex.search(clean_text)
    if first_action_match == null:
        return clean_text

    var first_action := first_action_match.get_string()
    var dialogue_text := action_regex.sub(clean_text, "", true).strip_edges()
    dialogue_text = dialogue_text.replace("  ", " ")
    var formatted_action := "[color=%s]%s[/color]" % [color, first_action]
    if dialogue_text == "":
        return formatted_action
    return formatted_action + " " + dialogue_text

