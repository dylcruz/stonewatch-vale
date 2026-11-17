# Vale routes and starting-town review

[Issues #4–7](https://github.com/dylcruz/stonewatch-vale/issues/4) and [#27](https://github.com/dylcruz/stonewatch-vale/issues/27) are already integrated through PRs #25 and #28. The [playtest record](playtest.md) records Windows acceptance. The main game opens in town and connects to North Road and all three optional loops. The campsite, Quarry Gate, supply crate, and starter chain now live in the compact Watchpost developer scene.

On Windows with Godot 4.7.2, all five regression suites passed. The timed route suite passed 36 checks, including both directions through the stepped crossings and the climb to Signal Ridge. Heather Rest to the Signal Ridge lookout via North Road took 124.6 seconds of simulation time for 613.9 meters of navigation.

For [#8](https://github.com/dylcruz/stonewatch-vale/issues/8), the prior scripted starter chain took 42.1 seconds through the third turn-in. The 10–15 minute benchmark still needs a fresh human timing and a location decision. Where should the starter quests live in the release world now that the main game begins in town and the Watchpost chain is a compact developer fixture? That determines which placements to tune for this benchmark.
