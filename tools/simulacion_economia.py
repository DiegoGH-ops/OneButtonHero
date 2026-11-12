"""Simulacion de la progresion economica de One Button Hero.

Lee los precios reales del arbol de mejoras y de la tienda directamente de
scripts/catalog.gd y los cruza con un modelo de ingresos que replica las
formulas de scripts/game_data.gd y scripts/campaign.gd.

Uso:  python3 tools/simulacion_economia.py

Supuestos del jugador (ajustables abajo):
  - Intentos por nivel hasta superarlo (los fallidos tambien suman monedas).
  - Monedas recogidas por metro (monedas, gemas, rubies y cofres).
  - Duracion de cada intento (recorrido / velocidad + menus).
  - Porcentaje de retos y modos de dominio que se superan.
"""
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = (ROOT / "scripts" / "catalog.gd").read_text(encoding="utf-8")

# ----------------------------------------------------------- datos del juego
TIER_BASE = {k: int(v) for k, v in re.findall(r'"(\w+)": (\d+)', re.search(r"const TIER_BASE := \{([^}]*)\}", CATALOG).group(1))}
TIER_GROWTH = float(re.search(r"const TIER_GROWTH := ([\d.]+)", CATALOG).group(1))
WORLD_PRICE = [float(x) for x in re.search(r"const WORLD_PRICE := \[([^\]]*)\]", CATALOG).group(1).split(",")]

tree_text = CATALOG[CATALOG.index("const TREE := ["):CATALOG.index("static var _tree_index")]
NODES = []
for m in re.finditer(r'\{"id": "([^"]+)", "cat": "([^"]+)".*?"tier": "(\w+)", "lv": (\d+), "w": (\d)', tree_text):
    NODES.append({"id": m.group(1), "cat": m.group(2), "tier": m.group(3), "lv": int(m.group(4)), "w": int(m.group(5))})

pu_text = CATALOG[CATALOG.index("const POWERUPS := ["):CATALOG.index("const TREE_BRANCHES")]
POWERUPS = [(int(w), int(p)) for w, p in re.findall(r'"world": (\d), "name": "[^"]+", "price": (\d+)', pu_text)]


def nice_price(raw: float) -> int:
    step = 50.0
    if raw >= 10000.0:
        step = 500.0
    elif raw >= 1000.0:
        step = 100.0
    return int(max(round(raw / step) * step, step))


def node_prices(node):
    base = TIER_BASE[node["tier"]] * WORLD_PRICE[node["w"]]
    return [nice_price(base * TIER_GROWTH ** lvl) for lvl in range(node["lv"])]


# ------------------------------------------------- formulas de recompensas
# (mismas constantes que scripts/game_data.gd)
WORLD_REWARD = [1.0, 2.0, 3.4, 5.2, 7.5]
WORLD_COIN = [1.0, 1.5, 2.1, 2.8, 3.6]
REPLAY_FACTOR = 0.6
LEVELS = 20


def meters(w, l):
    m = 260 + l * 18 + w * 40
    return m + 240 if l == LEVELS - 1 else m


def speed_ms(w, l):
    return (360 + 80 * w + 4 * l) / 48.0


# ------------------------------------------------- supuestos del jugador
COINS_PER_METER = 0.30          # monedas+gemas+cofres recogidos por metro
ATTEMPTS = [2.0, 2.6, 3.2, 3.8, 4.5]   # intentos medios hasta superar un nivel
FAILED_FRACTION = 0.45          # un intento fallido recorre ~45% del nivel
MENU_SECONDS = 12               # menus, pantallas de resultado, reintentos
CHALLENGE_RATE_FIRST = 0.45     # retos superados en la primera pasada
MODE_RATE = 0.35                # modos de dominio superados (a la larga)
DAILY_MINUTES = 45              # sesion media diaria (login, misiones)


