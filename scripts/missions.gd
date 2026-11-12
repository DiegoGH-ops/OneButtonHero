extends RefCounted
## Catalogo de misiones (mas de 220): diarias y semanales en rotacion,
## de mundo, de maestria, de jefes, secretas y de progresion.
##
## Cada mision cuenta un suceso real registrado con GameData.track():
##   stat: nombre del suceso ("kills", "perfect_jump"...). Si acaba en "@w",
##         se completa con el mundo ("kills@w2" = enemigos del mundo 3).
##   mode: "sum" (se acumula) o "max" (mejor marca en una partida).
## Las diarias y semanales cuentan desde que empieza su periodo; el resto
## leen las estadisticas de toda la partida.

const Campaign = preload("res://scripts/campaign.gd")
const Bestiary = preload("res://scripts/bestiary.gd")

const CATEGORIES := ["diaria", "semanal", "mundo", "maestria", "jefe", "secreta", "progresion"]
const CATEGORY_NAMES := ["DIARIAS", "SEMANALES", "MUNDOS", "MAESTRÍA", "JEFES", "SECRETAS", "PROGRESIÓN"]
const CATEGORY_COLORS := ["73eff7", "ef7d57", "38b764", "ffcd75", "b13e53", "b06fd0", "41a6f6"]
const DIFFICULTIES := ["FÁCIL", "NORMAL", "DIFÍCIL", "ÉPICA", "LEGENDARIA"]
const DIFFICULTY_COLORS := ["a7f070", "73eff7", "ffcd75", "f29cb5", "ef7d57"]

## Cuantas se eligen de cada rotacion.
const DAILY_COUNT := 4
const WEEKLY_COUNT := 5

## [stat, objetivo, nombre, descripcion (%d = objetivo), dificultad, monedas, modo]
const DAILY := [
	["coins_picked", 80, "BUSCADOR DE MONEDAS", "RECOGE %d MONEDAS", 0, 60, "sum"],
	["kills", 15, "LIMPIEZA DIARIA", "DERROTA %d ENEMIGOS", 0, 60, "sum"],
	["distance", 1500, "PIERNAS INCANSABLES", "RECORRE %d METROS", 0, 60, "sum"],
	["gems_picked", 4, "OJO DE JOYERO", "RECOGE %d GEMAS", 1, 70, "sum"],
	["run", 3, "CALENTAMIENTO", "JUEGA %d PARTIDAS", 0, 40, "sum"],
	["perfect_jump", 25, "SALTOS LIMPIOS", "HAZ %d SALTOS PERFECT", 1, 80, "sum"],
	["perfect_land", 8, "ATERRIZAJE SUAVE", "HAZ %d ATERRIZAJES PERFECT", 1, 80, "sum"],
	["perfect_attack", 20, "FILO PRECISO", "ASESTA %d GOLPES PERFECT", 1, 80, "sum"],
	["legendaries", 5, "AL ÚLTIMO SEGUNDO", "HAZ %d ACCIONES LEGENDARY", 2, 100, "sum"],
	["level_clear", 3, "AVANZA", "SUPERA %d NIVELES", 0, 70, "sum"],
	["three_star", 1, "TRES ESTRELLAS", "CONSIGUE 3 ESTRELLAS EN %d NIVEL", 1, 90, "sum"],
	["rapid_success", 3, "DEDOS RÁPIDOS", "SUPERA %d RAPID SIX", 1, 80, "sum"],
	["stomps", 6, "PISOTONES", "DERROTA %d ENEMIGOS PISÁNDOLOS", 1, 70, "sum"],
	["run_combo", 15, "EN RACHA", "LOGRA UN COMBO DE %d EN UNA PARTIDA", 2, 100, "max"],
	["flawless", 1, "SIN UN RASGUÑO", "SUPERA %d NIVEL SIN RECIBIR DAÑO", 2, 100, "sum"],
	["jump", 120, "SALTARÍN", "SALTA %d VECES", 0, 50, "sum"],
	["jump_full", 15, "SALTO MÁXIMO", "HAZ %d SALTOS MANTENIENDO HASTA EL TOPE", 1, 70, "sum"],
	["jump_tap", 20, "TOQUES CORTOS", "HAZ %d SALTOS MÍNIMOS CON UN TOQUE", 1, 70, "sum"],
	["nights", 1, "VIGILIA", "SOBREVIVE A %d NOCHE", 2, 100, "sum"],
	["perfect_dodge", 5, "ESQUIVA", "ESQUIVA %d PROYECTILES EN EL ÚLTIMO MOMENTO", 2, 100, "sum"],
	["rank_a", 2, "BUENA NOTA", "SUPERA %d NIVELES CON RANGO A O MEJOR", 1, 90, "sum"],
	["challenges_met", 2, "RETADOR", "CUMPLE %d RETOS DE NIVEL", 1, 80, "sum"],
	["endless_distance", 800, "MODO INFINITO", "RECORRE %d M EN UNA PARTIDA INFINITA", 1, 80, "max"],
	["bounce", 5, "MUELLES", "REBOTA %d VECES CON PRECISIÓN", 1, 70, "sum"],
	["turbo_clear", 1, "PISA A FONDO", "SUPERA %d NIVEL ENTERO A 2X", 2, 110, "sum"],
	["coins_run", 150, "BOLSA LLENA", "RECOGE %d MONEDAS EN UNA PARTIDA", 1, 80, "max"],
	["kills_run", 20, "ARRASA", "DERROTA %d ENEMIGOS EN UNA PARTIDA", 2, 90, "max"],
	["rapid_lightning", 1, "RELÁMPAGO", "SUPERA %d RAPID SIX EN MENOS DE 0.6 S", 3, 130, "sum"],
	["perfects", 40, "PRECISIÓN DIARIA", "HAZ %d ACCIONES PERFECT", 1, 80, "sum"],
	["run_distance", 1000, "LARGA CARRERA", "RECORRE %d M EN UNA SOLA PARTIDA", 1, 80, "max"],
	["boss_hit", 5, "ATACA AL JEFE", "GOLPEA %d VECES A UN JEFE", 2, 100, "sum"],
]

