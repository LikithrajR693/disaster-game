# READY OR NOT: THE LAST 10 MINUTES

A complete offline 2D disaster-preparedness simulation set in the fictional Indian town of Aaranya.

## Run

1. Open `project.godot` in Godot 4.4 or newer and wait for project scanning to finish.
2. Press **F5** (Run Project) to launch the configured main menu.
3. **F6** runs only the currently selected scene. `node_2d.tscn` is an empty editor-created scene and shows a blank viewport when run by itself.
4. Windows 1280 × 720 compatibility rendering is configured.

## Controls

- `WASD` or arrow keys: move
- `E`: interact
- `M`: mute/unmute audio
- `[MAP]` HUD button: field map
- `I`: emergency inventory
- `J`: mission objectives
- `ESC`: pause (or close a non-critical information panel)
- Mouse: menus and decisions
- Gamepad: left stick to move, A to interact/select, X for inventory, Y for map, Back for objectives, Start to pause, and B/Escape to close menus.

During a critical emergency decision, use **Up/Down** to navigate, **Enter** to choose, or **1**, **2**, and **3** to select an option directly. **Escape cannot discard an unanswered emergency decision.**

## Missions

1. **The Ground Remembers:** Drop, Cover and Hold On, assess damage, assist residents and evacuate.
2. **The Rising Line:** move to elevated shelter, avoid floodwater and electrical hazards.
3. **The Last Exit:** activate the alarm, use stairs, avoid smoke and elevators, and account for residents.

The project uses only Godot built-in nodes and procedural graphics. No assets, APIs or internet access are required.

## Feel and feedback tuning

Shared gameplay and presentation values live in `scripts/game_config.gd` (autoloaded as `GameConfig`). Movement speed/acceleration, escort spacing, camera damping and shake, interaction hit-stop, particle bursts, score popups, UI motion, audio variation, and pause ambience are tuned there. Audio and screen-shake preferences are saved locally in `user://settings.cfg`.

Interaction feedback is owned by `FeedbackManager`: short overlapping hit-stop requests are safely coalesced, and temporary particles, score callouts, and screen flashes are released automatically. `UIFeedback` provides the shared keyboard, mouse, and focus response for interactive controls. The procedural `SoundManager` adds light pitch/gain variation and ducks/filters ambience during pause and hit-stop without muting menu feedback.

## Disaster atmosphere

Mission worlds use a power-outage twilight grade, flickering streetlights, responder headlamp, green safe-zone/clinic beacons, and restrained procedural dust, rain, smoke, and electrical sparks. Earthquake camera trauma and screen-edge cues react to nearby hazards; flood missions add rain, moving water highlights, and ripples. World lighting and atmospheric overlays are kept below the mission HUD and layer-100 decision/debrief modals.

## Educational basis

Content follows Indian disaster-preparedness principles: immediate earthquake protective action, never entering uncertain or moving floodwater, and immediate fire evacuation by stairs rather than elevators. This game is educational and does not replace official emergency instructions.
