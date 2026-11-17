# Watchpost quest issue review

The active-only kill credit, encounter respawns, and concurrent journal changes are already integrated into `dev` through PRs #17 and #26. The [playtest record](playtest.md) records Windows acceptance for these checkpoints.

- [#1](https://github.com/dylcruz/stonewatch-vale/issues/1) covers an early Captain defeat, his return, and active-only kill credit. The accepted recurring Captain playtest superseded the original one-time XP criterion. The coat is awarded once and each defeat grants XP up to the level cap.
- [#2](https://github.com/dylcruz/stonewatch-vale/issues/2) covers the respawn delay, exit requirement, and repeated defeats. The refuge counts as leaving a wolf's encounter, matching the pursuit rule.
- [#3](https://github.com/dylcruz/stonewatch-vale/issues/3) covers concurrent acceptance, independent progress, both turn-in orders, and tracking one quest in the HUD.

The Windows Godot 4.7.2 quest regression suite exercises all three issues, including the current repeat XP rule. The original encounters are available in `scenes/watchpost_playtest.tscn` via **F6**.
