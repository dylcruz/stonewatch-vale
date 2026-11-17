# Stonewatch Vale

A single-player 3D action RPG prototype. Captain Mara sends the Warrior to clear Pine Road, recover supplies, and defeat the Raider Captain. See the [implementation plan](docs/stonewatch-implementation-plan.md) for later milestones.

## Run

1. Use **Godot 4.7.2 Standard** (`4.7.2.stable.official.ed1daf0bf`) with the Compatibility renderer.
2. Import `project.godot` in Godot Project Manager and allow the initial import to finish.
3. Press **F5** to start a fresh level 1 run in `scenes/stonewatch_vale.tscn`. Click Captain Mara at the watchpost for **Clear Pine Road**. After each turn-in, choose **View next quest** or speak to Mara again. Progress stays in the current run, including through defeat and recovery.

## Controls

- **Left-click ground:** move along the navigation mesh. A gold ring briefly marks the accepted destination.
- **Breadcrumb route** shows the remaining path around obstacles. The gold dots disappear behind the Warrior and clear when movement stops.
- **Hold left mouse on the world:** continuously steer toward the cursor. Release to finish moving to the last valid destination. Passing over the HUD pauses destination updates; starting a press on the HUD does not steer.
- **Left-click an enemy:** select it, approach, and automatically swing while in melee range. The gold ring marks your target. Basic attacks check range and blocking scenery at impact.
- **Left-click ground while fighting:** clear selection, cancel any pending sword hit, and move. Enemies give up the chase when you leave their leash range or reach the green watchpost circle.
- **1 — Cleave:** deal 12 damage to enemies in front of the Warrior within 2.8 m. Unlocks at level 2 and has a 4-second cooldown.
- **2 — Guard:** halve incoming damage for 1.25 seconds. A blue ring and the HUD show when Guard is active. The 6-second cooldown starts on activation.
- **J — Quest log:** check the current objective, turn-in status, and completed quests.
- **I — Gear:** inspect equipment, sword damage, and armor. Equip the Iron Sword and Warden’s Coat after earning them.
- **After defeat:** wait two seconds to recover at the watchpost at full health.
- HUD panels consume clicks and preserve the active movement command.
- Scenery, void, and the disconnected platform reject movement clicks and preserve the current command. Close the window or press **F8** in the editor to stop.

Three road wolves are east of the watchpost. They award 5 XP each, and turning in the quest grants 85 XP. At 100 XP the Warrior reaches level 2, gains 15 max HP, and can use Cleave. Equipping the Iron Sword raises basic sword damage from 8 to 12. An extra wolf northwest of the ruin gives you a target for the upgrade.

For **Recover the Supplies**, take Pine Road north and follow it west around the ruin to the abandoned campsite. Click the marked crate to approach and collect it. Each raider is worth 5 XP if defeated. Returning the crate to Mara grants 55 XP.

For **Break the Blockade**, take the south road west to Quarry Gate. Move out of the Raider Captain’s red circle to avoid the heavy hit or use Guard to halve it. Each Captain defeat awards 15 XP, and the first also grants the Warden’s Coat. Equipping it adds 2 armor. Turning in the quest grants 70 XP. The watchpost quests and their objectives give the Warrior one way to reach 240 XP, level 3, and 90 max HP.

Kill objectives count defeats while their quest is active. Wolves, raiders, and the Captain can respawn 30 seconds after any defeat. To let them return, move beyond their leash radius or wait in the green watchpost refuge. The Captain remains available for rematches after Break the Blockade is complete.

## Edit and bake

`scenes/stonewatch_vale.tscn` contains the playable watchpost, encounters, and HUD. Open its base `scenes/watchpost_arena.tscn` to edit the shared floor, walls, ruin, and baked navigation. Quest, combat, and item definitions live under `data/`. Player movement lives in `scripts/player.gd`, ray picking in `scripts/world_input.gd`, and camera following in `scripts/follow_camera.gd`.

Warrior abilities live in `scripts/warrior.gd`. The wolf and raiders share aggro, navigation, and basic attack timing through `scripts/enemy.gd`. The Captain inherits `scenes/raider.tscn` and enables the heavy attack in `scripts/raider.gd`. Tune HP, basic damage, reach, windup, and attack intervals in the actor resources under `data/`. Ability and pursuit settings are exported on the actor nodes. The `Watchpost` marker sets the recovery position and the center of the refuge.

After changing collision geometry, open `watchpost_arena.tscn`, select `NavigationRegion3D`, choose **Bake NavigationMesh**, and save. Baking reads ground and obstacle colliders on physics layers 1 and 2. Player collision uses layer 3 and target picking uses layer 4.

Alternatively, with the editor closed, run:

```sh
godot --headless --path . --script res://tools/bake_navigation.gd
```

Navigation uses Godot's [NavigationAgent3D path following](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationagents.html). Complete paths are validated before replacing an active command; unreachable islands are rejected even when the server can return a partial path.

## Verification

Import once before running the automated checks.

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . --script res://tests/movement_test.gd
godot --headless --path . --script res://tests/combat_test.gd
godot --headless --path . --script res://tests/quest_chain_test.gd
```

Run the breadcrumb draw-buffer checks with a graphical renderer:

```sh
godot --path . --script res://tests/breadcrumb_test.gd
```

See the [playtest record](docs/playtest.md) for Windows results and the quest credit and respawn checklist.

## Development and releases

Create feature branches from `dev` and open feature pull requests against `dev`. When a batch of features is ready to release, open a pull request from `dev` to `main`.

GitHub Actions runs the Godot regression suites on pull requests to `dev` and `main`, pushes to either branch, and manual runs. A push to `main` exports and uploads the x86_64 Windows build after the tests pass. Download `stonewatch-vale-windows-x86_64` from that workflow run and repeat the Windows playtest in `StonewatchVale.exe`.

## Assets

All arena visuals use Godot primitive meshes, materials, labels, and the built-in font. No external art or models were added.
