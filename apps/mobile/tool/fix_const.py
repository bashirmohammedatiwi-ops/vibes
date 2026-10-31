#!/usr/bin/env python3
"""Repeatedly drop `const` wherever an expression stopped being constant
(tokens became getters that follow the current theme/locale)."""
import re, subprocess, sys, collections
CODES = {'const_with_non_constant_argument','invalid_constant','non_constant_list_element',
 'const_initialized_with_non_constant_value','non_constant_map_element','non_constant_map_key',
 'non_constant_map_value','non_constant_set_element','const_eval_method_invocation','const_eval_property_access',
 'const_constructor_param_type_mismatch','const_eval_type_bool_num_string','const_with_non_const','const_eval_throws_exception','const_spread_expected_list_or_set'}
OPEN = '([{'; CLOSE = ')]}'
def span(s, i):
    j = i + 5
    while j < len(s) and s[j] not in '([{;,': j += 1
    if j >= len(s) or s[j] in ';,': return None
    depth = 0; q = None
    k = j
    while k < len(s):
        c = s[k]
        if q:
            if c == '\\': k += 1
            elif c == q: q = None
        elif c in '\'"': q = c
        elif c in OPEN: depth += 1
        elif c in CLOSE:
            depth -= 1
            if depth == 0: return k
        k += 1
    return None
for round_ in range(40):
    r = subprocess.run(['dart','analyze','--format=machine','lib'],capture_output=True,text=True)
    errs = collections.defaultdict(list); manual = []
    for l in (r.stdout + r.stderr).splitlines():
        p = l.split('|')
        if len(p) < 8 or p[0] != 'ERROR': continue
        code = p[2].lower()
        if code in CODES: errs[p[3]].append((int(p[4]),int(p[5]),code))
        elif 'const' in code: manual.append(l)
    if not errs:
        print('clean after', round_, 'rounds'); print('\n'.join(manual)); break
    fixed = 0
    for path, items in errs.items():
        s = open(path, encoding='utf-8').read()
        starts = [0] + [m.end() for m in re.finditer('\n', s)]
        kill = set(); decls = set()
        for line, col, code in items:
            off = starts[line-1] + col - 1
            best = None
            for m in re.finditer(r'\bconst\b', s[:off]):
                e = span(s, m.start())
                if e is not None and e >= off: best = m.start()
            if best is not None: kill.add(best)
            else:
                # a declaration: `const T x = ...;` / `static const T x = ...;`
                ls = s.rfind('\n', 0, off) + 1
                for m in re.finditer(r'\bconst\b', s[max(0,ls-300):off]): pass
                decls.add(line)
        for pos in sorted(kill, reverse=True):
            end = pos + 5
            while s[end] == ' ': end += 1
            s = s[:pos] + s[end:]; fixed += 1
        if decls:
            def getterize(m):
                nonlocal_fixed.append(1)
                ind, st, ty, name, val = m.groups()
                t = (ty or 'Color').strip()
                return f"{ind}{st or ''}{t} get {name} => {val};"
            nonlocal_fixed = []
            s = re.sub(r"^([ \t]*)(static )?const ([A-Za-z_<>, ?]+? )?([A-Za-z_]\w*)\s*=\s*((?:[^;'\"]|'[^']*'|\"[^\"]*\")+?);", lambda m: getterize(m) if s.count('\n',0,m.start())+1 in decls or any(s.count('\n',0,m.start())+1<=d<=s.count('\n',0,m.end())+1 for d in decls) else m.group(0), s, flags=re.M)
            fixed += len(nonlocal_fixed)
        open(path,'w',encoding='utf-8').write(s)
    print('round',round_,'errors',sum(map(len,errs.values())),'fixed',fixed)
    if not fixed:
        for p,i in errs.items(): print(p,i)
        sys.exit(1)
