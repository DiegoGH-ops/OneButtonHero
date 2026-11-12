"""Busca textos de interfaz en los scripts (literales en MAYUSCULAS).

Uso: python3 tools/i18n_scan.py [--sites]
  sin argumentos: lista de textos unicos (para el CSV de traducciones)
  --sites: literales usados con formato (%) o concatenados (+), que deben
           ir envueltos en Loc.s() en el codigo.
"""
import re, sys, glob, json

STR = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
SKIP_FILES = {"sprites.gd", "loc_keys.gd", "pixel_font.gd", "palette.gd", "pixel_art.gd", "loc.gd"}


def is_ui(text):
    if not re.search(r"[A-ZÁÉÍÓÚÜÑ]{2,}", text):
        return False
    stripped = re.sub(r"%[-0-9.]*[dsf]|x%d|\\n", "", text)
    if re.search(r"[a-z]", stripped):
        return False
    # Codigos de color, ids, nombres de accion...
    if re.fullmatch(r"[0-9A-F]{6}", text):
        return False
    return True


def literals(path):
    for n, line in enumerate(open(path, encoding="utf-8"), 1):
        code = line.split("#", 1)[0] if '"' not in line.split("#", 1)[0] else line
        if line.lstrip().startswith("#"):
            continue
        for m in STR.finditer(line):
            yield n, m, line


def main():
    sites = "--sites" in sys.argv
    found = {}
    for path in sorted(glob.glob("scripts/*.gd")):
        name = path.split("/")[-1]
        if name in SKIP_FILES:
            continue
        for n, m, line in literals(path):
            text = m.group(1)
            if not is_ui(text):
                continue
            after = line[m.end():].lstrip()
            before = line[:m.start()].rstrip()
            wrapped = before.endswith("Loc.s(") or before.endswith("Loc.f(")
            if sites:
                fmt = after.startswith("%") and not after.startswith("%=")
                cat = after.startswith("+") or before.endswith("+")
                if (fmt or cat) and not wrapped:
                    print("%s:%d: %s" % (path, n, line.strip()[:150]))
            else:
                found.setdefault(text, name)
    if not sites:
        json.dump(found, sys.stdout, ensure_ascii=False, indent=0)


main()
