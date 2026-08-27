# AGENTS.md — Hardware Empire

## Purpose

This file defines how AI coding agents should implement, extend, refactor, and maintain **Hardware Empire**.

Treat these instructions as persistent engineering constraints.

Before making changes:

1. Read this file.
2. Inspect the relevant existing scenes, scripts, resources, and tests.
3. Follow existing project patterns unless they conflict with this file.
4. Prefer extending existing abstractions over introducing parallel implementations.
5. Keep changes scoped to the requested task.
6. Run relevant tests and validation before considering the task complete.

Do not redesign unrelated systems while implementing a feature.

---

# Project Vision

Hardware Empire is a PC-focused **2D pixel-art incremental automation and workshop simulation game built with Godot**.

The player starts as a solo electronics repair technician and gradually grows into an advanced hardware technology company.

The defining feature of the game is that progression is **physically visible**.

The player should see:

* workers moving through the workshop,
* repair jobs moving between stations,
* components being collected from storage,
* PCBs moving through production,
* machines operating,
* queues building,
* bottlenecks emerging,
* products becoming increasingly complex,
* new rooms and production areas appearing,
* manual work becoming automated,
* the workshop evolving into a factory.

The workshop/factory view is the primary game experience.

Menus, dashboards, graphs, and management panels exist to help understand and control the simulation. They must **not become a replacement for the visual workshop**.

---

# Core Design Philosophy

Always preserve these principles.

## Visual progression is a reward

Major progression must usually produce a visible change.

Examples:

* purchasing a soldering station changes the bench;
* hiring a worker adds a visible worker;
* adding a diagnostics bench adds physical equipment;
* installing a reflow oven adds the machine;
* expanding the workshop adds usable physical space;
* creating a production line visibly changes item flow;
* unlocking QA introduces testing equipment and queues.

Avoid implementing major upgrades only as numeric multipliers when a visible representation is appropriate.

---

## Manual work becomes process

The fundamental progression pattern is:

```text
manual work
→ documented procedure
→ trained worker
→ dedicated workstation
→ machine-assisted process
→ automated production cell
→ scalable production line
```

New systems should reinforce this progression.

Automation should generally remove previously understood repetitive work and expose a higher-level decision.

---

## Complexity unfolds gradually

Do not expose the entire game at the beginning.

Systems, resources, workstations, machines, rooms, products, and management panels should unlock progressively.

Early gameplay must remain understandable.

Later complexity should emerge from combining systems the player already understands.

---

## Bottlenecks are gameplay

The primary challenge is not arbitrary random failure.

Interesting problems include:

* insufficient workers,
* overloaded stations,
* poor workshop layout,
* long walking distances,
* missing components,
* supplier delays,
* insufficient testing capacity,
* low quality,
* production imbalance,
* insufficient storage,
* shipping backlog,
* high defect rates.

Whenever possible, bottlenecks should be visible in the workshop before the player needs to inspect numerical reports.

---

# Architecture Principles

## Separate simulation from presentation

This is one of the most important architectural rules.

The authoritative game simulation must not depend on:

* animations,
* rendering,
* frame rate,
* sprite state,
* UI state,
* camera position,
* animation completion callbacks.

The simulation determines what is happening.

The workshop visualization represents that state.

Example:

```text
Simulation:
Worker is assigned to move component batch A from storage to assembly.

Visual layer:
Worker sprite walks to storage, displays carried box, and walks to assembly.
```

Do not make the economic simulation rely on an animation finishing.

If visual execution takes gameplay time, represent that duration in simulation state and let the animation visualize it.

This separation is required for:

* offline progress,
* deterministic testing,
* save/load,
* simulation speed changes,
* performance optimization,
* headless testing.

---

## Simulation time

Game economy and progression must use simulation time rather than rendered frames.

Never calculate production using assumptions such as:

```gdscript
money += production_per_second / 60.0
```

Use elapsed simulation time explicitly.

Prefer APIs shaped around:

```gdscript
advance(delta_seconds: float)
```

or domain-specific equivalents.

Long offline periods must use aggregated simulation where possible.

Do not attempt to replay hours of worker movement frame-by-frame when loading offline progress.

---

## Keep domain logic outside UI

UI should:

