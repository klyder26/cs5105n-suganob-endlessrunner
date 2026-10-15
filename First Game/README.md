# Knight's Quest: Endless Runner

> A 2D retro action-platformer and runner built in Godot 4. Sprint through hazardous forests and gravity-defying sky citadels, dodge slime patrols, gather coins, activate mid-level checkpoints, and warp through magical portals to survive!

> [!NOTE]
> **Screenshot Setup**: Place your activity preview screenshots in the [`screenshots/`](screenshots/) directory using the following naming format:
> - `week-01.png`
> - `week-02.png`
> - `week-03-1.png` & `week-03-2.png` (2 screenshots for Level Design)
> - `week-04.png`
> - `week-05-1.png` & `week-05-2.png` (2 screenshots for UI/UX & Audio)
> - `week-06.png`
> - `week-07.png`

---

## Prerequisites & Running the Project

- **Engine Version**: Godot 4.7.2 (or any Godot 4.x Standard build)
- **Renderer**: Forward+ / Metal / Vulkan Mobile
- **Main Scene**: `res://scenes/menu.tscn`
- **Project Location**: `First Game/` directory
- **Controls**:
  - `A` / `D` or `Left Arrow` / `Right Arrow`: Run Left / Right
  - `Space`: Jump
  - `P` / `Esc`: Pause Game
  - `Enter` / `Mouse Click`: Menu Selection & UI Navigation

To run locally:
1. Open the **Godot Engine Project Manager**.
2. Click **Import** and select the `First Game/project.godot` file.
3. Click **Run Project** (or press `F5`).

---

## Weekly Progress & Documentation

### Week 1: Godot & Git Setup
![Week 1 Preview](screenshots/week-01.png)
- **Description**: Initialized the project within Godot 4 using 2D canvas stretch mode and nearest-neighbor texture filtering for pixel-art fidelity. Established Git version control with a comprehensive `.gitignore` for engine caches and configured Git LFS tracking for audio (`*.wav`) and graphical assets (`*.png`). Set up the baseline project architecture dividing scenes, scripts, and audio into structured directories.

---

### Week 2: Gameplay Mechanics & Game Feel
![Week 2 Preview](screenshots/week-02.png)
- **Description**: Developed the responsive kinematic player controller in `player.gd` and `player.tscn` utilizing a `CharacterBody2D` with customized platformer physics. Tuned snappy jumping (`JUMP_VELOCITY = -300.0 px/s`), horizontal movement (`SPEED = 130.0 px/s`), and linear friction deceleration using `move_toward()`. Mapped custom multi-key input actions (`jump`, `move_left`, `move_right`) in `project.godot` to support both Arrow keys and WASD layouts.

---

### Week 3: Level Design
![Week 3 Preview - Part 1](screenshots/week-03-1.png)
![Week 3 Preview - Part 2](screenshots/week-03-2.png)
- **Description**: Crafted a multi-stage progression system featuring Level 1 (`game.tscn`) and Level 2: Sky Citadel (`game2.tscn`) using Godot's `TileMap` with dedicated physics collision layers. Implemented one-way jump-through platforms (`platform.tscn`), bottomless pit boundaries with `WorldBoundaryShape2D` hazards (`killzone.tscn`), and an experimental vertical gravity stream (`anti_gravity_zone.tscn`). Configured dynamic camera tracking (`Camera2D`) with horizontal position smoothing and level boundaries.

---

### Week 4: Art, Animation & Particles
![Week 4 Preview](screenshots/week-04.png)
- **Description**: Integrated retro pixel-art sprite sheets for the knight hero (`knight.png`), spinning coins (`coin.png`), and environmental tiles (`world_tileset.png`). Built multi-state frame animations in `AnimatedSprite2D` (`idle`, `run`, `jump`) alongside an `AnimationPlayer` pickup sequence that plays audio, disables colliders, and frees coins. Implemented CPU-based particle emitters (`CPUParticles2D`) for celestial portal vortexes, checkpoint golden spark bursts, and anti-gravity uplift streams.

---

### Week 5: UI/UX & Audio
![Week 5 Preview - Part 1](screenshots/week-05-1.png)
![Week 5 Preview - Part 2](screenshots/week-05-2.png)
- **Description**: Built a comprehensive user interface system featuring an animated Main Menu (`menu.tscn`, `menu.gd`) with button hover juice, an interactive "How to Play" controls modal, and an in-game pause screen (`pausemenu.tscn`) with real-time coin stats. Configured a dedicated audio bus layout (`default_bus_layout.tres`) separating `Master` and `SFX` channels alongside an autoloaded background soundtrack (`music.tscn`). Integrated audio feedback for jumps, coin collections, UI clicks, and victory fanfare.

---

### Week 6: AI & Enemies
![Week 6 Preview](screenshots/week-06.png)
- **Description**: Programmed autonomous patrol AI for enemies in `slime.gd` and `slime.tscn` using dual sensor raycasts (`RayCast2D`) to detect upcoming walls and ledges. Designed an automatic turnaround routine that inverts patrol velocity and flips the animated crawl sprite (`AnimatedSprite2D.flip_h`) when an obstacle or cliff is reached. Embedded a hazardous `Killzone` area that triggers player defeat and scene reload on contact.

---

### Week 7: Juice, Save/Load & Optimization
![Week 7 Preview](screenshots/week-07.png)
- **Description**: Added game feel polish including slow-motion death hitstop (`Engine.time_scale = 0.5`) and playful button and portal punch tweens (`Tween.TRANS_BACK`). Architected a production-ready `SaveManager` autoload singleton (`save_manager.gd`) using Godot's `FileAccess` and JSON serialization to persist level progression, coin counts, and mid-level checkpoints (`checkpoint.tscn`). Implemented decoupled player respawning that automatically repositions the player at the active checkpoint on death reload or game continuation.

---

## Architecture & Code Quality Highlights

- **Autoload Architecture**: Singletons manage persistent state (`SaveManager`, `Music`) across scene transitions without coupling logic to individual entities.
- **Decoupled Spawning**: The `Player` controller remains completely decoupled from save logic; `SaveManager` observes scene tree entries and repositions characters automatically.
- **Scalable Save Schema**: Built with an open `extra` dictionary bucket allowing future variables (gems, health, achievements, settings) to be saved without breaking compatibility.
- **Clean Game Loop**: Automatic saving triggers upon touching checkpoints, entering portals, and clearing levels, while starting a new game securely wipes previous data.
