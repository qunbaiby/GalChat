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
