# Stonewatch Vale playtest

## Accepted checkpoints

The user confirmed Windows playtesting for click-to-move and held steering, route breadcrumbs, melee, the full wolf encounter, raiders and Cleave, and the Captain’s telegraph. The user also accepted Clear Pine Road and Recover the Supplies. Prior Windows checks found that fixed HUD panels can overlap world labels as the camera follows the Warrior. A Windows executable export is pending matching Godot 4.7.2 templates.

## Automated verification

The original three-quest F5 scene passed the launch smoke test. The terrain navigation bake saved 27 polygons. The four suites passed 156 assertions across movement, combat, the quest chain, and graphical breadcrumbs. The sandboxed editor import completed with a safe-save error during initialization.

## Current Windows checklist

Press **F5** to launch the watchpost arena. This checklist uses the watchpost quests as one example of leveling through the zone.

- [ ] Route around the ruin. Try the disconnected platform, click the HUD, and verify both preserve the active movement command. Check held steering and breadcrumb clearance on arrival.
- [ ] Accept Clear Pine Road, defeat three wolves, and report to Mara. Confirm 100 XP, level 2, 75 max HP, and Cleave. Equip the Iron Sword in **I** and confirm 12 sword damage.
- [ ] Accept Recover the Supplies and collect the marked crate. Return with both guards alive and confirm 155 XP. Try **J** to check active and completed entries.
- [ ] Accept Break the Blockade. Dodge the Captain’s red circle once, then time Guard to halve a heavy hit. Defeat the Captain for 15 XP and the Warden’s Coat. Equip the coat and confirm 2 armor.
- [ ] Turn in the final quest. With optional enemies alive, confirm 240 XP, level 3, and 90 max HP. Check that death recovery retains progress during the run and reopening dialogue leaves XP and gear unchanged.

## Quest credit and respawn checkpoint

