# Stonewatch Vale playtest

## Accepted checkpoints

The user confirmed Windows playtesting for click-to-move and held steering, route breadcrumbs, melee, the full wolf encounter, raiders and Cleave, and the Captain’s telegraph. The user also accepted Clear Pine Road and Recover the Supplies. Prior Windows checks found that fixed HUD panels can overlap world labels as the camera follows the Warrior. A Windows executable export is pending matching Godot 4.7.2 templates.

## Automated verification

The original three-quest F5 scene passed the launch smoke test. The terrain navigation bake saved 27 polygons. The four suites passed 156 assertions across movement, combat, the quest chain, and graphical breadcrumbs. The sandboxed editor import completed with a safe-save error during initialization.

## Current Windows checklist

Press **F5** to launch the watchpost arena.

- [ ] Route around the ruin. Try the disconnected platform, click the HUD, and verify both preserve the active movement command. Check held steering and breadcrumb clearance on arrival.
- [ ] Accept Clear Pine Road, defeat three wolves, and report to Mara. Confirm 100 XP, level 2, 75 max HP, and Cleave. Equip the Iron Sword in **I** and confirm 12 sword damage.
- [ ] Accept Recover the Supplies and collect the marked crate. Return with both guards alive and confirm 155 XP. Try **J** to check active and completed entries.
- [ ] Accept Break the Blockade. Dodge the Captain’s red circle once, then time Guard to halve a heavy hit. Defeat the Captain for 50 XP and the Warden’s Coat. Equip the coat and confirm 2 armor.
- [ ] Turn in the final quest. With optional enemies alive, confirm 240 XP, level 3, and 90 max HP. Check that death recovery retains progress during the run and reopening dialogue leaves XP and gear unchanged.

## Quest credit and respawn checkpoint

During the previous Break the Blockade playtest, Mara’s offer treated an early Captain defeat as a completed objective. In this checkpoint, kill objectives start at zero and the Captain can return after an early defeat. Regular wolves and raiders return after their configured delay while the Warrior is outside their leash radius. The current placements use a 30-second delay and a 10-meter radius. [Issue #1](https://github.com/dylcruz/stonewatch-vale/issues/1), [issue #2](https://github.com/dylcruz/stonewatch-vale/issues/2)

**Automated on Windows with Godot 4.7.2 Standard.** Movement, combat, quest chain, and graphical breadcrumbs passed. The 52 quest assertions include the normal 240 XP route, active-only kill credit, both respawn conditions, repeated regular defeats, and the Captain’s early defeat and one-time rewards. The quest suite also passed with the Compatibility renderer. The sandboxed runs reported errors writing user data.

**Windows user playtest pending.**

- [ ] Defeat a road wolf before accepting Clear Pine Road. Verify the objective starts at 0 / 3, then defeat a respawned wolf and verify it advances to 1 / 3.
- [ ] Defeat a regular wolf or raider and stay near its spawn for more than 30 seconds. Verify it stays down, then leave the encounter area and check that it returns at full health. On the next defeat, leave immediately and check that it stays down until the delay elapses.
- [ ] Defeat the Captain before accepting Break the Blockade. Confirm the first defeat grants 50 XP and the Warden’s Coat. Leave the quarry and accept Break the Blockade. Confirm the objective starts at 0 / 1. Return to Quarry Gate after the delay, defeat the Captain again, and confirm the turn-in is ready and XP and loot do not repeat. Return after the delay to verify the credited Captain stays defeated.

## Quest journal follow-up

- [ ] Accept two eligible quests before either turn-in. Verify the journal shows both and that turning in one preserves the other’s progress and turn-in state.
