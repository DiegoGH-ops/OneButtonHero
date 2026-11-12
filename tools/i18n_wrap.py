"""Envuelve en Loc.s() los literales de interfaz usados con % o +."""
import re, glob, sys
sys.path.insert(0, "tools")
STR = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
from importlib.machinery import SourceFileLoader
SKIP = {"sprites.gd", "loc_keys.gd", "pixel_font.gd", "palette.gd", "pixel_art.gd", "loc.gd"}

def is_ui(text):
    if not re.search(r"[A-ZÁÉÍÓÚÜÑ]{2,}", text):
        return False
    stripped = re.sub(r"%[-0-9.]*[dsf]|x%d|\\n", "", text)
    if re.search(r"[a-z]", stripped):
        return False
    if re.fullmatch(r"[0-9A-F]{6}", text):
        return False
    return True

total = 0
for path in sorted(glob.glob("scripts/*.gd")):
    if path.split("/")[-1] in SKIP:
        continue
    lines = open(path, encoding="utf-8").read().split("\n")
    changed = False
    for i, line in enumerate(lines):
        if line.lstrip().startswith("#") or line.lstrip().startswith("const "):
            continue
        out = ""
        pos = 0
        for m in STR.finditer(line):
            text = m.group(1)
            before = line[:m.start()].rstrip()
            after = line[m.end():].lstrip()
            fmt = after.startswith("%") and not after.startswith("%=")
            cat = after.startswith("+") or before.endswith("+")
            wrapped = before.endswith("Loc.s(")
            if is_ui(text) and (fmt or cat) and not wrapped:
                out += line[pos:m.start()] + 'Loc.s("' + text + '")'
                pos = m.end()
                total += 1
        if pos:
            lines[i] = out + line[pos:]
            changed = True
    if changed:
        open(path, "w", encoding="utf-8").write("\n".join(lines))
print("wrapped", total)