During the previous Break the Blockade playtest, Mara’s offer treated an early Captain defeat as a completed objective. In this checkpoint, kill objectives start at zero and the Captain can return after an early defeat. Regular wolves and raiders return after their configured delay while the Warrior is outside their encounter area. The current placements use a 30-second delay and a 10-meter leash radius. [Issue #1](https://github.com/dylcruz/stonewatch-vale/issues/1), [issue #2](https://github.com/dylcruz/stonewatch-vale/issues/2)

The user reported that wolves killed before quest acceptance stayed defeated. The automated test reproduced this by killing the first road wolf via click-to-attack and waiting at the watchpost, which is inside that wolf’s leash radius. Returning to the green refuge now counts as leaving the encounter for respawns, matching the pursuit rule.

**Automated on Windows with Godot 4.7.2 Standard.** Movement, combat, quest chain, and graphical breadcrumbs passed. The 56 quest assertions include the pre-quest wolf respawn at the refuge, the normal 240 XP route, active-only kill credit, repeated regular defeats, and the Captain’s early defeat and one-time rewards. The quest suite also passed with the Compatibility renderer. The sandboxed runs reported errors writing user data.

**Windows user playtest passed.** The user confirmed the open checks on November 16, 2026.

- [x] Defeat the first road wolf before accepting Clear Pine Road. Return to the green watchpost refuge and wait for the 30-second timer to expire. Confirm the wolf returns. Accept Clear Pine Road at 0 / 3, then defeat the wolf again and verify it advances to 1 / 3.
- [x] Defeat a regular wolf or raider and stay near its spawn for more than 30 seconds. Verify it stays down, then leave the encounter area and check that it returns at full health. On the next defeat, leave immediately and check that it stays down until the delay elapses.
- [x] Defeat the Captain before accepting Break the Blockade. Confirm the first defeat grants 50 XP and the Warden’s Coat. Leave the quarry and accept Break the Blockade. Confirm the objective starts at 0 / 1. Return to Quarry Gate after the delay, defeat the Captain again, and confirm the turn-in is ready and XP and loot do not repeat. Return after the delay to verify the credited Captain stays defeated.

## Recurring Captain and quest XP checkpoint

The Captain now follows the same exit and timer rules as regular enemies, including after a credited defeat or a completed turn-in. Wolves and raiders award 5 XP per defeat. The Captain awards 15 XP per defeat and the Warden’s Coat on the first defeat. In the watchpost playtest, the three turn-ins award 210 of the 240 XP needed to reach level 3.

**Automated on Windows with Godot 4.7.2 Standard.** Movement, combat, quest chain, and graphical breadcrumbs passed. The quest suite covers XP before acceptance, with the turn-in ready, and after completion, as well as the authored 240 XP route.

**Windows user playtest pending.**

- [ ] Defeat the Captain with Break the Blockade active. Check that the quest is ready to turn in and the Captain awards 15 XP. Leave Quarry Gate and wait for the 30-second timer. Return to fight him while the turn-in is ready. Verify another 15 XP, one Warden’s Coat, and the same ready objective.
- [ ] Turn in Break the Blockade and revisit Quarry Gate after the respawn delay. Verify that the Captain is back at full health and the journal still shows the completed quest.
- [ ] Check that a wolf and a regular raider each award 5 XP. On a fresh run with optional enemies alive, check turn-in rewards of 85, 55, and 70 XP. This watchpost playtest reaches level 2 at the first turn-in and level 3 at the last.

## Quest journal follow-up

- [ ] Accept two eligible quests before either turn-in. Verify the journal shows both and that turning in one preserves the other’s progress and turn-in state.

## Vale routes checkpoint

The terrain now connects the fenced watchpost, Pine Road, the campsite and supply cart, and Quarry Gate. Pine Meadow rejoins North Road at the north meadow junction. Birchwater has a stone ford and timber bridge linked by an east-bank trail. Two climbs connect Signal Ridge and its lookout to North Road. All three loops are open on a fresh run. [Issue #4](https://github.com/dylcruz/stonewatch-vale/issues/4), [issue #5](https://github.com/dylcruz/stonewatch-vale/issues/5), [issue #6](https://github.com/dylcruz/stonewatch-vale/issues/6), [issue #7](https://github.com/dylcruz/stonewatch-vale/issues/7)

The Windows Godot 4.7.2 bake saved 360 navigation polygons. All five regression suites passed. The route suite passed 22 checks with the timed crossing enabled, including two-way portal, river, and ridge movement, matching placements across fresh runs, and command preservation when clicking deep water or a cliff. The route and landmark views were checked with the Compatibility renderer.

### Recorded timings

Times are 60 Hz simulation time from scripted gameplay clicks on Windows. The watchpost run started from a fresh instance and included combat and turn-ins with zero recoveries. The crossing used camera clicks and walked each leg from Heather Rest onward.

| Route | Measured time |
| --- | ---: |
| Watchpost → three road wolves → Mara | 21.7 s |
| Watchpost run through the supply crate turn-in | 33.4 s cumulative |
| Watchpost run through the Captain turn-in, optional encounters alive | 42.1 s cumulative |
| Heather Rest → north meadow junction → North Road → south ridge climb → Signal Ridge lookout, 613.9 m | 124.6 s |

The direct watchpost run is below the 10–15 minute benchmark. Time an exploratory run during the Windows playtest to see where discovery, combat, and optional content can add time. The three existing quest placements are close to Mara. [Issue #8](https://github.com/dylcruz/stonewatch-vale/issues/8)

To rerun the automated crossing, append `-- --pace` to the `vale_routes_test.gd` command.

### Windows user playtest

- [ ] From the watchpost, follow Pine Road to the supply cart and continue on foot to Quarry Gate. Return by the south road and check the junction signs and map edges from the gameplay camera.
- [ ] On a fresh run, take the east opening into Pine Meadow. Pass through Heather Rest and use the north trail to reach North Road.
- [ ] Cross Birchwater using the stone ford and return using the timber bridge. Try a deep-water click while moving and verify the original destination stays active.
- [ ] Climb Signal Ridge to the signal mast and descend the other climb. Try clicking a steep face while moving on the trail.
- [ ] Time a fresh watchpost quest run and a crossing from Heather Rest to the lookout via North Road. Record detours, combat, and stops that affect the times.
