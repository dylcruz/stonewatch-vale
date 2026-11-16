# Stonewatch Vale implementation plan

## Brief for the implementation chat

Build a playable single-player 3D action RPG prototype called **Stonewatch Vale**. The player is a human Warrior of the Dawnward Compact. Use a fixed, angled top-down camera and mouse-driven movement and targeting. The player should be able to start fresh, complete a three-quest chain, fight two kinds of enemies and a boss, reach level 3, equip meaningful upgrades, and resume progress after restarting.

The larger game is a single-player RPG with expansive, hand-authored leveling zones in the style of World of Warcraft and Final Fantasy XIV. Each zone has its own landmarks, settlements, routes, quests, and monsters. The game will eventually have two factions, multiple distinct races per faction, and shared classes across factions and races. Warrior and Mage are the starting class concepts. This build contains one faction, one race, one class, and one zone. Story names, tuning values, and the visual direction below are proposed defaults. Tune them through playtesting while preserving the quest route and progression milestones.

## Stack and delivery

- Use stable Godot 4 Standard with GDScript, the Compatibility renderer, and a Windows desktop target. Record the exact editor version used in the README. Windows mouse and keyboard are the launch controls.
- Use Godot scenes and reusable scripts with simple stylized 3D assets. Favor clear silhouettes, a legible stone road, simple attack animations, and obvious enemy telegraphs. Blender is optional for creating or refining assets. Import any external models as `.glb` files and record their licenses and attribution.
- Deliver the Godot source project with the editable Stonewatch Vale scenes, a README with launch instructions and controls, and a completed playtest checklist. Deliver a runnable Windows build if matching export templates are available. The source project should open and run with F5 after import.
- The prototype is local and single-player. Leave online services, multiplayer, a character creator, additional zones and classes, crafting, vendors, and randomized loot tables for later iterations. Web export is a possible later delivery target.

## The first 10–15 minutes

The Dawnward Compact holds a small watchpost at the edge of a pine valley. Wolves have spread onto the road, and raiders have cut off a supply party at the old quarry. Captain Mara sends the player out from the watchpost and runs each quest turn-in.

**Starter quest locations in order** · Watchpost → Pine Road → Abandoned Campsite → Quarry Gate. Return to the watchpost after each objective.

| Quest | Objective | Reward and teaching goal |
| --- | --- | --- |
| 1. Clear Pine Road | Leave the watchpost, defeat 3 road wolves, and report to Captain Mara. | 55 quest XP and an Iron Sword. Teaches click movement, targeting, health, leveling, and how to equip a weapon. |
| 2. Recover the Supplies | Follow the road to the campsite, interact with the marked supply crate, and return to Mara. Raiders guard the camp. | 55 quest XP. Gives the player an opportunity to try Cleave against clustered enemies, with crate interaction as the required objective. |
| 3. Break the Blockade | Enter the quarry, defeat the Raider Captain, and return to Mara. | The captain grants 50 kill XP and a Warden's Coat once. Turn-in grants 35 quest XP and completes the prototype. The captain tests movement and Guard. |

Place enough wolves to finish quest 1 in one pass. Give regular enemies 15 XP per kill. Set cumulative XP thresholds at 100 for level 2 and 240 for level 3. Three wolves and the first turn-in reach level 2. All three quests and the required kills reach level 3, even if the player skips regular raiders. Cap the prototype at level 3. The level 2 increase should be visible in max HP and unlock Cleave. Make both gear rewards visible upgrades to the starting sword and coat. For initial tuning, use +4 weapon damage for the sword upgrade and +2 armor for the coat upgrade.

## World layout and zone authoring

Build Stonewatch Vale as one large, continuous, explorable outdoor zone. Hand-author the terrain, roads, landmarks, vegetation, NPCs, quest objects, and enemy spawn points in saved Godot scenes. Every new game loads the same map with the same NPCs, quest locations, and encounter placements. Player progress determines quest availability, rewards, and the state of defeated quest enemies in each save.

Keep the 10–15 minute starter chain in one portion of the vale. Beyond it, give players room to roam through open meadows, across a river crossing, and up to a lookout ridge. Use branching paths and a loop back to the main road so players can explore and rejoin the quest route naturally. As a starting point for the graybox, aim for an on-foot crossing of several minutes across the full zone and tune it in playtests. The optional terrain should be walkable and recognizable from the gameplay camera. The three existing quests supply the starter area's content, and the surrounding areas can be built with simple terrain, recognizable landmarks, and a few fixed encounters.

Use the main road, signs, and distinct landmarks to guide players from the fenced watchpost to the abandoned supply cart and the broken quarry gate. Define the zone's outer edges with believable terrain, such as cliffs, deep water, or steep ridges. Bake the navigation mesh against the authored collision layout, including the optional routes, and save it with the zone scenes.

## Controls and combat

