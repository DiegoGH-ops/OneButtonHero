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
| Tiempo lento | **3** o **E**: ralentiza el mundo unos segundos |
| Pausa | **Esc** o el botón de pausa |

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
