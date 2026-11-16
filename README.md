# Stonewatch Vale

A single-player 3D action RPG prototype. Movement is playtested; the current checkpoint adds the Warrior's first melee fight against one wolf in the graybox arena. See the [implementation plan](docs/stonewatch-implementation-plan.md) for later checkpoints and milestones.

## Run

1. Use **Godot 4.7.2 Standard** (`4.7.2.stable.official.ed1daf0bf`) with the Compatibility renderer.
2. Import `project.godot` in Godot Project Manager and allow the initial import to finish.
3. Press **F5**. The main scene is `scenes/combat_demo.tscn`; it opens directly into the first melee checkpoint. The accepted movement-only scene remains available at `scenes/movement_demo.tscn` (open it and press **F6**).

## Controls

- **Left-click ground:** move along the navigation mesh. A gold ring briefly marks the accepted destination.
- **Breadcrumb route:** gold dots show the remaining navigation path around obstacles. They disappear behind the Warrior and clear on arrival or when movement stops. Replacement clicks and held steering update the route; invalid destinations and HUD clicks preserve it. Breadcrumbs are enabled by default in both demos. A player-facing toggle can be added later.
- **Hold left mouse on the world:** continuously steer toward the cursor. Release to finish moving to the last valid destination. Passing over the HUD pauses destination updates; starting a press on the HUD does not steer.
- **Left-click the wolf:** select it, approach, and automatically swing while in melee range. The gold selection ring shows the target. Sword swings and wolf bites have a windup, and check range and blocking scenery when damage resolves.
- **Left-click ground while fighting:** clear selection, cancel any pending sword hit, and move. The wolf can still finish its bite if you remain within reach. Holding LMB on ground also cancels combat and steers as before.
- **R / Reset fight:** restore both actors' health, positions, and combat state, including after either dies.
- **Test UI · keep command:** verifies UI input without changing movement or targeting. The entire HUD panel consumes clicks.
- Scenery, void, and the disconnected platform reject movement clicks and preserve the current command. Close the window or press **F8** in the editor to stop.

The blue capsule is the Warrior; the gray four-legged silhouette is the wolf. The Warrior has a visible sword swing, the wolf lunges its head to bite, hits flash the body, and health bars and timing text appear at the lower left. The camera follows at a fixed angle, zoom, and distance. The blue capsule's gold nose shows its facing direction. The wolf retaliates in melee but stays at its spawn in this checkpoint; Guard, roaming aggro/leash, raiders, Cleave, and the boss come after playtesting this first slice.

## Edit and bake

`scenes/combat_demo.tscn` inherits the accepted `scenes/movement_demo.tscn` arena, replaces the practice target with an instance of `scenes/wolf.tscn`, and adds the combat HUD. Open the base movement scene to edit the floor, enclosing walls, blocking ruin, disconnected platform, and baked navigation. The road strips and labels are visual guides. Player movement lives in `scripts/player.gd`, ray picking in `scripts/movement_demo.gd`, and camera following in `scripts/follow_camera.gd`.

The combat layer lives in `scripts/warrior.gd`, `scripts/wolf.gd`, and `scripts/combat_demo.gd`. Shared health and melee validation live in `scripts/health.gd` and `scripts/melee.gd`. Tune HP, damage, reach, windup, and attack intervals in `data/warrior.tres` and `data/wolf.tres`. The base scene's `PathBreadcrumbs` node and `scripts/path_breadcrumbs.gd` draw the route; its `enabled` property defaults to true and provides the hook for a future visibility setting.

After changing collision geometry, select `NavigationRegion3D`, choose **Bake NavigationMesh**, and save the scene. Baking reads static colliders on physics layers 1 (ground) and 2 (obstacles), with a 0.5 m agent margin for the 0.35 m player capsule. Player collision uses layer 3; target picking also uses layer 4. The navigation mesh is saved in the scene, so launching does not require a runtime bake.

Alternatively, with the editor closed, run:

```sh
godot --headless --path . --script res://tools/bake_navigation.gd
```

Navigation uses Godot's [NavigationAgent3D path following](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationagents.html). Complete paths are validated before replacing an active command; unreachable islands are rejected even when the server can return a partial path.

## Verification

Import once before running the automated movement checks:

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . --script res://tests/movement_test.gd
godot --headless --path . --script res://tests/combat_test.gd
```

Run the breadcrumb draw-buffer checks with a graphical renderer:

```sh
godot --path . --script res://tests/breadcrumb_test.gd
```

The source-project movement and first melee playtests are complete, including user confirmation. See [movement playtest results](docs/movement-playtest.md) for the breadcrumb follow-up, the recorded label-overlap caveat, and export limitations, and the [combat checklist](docs/combat-playtest.md) for the accepted first melee checkpoint.

## Windows export

Install the matching **4.7.2** export templates through **Editor → Manage Export Templates**. Add a **Windows Desktop** preset under **Project → Export**, select an x86_64 executable under the ignored `builds/` directory, and export. Repeat the playtest in the exported Windows build when one is produced; the source project is the milestone deliverable.

## Assets

All arena visuals use Godot primitive meshes, materials, labels, and the built-in font. No external art or models were added.
