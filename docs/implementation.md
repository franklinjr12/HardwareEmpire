# Hardware Empire implementation map

Playable code-native prototype covers backlog systems through one primary workshop scene.

## Runtime

- `scripts/game_state.gd`: authoritative simulation, workers, jobs, products, stations, machines, suppliers, R&D, contracts, quality, progression, saves, and offline aggregation.
- `scripts/main.gd`: workshop renderer, procedural crisp pixel-grid visuals, camera controls, inspection, placement/relocation, overlays, dashboard, and management panels.
- `data/content.json`: stable-ID content catalog for roles, stations, machines, products, research, contracts, components, and eras.
- `scripts/simulation/workshop_grid.gd`: grid placement and lightweight worker navigation.
- `scripts/simulation/simulation_rules.gd`: deterministic economy, quality, throughput, and bottleneck rules.

## Controls

- `WASD` / arrow keys: pan camera.
- Middle mouse drag: pan camera.
- Mouse wheel: zoom.
- Left click: inspect worker, station, item, or open build placement.
- Bottom navigation: dashboard and specialized management panels.

## Validation

```text
Godot 4.7.1 headless editor parse
tests/test_runner.gd
tests/ui_smoke.gd
headless project startup
```

Art uses deterministic draw primitives with a fixed 32px grid, preserving the backlog's placeholder-shape constraint while keeping silhouettes and states readable.
