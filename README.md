# ONE BUTTON HERO

Endless runner arcade 2D para **Godot 4** (GDScript 2.0) que se juega con **un solo botón**
(más tres poderes opcionales). No contiene ningún recurso externo: los gráficos pixel art,
la fuente, las partículas, las luces, los efectos de sonido y las seis canciones se generan por código.

## Cómo abrirlo

1. En Godot 4 (versión **4.2 o superior**): *Importar* → selecciona `project.godot` → *Abrir*.
2. Pulsa **F5**. La escena principal es `scenes/main_menu.tscn`.

## Controles

| Acción | Entrada |
| --- | --- |
| Saltar | Pulsación corta: **Espacio**, **clic izquierdo** o **toque** |
| Salto alto | Mantener pulsado |
| Atacar | El mismo botón cuando hay un enemigo cerca (aparece un **!** sobre él) |
| Turbo | **1** o **Q**, o su botón en pantalla: corre más, cruza huecos y arrolla |
| Onda | **2** o **W**: elimina enemigos y obstáculos cercanos |
| Soul Reaper | **3** o **E** cuando está cargado: el siguiente ataque perfecto es letal |
| Pausa | **Esc** o el botón de pausa |

## Campaña y timing (fase 1 de la gran expansión)

- **Campaña**: 5 mundos (Verdantia, Infernus, Amethystia, Frostfall, Solaris) × 20 niveles con
  recorrido fijo, meta, estrellas, rango de D a SSS, récord y recompensas. Mapa de niveles en el menú.
- **Timing**: cada salto, ataque y esquiva se evalúa según lo cerca del peligro que se ejecuta:
  GOOD, PERFECT, LEGENDARY y LAST SECOND, con texto, sonido, partículas y puntos propios.
  Las ventanas se configuran en `scripts/timing.gd` y se estrechan en cada mundo.
- **Combo de precisión**: 3, 5, 8, 12 y 20 acciones perfectas seguidas dan x1,5 a x5. Recibir daño lo rompe.
- **Soul Reaper**: sustituye al tiempo lento. Se carga con acciones perfectas.
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
  catalog.gd         Datos de la tienda, poderes, logros y misiones
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
  hud.gd / hud_bar.gd / power_button.gd   Interfaz de partida
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
