#!/usr/bin/env python3
"""Merge tool/i18n/parts/*.json into assets/translations/en.json (later files win)."""
import glob, json, os
root = os.path.dirname(os.path.abspath(__file__))
out = os.path.join(root, '..', '..', 'assets', 'translations', 'en.json')
merged = json.load(open(out, encoding='utf-8'))
for p in sorted(glob.glob(os.path.join(root, 'parts', '*.json'))):
    merged.update(json.load(open(p, encoding='utf-8')))
json.dump(dict(sorted(merged.items())), open(out, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print(len(merged), 'keys')
