# ONE BUTTON HERO

Endless runner arcade 2D para **Godot 4** (GDScript 2.0) que se juega con **un solo botón**.
No contiene ningún recurso externo: los gráficos pixel art, la fuente, las partículas,
los efectos de sonido y la música se generan por código.

## Cómo abrirlo

1. Descomprime la carpeta `OneButtonHero`.
2. En Godot 4 (versión **4.2 o superior**): *Importar* → selecciona `project.godot` → *Abrir*.
3. Pulsa **F5**. La escena principal es `scenes/main_menu.tscn`.

## Controles

| Acción | Entrada |
| --- | --- |
| Saltar | Pulsación corta: **Espacio**, **clic izquierdo** o **toque** |
| Salto alto | Mantener pulsado |
| Atacar | El mismo botón cuando hay un enemigo cerca (aparece un **!** sobre él) |
| Pausa | **Esc** o el botón de pausa |

## Reglas

- El héroe corre solo; la velocidad sube un nivel cada 20 segundos.
- 3 vidas. Pinchos, rocas, tótems y enemigos quitan una; caer por un hueco también
  (reapareces al otro lado con unos segundos de inmunidad).
- Puntos: 1 por metro, 10 por moneda, 50 por gema, 25 / 40 / 60 por baba, diablillo o murciélago.
- El récord y los ajustes se guardan en `user://one_button_hero.cfg` (ConfigFile).
- Cada nivel desbloquea patrones nuevos: huecos y diablillos, tótems y plataformas,
  murciélagos y pinchos dobles, combinaciones, abismos anchos.

## Estructura

```
OneButtonHero/
  project.godot
  scenes/
    main_menu.tscn   Menú principal (escena de inicio)
    game.tscn        Partida: fondo, mundo, héroe, cámara, generador y HUD
    player.tscn      CharacterBody2D + zona de daño + zona de ataque
    enemy.tscn       Area2D (baba, diablillo, murciélago)
    coin.tscn        Area2D (moneda / gema)
    obstacle.tscn    Area2D (pinchos, roca, tótem)
    hud.tscn         CanvasLayer de la interfaz de partida
  scripts/
    game_data.gd       Autoload: récord, ajustes, acción de entrada
    sfx.gd             Autoload: sintetizador de efectos y música
    main_menu.gd       Menú y configuración
    game.gd            Reglas de la partida, dificultad, puntuación
    player.gd          Movimiento, salto variable, ataque, daño
    level_generator.gd Generación procedural por patrones
    ground_span.gd     Tramo sólido de suelo (StaticBody2D)
    platform.gd        Plataforma flotante de un solo sentido
    enemy.gd / coin.gd / obstacle.gd
    hud.gd / hud_bar.gd  Marcadores, pausa y Game Over
    background.gd      Fondo parallax (cielo, montañas, castillos, bosque)
    ground_renderer.gd Dibujo del suelo visible
    fx.gd              Ráfagas de partículas y textos flotantes
    sprites.gd         Todos los sprites como texto (un carácter = un píxel)
    pixel_art.gd       Convierte los sprites en texturas y los dibuja
    pixel_font.gd      Fuente bitmap 5x7
    pixel_label.gd / pixel_button.gd / pixel_panel.gd / ui.gd  Controles de interfaz
    palette.gd         Paleta de 16 colores
```

Capas de colisión: 1 mundo · 2 jugador · 3 peligros · 4 enemigos · 5 monedas.

## Ajustes rápidos

| Qué | Dónde |
| --- | --- |
| Velocidad inicial, incremento, máximo, segundos por nivel, vidas | constantes al inicio de `scripts/game.gd` |
| Gravedad, fuerza de salto, salto corto, márgenes de ayuda | constantes al inicio de `scripts/player.gd` |
| Patrones, pesos y nivel en que aparecen | `TABLE` en `scripts/level_generator.gd` |
| Separación entre peligros | `_gap()` en `scripts/level_generator.gd` |
| Aspecto de personajes y objetos | `scripts/sprites.gd` |
| Colores | `scripts/palette.gd` |
| Sonidos y melodía | `_build_sounds()` y `_build_music()` en `scripts/sfx.gd` |
