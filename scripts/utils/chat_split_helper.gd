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
        merged.append(close_unbalanced_parentheses(temp_str))
    return merged

static func close_unbalanced_parentheses(text: String) -> String:
    var closing_stack: Array[String] = []
    for i in text.length():
        var ch := text[i]
        if ch == "（":
            closing_stack.append("）")
        elif ch == "(":
            closing_stack.append(")")
        elif ch == "）" or ch == ")":
            if not closing_stack.is_empty() and closing_stack[closing_stack.size() - 1] == ch:
                closing_stack.pop_back()
    var result := text
    while not closing_stack.is_empty():
        result += closing_stack.pop_back()
    return result

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

static func format_actions(text: String, color: String = "green") -> String:
    var clean_text := text.strip_edges()
    var color_tag_regex := RegEx.new()
    if color_tag_regex.compile("\\[/?color(?:=[^\\]]+)?\\]") == OK:
        clean_text = color_tag_regex.sub(clean_text, "", true)

    var chinese_action_regex := RegEx.new()
    if chinese_action_regex.compile("（([^（）]*)）") == OK:
        clean_text = chinese_action_regex.sub(clean_text, "[color=%s]（$1）[/color]" % color, true)
    var english_action_regex := RegEx.new()
    if english_action_regex.compile("\\(([^()]*)\\)") == OK:
        clean_text = english_action_regex.sub(clean_text, "[color=%s]($1)[/color]" % color, true)
    return clean_text

static func format_leading_action(text: String, color: String = "green") -> String:
    return format_actions(text, color)