- **Left-click ground** to move. Draw a short-lived destination marker and route the player around obstacles on the navigation mesh. Ignore a click that produces no valid destination and keep the character on walkable terrain.
- **Left-click an enemy** to select it, move toward it, and begin basic melee swings once in range. A ground click cancels pursuit and auto-attacks. Melee hits require range when they resolve. Clicking an NPC or quest object moves within interaction range and opens dialogue or performs the interaction. UI clicks are consumed by the UI.
- **1 — Cleave.** Unlock at level 2. Hit nearby enemies in front of the Warrior and show a short cooldown. **2 — Guard.** Available from the start. Briefly reduce incoming damage and show active and cooldown states. Give both abilities readable feedback and expose their key bindings in the HUD.
- **I — Gear.** Open a small panel showing owned items, the equipped weapon and armor, and their effects on attack and defense. Equip rewards explicitly. **J — Quest log.** Show the current objective, progress, and turn-in state. Give the player a compact active objective in the HUD as well.
- Wolves use a short-range bite. Regular raiders use a slower melee swing. Both can aggro, pursue, attack, and return to their spawn area if the player leaves their leash range. Regular enemies may respawn after a delay once the player has left the area. The watchpost stays safe.
- The Raider Captain adds a clearly telegraphed heavy attack that can be avoided by clicking away or mitigated by timing Guard. Present health, target selection, hit reactions, ability cooldowns, quest updates, XP, and gear rewards clearly. On death, return the player to the watchpost at full HP and retain earned progress.

## Implementation sequence

1. **Prove movement first.** Make a graybox scene with a following camera, a clickable floor, an obstacle, and the player. Use camera ray picking and Godot 3D navigation. Confirm that the player routes around the obstacle, stops reliably, and can select a target without moving through scenery. Use a stable camera angle and distance so targeting stays predictable.
2. **Build a complete fight.** Add the Warrior, one wolf, melee range and attack timing, health and death, Guard, enemy aggro and leash, and basic feedback. Use this scene to tune the first fight before adding content. Then add the raider, Cleave, and boss telegraph.
3. **Finish one quest end to end.** Implement accept, progress, ready to turn in, and completed states. Award XP and the Iron Sword once, expose equipping and updated stats, and prove the level 2 unlock through the normal quest route. Then wire the crate quest and boss quest through the same quest system.
4. **Author and integrate the zone.** Graybox the full vale in the editor, including the starter route and the optional paths beyond it. Playtest travel times and how players find their way from the gameplay camera. Place the terrain details, NPCs, objectives, and combat encounters in the saved scenes. Bake navigation and verify the campsite and quarry entrances, the optional routes, and their connections back to the main road.
5. **Save, playtest, and package.** Provide New Game and Continue with one local save slot. Store level/XP, active and completed quest state, earned gear, and equipment under `user://`. Autosave when quests advance, rewards are granted, or equipment changes. Continue at the watchpost. Resolve kill credit, quest progress, XP, and any associated item together before saving that event so reloading cannot split or duplicate the reward. Treat a defeated quest boss as defeated on reload after its credit is saved. Run the checklist below and document how to launch the project and edit the zone.

Keep movement and combat code reusable. Store enemy stats, item stats, quest definitions, and the player identity in simple Godot Resources or equivalent project data. Use stable IDs in saves. Keep faction, race, and class independent so a future class can be shared across playable races. Per-zone spawn positions and anchors belong to the zone. A small amount of shared code and data is sufficient for this build.

## Definition of done

- [ ] The project opens in the documented Godot version and launches into a usable New Game flow. Run the checklist on the Windows build too if one is produced.
- [ ] A ground click routes around a blocking object. Clicking an unreachable destination leaves the player on walkable ground. A ground click cancels pursuit, and clicking the HUD leaves the current movement command alone.
- [ ] From a fresh save, accept the first quest, defeat three wolves, return to Mara, reach level 2, equip the Iron Sword, and confirm the increased damage and the Cleave unlock. Reopening dialogue cannot grant the reward again.
- [ ] Complete the supply and boss quests. Escape the captain's heavy attack once and mitigate it once with Guard. Equip the Warden's Coat and see the armor increase. End at level 3 with the final quest complete, including on a run that skips optional enemy kills.
- [ ] Die during a fight and respawn at the safe watchpost with earned progress. Quit and relaunch mid-quest and after boss defeat. Confirm progress and equipped gear persist and boss credit and gear cannot be earned again.
- [ ] Compare two fresh games. The terrain, landmarks, NPCs, quest objects, and enemy spawn points match.
- [ ] Play the main quest route and check that the chain fits the proposed 10–15 minute window. On a separate pass, walk an optional route through a distinct part of the vale and loop back to the main road. Verify that both routes and their crossings are reachable on foot within the continuous zone.
- [ ] The README records the engine version, run and export steps, controls, the editable zone scene locations and navigation bake steps, asset credits as applicable, and any checks the implementation environment could not run.

## Engine references

- [Godot 3D navigation](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_introduction_3d.html)
- [Godot 3D scene formats](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html)
- [Godot persistent file paths](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html)
- [Godot web export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)
