# Stonewatch Vale

A single-player 3D action RPG prototype. The current milestone proves click-to-move in a small, editable graybox arena. Combat, quests, progression, saving, and the full vale are later milestones in the [implementation plan](docs/stonewatch-implementation-plan.md).

## Run

1. Use **Godot 4.7.2 Standard** (`4.7.2.stable.official.ed1daf0bf`) with the Compatibility renderer.
2. Import `project.godot` in Godot Project Manager and allow the initial import to finish.
3. Press **F5**. The main scene is `scenes/movement_demo.tscn`; it opens directly into the movement demo.

## Controls

- **Left-click ground:** move along the navigation mesh. A gold ring briefly marks the accepted destination.
- **Hold left mouse on the world:** continuously steer toward the cursor. Release to finish moving to the last valid destination. Passing over the HUD pauses destination updates; starting a press on the HUD does not steer.
- **Left-click the practice target:** select it and approach within interaction range. Its gold selection ring stays visible. This milestone has no attacks.
- **Left-click ground while approaching a target:** clear selection and replace the movement command.
- **Test UI · keep moving:** verifies UI input without changing the movement command. The entire HUD panel consumes clicks.
- Scenery, void, and the disconnected platform reject movement clicks and preserve the current command. Close the window or press **F8** in the editor to stop.

The camera follows at a fixed angle, zoom, and distance. The blue capsule's gold nose shows its facing direction. Click past the central ruin to test routing around it; the separate platform to the east tests unreachable destinations.

## Edit and bake

Open `scenes/movement_demo.tscn`. The floor, enclosing walls, blocking ruin, disconnected platform, and practice target are authored nodes below `NavigationRegion3D`. The road strips and labels are visual guides. Player movement lives in `scripts/player.gd`, ray picking in `scripts/movement_demo.gd`, and camera following in `scripts/follow_camera.gd`.

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
```

The source-project movement playtest is complete, including Windows rendering and user-confirmed physical-mouse testing. See [movement playtest results](docs/movement-playtest.md) for checks, the recorded label-overlap caveat, and export limitations.

## Windows export

Install the matching **4.7.2** export templates through **Editor → Manage Export Templates**. Add a **Windows Desktop** preset under **Project → Export**, select an x86_64 executable under the ignored `builds/` directory, and export. Repeat the playtest in the exported Windows build when one is produced; the source project is the milestone deliverable.

## Assets

All arena visuals use Godot primitive meshes, materials, labels, and the built-in font. No external art or models were added.
