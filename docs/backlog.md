# Hardware Empire — Updated Full Backlog (Visual Workshop / 2D Pixel Art Edition)

## 1. Project Overview

### Working Title

**Hardware Empire**

### Core Fantasy

The player starts as a solo electronics repair technician in a tiny garage-like workshop and gradually grows into a full hardware technology company. The player should **see** that growth happen: more benches, more workers, better tools, machines, storage, production cells, testing labs, shipping areas, and increasingly complex products moving through the workshop.

### Platform

* **PC only** for initial release
* Engine: **Godot**
* Visual style: **2D pixel art** (use placeholder shapes as sprites will be defined later)

* Genre:

  * Incremental game
  * Automation / workflow management game
  * Workshop / factory simulation
  * Business progression game

### Core Design Goal

This is **not** just a menu-and-bars idle game.

The main experience should be:

* Watching your workshop operate
* Seeing workers move and process jobs
* Seeing parts, boards, and products move through stations
* Seeing the workshop physically evolve across eras
* Identifying bottlenecks visually and solving them
* Enjoying the visual satisfaction of turning manual work into systems

### Design Pillars

1. **Visual progression is a core reward**

   * New benches, tools, and machines must visibly appear in the workshop.
   * The building itself should evolve across eras.

2. **The workshop is the main play space**

   * The player should spend most of their time in the workshop/factory view.
   * Management panels support the simulation rather than replacing it.

3. **Manual work becomes process**

   * Repair by hand → procedure → assigned worker → dedicated bench → machine-assisted process → automated production line.

4. **Complexity unfolds physically**

   * The workshop begins as one room.
   * It later becomes a multi-room workshop, then a small factory, then a production facility.

5. **Bottlenecks should be visible**

   * Queues, blocked workers, crowded benches, missing parts, idle machines, and testing backlogs should be visible in the scene.

---

# 2. High-Level Gameplay Structure

## Main game loop

1. Jobs, orders, or production goals enter the company.

2. The workshop scene shows them entering the process physically.

3. Workers and machines process the work through stations.

4. The player earns money, reputation, knowledge, and capability.

5. The player invests in:

   * tools,
   * benches,
   * workers,
   * layout expansion,
   * machines,
   * suppliers,
   * products,
   * testing,
   * automation,
   * product divisions.

6. The workshop becomes physically bigger, busier, and more capable.

---

# 3. Visual / Spatial Design Principles

## 3.1 The workshop is the primary game view

The workshop scene should be the main screen where the player can:

* see workers walking,
* see active benches,
* see parts moving,
* see incoming and outgoing items,
* see stations idle or overloaded,
* see queues building,
* click stations, workers, or products,
* inspect bottlenecks,
* place or upgrade major equipment,
* observe the company evolve.

### Acceptance criteria

* The game can be understood by watching the workshop.
* The player can visually tell whether the company is small, growing, or industrialized.
* The player can identify activity and congestion without opening a spreadsheet-like screen.

---

## 3.2 Pixel art art direction

### Style goals

* Clean readable pixel art
* Strong silhouettes for benches and machines
* Distinct visual categories:

  * repair area
  * diagnostics area
  * PCB area
  * firmware area
  * assembly area
  * testing area
  * storage area
  * packaging/shipping area
* Workers readable at small scale
* Objects easy to recognize
* Workshop evolution immediately noticeable

### Art requirements

* Use a consistent tile/grid approach for rooms and floor plans.
* Benches should have animated active states.
* Machines should have simple operating animations.
* Workers should have clear movement and task animations.
* Carried items should be visually distinct enough to understand what is moving.

### Acceptance criteria

* A player can tell the difference between a soldering bench, diagnostics bench, reflow station, and testing bench by visuals alone.
* Era transitions visibly change the workshop.

---

# 4. Era Progression with Visual Evolution

## Era 1 — Solo Repair Technician

### Fantasy

“I repair devices myself in a tiny workshop.”

### Visual state

* One small room / garage
* One basic workbench
* One stool/chair
* One shelf or parts drawer
* Basic soldering iron
* Multimeter
* Small cluttered space
* Customer drop-off area is tiny or implied
* Only the player character works in the room

### Visual behaviors

