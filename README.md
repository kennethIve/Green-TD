# Green TD

Warcraft 3 **Green TD** remake — single-player first; Steam / online later.

## Engine

- **Godot 4.3+** (Forward Plus)
- GDScript

## Open & run

1. Install [Godot 4](https://godotengine.org/download)
2. Open this folder as a project (`project.godot`)
3. Press **F5** (main scene: `scenes/main.tscn`)

## Layout

| Path | Purpose |
|------|---------|
| `project.godot` | Godot project config |
| `scenes/main.tscn` | Runnable root + CanvasLayer HUD |
| `scenes/ui/hud.tscn` | Dark-glass HUD (top bar, minimap, focus card, build tray) |
| `scripts/ui/hud.gd` | HUD API + F5 demo data |
| `scripts/main.gd` | Main entry; wires HUD signals |
| `icon.svg` | Placeholder app icon |

## Milestone status

- Runnable Godot 4 skeleton + modern HUD shell on `main`
- Next: map path, towers, waves, live resources wired to HUD

Steam multiplayer is out of scope for now.
