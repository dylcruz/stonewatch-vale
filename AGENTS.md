# Repository Guidelines

## Project Structure & Module Organization

Stonewatch Vale is a Godot 4.7.2 Standard project using GDScript and the Compatibility renderer.

- `scenes/`: editable `.tscn` scenes. The main scene `stonewatch_vale.tscn` and the developer scene `watchpost_playtest.tscn` share the player, HUD, and terrain through `vale_gameplay.tscn`. The main scene adds the starting town and its navigation mesh. The developer scene adds the Watchpost quests and encounters. Actor scenes are reusable.
- `scripts/`: movement, camera, combat, health, and breadcrumb rendering. `warrior.gd` extends the shared player motor.
- `data/`: `.tres` resources containing actor stats and combat tuning.
- `tests/`: executable GDScript regression suites; `tools/`: navigation baking.
- `docs/`: implementation sequence and playtest records.

Visuals currently use Godot primitives and `icon.svg`. Keep generated `.godot/` caches and local `builds/` artifacts untracked. Preserve script `.uid` files.

## Build, Test, and Development Commands

Run from the repository root; substitute your Godot executable for `godot`.

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . --script res://tests/movement_test.gd
godot --headless --path . --script res://tests/combat_test.gd
godot --headless --path . --script res://tests/quest_chain_test.gd
godot --headless --path . --script res://tests/vale_routes_test.gd
godot --path . --script res://tests/breadcrumb_test.gd
git diff --check
```

Import before testing. Breadcrumb checks require graphics because they inspect render-buffer transforms. In the editor, **F5** starts the main game in town. Open `scenes/watchpost_playtest.tscn` and press **F6** for the original watchpost checkpoint.

After collision-layout changes, bake and save both navigation meshes. Run this command with the editor closed.

```sh
godot --headless --path . --script res://tools/bake_navigation.gd
```

Windows exports require matching 4.7.2 templates; place outputs under `builds/`.

## Coding Style & Naming Conventions

Use tabs for GDScript indentation, `snake_case` filenames/functions/variables, `PascalCase` node and class names, and `UPPER_SNAKE_CASE` constants. Follow existing typed declarations, signals, and `@export` tuning properties. Keep reusable behavior in scripts and authored geometry in scenes. Use UTF-8 and LF line endings. No standalone formatter or linter is configured.

## Testing Guidelines

Tests extend `SceneTree`, instantiate real scenes, print assertions, and return nonzero on failure. Name suites `tests/<feature>_test.gd`. Cover relevant behavior and regressions; no numeric coverage threshold is configured. Verify visual/input changes in Windows and update playtest records, distinguishing automated results from user confirmation.

## Commit & Pull Request Guidelines

Use concise, imperative commit subjects, matching history: `Add first melee combat checkpoint and path breadcrumbs`. Keep commits focused on reviewable checkpoints. PRs should explain changed behavior, list validation and limitations, link relevant issues when applicable, and include screenshots for visual changes.

Branch feature work from `dev` and target `dev` with feature PRs. Release a batch of integrated features through a PR from `dev` to `main`. GitHub Actions tests both branches and produces Windows executables only after tests pass on a push to `main`.

## Gameplay Direction

Design Stonewatch Vale as an open, living world with standalone quests and quest chains. Keep chain prerequisites local to the quests they unlock. Let players choose which zones to explore and level through local quests and combat. Quest turn-ins should be the main source of XP, with smaller rewards from repeatable encounters. Use the watchpost quest route as a playtest benchmark for one way to level.

## Incremental Delivery

Follow `docs/stonewatch-implementation-plan.md`. Implement one playable checkpoint at a time and pause for user playtesting before advancing. Preserve accepted movement behavior, including HUD input consumption and rejection of unreachable destinations.