* display state,
* issue commands,
* react to signals/events.

UI should not own:

* production formulas,
* job completion rules,
* inventory consumption,
* employee productivity calculations,
* research progression,
* contract success logic,
* quality formulas.

If gameplay behavior disappears when a UI scene is removed, the architecture is probably wrong.

---

## Avoid god objects

Do not place all game logic into:

* `GameState`,
* `Main`,
* `Workshop`,
* a single manager,
* one giant autoload.

Use small domain-focused systems.

Possible domains include:

```text
simulation
jobs
workers
workstations
inventory
suppliers
production
products
research
quality
contracts
market
progression
save
```

If a `GameState` autoload exists, keep it primarily responsible for current persistent/session state and high-level coordination.

Business rules belong in their appropriate domain.

---

# Godot Conventions

## Language

Use **GDScript** by default unless the existing project establishes another language for a specific subsystem.

Use typed GDScript.

Prefer:

```gdscript
var speed: float = 20.0

func calculate_duration(base_duration: float) -> float:
    return base_duration
```

Avoid unnecessary untyped APIs.

All public methods should have parameter and return types wherever practical.

Use typed collections where they improve clarity.

---

## Naming

Follow Godot conventions.

### Files and folders

Use:

```text
snake_case
```

Examples:

```text
worker_agent.gd
repair_job.gd
production_station.tscn
temperature_sensor.tres
```

### Classes and nodes

Use:

```text
PascalCase
```

Examples:

```text
WorkerAgent
ProductionStation
RepairBench
```

### Variables and functions

Use:

```text
snake_case
```

### Constants

Use:

```text
CONSTANT_CASE
```

### Signals

Use descriptive past-tense event names where appropriate.

Examples:

```gdscript
signal job_started
signal job_completed
signal station_blocked
signal inventory_changed
```

---

# Scenes

Treat reusable scenes as reusable components with clear responsibilities.

Good scene candidates include:

```text
Worker
Station
RepairBench
Machine
StorageShelf
JobItem
ProductItem
WorkshopRoom
Notification
InspectionPanel
```

A scene should generally own its local visual behavior and closely related interaction logic.

Avoid huge scenes containing unrelated systems.

Prefer composition over deeply nested inheritance trees.

---

# Nodes vs Plain Logic

Do not make everything a `Node`.

Use Nodes when behavior needs:

* scene-tree lifecycle,
* rendering,
* physics,
* signals tied to scene objects,
* Godot processing callbacks,
* child nodes.

Use `Resource`, `RefCounted`, or plain typed classes for:

* formulas,
* economic models,
* definitions,
* simulation data,
* immutable/configuration data,
* calculations.

This keeps simulation logic easy to test without instantiating entire scenes.

---

# Autoloads

Use autoloads sparingly.

Appropriate uses may include true application-lifetime services such as:

* save management,
* settings,
* global session coordination.

Do not create a new autoload merely because multiple scenes need access to something.

Prefer:

* dependency references,
* signals,
* Resources,
* scene ownership,
* explicit system composition.

---

# Signals and Communication

Prefer signals for events crossing scene/component boundaries.

Examples:

```text
worker assignment changed
job completed
station became blocked
inventory changed
research completed
era unlocked
```

Avoid tightly coupling children to distant nodes using long paths such as:

```gdscript
get_node("../../../../SomeManager")
```

Avoid event buses for trivial local communication.

Use direct references when two objects naturally belong together.

---

# Data-Driven Content

Jobs, products, workers, suppliers, machines, stations, research, upgrades, contracts, and progression definitions should be data-driven.

Prefer Godot custom `Resource` definitions when appropriate.

Examples:

```text
RepairJobDefinition
ProductDefinition
ComponentDefinition
StationDefinition
MachineDefinition
EmployeeRoleDefinition
ResearchDefinition
ContractDefinition
SupplierDefinition
```

Definitions describe content.

Runtime objects describe current state.

Do not mix the two.

Example:

```text
TemperatureSensorDefinition
    base_price
    bill_of_materials
    process_steps
    required_research

ProductBatchState
    quantity
    completed_quantity
    current_step
    quality
```

Do not hardcode individual products or jobs into generic simulation systems.