* The player character picks up jobs from an incoming shelf or counter
* Takes devices to workbench
* Repairs manually
* Puts repaired items in completed area
* Walks to parts shelf when required

### Core systems

* Manual repair jobs
* Basic tools
* Money
* Reputation
* Skill / knowledge
* Minimal inventory

### Acceptance criteria

* The workshop feels small and personal.
* The player sees themselves doing the work.
* The first upgrades visibly improve the bench and room.

---

## Era 2 — Local Repair Shop

### Fantasy

“I have a real repair shop with staff and multiple jobs happening at once.”

### Visual state

* Larger room or multiple connected rooms
* Reception area / customer counter
* Two or more workbenches
* Separate diagnostics bench
* Better parts storage
* More organized workspace
* 2–4 workers visible
* Simple queue shelves / incoming and outgoing job areas

### Visual behaviors

* Customers/jobs enter reception
* Devices move to diagnostics
* Devices move to repair benches
* Completed devices move to pickup/completed area
* Workers specialize by station

### Core systems

* Employees
* Assignment
* Training
* Workstations
* Job queue
* Parallel processing

### Acceptance criteria

* The player visually sees multiple repairs being processed at once.
* More workers and benches create a clearly busier shop.
* Basic bottlenecks are visible in the room.

---

## Era 3 — Electronics Workshop

### Fantasy

“We do electronics engineering and prototype work.”

### Visual state

* Expanded workshop
* Dedicated electronics area
* Oscilloscope bench
* PCB design desk / computer station
* Reflow station
* Component storage wall
* Firmware/programming station
* Prototype shelves
* Specialist employees visible

### Visual behaviors

* Prototype boards or boards-in-progress move between stations
* Workers can carry parts bins, PCBs, or devices
* More complex flows appear:

  * diagnostics,
  * bench repair,
  * PCB rework,
  * firmware flashing,
  * prototype handling

### Core systems

* Advanced diagnostics
* Supplier orders
* PCB and prototype work
* R&D
* First original designs

### Acceptance criteria

* This era visually communicates a shift from simple repair to technical electronics work.
* The workshop no longer looks like just a repair shop.

---

## Era 4 — Small Manufacturer

### Fantasy

“We manufacture our own products.”

### Visual state

* Workshop becomes small production facility
* Dedicated assembly area
* Reflow oven
* PCB assembly station
* Testing station
* Packaging area
* Small warehouse/storage area
* Product shelves
* More workers, more station specialization
* More structured floor layout

### Visual behaviors

* Component bins go from storage to assembly
* Boards move through assembly and reflow
* Boards move to inspection/testing
* Products move to casing/final assembly
* Finished units move to packaging and finished goods shelves

### Core systems

* Product catalog
* Batch production
* Product assembly pipeline
* Market sales
* Quality testing
* Returns

### Acceptance criteria

* Production lines are visible and understandable.
* The player can watch a product move through multiple steps.
* This era visually feels like a transition from workshop to manufacturing.

---

## Era 5 — Industrial Supplier

### Fantasy

“We build serious systems for companies.”

### Visual state

* Larger building / multiple production zones
* Industrial testing area
* QA lab
* Calibration bench
* Contract project area
* More substantial storage/warehouse zone
* Packaging/shipping is more formalized
* More specialized teams
* Clear division between repair, manufacturing, engineering, and QA zones

### Visual behaviors

* Larger batches moving through production
* Dedicated project items for contracts
* More test/QA handling
* Support/maintenance work appears alongside manufacturing
* More visible queues if systems are unbalanced

### Core systems

* Contracts
* Deadlines
* Penalties
* Industrial requirements
* Certifications
* Reliability management

### Acceptance criteria

* The workshop/factory feels like a real company.
* Different areas reflect different functions.
* Contract work visibly looks more advanced than earlier product work.

---

## Era 6 — Advanced Technology Company

### Fantasy

“We produce complex integrated technology systems.”

### Visual state

* Advanced production facility
* Multiple room types or building wings
* Automated production cells
* Advanced test lab
* Drone / infrastructure assembly areas
* High-end R&D section
* Certified production line
* Product divisions represented visually
* More advanced storage/logistics flow

### Visual behaviors

