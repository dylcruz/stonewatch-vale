# Stonewatch Vale implementation plan

## Gameplay direction

Players choose where to explore and level. Offer standalone quests alongside chains with prerequisites for later steps. Keep travel between zones open to players who skip the watchpost quests, and make leveling through quests and combat in other zones viable.

Enemies repopulate encounters and award XP again on defeat. Quest turn-ins provide most of the XP along the watchpost playtest route. Use that route to check pacing, rewards, navigation, and level milestones as other routes are added.

## Completed

The watchpost graybox supports click-to-move, breadcrumbs, combat, death recovery, and all three starter quests. Completing the watchpost quests can bring the player to level 3 and grants the Iron Sword and Warden’s Coat. Windows playtesting accepted movement, combat, and the first two quests. The final quest playtest exposed retroactive Captain kill credit. [Playtest record](playtest.md)

The main game starts in a small town at the original spawn site, with routes into the Vale open from the start. The original Watchpost layout, encounters, and quests are available in the developer scene. Windows user playtesting passed. [Issue #27](https://github.com/dylcruz/stonewatch-vale/issues/27)

## Remaining work

### Quest credit, respawns, and journal

- [ ] Count kill objectives only while their quest is active. Verify that defeating the Raider Captain before accepting Break the Blockade leaves the objective open.
- [ ] Respawn regular enemies and the Captain after a configurable delay once the player leaves the area. Apply the rule to the Captain before, during, and after Break the Blockade.
- [ ] Award XP for every defeat up to the current level cap. Keep the Warden’s Coat one-time and put most of the watchpost quest route’s XP in turn-ins.
- [ ] Let players accept multiple eligible quests before turning any of them in. Show their objectives, progress, and turn-in states independently in the journal and keep a compact tracked objective in the HUD.

### Author and integrate the vale

- [ ] Graybox one continuous outdoor zone, with a road from the fenced watchpost through Pine Road and the abandoned campsite to the broken Quarry Gate. Place the supply cart at the campsite.
- [ ] Add optional meadow, river-crossing, and lookout-ridge routes that loop back to the main road. Define the zone edges with terrain such as cliffs, deep water, or steep ridges.
- [ ] Hand-author terrain, roads, signs, landmarks, vegetation, NPCs, quest objects, and fixed encounter placements. Keep landmarks legible from the gameplay camera and confirm two fresh games use the same layout and placements.
- [ ] Bake navigation for the full zone and verify walkable access to the campsite, quarry, river crossing, lookout ridge, and routes back to the main road.
- [ ] Playtest and tune travel times. Use the watchpost quests as a 10–15 minute pacing benchmark and aim for a full-zone crossing that takes several minutes on foot.
- [ ] Store the player’s Dawnward Compact faction, human race, and Warrior class as independent data.

### Save and resume

- [ ] Add New Game and Continue with one local save slot under `user://`. Continue in the town square.
- [ ] Persist level, XP, active and completed quests, owned and equipped gear, and relevant encounter state using stable IDs.
- [ ] Autosave when quests advance, rewards are granted, or equipment changes. Save kill credit, quest progress, XP, and associated loot together.
- [ ] Restore Captain quest credit and Warden’s Coat ownership on Continue. Verify the encounter still follows the respawn rules after relaunching mid-quest and after a turn-in, including equipment retention.

### Final playtest and delivery

- [ ] Repeat the [watchpost Windows playtest](playtest.md#watchpost-windows-playtest) from a new save in the full zone. Verify both gear upgrades, both responses to the Captain’s heavy attack, all three turn-ins, and level 3 with optional enemies left alive.
- [ ] Update the README for New Game, Continue, and the final zone. Record licenses and attribution for any external assets added.
- [ ] Produce a runnable Windows build and repeat the playtest in it.
