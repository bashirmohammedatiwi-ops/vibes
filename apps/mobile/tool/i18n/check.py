#!/usr/bin/env python3
"""i18n audit. Usage: check.py [path-prefix ...]

Reports, under lib/:
  UNWRAPPED  Arabic string literal not wrapped in .tr / .trArgs / .trN
             (a literal that exists in en.json and is translated at its use
             site is fine: mark such lines `// i18n-ok`, e.g. const lists).
  MISSING    wrapped key with no English in en.json
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
        src = open(path, encoding='utf-8').read()
        lines = src.split('\n')
        for m in lit.finditer(src):
            lit_text = m.group(1)[1:-1]
            if not ar.search(lit_text):
                continue
            no = src.count('\n', 0, m.start()) + 1
            line = lines[no - 1]
            before = line[:m.start() - src.rfind('\n', 0, m.start()) - 1]
            if '//' in before or 'i18n-ok' in line or (no < len(lines) and 'i18n-ok' in lines[no].split("'")[0]):
                continue
            value = lit_text.replace("\\'", "'").replace('\\n', '\n').replace('\\"', '"')
            if m.group(2):
                if value not in known:
                    missing += 1
                    print(f'MISSING   {rel}:{no}: {value}')
            else:
                unwrapped += 1
                print(f'UNWRAPPED {rel}:{no}: {lit_text}')
print(f'unwrapped={unwrapped} missing={missing}')
sys.exit(1 if unwrapped or missing else 0)