Adding a new product should primarily involve adding data/resources, not modifying central production code.

---

# Stable IDs

Persistent content must use stable IDs.

Examples:

```text
repair.basic_capacitor
station.soldering_bench
product.temperature_sensor
component.microcontroller_basic
research.pcb_design
```

Save files should reference stable IDs rather than scene paths or display names.

Display names may change.

IDs must not change after release without a save migration.

---

# Workshop Simulation

## Workers

Workers are visible agents but their visuals must reflect simulation state.

Suggested worker states include:

```text
IDLE
MOVING_TO_PICKUP
PICKING_UP
MOVING_TO_STATION
WORKING
MOVING_TO_DROPOFF
WAITING
BLOCKED
```

State transitions should be explicit.

Avoid large collections of loosely related booleans such as:

```text
is_working
is_walking
has_item
is_waiting
is_blocked
```

when a state machine communicates intent more clearly.

---

## Pathfinding

Worker navigation must be isolated behind a movement/navigation component.

Gameplay systems should request:

```text
move worker to destination
```

rather than directly manipulate navigation internals.

Avoid recalculating paths unnecessarily.

Do not enable expensive dynamic avoidance for every worker by default.

Profile first.

Workshop layout must remain readable even if agents occasionally use simplified movement behavior.

---

# Workstations

Stations should share a common conceptual contract.

A processing station should usually expose concepts such as:

```text
input requirements
queue
capacity
assigned workers
process duration
output
current state
quality modifiers
speed modifiers
```

Common states may include:

```text
IDLE
PROCESSING
STARVED
BLOCKED
OVERLOADED
DISABLED
```

Do not implement every station as an unrelated bespoke system.

Specialized stations should extend or compose shared station behavior.

---

# Items and Process Flow

Physical items should represent logical items or batches.

Do not create one full simulation object for every resistor in a warehouse.

Choose an appropriate abstraction level.

Examples:

Good:

```text
ComponentBatch x100
PCB batch x20
Laptop repair job
Sensor batch x10
```

Potentially bad:

```text
100 individually simulated resistor agents
```

Visual fidelity must not make late-game simulation impractical.

Batch or aggregate objects when scale grows.

---

# Production Pipelines

Products consist of explicit process steps.

Example:

```text
component_pick
→ pcb_assembly
→ reflow
→ firmware
→ test
→ case_assembly
→ packaging
```

The pipeline should be defined by data.

Stations should declare which process types they can perform.

Do not hardcode:

```text
if product == "temperature_sensor"
```

inside generic station logic.

Advanced products should reuse earlier processes and subassemblies whenever possible.

---

# Pixel Art Rules

The visual style is **2D pixel art**.

Preserve crisp pixels.

Avoid:

* unintended texture smoothing,
* arbitrary sprite scaling,
* subpixel jitter,
* inconsistent pixel density,
* assets with incompatible visual scale.

Keep a consistent pixel-per-unit / tile-size policy once established.

Camera zoom values should preserve pixel-art readability.

When modifying pixel art presentation, test actual movement and camera behavior rather than judging only static screenshots.

Major machines and stations must have strong silhouettes and distinct readable states.

Animation should communicate function more than decorative realism.

---

# Workshop Visual Feedback

The workshop should visually communicate system state.

Examples:

### Starved station

* worker waiting,
* empty input area,
* subtle missing-parts indicator.

### Overloaded station

* visible input queue,
* workers busy,
* backlog accumulating.

### Blocked output

* completed items waiting,
* machine stopped despite available input.

### Idle station

* no process animation,
* no queue,
* assigned worker visibly idle when appropriate.

### Quality problems

* failed items routed to rework/inspection,
* visible QA hold area where appropriate.

Do not rely exclusively on warning text.

---

# Layout Gameplay

Workshop layout should affect the game, but avoid turning the project into a full conveyor-belt simulator unless explicitly requested.

Relevant layout factors may include:

* walking distance,
* station capacity,
* storage proximity,
* queue space,
* logical room grouping.

Layout calculations should remain understandable and testable.

Do not introduce complex physical collision simulation where simple grid/path relationships suffice.

---

# Incremental Game Rules

## Always provide a next goal

The player should usually have a visible near-term target.

Examples:

