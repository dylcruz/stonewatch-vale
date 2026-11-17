# Stonewatch Vale playtest

## Accepted checkpoints

The user confirmed Windows playtesting for click-to-move and held steering, route breadcrumbs, melee, the full wolf encounter, raiders and Cleave, and the Captain’s telegraph. Prior Windows checks found that fixed HUD panels can overlap world labels as the camera follows the Warrior.

## Automated verification

The original three-quest F5 scene passed the launch smoke test. The terrain navigation bake saved 27 polygons. The four suites passed 156 assertions across movement, combat, the quest chain, and graphical breadcrumbs. The sandboxed editor import completed with a safe-save error during initialization.

## Watchpost Windows playtest

The user completed the watchpost route on Windows. The checks covered navigation and HUD input, all three turn-ins with optional enemies alive, dodging and guarding the Captain’s heavy attack, and progress through defeat and recovery. The route reached 240 XP and level 3. The Iron Sword dealt 12 damage, and the Warden’s Coat granted 2 armor.

## Quest credit and respawn checkpoint

During the previous Break the Blockade playtest, Mara’s offer treated an early Captain defeat as a completed objective. In this checkpoint, kill objectives start at zero and the Captain can return after an early defeat. Regular wolves and raiders return after their configured delay while the Warrior is outside their encounter area. The current placements use a 30-second delay and a 10-meter leash radius. [Issue #1](https://github.com/dylcruz/stonewatch-vale/issues/1), [issue #2](https://github.com/dylcruz/stonewatch-vale/issues/2)

The user reported that wolves killed before quest acceptance stayed defeated. The automated test reproduced this by killing the first road wolf via click-to-attack and waiting at the watchpost, which is inside that wolf’s leash radius. Returning to the green refuge now counts as leaving the encounter for respawns, matching the pursuit rule.

**Automated on Windows with Godot 4.7.2 Standard.** Movement, combat, quest chain, and graphical breadcrumbs passed. The 56 quest assertions include the pre-quest wolf respawn at the refuge, the normal 240 XP route, active-only kill credit, repeated regular defeats, and the Captain’s early defeat and one-time rewards. The quest suite also passed with the Compatibility renderer. The sandboxed runs reported errors writing user data.

**Windows user playtest passed.** The user confirmed the open checks on November 16, 2026.

## Recurring Captain and quest XP checkpoint

The Captain now follows the same exit and timer rules as regular enemies, including after a credited defeat or a completed turn-in. Wolves and raiders award 5 XP per defeat. The Captain awards 15 XP per defeat and the Warden’s Coat on the first defeat. In the watchpost playtest, the three turn-ins award 210 of the 240 XP needed to reach level 3.

**Automated on Windows with Godot 4.7.2 Standard.** Movement, combat, quest chain, and graphical breadcrumbs passed. The quest suite covers XP before acceptance, with the turn-in ready, and after completion, as well as the authored 240 XP route.

**Windows user playtest passed.** The user confirmed the Captain’s return during and after the quest, repeat kill XP, the one-time coat, and the revised quest XP balance.

## Quest journal follow-up

Mara offers Clear Pine Road and Recover the Supplies from the start. The player can accept and turn in either quest first. Break the Blockade unlocks after both turn-ins. [Issue #3](https://github.com/dylcruz/stonewatch-vale/issues/3)

In a fresh Watchpost playtest run, speak to Mara. The opening dialogue shows **Clear Pine Road** and a **View Recover the Supplies** button. Accepting an offer closes the dialogue. Speak to Mara again for the other offer, then open **J** to see both accepted quests.

**Automated on Windows with Godot 4.7.2 Standard.** All five suites passed on the build with the Vale routes and revised XP. The quest suite passed 75 assertions, including both starting offers, independent objectives, both turn-in orders, and HUD tracking. Both offers and the two accepted quests were visible with the Compatibility renderer.

**Windows user playtest passed.**

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

The scripted watchpost run is below the 10–15 minute benchmark. The three existing quest placements are close to Mara. Further pacing work can use the measured runs as a baseline. [Issue #8](https://github.com/dylcruz/stonewatch-vale/issues/8)

To rerun the automated crossing, append `-- --pace` to the `vale_routes_test.gd` command.

### Windows user playtest

The user confirmed all Vale routes playtest items were complete on November 16, 2026. The playtest identified follow-up work for scenery collision and the view beyond walkable terrain. [Issue #20](https://github.com/dylcruz/stonewatch-vale/issues/20), [issue #21](https://github.com/dylcruz/stonewatch-vale/issues/21)

## Starting town checkpoint

A fresh game starts in the town square on the old Watchpost site. The town hall, cottages, and well are graybox placeholders. Two cottages occupy the former campsite and Quarry Gate sites. Pine Road leads east to Pine Meadow. The separate Watchpost developer scene contains the original landmarks, Captain Mara, the wolves and raiders, and the three quests. [Issue #27](https://github.com/dylcruz/stonewatch-vale/issues/27)

**Automated on Windows with Godot 4.7.2 Standard.** Both navigation bakes and all five regression suites passed. The route suite walked around the new cottages and out to Pine Meadow, opened the empty journal and gear panel, and verified town square recovery. The separate Watchpost scene retained both landmarks and passed all 75 quest checks.

**Windows user playtest passed.** The user confirmed the starting town checkpoint on November 16, 2026.

## Compact Watchpost developer scene

The Watchpost developer scene now ends at the arena walls. It keeps the original encounters, campsite, Quarry Gate, and the three quests. The main game loads the larger Vale routes.

**Automated on Windows with Godot 4.7.2 Standard.** Both bakes and all five regression suites passed. The Watchpost bake has 40 polygons, and all 75 quest checks passed. The route suite verified the two closed exits and completed the timed crossing in the main game with the same baked mesh.

- [ ] Open `scenes/watchpost_playtest.tscn` and press **F6**. Walk to the east and north walls, then return to Captain Mara in the square. Press **F5** after stopping the playtest to verify that Pine Meadow and North Road are open from town.

## World map

Press **M** in the main Vale to see the route cells you have entered. Landmarks appear when their area is explored. A fresh run starts with only the town square area revealed. Exploration stays visible while traveling elsewhere in the same run. [Issue #24](https://github.com/dylcruz/stonewatch-vale/issues/24)

**Automated on Windows with Godot 4.7.2 Standard.** All six suites passed. The map suite passed 16 checks covering concealed terrain, different orders, walking into a new area, revisits, and HUD input. The fresh and partially explored views were checked with the Compatibility renderer.

- [ ] Open the map in town, then walk to Heather Rest or Birchwater first. Verify only the traveled area and discovered landmarks are shown. Leave and reopen the map to check that the first area remains visible.
