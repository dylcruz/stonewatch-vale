# Combat checkpoint 1: first melee

Status: **user playtest completed successfully**. This is the first slice of implementation phase 2, **Build a complete fight**, using Godot **4.7.2 Standard**, `4.7.2.stable.official.ed1daf0bf`.

## Scope and tuning

F5 opens `scenes/combat_demo.tscn`. Click the gray wolf to approach and auto-attack. The wolf retaliates once the Warrior starts a melee swing; it stays at its authored position in this checkpoint. Ground commands cancel selection and any pending sword hit. Walking out of range during a bite avoids damage. HUD clicks continue to be consumed by the HUD.

| Actor | HP | Damage | Reach | Windup | Attack interval |
| --- | --- | --- | --- | --- | --- |
| Warrior | 60 | 8 | 1.8 m | 0.3 s | 1.1 s |
| Road wolf | 40 | 6 | 1.9 m | 0.5 s | 1.6 s |

Health bars, target selection, weapon/head animation, body flashes, and last-hit text provide feedback. A defeated actor stops fighting. The wolf's body remains visible but stops accepting target clicks. **R** or **Reset fight** restores both actors' starting health, positions, and state.

Guard, proximity aggro, pursuing enemies, leash/return, watchpost respawn, raiders, Cleave, boss attacks, rewards, and saving are not implemented in this checkpoint. The next step is Guard and the full wolf encounter, after feedback on this first slice.

## Automated verification

- [x] Windows headless editor import and main-scene smoke test complete without errors.
- [x] `tests/combat_test.gd`: **31 assertions, zero failures**, exit code 0. Uses the real scene, physics ray picking, saved navigation, actors, health, and viewport input; no physics or combat mocks.
- [x] Ground-click approach, target ring, windup before damage, exact sword/bite damage, natural wolf defeat, and Warrior survival at the initial tuning.
- [x] HUD input preserves combat targeting and movement.
- [x] Ground cancellation during windup prevents a delayed sword hit and allows walking away.
- [x] Sword and bite both reject a hit if the victim leaves range before impact; scenery blocks melee.
- [x] Fatal bite, health clamping, one death signal, disabled commands after death, and no attacks against a defeated Warrior.
- [x] R resets health, positions, cooldowns, selection, opponent state, and wolf picking.
- [x] All **31 accepted movement assertions** continue to pass in the original movement scene.
- [x] `git diff --check` passes.

## Windows visual verification

- [x] F5 launches the combat scene at 1280 × 800 using OpenGL Compatibility on the AMD Radeon RX 9070 XT.
- [x] Warrior/sword and wolf silhouettes, target ring, readable HP bars, windup/recovery text, hit flashes, and hit messages render correctly during an injected-mouse fight.
- [x] The default fight ends with the wolf defeated and the Warrior alive at 42 / 60 HP. Selection clears, the corpse remains, and the HUD reports defeat.
- [x] Clicking Reset fight restores both actors, clears the fight state, and restores 60 / 60 and 40 / 40 HP.

The fixed HUD can still overlap world scenery/labels as the camera follows, as recorded in the movement playtest. The user confirmed the combat playtest completed successfully.

## User playtest

1. Press **F5**, click the wolf once, and let the fight finish. Confirm approach, facing, sword and bite timing, HP loss, and the wolf's defeat are clear.
2. Press **R**. Start a fight, then click clear ground during a sword windup. Confirm selection clears and the pending sword hit is cancelled. Try holding LMB to leave the fight too.
3. Reset and repeat. Click away during a wolf bite windup; confirm moving beyond its reach avoids the bite. The wolf stays at its spawn for now.
4. While fighting, click **Test UI · keep command** and confirm the target stays selected. Confirm HUD clicks do not pass through to the world.
5. To test Warrior death, begin fighting, then click the ground at the Warrior's feet to cancel auto-attacking while remaining beside the wolf. Let it keep biting. Confirm zero HP stops the Warrior, then **R** or **Reset fight** starts a clean encounter.

- [x] User confirms the first melee checkpoint completed successfully. The requested follow-up is an always-visible breadcrumb route preview before proceeding to Guard/aggro/leash work.

The movement motor and saved navigation remain shared with the movement regression scene. The breadcrumb follow-up adds a route display to both scenes. No Windows export was made; matching export templates are still unavailable.
