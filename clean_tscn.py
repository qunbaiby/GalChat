import re
import sys

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # We need to remove the specific node blocks and all their children.
    # The nodes to remove are:
    nodes_to_remove = [
        "Sub_stat_body",
        "Sub_stat_focus",
        "Sub_stat_planning",
        "Sub_stat_art_theory",
        "Sub_stat_manner",
        "Sub_stat_stage",
        "Sub_stat_empathy",
        "Sub_stat_inspiration"
    ]

    for node_name in nodes_to_remove:
        # Pattern: match from [node name="node_name" ... up to the next [node
        # But we need to handle children as well, which are [node name="..." parent=".../node_name"]
        # Actually, in Godot tscn, properties come after [node].
        # So we can match `\[node name="node_name" .*?\](?:\n.*?)*?(?=\n\[node|\Z)`
        # And we also need to remove its children. Its children will have `parent=".../node_name"`
        
        # Remove the main node
        pattern_main = re.compile(r'\[node name="' + node_name + r'".*?\].*?(?=\n\[node|\Z)', re.DOTALL)
        content = pattern_main.sub('', content)
        
        # Remove children
        pattern_children = re.compile(r'\[node name="[^"]+" type="[^"]+" parent="[^"]*/' + node_name + r'".*?\].*?(?=\n\[node|\Z)', re.DOTALL)
        content = pattern_children.sub('', content)

    # Clean up empty lines
    content = re.sub(r'\n{3,}', '\n\n', content)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

process_file(sys.argv[1])
