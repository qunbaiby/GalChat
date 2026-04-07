import json

file_path = r'e:\GalChat_APP\assets\data\characters\luna.json'

with open(file_path, 'r', encoding='utf-8') as f:
    data = json.load(f)

# Add base_personality
data['base_personality'] = {
    "openness": 50.0,
    "conscientiousness": 50.0,
    "extraversion": 50.0,
    "agreeableness": 50.0,
    "neuroticism": 50.0,
    "core_traits": "温柔、安静、慢热，对外在环境保持着一定的警惕与好奇",
    "dialogue_style": "语气自然轻柔，不带过多夸张的口癖"
}

# Remove personality_traits from stages
if 'stages' in data:
    for stage in data['stages']:
        if 'personality_traits' in stage:
            del stage['personality_traits']

# Reorder keys to put base_personality after world_background
new_data = {}
for k, v in data.items():
    if k == 'stages':
        new_data['base_personality'] = data['base_personality']
    if k != 'base_personality':
        new_data[k] = v

with open(file_path, 'w', encoding='utf-8') as f:
    json.dump(new_data, f, ensure_ascii=False, indent=4)

print("Done")