* More complex products assembled from subassemblies
* Specialized stations for advanced items
* Worker and machine cooperation
* Larger production throughput
* Multiple product families active at once

### Core systems

* Product divisions
* Advanced technology products
* Large contracts
* Advanced quality and certification
* Branch expansion prestige

### Acceptance criteria

* The final era looks dramatically different from the first.
* The player can look at the workshop and feel they built a real technology company.

---

# 5. Main Game Screens

## 5.1 Workshop / Factory View (Primary Screen)

### Purpose

The main screen of the game. This is where the player watches the company operate.

### Must support

* Camera / navigation around workshop
* Visible workers
* Visible stations
* Visible machines
* Visible item movement
* Visible queues
* Click-to-inspect workers
* Click-to-inspect stations
* Click-to-inspect products/jobs
* Visual status indicators:

  * active,
  * idle,
  * blocked,
  * waiting for parts,
  * overloaded

### Interactions

* Click worker → open worker panel
* Click station → open station panel
* Click machine → open machine panel
* Click item/queue → inspect product/job info
* Click empty planned spot → place or build new station/machine
* Toggle overlays:

  * throughput,
  * queue heatmap,
  * worker assignment,
  * part shortages,
  * quality issues

### Tasks

* [ ] Create main workshop scene.
* [ ] Create camera movement and zoom.
* [ ] Create workshop tile/grid layout system.
* [ ] Create placeable workstation objects.
* [ ] Create worker entities.
* [ ] Create item/job visual representations.
* [ ] Create pathing/navigation for workers.
* [ ] Create station activity animations.
* [ ] Create click interaction system.
* [ ] Create overlay toggles.
* [ ] Create visual queue indicators.
* [ ] Create congestion / bottleneck indicators.

### Acceptance criteria

* The workshop is readable and interactive.
* A player can spend most of their session on this screen.
* The player can understand the company’s operation by observation.

---

## 5.2 Dashboard (Secondary Summary Screen)

### Purpose

A high-level summary screen for quick stats and alerts.

### Must show

* Cash
* Reputation
* Knowledge
* Active jobs
* Active contracts
* Current production
* Active bottlenecks
* Daily/weekly financial snapshot
* Current era
* Current top goals

### Tasks

* [ ] Build summary dashboard.
* [ ] Add KPI widgets.
* [ ] Add current alerts panel.
* [ ] Add shortcuts to relevant workshop locations or systems.
* [ ] Add milestone tracker.

### Acceptance criteria

* The dashboard complements the workshop view rather than replacing it.

---

## 5.3 Specialized Management Panels

The following panels still exist, but they support the workshop simulation instead of being the main gameplay surface:

* Employees
* Inventory/Suppliers
* R&D
* Products
* Market
* Contracts
* Quality
* Company
* Settings

All of these panels should be reachable from either:

* the main navigation, or
* clicking relevant workshop elements.

---

# 6. Core Simulation Systems

## 6.1 Worker Simulation

### Purpose

Workers must physically exist in the workshop and perform visible tasks.

### Worker actions

* Move to station
* Pick up parts
* Carry parts or job items
* Perform task animation
* Deliver completed item to next station
* Wait if blocked
* Stay idle if no assignment

### Worker types

* Player/founder
* Junior Technician
* Senior Technician
* Electronics Specialist
* Diagnostics Technician
* PCB Designer
* Firmware Engineer
* QA Technician
* Production Operator
* Procurement Assistant
* Field Support Engineer
* Sales/Support staff
* Process Engineer

### Tasks

* [ ] Create worker entity system.
* [ ] Create worker sprite sets and animation states.
* [ ] Create worker task state machine.
* [ ] Create worker pathing.
* [ ] Create worker carrying visuals.
* [ ] Create worker idle states.
* [ ] Create worker assignment logic.
* [ ] Create worker training/progression data.
* [ ] Create worker info panel.

### Acceptance criteria

* Workers visibly perform their jobs.
* Worker state is understandable by watching them.
* Hiring more workers visibly increases workshop activity.

---

## 6.2 Item / Job Flow Simulation

### Purpose

Repairs, components, PCBs, and products should move through the workshop as visible entities.

### Item examples