## [stat, objetivo, nombre, descripcion, dificultad, monedas, diamantes, modo]
const WEEKLY := [
	["coins_picked", 600, "FIEBRE DEL ORO", "RECOGE %d MONEDAS", 1, 400, 1, "sum"],
	["kills", 120, "CAZA SEMANAL", "DERROTA %d ENEMIGOS", 1, 400, 1, "sum"],
	["distance", 12000, "MARATÓN", "RECORRE %d METROS", 1, 400, 1, "sum"],
	["gems_picked", 30, "COLECCIÓN DE GEMAS", "RECOGE %d GEMAS", 2, 450, 1, "sum"],
	["run", 20, "CONSTANCIA", "JUEGA %d PARTIDAS", 0, 300, 1, "sum"],
	["perfect_jump", 200, "SALTADOR DE ÉLITE", "HAZ %d SALTOS PERFECT", 2, 500, 1, "sum"],
	["perfect_land", 60, "PIES DE PLUMA", "HAZ %d ATERRIZAJES PERFECT", 2, 500, 1, "sum"],
	["perfect_attack", 150, "ESPADACHÍN", "ASESTA %d GOLPES PERFECT", 2, 500, 1, "sum"],
	["legendaries", 40, "CAZADOR DEL INSTANTE", "HAZ %d ACCIONES LEGENDARY", 3, 650, 2, "sum"],
	["level_clear", 20, "SEMANA DE AVENTURAS", "SUPERA %d NIVELES", 1, 450, 1, "sum"],
	["three_star", 8, "CIELO ESTRELLADO", "CONSIGUE 3 ESTRELLAS EN %d NIVELES", 2, 550, 1, "sum"],
	["rapid_success", 25, "MARTILLO SEMANAL", "SUPERA %d RAPID SIX", 2, 500, 1, "sum"],
	["stomps", 50, "APLASTADOR", "DERROTA %d ENEMIGOS PISÁNDOLOS", 1, 450, 1, "sum"],
	["run_combo", 35, "COMBO DE LA SEMANA", "LOGRA UN COMBO DE %d EN UNA PARTIDA", 3, 650, 2, "max"],
	["flawless", 6, "INTOCABLE", "SUPERA %d NIVELES SIN RECIBIR DAÑO", 3, 650, 2, "sum"],
	["jump", 1000, "MIL SALTOS", "SALTA %d VECES", 0, 300, 1, "sum"],
	["jump_full", 120, "ALTURA MÁXIMA", "HAZ %d SALTOS MANTENIENDO HASTA EL TOPE", 1, 400, 1, "sum"],
	["jump_tap", 150, "TOQUE MAESTRO", "HAZ %d SALTOS MÍNIMOS", 2, 450, 1, "sum"],
	["nights", 5, "GUARDIÁN NOCTURNO", "SOBREVIVE A %d NOCHES", 3, 600, 2, "sum"],
	["perfect_dodge", 40, "BAILARÍN", "ESQUIVA %d PROYECTILES EN EL ÚLTIMO MOMENTO", 3, 600, 2, "sum"],
	["rank_a", 15, "ALUMNO EJEMPLAR", "SUPERA %d NIVELES CON RANGO A O MEJOR", 2, 550, 1, "sum"],
	["challenges_met", 15, "RETOS SEMANALES", "CUMPLE %d RETOS DE NIVEL", 2, 500, 1, "sum"],
	["endless_distance", 2500, "SIN FIN", "RECORRE %d M EN UNA PARTIDA INFINITA", 3, 600, 2, "max"],
	["bounce", 40, "RESORTE", "REBOTA %d VECES CON PRECISIÓN", 2, 450, 1, "sum"],
	["turbo_clear", 6, "SEMANA TURBO", "SUPERA %d NIVELES ENTEROS A 2X", 3, 650, 2, "sum"],
	["coins_run", 400, "COFRE REPLETO", "RECOGE %d MONEDAS EN UNA PARTIDA", 2, 500, 1, "max"],
	["kills_run", 45, "TORMENTA DE ACERO", "DERROTA %d ENEMIGOS EN UNA PARTIDA", 3, 600, 2, "max"],
	["rapid_lightning", 8, "TORMENTA ELÉCTRICA", "SUPERA %d RAPID SIX EN MENOS DE 0.6 S", 4, 800, 3, "sum"],
	["perfects", 350, "SEMANA PRECISA", "HAZ %d ACCIONES PERFECT", 2, 500, 1, "sum"],
	["run_distance", 3000, "ULTRAFONDO", "RECORRE %d M EN UNA SOLA PARTIDA", 3, 600, 2, "max"],
	["boss_hit", 40, "AZOTE DE JEFES", "GOLPEA %d VECES A LOS JEFES", 2, 550, 1, "sum"],
	["boss_kill", 2, "CAZA MAYOR", "DERROTA A %d JEFES", 3, 700, 2, "sum"],
	["mode_clear", 3, "DOMINADOR SEMANAL", "SUPERA %d MODOS DE DOMINIO", 3, 650, 2, "sum"],
	["rank_s", 5, "NOTA MÁXIMA", "SUPERA %d NIVELES CON RANGO S O MEJOR", 3, 700, 2, "sum"],
	["rapid_extreme", 3, "EXTREMO", "SUPERA %d RAPID SIX EXTREMOS", 3, 650, 2, "sum"],
	["login", 5, "VISITA FRECUENTE", "JUEGA %d DÍAS DISTINTOS ESTA SEMANA", 0, 350, 1, "sum"],
	["daily_claimed", 12, "DISCIPLINA", "COBRA %d MISIONES DIARIAS", 1, 500, 2, "sum"],
	["level_new", 5, "TIERRA NUEVA", "SUPERA %d NIVELES POR PRIMERA VEZ", 2, 550, 1, "sum"],
	["rapid_streak_run", 6, "CADENA RAPID", "SUPERA %d RAPID SIX SEGUIDOS SIN FALLAR", 3, 650, 2, "max"],
	["level_legendary", 12, "MOMENTOS ÉPICOS", "HAZ %d LEGENDARY EN UN SOLO NIVEL", 4, 800, 3, "max"],
]

