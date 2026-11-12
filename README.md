# ONE BUTTON HERO

Endless runner arcade 2D para **Godot 4** (GDScript 2.0) que se juega con **un solo botón**
(más tres poderes opcionales). No contiene ningún recurso externo: los gráficos pixel art,
la fuente, las partículas, las luces, los efectos de sonido y las seis canciones se generan por código.

## Cómo abrirlo

1. En Godot 4 (versión **4.2 o superior**): *Importar* → selecciona `project.godot` → *Abrir*.
2. Pulsa **F5**. La escena principal es `scenes/main_menu.tscn`.

## Controles (un solo botón: Espacio, clic o toque)

| Acción | Cómo |
| --- | --- |
| Saltar | Pulsar |
| Salto alto / largo | Mantener pulsado |
| Salto corto (techos bajos) | Tocar y soltar enseguida |
| Atacar | Pulsar con un enemigo delante (aparece **!**) |
| Pulsación rápida | Pulsar muy seguido contra barricadas y brutos |
| Pisotón | Pulsar mientras caes desde lo alto |
| Super rebote | Pulsar justo al pisar un trampolín |
| Pausa | **Esc** o el botón de pausa |

**Un solo golpe mata.** No hay vidas ni poderes activables.

## Campaña y timing (fase 1 de la gran expansión)

- **Campaña**: 5 mundos (Verdantia, Infernus, Amethystia, Frostfall, Solaris) × 20 niveles con
  recorrido fijo, meta, estrellas, rango de D a SSS, récord y recompensas. Mapa de niveles en el menú.
- **Timing**: cada salto, ataque y esquiva se evalúa según lo cerca del peligro que se ejecuta:
  GOOD, PERFECT, LEGENDARY y LAST SECOND, con texto, sonido, partículas y puntos propios.
  Las ventanas se configuran en `scripts/timing.gd` y se estrechan en cada mundo.
- **Combo de precisión**: 3, 5, 8, 12 y 20 acciones perfectas seguidas dan x1,5 a x5. Recibir daño lo rompe.
- **Soul Reaper**: (eliminado en el overhaul, junto con el resto de poderes activables).
- **Diamantes**: se ganan en los niveles 5, 10, 15 y 20 de cada mundo y al lograr tres estrellas.
- **Modo infinito**: la partida sin fin original sigue disponible desde el menú.

### Fase 2

- **Jefes**: el nivel 20 de cada mundo es un combate contra su jefe (The Ancient Root, The Infernal
  King, The Crystal Empress, The Frozen Titan, The Sand Devourer): barra de vida, tres fases, avisos,
  fintas, oleadas que se saltan, proyectiles que se devuelven de un golpe y una ventana de
  vulnerabilidad en la que el daño depende del timing. Datos en `BOSSES` (`scripts/campaign.gd`).
- **Enemigos nuevos**: lobo, gólem de cristal, momia, murciélago de fuego y espíritu de ventisca;
  cada mundo sustituye y recolorea parte de las criaturas básicas.
- **Tienda de diamantes**: espadas, estelas y auras exclusivas con rareza (Rare, Epic, Legendary,
  Mythic) dentro de sus pestañas; la tienda ahora tiene páginas.
- **Mejoras ampliadas**: Fortuna, Alcance, Maestría, Botín de combo y Recuperación.
- **Retos por nivel**: tres retos opcionales por nivel (sin daño, combo, Legendary, Perfect, precisión).
- **Depuración**: la tecla **F3** muestra en partida las ventanas de timing, el margen de la última
  acción, la distancia y el tiempo al próximo peligro, el combo y la dificultad.

### Fase 3

- **Curva de dificultad** por tramos (1-4, 5-8, 9-12, 13-16, 17-19 y jefe) que no se reinicia entre
  mundos: cada mundo arranca más rápido que el final del anterior y con ventanas de timing más estrechas.
- **Modos de dominio** (opcionales, al superar un nivel): Precisión, Sin daño, Combo perfecto,
  Contrarreloj y Solo Legendary. Se eligen en el mapa; el primero superado da monedas y un diamante.