* Broken laptop
* Power supply board
* Box of components
* PCB
* Assembled PCB
* Product in casing
* Finished product box
* Contract package

### Tasks

* [ ] Create item entity system.
* [ ] Create visual categories of items.
* [ ] Create item state system.
* [ ] Create station input/output logic.
* [ ] Create transfer logic between stations.
* [ ] Create waiting queue representation.
* [ ] Create visual stacking or queue markers where needed.

### Acceptance criteria

* Products and jobs visibly move through the workshop.
* The player can visually follow a process chain.

---

## 6.3 Station / Bench Simulation

### Purpose

Each station should act as both a simulation node and a visual object.

### Station examples

* Repair bench
* Soldering bench
* Diagnostics bench
* Oscilloscope bench
* PCB design station
* Firmware desk
* Reflow station
* Assembly station
* Testing station
* Calibration bench
* Packaging station
* Shipping area
* Warehouse shelf
* Customer counter

### Station behavior

* Accepts inputs
* Processes work
* Produces output
* Requires worker and/or machine
* Can be idle, working, blocked, starved, or overloaded

### Tasks

* [ ] Create station base class/data model.
* [ ] Create station state machine.
* [ ] Create station queue handling.
* [ ] Create station animations.
* [ ] Create station upgrade states/sprites.
* [ ] Create click panel for stats and actions.
* [ ] Create visible queue areas around stations.

### Acceptance criteria

* Stations are recognizable, interactive, and useful.
* Upgrades should visibly change the station.

---

## 6.4 Machine Simulation

### Purpose

Machines should feel like major visible technological achievements.

### Machine examples

* Better soldering station
* Automated test jig
* Reflow oven
* Small pick-and-place machine
* CNC/router
* 3D printer
* Laser cutter
* Calibration rig
* Environmental testing chamber
* Packaging machine

### Tasks

* [ ] Create machine object system.
* [ ] Create machine operation animations.
* [ ] Create machine input/output logic.
* [ ] Create worker-machine interaction logic.
* [ ] Create machine upgrade visuals.
* [ ] Add maintenance or downtime logic only if it improves gameplay.

### Acceptance criteria

* Buying a machine visibly transforms the workshop.
* Machines feel different from benches and workers.

---

# 7. Workshop Layout and Expansion

## 7.1 Layout system

### Purpose

The workshop must physically evolve over time.

### Tasks

* [ ] Define workshop grid/tile system.
* [ ] Define placement rules.
* [ ] Define walkable vs occupied areas.
* [ ] Define zone categories.
* [ ] Define room expansion flow.
* [ ] Define new room unlocks by era.
* [ ] Define station placement/edit mode.
* [ ] Define relocation flow for existing stations.

### Acceptance criteria

* The workshop can be expanded in stages.
* New stations need actual space.
* The workshop layout matters visually.

---

## 7.2 Expansion milestones

### Examples

* Small room → larger workshop
* Add reception area
* Add separate diagnostics area
* Add electronics/prototyping room
* Add small production floor
* Add QA lab
* Add warehouse/shipping area
* Add industrial production area
* Add advanced R&D area

### Tasks

* [ ] Design expansion unlock list.
* [ ] Create visual map/floorplan progression.
* [ ] Create expansion UI and confirmation flow.
* [ ] Create art states for each major expansion.

### Acceptance criteria

* Expansions feel like major rewards.
* Era progression is reflected physically in the building.

---

# 8. Products and Process Visualization

## 8.1 Product flow

Products must be visible as they move through stages.

### Example flow

**Temperature Sensor**

* Parts fetched from storage
* PCB assembled
* Reflow
* Firmware flashed
* Testing
* Case assembly
* Packaging

**Farming Drone Module**

* Controller board
* Sensor package
* Power module
* Mechanical parts
* Assembly
* Calibration
* Testing
* Packaging

### Tasks

* [ ] Create visual product families.
* [ ] Define process chains for products.
* [ ] Create stage-specific visual states where useful.
* [ ] Create subassembly representation.
* [ ] Create final product representation.

### Acceptance criteria

* Advanced products visually feel more complex than early products.

---

## 8.2 Repair job flow

Repairs should also have visible flows.

### Example flow