## Plantillas por mundo (5 mundos x 10 = 50).
## [stat, objetivo, nombre (%s mundo), descripcion, dificultad, monedas base, diamantes]
const WORLD_TEMPLATES := [
	["level_unique@w", 10, "EXPLORA %s", "SUPERA 10 NIVELES DISTINTOS DE %s", 1, 250, 0],
	["level_unique@w", 20, "CONQUISTA %s", "SUPERA LOS 20 NIVELES DE %s", 2, 500, 2],
	["kills@w", 150, "LIMPIA %s", "DERROTA 150 ENEMIGOS EN %s", 1, 300, 0],
	["kill_c0@w", 25, "CAZA: %s", "DERROTA 25 VECES A ESTE ENEMIGO", 1, 250, 0],
	["kill_c2@w", 25, "CAZA: %s", "DERROTA 25 VECES A ESTE ENEMIGO", 1, 250, 0],
	["kill_c4@w", 25, "CAZA: %s", "DERROTA 25 VECES A ESTE ENEMIGO", 2, 300, 1],
	["three_star_levels@w", 10, "ESTRELLAS DE %s", "CONSIGUE 3 ESTRELLAS EN 10 NIVELES DE %s", 2, 450, 1],
	["perfects@w", 300, "PRECISIÓN EN %s", "HAZ 300 ACCIONES PERFECT EN %s", 2, 400, 1],
	["rapid_success@w", 10, "MURALLAS DE %s", "SUPERA 10 RAPID SIX EN %s", 2, 350, 0],
	["coins_picked@w", 2000, "TESORO DE %s", "RECOGE 2000 MONEDAS EN %s", 1, 300, 0],
]

