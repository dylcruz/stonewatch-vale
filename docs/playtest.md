# Stonewatch Vale playtest

## Accepted checkpoints

The user confirmed Windows playtesting for click-to-move and held steering, route breadcrumbs, melee, the full wolf encounter, raiders and Cleave, and the Captain’s telegraph. The user also accepted Clear Pine Road and Recover the Supplies. Prior Windows checks found that fixed HUD panels can overlap world labels as the camera follows the Warrior. A Windows executable export is pending matching Godot 4.7.2 templates.

## Automated verification

The consolidated F5 scene passed the launch smoke test. The terrain navigation bake saved 27 polygons. The four retained suites exercise the playable scene and passed 156 assertions across movement, combat, the quest chain, and graphical breadcrumbs. The sandboxed editor import completed with a safe-save error during initialization.

## Current Windows checklist

Press **F5** to launch the watchpost arena.

- [ ] Route around the ruin. Try the disconnected platform, click the HUD, and verify both preserve the active movement command. Check held steering and breadcrumb clearance on arrival.
- [ ] Accept Clear Pine Road, defeat three wolves, and report to Mara. Confirm 100 XP, level 2, 75 max HP, and Cleave. Equip the Iron Sword in **I** and confirm 12 sword damage.
- [ ] Accept Recover the Supplies and collect the marked crate. Return with both guards alive and confirm 155 XP. Try **J** to check active and completed entries.
- [ ] Accept Break the Blockade. Dodge the Captain’s red circle once, then time Guard to halve a heavy hit. Defeat the Captain for 50 XP and the Warden’s Coat. Equip the coat and confirm 2 armor.
- [ ] Turn in the final quest. With optional enemies alive, confirm 240 XP, level 3, and 90 max HP. Check that death recovery retains progress during the run and reopening dialogue leaves XP and gear unchanged.

## Quest and world follow-up

**Reported during the Break the Blockade playtest.** The player defeated the Captain before accepting his quest. Mara’s later offer treated the objective as already satisfied. The game currently records kill counts for future quests, then uses those counts on acceptance. Enemies stay defeated for the run, and Mara advances a single quest at a time.

- [ ] **Active-only kill credit.** Defeat the Captain before accepting Break the Blockade. After accepting, verify the objective still requires a kill. Defeat the Captain while it is active and verify credit advances the objective once. Apply the same timing rule to other kill objectives.
- [ ] **Timed enemy respawns.** Give regular enemies a configurable respawn delay and let them return after the player leaves the area. Let the Captain return after a pre-quest defeat so the quest remains completable. Verify the Captain’s kill XP and Warden’s Coat are each awarded once even across encounters.
- [ ] **Concurrent quests.** Let the player accept two eligible quests before either is turned in. Track their progress and turn-ins independently. Verify the quest log shows both and that completing one preserves the other’s state.