def run_coins(w, l, fraction, replay=False, coin_buff=1.0):
    mult = WORLD_COIN[w] * coin_buff
    if replay:
        mult *= REPLAY_FACTOR
    collected = meters(w, l) * fraction * COINS_PER_METER
    milestones = int(meters(w, l) * fraction // 250) * 12
    return collected * mult + milestones


def attempt_minutes(w, l, fraction):
    return (meters(w, l) * fraction / speed_ms(w, l) + MENU_SECONDS) / 60.0


def campaign_pass():
    """Primera pasada por la campana, mundo a mundo."""
    rows = []
    total = 0.0
    minutes = 0.0
    diamonds = 0
    for w in range(5):
        w_coins = 0.0
        w_min = 0.0
        for l in range(LEVELS):
            fails = ATTEMPTS[w] - 1.0
            w_coins += run_coins(w, l, 1.0) + fails * run_coins(w, l, FAILED_FRACTION)
            w_min += attempt_minutes(w, l, 1.0) + fails * attempt_minutes(w, l, FAILED_FRACTION)
            w_coins += (60 + 5 * l) * WORLD_REWARD[w]
            if l == 0:
                w_coins += 150 * WORLD_REWARD[w]
            if l == LEVELS - 1:
                w_coins += 800 * WORLD_REWARD[w]
            w_coins += 3 * CHALLENGE_RATE_FIRST * 30 * WORLD_REWARD[w]
            if (l + 1) % 5 == 0:
                diamonds += [1, 2, 3, 5][(l + 1) // 5 - 1] + w
        # Misiones diarias y premio de login durante ese tiempo de juego.
        days = w_min / DAILY_MINUTES
        w_coins += days * (40 * 4 + 120)
        total += w_coins
        minutes += w_min
        rows.append((w, w_coins, w_min, total, minutes, diamonds))
    return rows


def late_game_rate(coin_buff=1.6):
    """Monedas por hora repitiendo niveles del ultimo mundo con buffs."""
    w = 4
    coins = 0.0
    mins = 0.0
    for l in range(LEVELS - 1):
        coins += run_coins(w, l, 1.0, replay=False, coin_buff=coin_buff) * 0.8 + run_coins(w, l, FAILED_FRACTION, coin_buff=coin_buff) * 0.2
        mins += attempt_minutes(w, l, 1.0) * 0.8 + attempt_minutes(w, l, FAILED_FRACTION) * 0.2
    return coins / mins * 60.0


def extra_content():
    """Retos restantes, modos de dominio y maestria de mundos (una vez)."""
    coins = 0.0
    for w in range(5):
        per_level = 3 * (1 - CHALLENGE_RATE_FIRST) * 30 * WORLD_REWARD[w] + 5 * MODE_RATE * 120 * WORLD_REWARD[w]
        coins += per_level * LEVELS
        coins += 1500 * WORLD_REWARD[w] * 0.5  # la mitad de los mundos con 60 estrellas
    return coins


def main():
    tiers = {}
    worlds = {}
    cats = {}
    total_tree = 0
    for node in NODES:
        cost = sum(node_prices(node))
        total_tree += cost
        tiers.setdefault(node["tier"], [0, 0, 0])
        tiers[node["tier"]][0] += 1
        tiers[node["tier"]][1] += node["lv"]
        tiers[node["tier"]][2] += cost
        worlds[node["w"]] = worlds.get(node["w"], 0) + cost
        cats[node["cat"]] = cats.get(node["cat"], 0) + cost
    levels = sum(n["lv"] for n in NODES)
    pu_total = sum(p for _, p in POWERUPS)

    print("=" * 66)
    print("ÁRBOL DE MEJORAS")
    print("=" * 66)
    print(f"Mejoras: {len(NODES)}   Niveles comprables: {levels}   Coste total: {total_tree:,}")
    for tier in ["normal", "advanced", "epic", "special", "legendary", "secret"]:
        n, lv, cost = tiers.get(tier, [0, 0, 0])
        print(f"  {tier:10s} {n:3d} mejoras {lv:3d} niveles  {cost:>10,} monedas")
    print("Coste acumulado por mundo exigido:")
    acc = 0
    for w in range(5):
        acc += worlds.get(w, 0)
        print(f"  mundo {w + 1}: {worlds.get(w, 0):>10,}  (acumulado {acc:,})")
    print(f"Power-ups (10, dos por mundo): {pu_total:,}")
    cheapest = min(sum(node_prices(n)) for n in NODES)
    print(f"Rama mas barata: {min(cats.values()):,}  mas cara: {max(cats.values()):,}  nodo mas barato: {cheapest}")

    print()
    print("=" * 66)
    print("PRIMERA PASADA POR LA CAMPAÑA (sin mejoras de monedas)")
    print("=" * 66)
    rows = campaign_pass()
    for w, coins, mins, total, minutes, dia in rows:
        print(f"Mundo {w + 1}: +{coins:>9,.0f} monedas en {mins / 60:4.1f} h  | acumulado {total:>9,.0f} en {minutes / 60:4.1f} h | diamantes {dia}")
    total_campaign = rows[-1][3]
    hours_campaign = rows[-1][4] / 60

    # Lo que se puede comprar al terminar el mundo 1.
    w1 = rows[0][3]
    affordable = sorted(sum(node_prices(n)) for n in NODES if n["w"] == 0)
    spent = 0
    count = 0
    for c in affordable:
        if spent + c > w1:
            break
        spent += c
        count += 1
    print()
    normal_levels = sorted(p for n in NODES if n["tier"] == "normal" for p in node_prices(n))
    bought = 0
    acc_n = 0
    for p in normal_levels:
        if acc_n + p > w1:
            break
        acc_n += p
        bought += 1
    print(f"Al terminar el mundo 1 ({w1:,.0f} monedas) se pueden completar como mucho {count} de {len(NODES)} mejoras")
    print(f"  o comprar {bought} de los {len(normal_levels)} niveles de mejoras normales (las más baratas)")
    print(f"  -> {w1 / total_tree * 100:.1f}% del coste del árbol")

    extra = extra_content()
    rate = late_game_rate()
    remaining = total_tree + pu_total - total_campaign - extra
    hours_farm = max(remaining, 0) / rate
    print()
    print("=" * 66)
    print("TIEMPOS ESTIMADOS")
    print("=" * 66)
    first = [n for n in NODES if n["tier"] == "normal"]
    inter = [n for n in NODES if n["tier"] in ("advanced", "epic")]
    adv = [n for n in NODES if n["tier"] in ("special", "legendary", "secret")]
    def hours_to(amount):
        acc_coins = 0.0
        for w, coins, mins, total, minutes, dia in rows:
            if total >= amount:
                prev_total = total - coins
                prev_min = minutes - mins
                return (prev_min + (amount - prev_total) / coins * mins) / 60
        return hours_campaign + (amount - total_campaign - extra) / rate
    c_first = sum(sum(node_prices(n)) for n in first)
    c_inter = sum(sum(node_prices(n)) for n in inter)
    c_adv = sum(sum(node_prices(n)) for n in adv)
    print(f"Mejoras iniciales (normal, {c_first:,}):           ~{hours_to(c_first):5.1f} h")
    print(f"+ intermedias (avanzada/épica, {c_inter:,}):    ~{hours_to(c_first + c_inter):5.1f} h")
    branch = cats["movimiento"]
    print(f"Una rama completa (Movimiento, {branch:,}):        ~{hours_to(branch):5.1f} h")
    print(f"+ avanzadas (especial/legend./secreta, {c_adv:,}): ~{hours_to(c_first + c_inter + c_adv):5.1f} h")
    print(f"Campaña completa: {total_campaign:,.0f} monedas en {hours_campaign:.1f} h")
    print(f"Retos, modos y maestrías restantes: +{extra:,.0f}")
    print(f"Ritmo de juego avanzado (mundo 5 con buffs): {rate:,.0f} monedas/h")
    print(f"Árbol completo + 10 power-ups: ~{hours_campaign + hours_farm + extra / rate:.0f} h de juego")


if __name__ == "__main__":
    main()
