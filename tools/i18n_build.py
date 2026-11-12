"""Traducciones de One Button Hero.

  python3 tools/i18n_build.py keys
      Regenera scripts/loc_keys.gd a partir de translations/strings.csv
      (relaciona cada texto espanol del codigo con su clave). Ejecutalo si
      cambias la columna "es" o anades filas al CSV.

  python3 tools/i18n_build.py check
      Comprueba el CSV: que todas las filas tengan los 21 idiomas, que los
      %d / %s se mantengan en el mismo orden y que los idiomas con fuente
      pixel solo usen letras que esa fuente sabe dibujar.

  python3 tools/i18n_build.py missing
      Lista los textos de interfaz del codigo que no estan en el CSV.

El CSV es la fuente unica: una fila por texto, una columna por idioma.
"""
import csv, re, sys, glob, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV_PATH = os.path.join(ROOT, "translations", "strings.csv")
KEYS_PATH = os.path.join(ROOT, "scripts", "loc_keys.gd")
LANGS = ["en", "es", "zh_CN", "hi", "ar", "pt", "bn", "fr", "ru", "id", "ur", "de",
         "ja", "pa", "mr", "te", "tr", "ko", "ta", "vi", "it"]
PIXEL_LANGS = ["en", "es", "pt", "fr", "ru", "id", "de", "tr", "it"]
SPEC = re.compile(r"%[-0-9.]*[dsf]|%%")


def specs(text):
    return SPEC.findall(text)


def read_csv():
    with open(CSV_PATH, encoding="utf-8", newline="") as f:
        rows = list(csv.reader(f))
    return rows[0], rows[1:]


def gd_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def build_keys():
    header, rows = read_csv()
    es = header.index("es")
    lines = [
        "extends RefCounted",
        "## GENERADO por tools/i18n_build.py a partir de translations/strings.csv.",
        "## No editar a mano: texto espanol del codigo -> clave de traduccion.",
        "",
        "const SOURCE := {",
    ]
    for row in rows:
        if len(row) > es and row[es] != "":
            lines.append("\t%s: %s," % (gd_string(row[es]), gd_string(row[0])))
    lines.append("}")
    with open(KEYS_PATH, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("%d claves -> %s" % (len(rows), KEYS_PATH))


def pixel_chars():
    path = os.path.join(ROOT, "scripts", "pixel_font.gd")
    text = open(path, encoding="utf-8").read()
    chars = set(re.findall(r'^\t"(.)": ', text, re.M))
    chars |= set(re.findall(r'"(.)": \["?[A-ZИЕ]', text))
    chars |= set(re.findall(r'"(.)": "[A-Z]"', text))
    chars.add(" ")
    return chars


def check():
    header, rows = read_csv()
    ok = True
    allowed = pixel_chars()
    for row in rows:
        key = row[0]
        if len(row) != len(header):
            print("%s: %d columnas (esperadas %d)" % (key, len(row), len(header)))
            ok = False
            continue
        base = specs(row[header.index("es")])
        for i, lang in enumerate(header[1:], 1):
            text = row[i]
            if text == "":
                print("%s: falta %s" % (key, lang))
                ok = False
            elif specs(text) != base:
                print("%s [%s]: formato %s distinto de %s" % (key, lang, specs(text), base))
                ok = False
            if lang in PIXEL_LANGS:
                bad = sorted(set(c for c in text if c not in allowed and c.upper() not in allowed))
                if bad:
                    print("%s [%s]: letras sin glifo pixel %s (se vera con la fuente vectorial)" % (key, lang, "".join(bad)))
    print("OK" if ok else "HAY ERRORES")
    return ok


def missing():
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    header, rows = read_csv()
    known = set(r[header.index("es")] for r in rows)
    pattern = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
    skip = {"sprites.gd", "loc_keys.gd", "pixel_font.gd", "palette.gd", "pixel_art.gd", "loc.gd"}
    count = 0
    for path in sorted(glob.glob(os.path.join(ROOT, "scripts", "*.gd"))):
        if os.path.basename(path) in skip:
            continue
        for n, line in enumerate(open(path, encoding="utf-8"), 1):
            if line.lstrip().startswith("#"):
                continue
            for m in pattern.finditer(line):
                t = m.group(1)
                if not re.search(r"[A-ZÁÉÍÓÚÜÑ]{2,}", t):
                    continue
                if re.search(r"[a-z]", re.sub(r"%[-0-9.]*[dsf]|x%d|\\n", "", t)):
                    continue
                if re.fullmatch(r"[0-9A-F]{6}", t):
                    continue
                if t not in known:
                    print("%s:%d: %s" % (os.path.basename(path), n, t))
                    count += 1
    print("%d textos sin traducir" % count)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"
    {"keys": build_keys, "check": check, "missing": missing}[cmd]()
