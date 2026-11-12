"""Comprobaciones estaticas basicas de los scripts GDScript del proyecto.

No sustituye al editor de Godot, pero detecta errores tipicos antes de
abrirlo:
  - sangria con espacios o mezclada con tabuladores;
  - parentesis, corchetes y llaves desequilibrados;
  - lineas de bloque (func, if, for...) sin ':' final;
  - llamadas a funciones, constantes o variables de otros scripts que no
    existen (GameData.x, Catalog.x, Buffs.x, Daylight.x...);
  - preloads de archivos que no existen.

Uso:  python3 tools/verificar_gdscript.py
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = ROOT / "scripts"

# Nombre con el que se usa cada script desde otros -> archivo.
ALIASES = {
    "GameData": "game_data.gd", "Sfx": "sfx.gd", "Transition": "transition.gd",
}

BLOCK = re.compile(r"^\s*(func|static func|if|elif|else|for|while|match|class)\b")


def strip_strings(line: str) -> str:
    out = []
    quote = None
    i = 0
    while i < len(line):
        c = line[i]
        if quote:
            if c == "\\":
                i += 2
                continue
            if c == quote:
                quote = None
            i += 1
            continue
        if c in "\"'":
            quote = c
            i += 1
            continue
        if c == "#":
            break
        out.append(c)
        i += 1
    return "".join(out)


def members(path: Path) -> set:
    text = path.read_text(encoding="utf-8")
    names = set(re.findall(r"^(?:static )?func (\w+)", text, re.M))
    names |= set(re.findall(r"^(?:static )?var (\w+)", text, re.M))
    names |= set(re.findall(r"^const (\w+)", text, re.M))
    names |= set(re.findall(r"^signal (\w+)", text, re.M))
    names |= set(re.findall(r"^enum (\w+)", text, re.M))
    # Miembros heredados de uso comun.
    names |= {"get_tree", "emit_signal", "call_deferred", "connect", "get", "set", "new", "has_method", "call", "queue_free", "is_inside_tree"}
    return names


def main() -> int:
    errors = []
    files = sorted(SCRIPTS.glob("*.gd"))
    table = {f.name: members(f) for f in files}
    for f in files:
        text = f.read_text(encoding="utf-8")
        # Alias locales: const X = preload("res://scripts/y.gd")
        aliases = dict(ALIASES)
        for alias, target in re.findall(r'const (\w+)(?:: \w+)? = preload\("res://scripts/([\w.]+)"\)', text):
            aliases[alias] = target
        for target in re.findall(r'preload\("res://([^"]+)"\)', text):
            if not (ROOT / target).exists():
                errors.append(f"{f.name}: preload de archivo inexistente {target}")
        depth = 0
        for n, raw in enumerate(text.split("\n"), 1):
            if raw.strip() == "":
                continue
            indent = raw[: len(raw) - len(raw.lstrip())]
            if " " in indent and depth == 0:
                errors.append(f"{f.name}:{n}: sangria con espacios")
            line = strip_strings(raw)
            if depth == 0 and BLOCK.match(line):
                flat = re.sub(r"\([^()]*\)", "", re.sub(r"\([^()]*\)", "", line))
                flat = re.sub(r"\[[^\[\]]*\]", "", flat)
                opens = line.count("(") + line.count("[") + line.count("{") - line.count(")") - line.count("]") - line.count("}")
                if ":" not in flat and opens == 0:
                    errors.append(f"{f.name}:{n}: bloque sin ':' -> {raw.strip()[:60]}")
            depth += line.count("(") + line.count("[") + line.count("{")
            depth -= line.count(")") + line.count("]") + line.count("}")
            if depth < 0:
                errors.append(f"{f.name}:{n}: cierre sin apertura")
                depth = 0
            for alias, member in re.findall(r"\b([A-Z]\w*)\.(\w+)", line):
                target = aliases.get(alias)
                if target and target in table and member not in table[target]:
                    errors.append(f"{f.name}:{n}: {alias}.{member} no existe en {target}")
        if depth != 0:
            errors.append(f"{f.name}: parentesis desequilibrados al final ({depth})")
    for e in errors:
        print(e)
    print(f"{len(files)} scripts revisados, {len(errors)} problemas")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
