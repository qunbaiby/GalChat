import os

out_dir = r'e:\GalChat\GalChat\assets\images\icons\ui\stats'
os.makedirs(out_dir, exist_ok=True)

# 纯色线条风格，但是这次使用彩色
# 体：代表力量/体能的哑铃或肌肉图标（红色 #ff4757）
# 智：代表智力/思维的大脑或书本图标（蓝色 #1e90ff）
# 魅：代表魅力的星星或皇冠图标（粉色/紫色 #ff6b81）

icons = {
    'core_physical.svg': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#ff4757" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M6.5 6.5l11 11M3 14.5l6.5 6.5M14.5 3l6.5 6.5M5 8.5l-2-2a2.828 2.828 0 1 1 4-4l2 2M15.5 18.5l2 2a2.828 2.828 0 1 0 4-4l-2-2"/></svg>''',
    'core_intelligence.svg': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#1e90ff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M9.5 2A2.5 2.5 0 0 1 12 4.5v15a2.5 2.5 0 0 1-4.96.44 2.5 2.5 0 0 1-2.96-3.08 2.5 2.5 0 0 1-1.28-4.7 2.5 2.5 0 0 1 2.22-4.14A2.5 2.5 0 0 1 9.5 2z"/><path d="M14.5 2A2.5 2.5 0 0 0 12 4.5v15a2.5 2.5 0 0 0 4.96.44 2.5 2.5 0 0 0 2.96-3.08 2.5 2.5 0 0 0 1.28-4.7 2.5 2.5 0 0 0-2.22-4.14A2.5 2.5 0 0 0 14.5 2z"/></svg>''',
    'core_charm.svg': '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#ff6b81" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>'''
}

for name, content in icons.items():
    with open(os.path.join(out_dir, name), 'w', encoding='utf-8') as f:
        f.write(content)
print('Core stat icons generated.')