## [stat, objetivos, nombres, descripcion, dificultades, monedas, diamantes]
const MASTERY := [
	["best_combo", [20, 40, 60, 80, 100], ["RITMO", "CADENCIA", "SINFONÍA", "TRANCE", "PERFECCIÓN"], "LOGRA UN COMBO PERFECTO DE %d", [1, 2, 3, 4, 4], [300, 700, 1500, 3000, 6000], [0, 1, 2, 3, 5]],
	["perfects", [250, 1000, 3000, 8000], ["MANO FIRME", "OJO CLÍNICO", "CIRUJANO", "RELOJERO"], "HAZ %d ACCIONES PERFECT", [1, 2, 3, 4], [300, 800, 2000, 5000], [0, 1, 2, 4]],
	["legendaries", [50, 250, 750, 2000], ["CHISPA", "DESTELLO", "FULGOR", "LEYENDA FUGAZ"], "HAZ %d ACCIONES LEGENDARY", [1, 2, 3, 4], [400, 1000, 2500, 6000], [0, 1, 2, 4]],
	["rank_s", [5, 25, 60], ["SOBRESALIENTE", "MATRÍCULA", "CUM LAUDE"], "SUPERA %d NIVELES CON RANGO S O MEJOR", [2, 3, 4], [600, 2000, 5000], [1, 2, 4]],
	["rank_sss", [1, 10], ["TRIPLE S", "COLECCIÓN SSS"], "SUPERA %d NIVELES CON RANGO SSS", [3, 4], [1500, 6000], [2, 5]],
	["flawless", [5, 20, 50], ["CUIDADOSO", "IMPOLUTO", "INTACTO"], "SUPERA %d NIVELES SIN RECIBIR DAÑO", [1, 2, 3], [400, 1200, 3000], [0, 1, 3]],
	["mode_clear", [5, 20, 50, 100], ["APRENDIZ DE MODOS", "ADEPTO", "VIRTUOSO", "GRAN MAESTRO"], "SUPERA %d MODOS DE DOMINIO", [1, 2, 3, 4], [400, 1200, 3000, 7000], [1, 2, 3, 5]],
	["three_star_levels", [25, 50, 75, 100], ["CONSTELACIÓN", "GALAXIA", "NEBULOSA", "UNIVERSO"], "CONSIGUE 3 ESTRELLAS EN %d NIVELES", [1, 2, 3, 4], [600, 1500, 3500, 8000], [1, 2, 3, 6]],
	["turbo_clear", [10, 40], ["ACELERADO", "SUPERSÓNICO"], "SUPERA %d NIVELES ENTEROS A 2X", [2, 3], [800, 2500], [1, 2]],
	["perfect_land", [50, 200], ["GATO", "ATERRIZAJE DE SEDA"], "HAZ %d ATERRIZAJES PERFECT", [1, 2], [400, 1200], [0, 1]],
	["perfect_dodge", [25, 100], ["ESCURRIDIZO", "FANTASMA"], "ESQUIVA %d PROYECTILES EN EL ÚLTIMO MOMENTO", [2, 3], [600, 1800], [1, 2]],
	["level_legendary", [10, 20], ["NIVEL ÉPICO", "NIVEL MÍTICO"], "HAZ %d LEGENDARY EN UN SOLO NIVEL", [3, 4], [1200, 4000], [1, 3]],
	["jump_full", [200, 1000], ["ALAS", "VUELO"], "HAZ %d SALTOS MANTENIENDO HASTA EL TOPE", [1, 2], [300, 900], [0, 1]],
	["challenge_new", [30, 150], ["RETADOR NATO", "SIN RETOS PENDIENTES"], "CUMPLE %d RETOS DE NIVEL DISTINTOS", [2, 3], [800, 3000], [1, 3]],
]

