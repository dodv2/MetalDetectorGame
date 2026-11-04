# Checks property names used in UIKit.new/Text/Button/... prop tables against the Roblox API definitions.
import re, sys, glob
defs = open('/root/tools/lsprepo/scripts/globalTypes.None.d.luau').read()
classes = {}
for m in re.finditer(r'declare (?:extern type|class) (\w+)(?: extends (\w+))?(?: with)?\n(.*?)\nend', defs, re.S):
    name, parent, body = m.group(1), m.group(2), m.group(3)
    members = set(re.findall(r'^\s+([A-Za-z_]\w*)\s*:', body, re.M))
    members |= set(re.findall(r'^\s+function\s+([A-Za-z_]\w*)', body, re.M))
    classes[name] = (parent, members)
def members(cls):
    out = set()
    while cls and cls in classes:
        p, m = classes[cls]; out |= m; cls = p
    return out

def find_table(src, start):
    # start index at '{'; return (end index, text)
    depth = 0; i = start; in_str = None
    while i < len(src):
        c = src[i]
        if in_str:
            if c == '\\': i += 2; continue
            if c == in_str: in_str = None
        elif c in '"\'': in_str = c
        elif c == '{': depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0: return i, src[start+1:i]
        i += 1
    return None, None

def top_keys(body):
    keys = []; depth = 0; in_str = None; i = 0; token_start = 0
    # split by top-level commas
    parts = []; cur = ''
    while i < len(body):
        c = body[i]
        if in_str:
            cur += c
            if c == '\\': cur += body[i+1]; i += 2; continue
            if c == in_str: in_str = None
        else:
            if c in '"\'': in_str = c
            if c in '({[': depth += 1
            if c in ')}]': depth -= 1
            if c == ',' and depth == 0: parts.append(cur); cur = ''; i += 1; continue
            cur += c
        i += 1
    parts.append(cur)
    for p in parts:
        m = re.match(r'\s*([A-Za-z_]\w*)\s*=(?!=)', p)
        if m: keys.append(m.group(1))
    return keys

patterns = [
    (r'UIKit\.new\(\s*"(\w+)"\s*,\s*\{', None),
    (r'UIKit\.Text\(\{', 'TextLabel'),
    (r'UIKit\.ScrollFrame\(\{', 'ScrollingFrame'),
    (r'UIKit\.RarityLabel\([^,]+,\s*\{', 'TextLabel'),
    (r'UIKit\.Bar\(\{', 'Frame'),
]
errors = 0
for f in glob.glob('src/**/*.lua', recursive=True):
    src = open(f).read()
    for pat, fixed in patterns:
        for m in re.finditer(pat, src):
            cls = fixed or m.group(1)
            start = m.end() - 1
            end, body = find_table(src, start)
            if body is None: continue
            valid = members(cls)
            if not valid: print(f"{f}: unknown class {cls}"); errors += 1; continue
            for k in top_keys(body):
                if k == 'Parent': continue
                if k.startswith('On') and k[2:] in valid: continue
                if k not in valid:
                    line = src[:m.start()].count('\n') + 1
                    print(f"{f}:{line}: {cls} has no property '{k}'"); errors += 1
    # Button extra props: UIKit.Button(text, color, fn, { ... })  -> TextButton
    for m in re.finditer(r'UIKit\.Button\(', src):
        # find the props table: last top-level arg that starts with {
        i = m.end(); depth = 1; in_str=None; args_start = i
        while i < len(src) and depth > 0:
            c = src[i]
            if in_str:
                if c == '\\': i += 2; continue
                if c == in_str: in_str = None
            elif c in '"\'': in_str = c
            elif c in '({[': depth += 1
            elif c in ')}]': depth -= 1
            i += 1
        call = src[args_start:i-1]
        # find '{' that begins the 4th arg: last occurrence of ', {' at depth 0
        d=0; in_str=None; last=None
        for j,c in enumerate(call):
            if in_str:
                if c == in_str: in_str=None
                continue
            if c in '"\'': in_str=c
            elif c in '({[': 
                if c=='{' and d==0 and call[:j].rstrip().endswith(','): last=j
                d+=1
            elif c in ')}]': d-=1
        if last is not None:
            end, body = find_table(call, last)
            if body is None: continue
            valid = members('TextButton')
            for k in top_keys(body):
                if k == 'Parent': continue
                if k not in valid:
                    line = src[:m.start()].count('\n') + 1
                    print(f"{f}:{line}: TextButton has no property '{k}'"); errors += 1
print("prop lint errors:", errors)