* Customer device arrives
* Goes to diagnostics
* Goes to repair bench
* Goes to testing
* Goes to completed/pickup area

### Tasks

* [ ] Create repair job visual lifecycle.
* [ ] Create incoming/outgoing job shelves.
* [ ] Create customer item categories.

### Acceptance criteria

* Repair shop operations are understandable by watching the scene.

---

# 9. Visual Bottleneck Detection

## Purpose

The workshop should visually communicate problems before the player reads numbers.

## Bottleneck examples

* Queue of items building up at testing
* Worker constantly walking too far
* Missing parts causing a station to sit idle
* Output shelves full
* Product flow blocked because next station is overloaded
* Too few workers in an area
* Too many workers waiting at one machine
* Shipping backlog

### Tasks

* [ ] Add queue visuals.
* [ ] Add warning icons above blocked stations.
* [ ] Add subtle colored overlays for bottlenecks.
* [ ] Add heatmap or utilization overlay.
* [ ] Add path congestion indicator.
* [ ] Add starvation indicator for part shortages.
* [ ] Add machine idle/blocked indicator.

### Acceptance criteria

* The player can understand where problems are happening by observation.

---

# 10. Management Systems (Updated Emphasis)

The systems below remain from the earlier backlog, but now they should be tightly connected to what happens visually in the workshop.

## 10.1 Employees

### Key update

Employees must not only exist as data but also as visible agents in the workshop.

### Tasks

* [ ] Keep all employee management tasks from previous backlog.
* [ ] Add visible sprite variations per role.
* [ ] Add workstation-specific behavior.
* [ ] Add visible assignment cues.

---

## 10.2 Inventory and suppliers

### Key update

Inventory should be reflected physically:

* component shelves,
* bins,
* crates,
* incoming deliveries,
* storage areas.

### Tasks

* [ ] Create warehouse/storage visuals.
* [ ] Add delivery arrival visuals.
* [ ] Add stock level visual states for storage shelves.
* [ ] Add part shortage visual indicators.

---

## 10.3 R&D

### Key update

R&D should have a visual footprint:

* engineering desks,
* prototype shelves,
* design computers,
* prototype boards,
* test prototypes.

### Tasks

* [ ] Create R&D room/zone visuals.
* [ ] Create prototype-in-progress visuals.
* [ ] Create product blueprint/research panel connected to workshop.

---

## 10.4 Quality

### Key update

Quality must be visible through:

* testing benches,
* inspection flow,
* rejected items,
* calibration stations,
* QA room evolution.

### Tasks

* [ ] Create QA station visuals.
* [ ] Create failed test item visuals where useful.
* [ ] Create quality hold / rework queue visuals.
* [ ] Create certification-related room upgrades or decorations.

---

# 11. Art Backlog

## 11.1 Character art

### Tasks

* [ ] Create founder/player sprite.
* [ ] Create worker base sprite set.
* [ ] Create role variations by color, accessories, or clothing.
* [ ] Create animations:

  * idle
  * walk
  * carry
  * work at bench
  * inspect
  * operate machine

### Acceptance criteria

* Workers are readable and distinct.

---

## 11.2 Environment art

### Tasks

* [ ] Create floor tiles.
* [ ] Create wall tiles.
* [ ] Create doors/room separators.
* [ ] Create decoration set for each era.
* [ ] Create workstation sprites.
* [ ] Create machine sprites.
* [ ] Create storage shelves/crates/bins.
* [ ] Create incoming/outgoing shelves.
* [ ] Create shipping/packaging props.

### Acceptance criteria

* The workshop looks increasingly advanced with each era.

---

## 11.3 Item art

### Tasks

* [ ] Create broken device item icons/sprites.
* [ ] Create PCB item sprites.
* [ ] Create component box/bin sprites.
* [ ] Create product family sprites.
* [ ] Create packaged product sprites.
* [ ] Create contract-specific object sprites where needed.

### Acceptance criteria

* A player can visually distinguish categories of things moving through the workshop.

---

# 12. Godot Implementation Backlog

## 12.1 Core project setup

* [ ] Initialize Godot project.
* [ ] Create main scene structure.
* [ ] Create autoload game state.
* [ ] Create data-driven content loading.
* [ ] Create save/load.
* [ ] Create simulation tick.
* [ ] Create offline progress.

