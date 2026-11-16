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

During the previous Break the Blockade playtest, Mara’s offer treated an early Captain defeat as a completed objective. In this checkpoint, kill objectives start at zero and the Captain can return after an early defeat. Regular wolves and raiders return after their configured delay while the Warrior is outside their encounter area. The current placements use a 30-second delay and a 10-meter leash radius. [Issue #1](https://github.com/dylcruz/stonewatch-vale/issues/1), [issue #2](https://github.com/dylcruz/stonewatch-vale/issues/2)

The user reported that wolves killed before quest acceptance stayed defeated. The automated test reproduced this by killing the first road wolf via click-to-attack and waiting at the watchpost, which is inside that wolf’s leash radius. Returning to the green refuge now counts as leaving the encounter for respawns, matching the pursuit rule.

**Automated on Windows with Godot 4.7.2 Standard.** Movement, combat, quest chain, and graphical breadcrumbs passed. The 56 quest assertions include the pre-quest wolf respawn at the refuge, the normal 240 XP route, active-only kill credit, repeated regular defeats, and the Captain’s early defeat and one-time rewards. The quest suite also passed with the Compatibility renderer. The sandboxed runs reported errors writing user data.

**Windows user playtest pending.**

- [ ] Defeat the first road wolf before accepting Clear Pine Road. Return to the green watchpost refuge and wait for the 30-second timer to expire. Confirm the wolf returns. Accept Clear Pine Road at 0 / 3, then defeat the wolf again and verify it advances to 1 / 3.
- [ ] Defeat a regular wolf or raider and stay near its spawn for more than 30 seconds. Verify it stays down, then leave the encounter area and check that it returns at full health. On the next defeat, leave immediately and check that it stays down until the delay elapses.
- [ ] Defeat the Captain before accepting Break the Blockade. Confirm the first defeat grants 50 XP and the Warden’s Coat. Leave the quarry and accept Break the Blockade. Confirm the objective starts at 0 / 1. Return to Quarry Gate after the delay, defeat the Captain again, and confirm the turn-in is ready and XP and loot do not repeat. Return after the delay to verify the credited Captain stays defeated.

## Concurrent quest journal checkpoint

Mara offers Clear Pine Road and Recover the Supplies from the start. The player can accept and turn in either quest first. Break the Blockade unlocks after both turn-ins. [Issue #3](https://github.com/dylcruz/stonewatch-vale/issues/3)

**Automated on Windows with Godot 4.7.2 Standard.** Movement, combat, quest chain, and graphical breadcrumbs passed. The quest suite passed 70 assertions covering independent objectives and rewards, both turn-in orders, HUD tracking during movement, and the Captain’s prerequisites. The journal and Mara’s dialogue were also checked with the Compatibility renderer.

**Windows user playtest pending.**

- [ ] Accept both quests before turning either in. Open **J** and verify each quest has its own objective. Use **Track** to switch the single HUD objective while a movement command is active.
- [ ] Defeat one road wolf and recover the crate while tracking Clear Pine Road. Confirm the journal shows `1 / 3` for Clear Pine Road and **Ready to turn in** for Recover the Supplies.
- [ ] Defeat the remaining wolves and return to Mara with both quests ready. Turn in Recover the Supplies first. Confirm the journal shows it as completed and Clear Pine Road still ready with all three kills. Turn in Clear Pine Road and verify Break the Blockade becomes available at 155 XP.
