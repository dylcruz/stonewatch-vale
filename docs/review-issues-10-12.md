# Save checkpoint review

[Issues #10–12](https://github.com/dylcruz/stonewatch-vale/issues/10) share the local save and restore flow. Press **F5** to open the title screen. **New Game** starts in the town square; **Continue** restores the latest checkpoint there. New Game asks before replacing a valid existing save. The slot lives at `user://stonewatch-slot.save`.

The compact Watchpost remains a fresh **F6** scene. To exercise the same save code with quests, launch a development build with `godot --path . -- --watchpost-save`. This opens the title screen for the developer scene with an isolated playtest slot. Continue there returns to the Watchpost recovery point. The Captain's respawn delay resumes from the last checkpoint and his coat stays one-time. Repeat defeats continue to grant XP, matching the accepted recurring Captain checkpoint.

Automated Windows checks relaunch Godot at each step and verify a missing and corrupt slot, replacement confirmation, mid-quest progress, both Captain defeat paths, both gear upgrades, and a completed chain without a second turn-in.

The town square is the accepted player-facing spawn. The recurring Captain playtest established repeat kill XP and a one-time coat. Final release quest placements remain open.

For [#14](https://github.com/dylcruz/stonewatch-vale/issues/14), the README now explains New Game, Continue, and the developer quest route. Update the quest directions for the release world once the final placements are authored. All artwork added in this branch uses Godot's built-in controls.
