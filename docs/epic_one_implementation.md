# Era 1 physical workflow

Implemented in `RepairShopSimulation`, synchronized through `HardwareEmpireState`.
The renderer only reflects state and issues commands.

- Empty start; seeded, configurable 3–6 second first arrival, 15–30 second later arrivals. Three waiting slots; blocked arrival opportunities reschedule normally.
- Persistent customer identity, appearance, arrival/departure and pickup lifecycle. Customers stay on the public side of the partition.
- Supplier orders use sequential courier visits. Transit does not credit inventory. A single courier drops stock, reserves it for its job, then exits through the service door. Credited visits do not count twice against storage.
- One occupied bench and one carried bundle/device. Founder movement remains required between stations. Movement commands are rejected during timed work.
- Three outbound slots, individual return timers, original customers, sequential pickup visits. Cash, XP, reputation, mastery and sales update once at collection.
- Nested repair-shop schema 3 migrates older state, retains completed rewards, remaps old founder coordinates, and saves RNG state plus fractional simulation time. Outer save format remains version 2 because its envelope has not changed.
- Shared layout defines stations, hitboxes, entrances and navigation. Node-based furniture, devices, NPCs and founder support Y sorting and future sprite replacement. Placeholder art remains native Godot drawing.
- Anchored container HUD, XP/storage meters, cash and level feedback, scrollable context drawer, contextual progress/status, action styling, hover highlights, doors and sound signals.

## Validation

Run with the installed Godot executable:

```
Godot.exe --headless --path . --script res://tests/test_runner.gd
Godot.exe --headless --path . --script res://tests/epic_one_tests.gd
Godot.exe --headless --path . --script res://tests/ui_smoke.gd
Godot.exe --path . --script res://tests/visual_playtest.gd
```

The rendered walkthrough saves screenshots to the OS temporary directory at 1440×900 and 1280×720. It uses isolated in-memory state and does not overwrite the player's save. This is an automated rendered walkthrough, not a human mouse-driven playtest.

The referenced conversation exposed art-direction text but no retrievable images. The native placeholders follow its inexpensive, slightly angled workshop direction; no final artwork or audio was added.

No Era-2 mechanics were added. The pre-existing untracked epic document was left unchanged.
