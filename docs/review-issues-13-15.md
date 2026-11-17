# Final Windows playtest and export review

[Issues #13 and #15](https://github.com/dylcruz/stonewatch-vale/issues/13) require a release candidate that contains the starter quests and a clean-save entry flow. The baseline already opens in town. Its complete quest route runs in the separate developer scene. The [playtest record](playtest.md#windows-release-verification-baseline) has the graphical Watchpost results and the current `dev` executable smoke test.

The final release world still needs a decision about where the starter quest giver, campsite, Quarry Gate, and corresponding encounters should live. The save and inventory branches also both change quest rewards and equipment. When combining them, capture the equipped bag, stored items, and waiting rewards in the same snapshot as progression. The map branch retains exploration during a run. If discovery should carry through Continue, include its revealed cells in the integrated checkpoint.

After those decisions and the feature review, run this checklist against a single candidate commit and its matching CI export.

- [ ] Start from a fresh slot, leave town, and find the quest route without clearing optional encounters.
- [ ] Accept both opening quests, find the road wolves and campsite crate, and complete all three turn-ins.
- [ ] Equip the Iron Sword and Warden's Coat, check their effective stats, and reach level 3 on the required route.
- [ ] Avoid the Captain's heavy attack once by moving and once by using Guard. Check quest and gear retention after Continue.
- [ ] Copy the final x86_64 export into a clean directory. Repeat the same checklist in the executable and record the tested commit, artifact URL or local path, and outcomes.