## Misiones de jefe por mundo (5 x 5) y cinco globales.
## [stat, objetivo, nombre, descripcion, dificultad, monedas base, diamantes]
const BOSS_TEMPLATES := [
	["boss_kill@w", 1, "DERROTA A %s", "VENCE AL JEFE DEL MUNDO", 1, 400, 1],
	["boss_kill@w", 3, "CAZADOR DE %s", "VENCE 3 VECES AL JEFE DEL MUNDO", 2, 600, 1],
	["boss_flawless@w", 1, "%s SIN DAÑO", "VENCE AL JEFE SIN RECIBIR NINGÚN GOLPE", 3, 1000, 2],
	["boss_rapid@w", 5, "ROMPE %s", "SUPERA 5 RAPID SIX DE ESTE JEFE", 2, 500, 1],
	["boss_fast@w", 1, "%s EXPRÉS", "VENCE AL JEFE ANTES DEL TIEMPO OBJETIVO", 3, 800, 2],
]
const BOSS_GLOBAL := [
	["boss_kill", 10, "MATAJEFES", "DERROTA %d JEFES", 2, 2000, 2, "sum"],
	["boss_kill", 25, "AZOTE DE TIRANOS", "DERROTA %d JEFES", 3, 5000, 4, "sum"],
	["boss_flawless", 5, "NI UN RASGUÑO", "VENCE A %d JEFES SIN RECIBIR DAÑO", 4, 6000, 5, "sum"],
	["boss_rapid", 50, "MARTILLO DE JEFES", "SUPERA %d RAPID SIX DE JEFE", 3, 3000, 3, "sum"],
	["worlds_conquered", 5, "LIBERADOR", "LIBERA LOS %d MUNDOS", 4, 8000, 6, "max"],
]

