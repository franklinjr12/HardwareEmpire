# Hardware Empire implementation map

Era-1 vertical slice uses one primary physical workshop scene. Player personally handles customer intake, parts, diagnosis, repair, and outbound delivery.

## Runtime

- `scripts/game_state.gd`: application coordinator, legacy later-era compatibility, save/load routing, and Era-1 state projection.
- `scripts/simulation/repair_shop_simulation.gd`: authoritative Era-1 simulation for customers, job states, reservations, timed supplier deliveries, player movement actions, diagnosis, repair choices, XP, mastery, tools, upgrades, and serialization.
- `scripts/tiny_workshop.gd`: physical workshop renderer and interaction UI. Click stations to walk there; actions resolve only on arrival.
- `scripts/main.gd`: retained later-era management prototype for compatibility while Era 1 is the active main scene.
- `data/content.json`: stable-ID content catalog for repair jobs, customers, components, tools, stations, products, research, contracts, and eras.
- `scripts/simulation/workshop_grid.gd`: grid placement and lightweight worker navigation.
- `scripts/simulation/simulation_rules.gd`: deterministic economy, quality, throughput, and bottleneck rules.

## Controls

- Left click empty floor: move founder.
- Left click workstation: walk to it, then open interaction panel.
- `ESC`: close interaction panel.
- Top bar: save and workshop upgrades.

## Validation

```text
Godot 4.7.1 headless editor parse
tests/test_runner.gd
tests/ui_smoke.gd
headless project startup
```

Art uses deterministic draw primitives with a fixed 32px grid, preserving crisp placeholder pixel-art silhouettes while making customer, courier, carried parts, bench equipment, and completed-device states readable.