- **Rango** con precisión, Legendary, combo, daño, enemigos derrotados, recompensas y tiempo.
- **Hitos de campaña**: nivel 1 bono inicial, nivel 5 espada, 10 aura, 15 estela y 20 aspecto de héroe
  exclusivo de cada mundo; premios por combos de 10, 20, 30 y 50; logros nuevos.
- **Árbol de mejoras** en cuatro ramas (monedas, combate, supervivencia, precisión), con requisitos y
  hasta cinco niveles: incluye Armadura, Salto maestro y Esquiva maestra.
- **Mecánicas por mundo**: pinchos de espinas, lava, cristal, hielo y arena; plataformas que se derrumban
  (Infernus, Solaris) o parpadean (Amethystia); hielo que acelera (Frostfall); trampas rítmicas
  (sobre todo en Solaris); ventiscas y tormentas de arena.
- **Rutas segura y arriesgada**: abajo un solo salto; arriba plataforma del mundo, un peligro y muchas
  recompensas, con un diamante oculto por nivel.
- **Timing de aterrizaje**: caer justo tras el borde de un hueco da ATERRIZAJE PERFECT/LEGENDARY.
- **Desafío semanal** (tres misiones, un diamante cada una) y **recompensa diaria** por racha.
- **Música**: tema propio por mundo con variante nocturna, jefes, victoria y recompensas; la música
  se acelera con el combo. Efectos nuevos: pasos, esquiva, combo, diamante, desbloqueo, golpe de jefe.
- **Estela de carrera** que sigue al héroe, se tiñe con el aura y crece con la velocidad; **tajos**
  con arcos, líneas de movimiento, destellos y ondas que crecen con PERFECT y LEGENDARY.

### Overhaul (un golpe, mecánicas de un botón, árbol de mejoras)

- **Sin vidas**: cualquier golpe o caída termina el intento. Reinicio rápido desde el Game Over.
- **Mecánicas nuevas de un botón**, introducidas poco a poco en el mundo 1: saltos encadenados (1-2),
  pisotón (1-3), techo bajo / salto corto (1-4), barricada de pulsación rápida (1-7) y trampolín (1-11).
- **Cinco enemigos propios por mundo** (`scripts/bestiary.gd` y `scripts/creature.gd`), que se estrenan
  en los niveles 1, 5, 9, 13 y 16 de su mundo y después se combinan: perseguidor (llega por detrás),
  centinela (solo vulnerable al brillar), bruto (pulsación rápida), cambiante (alterna suelo y aire),
  saltarín, torreta, excavador (sale del suelo) y divisible (se parte en dos).
- **Más obstáculos por nivel**: menos espacio entre peligros, siempre con tiempo de reacción.
- **Sin poderes activables ni categoría Objetos**: Turbo, Onda y Soul Reaper y los consumibles se han
  eliminado. Lo gastado en ellos o en las mejoras antiguas se reembolsa al cargar la partida.
- **Dos power-ups de tienda** (pestaña PODERES, se activan o desactivan): **Pluma de Fénix** (9000;
  sobrevives a un golpe una vez por intento, pierdes el combo y el rango máximo baja a A) y **Ojo de
  Halcón** (7000; marca el punto de salto PERFECT, a cambio de −15% de puntos).
- **Cosméticos con buffs**: cada héroe, espada, estela y aura tiene un buff pequeño (las espadas, alcance
  de +0% a +3.5%). La tienda muestra el buff exacto antes de comprar y lo compara con lo equipado. Solo
  cuentan los cosméticos equipados.
- **Árbol de mejoras** (botón MEJORAS del menú): 31 nodos en seis ramas (movimiento, precisión, combate,
  supervivencia, economía y especialización), con niveles, requisitos, líneas de conexión y
  especializaciones por parejas incompatibles. Datos en `TREE` de `scripts/catalog.gd`.
- Los buffs de todo (cosméticos, power-ups y árbol) se suman en `scripts/buffs.gd`.

## Contenido