## [stat, objetivo, nombre, descripcion, pista, dificultad, monedas, diamantes, modo]
const SECRET := [
	["rapid_last_click", 1, "POR LOS PELOS", "TERMINA UN RAPID SIX CON MENOS DE 0.15 S", "ALGO SOBRE APURAR EL TIEMPO", 2, 500, 1, "sum"],
	["rapid_last_click", 10, "ADICTO AL LÍMITE", "TERMINA %d RAPID SIX CON MENOS DE 0.15 S", "REPITE LA HAZAÑA DEL ÚLTIMO INSTANTE", 4, 2500, 3, "sum"],
	["rapid_fail", 10, "DEDOS DE MANTEQUILLA", "FALLA %d RAPID SIX", "NO SIEMPRE SE GANA", 0, 200, 0, "sum"],
	["death", 50, "PERSEVERANCIA", "CAE %d VECES Y SIGUE INTENTÁNDOLO", "CAER TAMBIÉN ENSEÑA", 0, 300, 0, "sum"],
	["death", 250, "INMORTAL DE ESPÍRITU", "CAE %d VECES", "CAER MUCHO, MUCHO", 1, 1000, 1, "sum"],
	["nights", 10, "HIJO DE LA LUNA", "SOBREVIVE A %d NOCHES", "LA OSCURIDAD ESCONDE ALGO", 2, 900, 1, "sum"],
	["jump_tap", 500, "PLUMA", "HAZ %d SALTOS MÍNIMOS", "MENOS ES MÁS", 1, 600, 1, "sum"],
	["stomps", 200, "PESO PLUMA... O NO", "DERROTA %d ENEMIGOS PISÁNDOLOS", "DESDE ARRIBA SE VE MEJOR", 2, 900, 1, "sum"],
	["endless_distance", 3000, "MÁS ALLÁ DEL MAPA", "RECORRE %d M EN UNA PARTIDA INFINITA", "EL CAMINO NO TERMINA", 3, 1500, 2, "max"],
	["bounce", 100, "SALTIMBANQUI", "REBOTA %d VECES CON PRECISIÓN", "TODO LO QUE SUBE...", 1, 600, 1, "sum"],
	["pacifist", 1, "PACIFISTA", "SUPERA UN NIVEL CON ENEMIGOS SIN DERROTAR A NINGUNO", "NO TODO SE RESUELVE A ESPADAZOS", 3, 1200, 2, "sum"],
	["slow_clear", 1, "TURISTA", "SUPERA UN NIVEL TARDANDO EL DOBLE DEL TIEMPO OBJETIVO", "DISFRUTA DEL PAISAJE", 1, 400, 1, "sum"],
	["comeback", 1, "AL BORDE", "SUPERA UN NIVEL TRAS RECIBIR 3 GOLPES O MÁS", "AGUANTA HASTA EL FINAL", 1, 500, 1, "sum"],
	["turbo_s", 1, "BÓLIDO", "SUPERA UN NIVEL ENTERO A 2X CON RANGO S", "RÁPIDO Y BIEN", 3, 1500, 2, "sum"],
	["abyss_worn", 1, "VUELTA DEL ABISMO", "SUPERA UN NIVEL CON EL CONJUNTO DEL ABISMO COMPLETO", "VÍSTETE DE OSCURIDAD", 3, 2000, 3, "sum"],
	["rapid_lightning", 10, "TRUENO", "SUPERA %d RAPID SIX EN MENOS DE 0.6 S", "MÁS RÁPIDO QUE LA LUZ", 4, 2500, 3, "sum"],
	["rapid_streak", 15, "IMPARABLE", "SUPERA %d RAPID SIX SEGUIDOS", "NO FALLES NI UNO", 3, 1500, 2, "max"],
	["coins_spent", 100000, "DERROCHADOR", "GASTA %d MONEDAS", "EL DINERO ESTÁ PARA GASTARLO", 2, 3000, 2, "sum"],
	["buy_cosmetic", 20, "FASHIONISTA", "COMPRA %d COSMÉTICOS", "LA IMAGEN LO ES TODO", 2, 1500, 2, "sum"],
	["login", 30, "FIEL", "JUEGA %d DÍAS DISTINTOS", "VUELVE CADA DÍA", 2, 2000, 3, "sum"],
	["perfect_dodge", 250, "INTANGIBLE", "ESQUIVA %d PROYECTILES EN EL ÚLTIMO MOMENTO", "QUE NO TE TOQUEN", 4, 3000, 3, "sum"],
	["level_legendary", 30, "TOCADO POR LOS DIOSES", "HAZ %d LEGENDARY EN UN SOLO NIVEL", "UN NIVEL PARA EL RECUERDO", 4, 4000, 4, "max"],
	["nodeath_streak", 20, "INCANSABLE", "SUPERA %d NIVELES SEGUIDOS SIN CAER", "SIGUE Y SIGUE", 3, 2000, 2, "max"],
	["flawless_streak", 10, "CRISTAL", "SUPERA %d NIVELES SEGUIDOS SIN RECIBIR DAÑO", "NI UN SOLO GOLPE", 4, 3500, 3, "max"],
	["kills_run", 60, "HURACÁN", "DERROTA %d ENEMIGOS EN UNA PARTIDA", "NADIE QUEDA EN PIE", 3, 1500, 2, "max"],
	["speed_toggle", 50, "INDECISO", "CAMBIA LA VELOCIDAD %d VECES", "¿RÁPIDO O NORMAL?", 0, 300, 0, "sum"],
	["boss_hit", 500, "MARTILLO PILÓN", "GOLPEA %d VECES A LOS JEFES", "LOS GRANDES CAEN DESPACIO", 2, 1500, 2, "sum"],
	["pause", 25, "TOMANDO AIRE", "PAUSA LA PARTIDA %d VECES", "RESPIRA", 0, 200, 0, "sum"],
	["retry", 30, "OTRA MÁS", "REINTENTA UN NIVEL %d VECES", "SOLO UNA MÁS...", 0, 300, 0, "sum"],
	["three_star_flawless", 10, "OBRA MAESTRA", "CONSIGUE 3 ESTRELLAS SIN DAÑO EN %d NIVELES", "ESTRELLAS SIN CICATRICES", 3, 2000, 2, "sum"],
]