* next tool,
* next worker,
* next station,
* next procedure,
* next room,
* next research,
* next product,
* next era.

---

## Upgrades need purpose

Avoid excessive upgrades such as:

```text
+2% speed
+3% speed
+4% speed
```

unless they support a meaningful progression system.

Prefer upgrades that:

* change workflow,
* remove repetition,
* create capacity,
* unlock automation,
* introduce new machines,
* open new markets,
* alter strategy.

---

## Respect player time

Waiting should normally happen because the player has built an automated process.

Avoid making the player watch an inactive progress bar when no decision exists.

---

# Save System

Save data is a public contract with future versions of the game.

Treat save compatibility seriously.

Every save must include a schema/version number.

Example:

```text
save_version
game_version
timestamp
```

Never silently change serialized structures without considering migration.

When modifying persistent models:

1. determine whether existing saves are affected;
2. add migration logic when needed;
3. test old → new conversion;
4. preserve stable content IDs.

Do not serialize direct runtime node references.

Persist logical state and rebuild visual objects from that state.

---

# Offline Progress

Offline progress must operate on simulation data.

Do not instantiate the entire visible workshop and replay every second of absence.

Use aggregated calculations wherever equivalent.

Examples:

```text
supplier delivery completion
research progression
known production throughput
payroll
sales
job completion
```

If a system cannot be accurately aggregated because of bottlenecks, process meaningful simulation boundaries/events rather than rendered frames.

Offline and online results should be reasonably consistent.

---

# Performance

The late-game workshop may contain many workers, stations, items, and effects.

Do not optimize prematurely, but design for scale.

Prefer:

* batching where appropriate,
* event-driven updates over unnecessary `_process`,
* lower-frequency simulation ticks for systems that do not require frame updates,
* object pooling only when profiling demonstrates value,
* simplified distant/nonessential visual updates,
* aggregated item representation at high volume.

Avoid giving every passive object its own `_process()` function.

Profile before implementing complicated optimization.

---

# Testing

Automated tests are required for nontrivial simulation and business logic.

Use **GdUnit4** when available in the project.

Never modify third-party testing framework files under `addons/` to make tests pass.

Tests should mirror relevant source domains where practical.

Example:

```text
game/
  simulation/
    production_system.gd

tests/
  simulation/
    production_system_test.gd
```

---

## What must be tested

Prioritize tests for:

* job progression,
* job rewards,
* inventory consumption,
* worker productivity,
* station queues,
* station state transitions,
* production pipelines,
* product bills of materials,
* quality calculations,
* supplier orders,
* research unlocks,
* contracts,
* market calculations,
* era progression,
* save migrations,
* offline progress,
* economic formulas.

Visual animation details generally do not require unit tests.

Scene integration tests should cover important interactions such as:

```text
worker receives assignment
→ worker reaches station
→ station processes job
→ output becomes available
```

---

## Regression tests

Whenever fixing a bug:

1. reproduce it;
2. add a test that fails for the bug when practical;
3. fix the implementation;
4. confirm the test passes.

Do not delete or weaken a valid test simply to make a change pass.

---

# Determinism

Pure economic functions should be deterministic.

If randomness is required, inject or centralize RNG state so tests can use fixed seeds.

Do not scatter uncontrolled calls to random functions throughout business logic.

Random events must be reproducible when debugging from a known seed where practical.

---

# Validation Commands

Use the project-defined scripts if they exist.

Otherwise typical validation may include:

```bash
godot --headless --path . --quit
```

for project parsing/startup validation.

When GdUnit4 is installed, use the repository's documented GdUnit runner.

Run the narrowest relevant tests during development, then the full suite before completing significant changes.

For exported builds, validate the configured PC export preset when the task affects packaging or platform behavior.

Do not claim tests passed unless they were actually run.

If a required executable or dependency is unavailable, clearly report that limitation.

---

# Code Quality

Follow single responsibility.

Prefer small cohesive classes over large managers.

Avoid duplicated formulas.

Extract shared calculations into appropriately named domain classes.

Avoid magic numbers.

Game balance values belong in:

* definitions,
* configuration resources,
* balancing data,

not scattered through implementation code.

Document **why**, not obvious syntax.

Example of useful comment:

```gdscript
# Offline production is capped at this process boundary because subsequent
# testing capacity can become the bottleneck.
```

Avoid comments like:

```gdscript
# Increment counter by one.
counter += 1
```

---

# Error Handling

Invalid data should fail clearly during development.

Examples:

* product references unknown component;
* station references unsupported process;
* research references missing prerequisite;
* save references removed stable ID.

Prefer descriptive validation errors over silent fallback behavior.

Player-facing recoverable failures should not crash the game.

---

# Logging

Use consistent categories where practical.

Avoid leaving noisy debug output in production code.

Useful debug information includes:

* simulation transitions,
* save migration failures,
* invalid content definitions,
* impossible station states,
* broken pipeline references.

Do not log every simulation tick or worker movement by default.

---

# UI Rules

The primary workshop view should remain usable without constantly opening panels.

Panels should answer questions such as:

* What is this worker doing?
* Why is this station blocked?
* What does this upgrade change?
* Where is this product in the pipeline?
* Why is production slow?
* Which component is missing?

Always explain blocked actions.

Prefer:

```text
Requires:
✓ PCB Design
✗ Reflow Station
✓ Electronics Specialist
```

over a disabled button with no explanation.

Display before/after values for meaningful upgrades where possible.

---

# Feature Implementation Workflow

When implementing a backlog item:

## 1. Understand the gameplay intent

Identify:

* what the player sees;
* what decision the player makes;
* what simulation changes;
* how progress is represented visually.

Do not implement only the underlying number if the feature is intended to be visible.

---

## 2. Find existing architecture

Before creating a new abstraction, search for:

* similar stations,
* similar resources,
* similar UI panels,
* existing formulas,
* existing definitions,
* existing state machines.

Reuse patterns.

---

## 3. Implement simulation first

Define:

* state,
* transitions,
* rules,
* data contracts.

Write tests for important behavior.

---

## 4. Connect visualization

Make the workshop represent the simulation.

Add:

* sprites,
* animation states,
* worker tasks,
* item movement,
* visible queues,
* relevant feedback.

---

## 5. Connect UI

Expose information and player actions without duplicating simulation rules.

---

## 6. Validate

Run:

* relevant automated tests,
* project parse/startup,
* affected scene manually when possible.

Check visual behavior as well as numerical correctness.

---

# Definition of Done for a Feature

A feature is not complete merely because the underlying logic works.

For gameplay features, verify all relevant items:

* [ ] Simulation behavior works.
* [ ] Simulation is independent of rendered frame rate.
* [ ] Appropriate automated tests exist.
* [ ] Data definitions are not unnecessarily hardcoded.
* [ ] Save compatibility was considered.
* [ ] Workshop representation exists when the feature should be visible.
* [ ] Worker/item/station behavior communicates the process.
* [ ] Relevant UI explains state and blocked conditions.
* [ ] Pixel-art presentation remains consistent.
* [ ] No unrelated functionality was broken.
* [ ] Relevant tests were executed.
* [ ] No new warnings/errors appear during validation.

---

# Things Codex Must Not Do

Do not:

* turn the game into a mostly menu-driven idle game;
* implement major progression solely as statistics when it should appear physically;
* make animations authoritative for economic outcomes;
* tie production to FPS;
* put most gameplay logic into one manager/autoload;
* hardcode every individual product into simulation code;
* tightly couple UI to business logic;
* serialize scene/node references as persistent game state;
* introduce random numbers that cannot be controlled in tests;
* add a separate architecture when an existing system can be extended;
* edit generated/imported Godot files unnecessarily;
* modify third-party addon code for convenience;
* remove tests because implementation changed;
* silently break existing save formats;
* add complicated systems beyond the requested backlog item;
* optimize before evidence shows a performance problem.

---

# When Unsure

When multiple solutions are reasonable, prefer the one that:

1. keeps simulation testable;
2. preserves visual workshop gameplay;
3. minimizes coupling;
4. supports data-driven content;
5. supports future save compatibility;
6. scales to later eras;
7. follows existing project patterns;
8. introduces the least unnecessary complexity.

The long-term goal is not merely to make numbers increase.

The goal is for the player to **watch a tiny electronics repair bench evolve into a living, increasingly complex hardware production company**.