- **Ciclo de día y noche** continuo (amanecer, mañana, mediodía, atardecer, noche): cielo, luz
  ambiental, sombras proyectadas, sol y luna, estrellas, luciérnagas, ventanas encendidas y música
  cambian con la hora. De noche los puntos valen x1,5 y aparecen espectros.
- **Tienda** (menú y Game Over): mejoras permanentes (imán, multiplicador, escudo, puntuación,
  recompensa, energía), objetos de un uso (revivir, protección, doble botín, superimán) y
  personalización (6 héroes, 6 espadas, 5 estelas, 4 auras). Todo se guarda al instante.
- **Enemigos**: baba, diablillo, murciélago, escudero (dos golpes) y espectro nocturno.
- **Obstáculos**: pinchos, llamas, rocas, tótems, rocas rodantes, huecos y plataformas.
- **Recompensas**: monedas, rubíes, gemas, corazones, estrellas de invencibilidad y cofres.
- **Eventos aleatorios**: lluvia de monedas, horda y fiebre del oro. Combo de puntos por
  enemigos seguidos sin recibir daño y premio cada 250 metros.
- **Progresión**: tres misiones diarias, 14 logros con recompensa y estadísticas permanentes.
- **Audio**: música de menú, día, atardecer, noche, tienda y Game Over con fundido cruzado;
  volumen y silencio independientes para música y efectos.

El perfil se guarda en `user://one_button_hero.cfg` (ConfigFile).

## Estructura

```
project.godot
scenes/   main_menu, game, player, enemy, coin, obstacle, hud
scripts/
  game_data.gd       Autoload: perfil, monedero, compras, misiones, logros, ajustes
  sfx.gd             Autoload: sintetizador de efectos y de las seis canciones
  transition.gd      Autoload: fundido entre pantallas
  catalog.gd         Cosméticos con buffs, power-ups, árbol de mejoras, logros y misiones
  buffs.gd           Suma de buffs activos (cosméticos equipados, power-ups, árbol)
  bestiary.gd        Cinco enemigos por mundo y cuándo aparecen
  creature.gd        Comportamiento de los enemigos nuevos
  skill_tree.gd      Pantalla del árbol de mejoras
  daylight.gd        Ciclo de día y noche (hora, luz ambiental, sombras)
  campaign.gd        Mundos y niveles de la campaña
  timing.gd          Ventanas de timing, combos y rangos
  precision.gd       Árbitro del timing durante la partida
  campaign_map.gd    Mapa de selección de niveles
  game.gd            Reglas de la partida, dificultad, poderes, eventos
  player.gd          Movimiento, salto variable, ataque, escudo, turbo, cosméticos
  level_generator.gd Generación procedural por patrones
  enemy.gd / coin.gd / obstacle.gd / platform.gd / ground_span.gd
  background.gd      Fondo parallax sincronizado con la hora
  lights.gd          Resplandores aditivos, halo del héroe y luciérnagas
  ground_renderer.gd Dibujo del suelo visible
  hud.gd / hud_bar.gd   Interfaz de partida
  main_menu.gd / shop.gd / shop_card.gd / hero_preview.gd / progress_panel.gd / toaster.gd
  fx.gd              Ráfagas de partículas y textos flotantes
  sprites.gd / pixel_art.gd / pixel_font.gd / palette.gd
  pixel_label.gd / pixel_button.gd / pixel_panel.gd / ui.gd
```

Capas de colisión: 1 mundo · 2 jugador · 3 peligros · 4 enemigos · 5 monedas.

## Ajustes rápidos

| Qué | Dónde |
| --- | --- |
| Velocidad, vidas, duración del día, premios por distancia | constantes al inicio de `scripts/game.gd` |
| Gravedad, salto, turbo | constantes al inicio de `scripts/player.gd` |
| Precios, artículos, poderes, logros y misiones | `scripts/catalog.gd` |
| Horas del día, luz ambiental y sombras | `scripts/daylight.gd` |
| Patrones, pesos y nivel en que aparecen | `TABLE` en `scripts/level_generator.gd` |
| Canciones y efectos | `TRACKS` y `_build_sounds()` en `scripts/sfx.gd` |
| Aspecto de personajes y objetos | `scripts/sprites.gd` |