## [stat, objetivos, nombres, descripcion, monedas, diamantes]
const PROGRESSION := [
	["level_unique", [1, 5, 10, 25, 40, 60, 80, 100], ["EL PRIMER PASO", "EN MARCHA", "VIAJERO", "CAMINANTE", "TROTAMUNDOS", "PEREGRINO", "VETERANO", "HÉROE COMPLETO"], "SUPERA %d NIVELES DISTINTOS", [50, 150, 300, 600, 1000, 1600, 2400, 4000], [0, 0, 1, 1, 1, 2, 2, 4]],
	["worlds_conquered", [1, 2, 3, 4, 5], ["PRIMERA VICTORIA", "DOS MUNDOS", "TRES MUNDOS", "CUATRO MUNDOS", "LOS CINCO MUNDOS"], "LIBERA %d MUNDOS", [500, 1200, 2500, 4500, 8000], [1, 2, 3, 4, 6]],
	["tree_bought", [1, 10, 25, 50, 100, 200], ["PRIMERA MEJORA", "RAÍCES", "TRONCO", "RAMAS", "COPA", "ÁRBOL MILENARIO"], "COMPRA %d NIVELES DEL ÁRBOL", [50, 200, 500, 1000, 2500, 6000], [0, 0, 1, 1, 2, 4]],
	["buy_cosmetic", [1, 5, 15, 30], ["NUEVO LOOK", "ARMARIO", "VESTIDOR", "PASARELA"], "COMPRA %d COSMÉTICOS", [50, 200, 600, 1500], [0, 1, 1, 2]],
	["buy_power", [1, 5, 10], ["PODER NUEVO", "ARSENAL", "TODOS LOS PODERES"], "COMPRA %d POWER-UPS", [100, 500, 1500], [0, 1, 2]],
	["stars_gained", [30, 90, 180, 300], ["ESTRELLADO", "LLUVIA DE ESTRELLAS", "VÍA LÁCTEA", "TODAS LAS ESTRELLAS"], "CONSIGUE %d ESTRELLAS", [300, 800, 2000, 5000], [0, 1, 2, 4]],
	["missions_claimed", [10, 50, 150], ["CUMPLIDOR", "RESPONSABLE", "INFALIBLE"], "COBRA %d MISIONES", [200, 800, 2500], [0, 1, 3]],
]

static var _all: Array = []
static var _by_id: Dictionary = {}


static func world_name(world: int) -> String:
	return String(Campaign.theme(world).get("name", "MUNDO %d" % (world + 1)))


static func boss_name(world: int) -> String:
	var boss: Dictionary = Campaign.BOSSES[clampi(world, 0, Campaign.BOSSES.size() - 1)]
	return String(boss["name"])


static func _mission(id: String, cat: String, stat: String, target: int, name: String, desc: String, diff: int, coins: int, gems: int, mode: String = "sum") -> Dictionary:
	return {"id": id, "cat": cat, "stat": stat, "target": target, "name": name, "desc": desc, "diff": diff, "coins": coins, "gems": gems, "mode": mode}


static func _text(desc: String, target: int) -> String:
	return desc % target if desc.contains("%d") else desc


