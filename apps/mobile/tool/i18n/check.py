#!/usr/bin/env python3
"""i18n audit. Usage: check.py [path-prefix ...]

Reports, under lib/:
  UNWRAPPED  Arabic string literal not wrapped in .tr / .trArgs / .trN
             (a literal that exists in en.json and is translated at its use
             site is fine: mark such lines `// i18n-ok`, e.g. const lists).
  MISSING    wrapped key with no English in en.json or tool/i18n/parts/*.json
"""
import glob, json, os, re, sys
root = os.path.dirname(os.path.abspath(__file__))
lib = os.path.join(root, '..', '..', 'lib')
known = {}
for p in [os.path.join(root, '..', '..', 'assets', 'translations', 'en.json')] + glob.glob(os.path.join(root, 'parts', '*.json')):
    known.update(json.load(open(p, encoding='utf-8')))
lit = re.compile(r"""(?<![\w])r?('(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*")(\s*\.\s*(?:tr\b|trArgs\(|trN\())?""")
ar = re.compile(r'[؀-ۿ]')
prefixes = sys.argv[1:]
unwrapped = missing = 0
for d, _, fs in os.walk(lib):
    for f in fs:
        if not f.endswith('.dart') or f == 'i18n.dart':
            continue
        path = os.path.join(d, f)
        rel = os.path.relpath(path, lib)
        if prefixes and not any(rel.startswith(x) for x in prefixes):
            continue
        for no, line in enumerate(open(path, encoding='utf-8'), 1):
            code = line.split(' //')[0] if not ar.search(line.split(' //')[0]) or "'" in line.split(' //')[0] else line
            if line.strip().startswith('//') or 'i18n-ok' in line:
                continue
            for m in lit.finditer(code):
                s = m.group(1)[1:-1]
                if not ar.search(s):
                    continue
                value = s.replace("\\'", "'").replace('\\n', '\n').replace('\\"', '"')
                if m.group(2):
                    if value not in known:
                        missing += 1
                        print(f'MISSING   {rel}:{no}: {value}')
                else:
                    unwrapped += 1
                    print(f'UNWRAPPED {rel}:{no}: {s}')
print(f'unwrapped={unwrapped} missing={missing}')
sys.exit(1 if unwrapped or missing else 0)