---

## 12.2 Workshop simulation foundation

* [ ] Build workshop grid/tilemap scene.
* [ ] Build worker entity system.
* [ ] Build station system.
* [ ] Build item movement system.
* [ ] Build pathing.
* [ ] Build click interaction.
* [ ] Build basic camera controls.
* [ ] Build basic overlays.

---

## 12.3 First visual vertical slice

### Scope

Era 1 playable slice with visible workshop activity.

### Includes

* 1 room
* founder/player visible
* 1 bench
* 1 shelf
* incoming and outgoing job area
* 5 repair jobs
* visible walking and work animation
* basic tool upgrades
* save/load

### Acceptance criteria

* The player can visually watch jobs being processed.

---

## 12.4 Second visual slice

### Scope

Era 2 repair shop slice.

### Includes

* second worker
* second bench
* diagnostics station
* visible queue flow
* reception area
* first obvious bottleneck behavior
* hiring
* assignment

### Acceptance criteria

* Parallel work is visible and satisfying.

---

## 12.5 Third visual slice

### Scope

Era 3 electronics workshop slice.

### Includes

* PCB prototype workflow
* R&D area
* oscilloscope bench
* reflow station
* firmware desk
* prototype item flow

### Acceptance criteria

* The player can watch the shift from repair to engineering.

---

## 12.6 Manufacturing slice

### Scope

Era 4 small manufacturer slice.

### Includes

* assembly pipeline
* testing
* packaging
* simple market sales
* visible product flow through production stages

### Acceptance criteria

* A product can visibly move through a multi-step production process.

---

# 13. Revised Milestones

## Milestone 1 — Visual Core Loop

* [ ] Workshop scene exists
* [ ] Founder visible
* [ ] Basic repair flow visible
* [ ] One bench and one shelf
* [ ] Jobs visually enter and exit system
* [ ] Money/reputation update works

## Milestone 2 — Repair Shop

* [ ] Multiple workers visible
* [ ] Multiple benches visible
* [ ] Diagnostics visible
* [ ] Parts retrieval visible
* [ ] Job queue visible
* [ ] Bottlenecks begin to appear

## Milestone 3 — Electronics Workshop

* [ ] PCB-related workflow visible
* [ ] R&D visible
* [ ] Specialist roles visible
* [ ] Prototype process visible

## Milestone 4 — Small Manufacturing

* [ ] Product pipeline visible
* [ ] Assembly/testing/packaging visible
* [ ] Machines visibly transform capacity

## Milestone 5 — Industrial Supplier

* [ ] Larger facility layout
* [ ] QA and contract work visible
* [ ] Larger throughput and complexity visible

## Milestone 6 — Advanced Technology Company

* [ ] Distinct production divisions visible
* [ ] Advanced products visible
* [ ] Final company scale dramatically different from start

---

# 14. Design Rules for This Updated Version

## Rule 1

The workshop/factory view is the primary play surface.

## Rule 2

Every major upgrade must have a visible representation.

## Rule 3

Workers, items, and stations should communicate the process visually.

## Rule 4

If a system cannot be felt in the workshop scene, reconsider whether it needs a stronger visual representation.

## Rule 5

The player should be able to see progression both numerically and spatially.

## Rule 6

Menus and panels support the simulation; they do not replace it.

## Rule 7

The first hour should already show satisfying visual growth, even before advanced systems unlock.

---

# 15. Definition of Done

The game is considered complete for the first full PC release when:

* [ ] The player starts in a tiny visible workshop.
* [ ] The player can watch repair jobs happen in real time.
* [ ] Workers physically exist and do their jobs.
* [ ] Stations, benches, tools, and machines are visible and upgrade visually.
* [ ] Parts and products move visibly through the company.
* [ ] Workshop expansions change the building physically.
* [ ] Era transitions feel visible and dramatic.
* [ ] Products can be visually manufactured through multi-stage pipelines.
* [ ] Bottlenecks can be observed in the scene.
* [ ] UI panels support but do not replace the visual workshop simulation.
* [ ] The visual language remains readable in 2D pixel art.
* [ ] The player can clearly feel the transformation from small repair shop to advanced technology company.