## Todas las misiones (se construyen una vez).
static func all() -> Array:
	if not _all.is_empty():
		return _all
	for i in DAILY.size():
		var d: Array = DAILY[i]
		_add(_mission("d_%d" % i, "diaria", String(d[0]), int(d[1]), String(d[2]), _text(String(d[3]), int(d[1])), int(d[4]), int(d[5]), 0, String(d[6])))
	for i in WEEKLY.size():
		var w: Array = WEEKLY[i]
		_add(_mission("s_%d" % i, "semanal", String(w[0]), int(w[1]), String(w[2]), _text(String(w[3]), int(w[1])), int(w[4]), int(w[5]), int(w[6]), String(w[7])))
	for world in Campaign.world_count():
		var factor: float = Campaign.world_reward(world)
		for i in WORLD_TEMPLATES.size():
			var t: Array = WORLD_TEMPLATES[i]
			var stat: String = String(t[0]).replace("@w", "@w%d" % world)
			var label: String = world_name(world)
			if stat.begins_with("kill_c"):
				var index: int = int(stat.substr(6, 1))
				label = String(Bestiary.entry(world, index)[0])
			var name: String = String(t[2]) % label
			var desc: String = String(t[3]).replace("%s", world_name(world))
			var entry: Dictionary = _mission("w%d_%d" % [world, i], "mundo", stat, int(t[1]), name, desc, int(t[4]), int(float(t[5]) * factor), int(t[6]))
			entry["world"] = world
			_add(entry)
	for row in MASTERY:
		var m: Array = row
		var targets: Array = m[1]
		for j in targets.size():
			_add(_mission("m_%s_%d" % [String(m[0]), j], "maestria", String(m[0]), int(targets[j]), String(m[2][j]), _text(String(m[3]), int(targets[j])), int(m[4][j]), int(m[5][j]), int(m[6][j]), "max" if String(m[0]) == "best_combo" or String(m[0]) == "level_legendary" else "sum"))
	for world in Campaign.world_count():
		var factor: float = Campaign.world_reward(world)
		for i in BOSS_TEMPLATES.size():
			var b: Array = BOSS_TEMPLATES[i]
			var entry: Dictionary = _mission("b%d_%d" % [world, i], "jefe", String(b[0]).replace("@w", "@w%d" % world), int(b[1]), String(b[2]) % boss_name(world), String(b[3]), int(b[4]), int(float(b[5]) * factor), int(b[6]))
			entry["world"] = world
			_add(entry)
	for i in BOSS_GLOBAL.size():
		var g: Array = BOSS_GLOBAL[i]
		_add(_mission("bg_%d" % i, "jefe", String(g[0]), int(g[1]), String(g[2]), _text(String(g[3]), int(g[1])), int(g[4]), int(g[5]), int(g[6]), String(g[7])))
	for i in SECRET.size():
		var s: Array = SECRET[i]
		var entry: Dictionary = _mission("x_%d" % i, "secreta", String(s[0]), int(s[1]), String(s[2]), _text(String(s[3]), int(s[1])), int(s[5]), int(s[6]), int(s[7]), String(s[8]))
		entry["hint"] = String(s[4])
		_add(entry)
	for row in PROGRESSION:
		var p: Array = row
		var targets: Array = p[1]
		for j in targets.size():
			var mode: String = "max" if String(p[0]) == "worlds_conquered" else "sum"
			_add(_mission("p_%s_%d" % [String(p[0]), j], "progresion", String(p[0]), int(targets[j]), String(p[2][j]), _text(String(p[3]), int(targets[j])), mini(j, 4), int(p[4][j]), int(p[5][j]), mode))
	return _all


static func _add(entry: Dictionary) -> void:
	_all.append(entry)
	_by_id[String(entry["id"])] = entry


static func find(id: String) -> Dictionary:
	all()
	return _by_id.get(id, {})


static func by_category(cat: String) -> Array:
	var list: Array = []
	for item in all():
		var entry: Dictionary = item
		if String(entry["cat"]) == cat:
			list.append(entry)
	return list


static func category_name(cat: String) -> String:
	var index: int = CATEGORIES.find(cat)
	return String(CATEGORY_NAMES[index]) if index >= 0 else cat.to_upper()


static func category_color(cat: String) -> Color:
	var index: int = CATEGORIES.find(cat)
	return Color(String(CATEGORY_COLORS[index])) if index >= 0 else Color("94b0c2")
