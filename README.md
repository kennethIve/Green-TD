# Green TD

Warcraft 3 **Green TD** remake — single-player first; Steam / online later.

## Engine

- **Godot 4.3+** (Forward Plus)
- GDScript

## Open & run

1. Install [Godot 4](https://godotengine.org/download)
2. Open this folder as a project (`project.godot`)
3. Press **F5**

### Controls (Milestone 2 slice)

- **Space** — start next wave
- **Left click** — place archer tower ($50)
- Survive 5 waves / clear all = win; lives 0 = lose

## Layout

| Path | Purpose |
|------|---------|
| `scenes/main.tscn` | Map path + spawner + towers + HUD |
| `scenes/ui/hud.tscn` | HUD shell |
| `scenes/creep/creep.tscn` | Placeholder creep |
| `scripts/wave/wave_spawner.gd` | Waves |
| `scripts/tower/tower.gd` | Basic tower |
| `scripts/path/creep_path.gd` | Waypoints |

Steam multiplayer out of scope for now.
