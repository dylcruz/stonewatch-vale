# Click-to-move milestone verification

Initially verified on 2026-11-15 in Linux/WSL; automated checks and Windows visual verification repeated on 2026-11-16 using Godot **4.7.2 Standard**, `4.7.2.stable.official.ed1daf0bf`. Automated checks use the real scene, physics collision queries, navigation server, character motor, and viewport input dispatch. No navigation or physics mocks are used.

## Completed checks

- [x] Bake navigation from the authored collision layout and save it in the editable arena scene (35 polygons).
- [x] Dispatch a left mouse click through the viewport and accept the ray-picked ground destination.
- [x] Route around the central ruin, reach the opposite side, and stop without arrival jitter.
- [x] Reject clicks on a disconnected platform, void, and the top of the ruin; retain the active command.
- [x] Dispatch a click to the HUD button; the button receives it and the movement destination stays unchanged.
- [x] Select the practice target across the ruin and show its selection ring.
- [x] Cancel target pursuit with a ground click and clear the selection ring.
- [x] Select the target again and stop within interaction range, on walkable ground.
- [x] Expire the short-lived destination marker.
- [x] Hold LMB and move the cursor to replace the destination and cancel target pursuit.
- [x] Preserve the last valid destination over unreachable ground and the HUD while holding.
- [x] Release over the HUD, then move the cursor without changing the last destination; finish walking there.
- [x] Keep presses that begin on the HUD from starting cursor following.
- [x] Settle when holding at the player's feet; end cursor following when the window loses focus.
- [x] Launch the configured main scene headlessly without script/runtime errors.

`tests/movement_test.gd` completed **31 assertions with zero failures**. The navigation bake also completed without warnings after matching the mesh and map cell dimensions. `git diff --check` passed.

## Windows verification (2026-11-16)

Located the installed Windows binaries at:

```text
C:\Users\Dylan\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe
C:\Users\Dylan\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe
```

- [x] Confirm the executable version matches `4.7.2.stable.official.ed1daf0bf`.
- [x] Run the README's headless editor import successfully on Windows.
- [x] Run `tests/movement_test.gd`: **31 assertions, zero failures**, exit code 0, without engine warnings or errors in the unrestricted run.
- [x] Open the Windows editor and press F5. The configured main scene renders using OpenGL 3.3 Compatibility on an AMD Radeon RX 9070 XT. The editor reports zero errors and zero warnings after stopping with F8.
- [x] Inspect the fixed camera angle, blue player silhouette, gold facing cue, HUD, world labels, and gold destination marker at 1280 × 800. Inspect resized game viewports at 1024 × 640 and 1644 × 1002; see the label-overlap finding below.
- [x] Use Windows computer-use mouse input to route past the central ruin, observe arrival, select the practice target and its persistent gold ring, observe the in-range status, clear selection with a ground command, and receive the HUD button's input confirmation.
- [x] Smoke-test world drags ending over the HUD and HUD-origin drags with injected Windows input. The player finishes a ground destination; a HUD-origin drag leaves the player in place. Detailed held-input timing, destination preservation, and release behavior also pass in the automated suite.
- [x] Dispatch three replacement ground clicks on consecutive physics frames in a graphical run of the real scene. The final destination is approximately `(7, 0.2, 3)`, matching the last click. Capture the marker before its normal timeout and confirm it subsequently expires.
- [x] Run `git diff --check` successfully.

The embedded F5 runner initially used **Fixed Size**, so maximizing its container alone kept the game at 1280 × 800. Selecting **Stretch to Fit** produced a 1644 × 1002 game viewport. A local diagnostic script also resized the actual game viewport and captured the brief marker without changing gameplay scripts or its lifetime.

Local diagnostic artifacts are in the ignored `builds/playtest/` directory:

- `visual_capture.gd` and `visual-capture.log`
- `default-1280x800.png`
- `destination-marker-1280x800.png`
- `destination-marker-1024x640.png`
- `destination-marker-1644x1002.png`

**Visual finding:** the HUD text, player, and destination ring remain legible at all three inspected sizes. World labels are small at 1024 × 640. Because the HUD stays fixed while the camera follows the player, the practice-target and ruin labels can pass behind the translucent HUD and overlap its text; this was observed during movement and in the smaller capture. Full label legibility across all player positions is therefore not a clean pass. No gameplay changes were made during this verification.

## Physical-mouse acceptance (2026-11-16)

- [x] The user confirmed physical-mouse testing is complete and movement works as expected, covering the remaining native-input playtest.
- [x] Confirm that clicks do not pass through the HUD. This is intentional: the entire HUD panel consumes mouse input, preserving the active movement command. A press begun on the HUD cannot start cursor following.

The source-project movement playtest is **complete and accepted**. No further movement tests are required for this milestone. The label-overlap finding above remains a recorded visual caveat.

## Future exported-build check

- [ ] Export and repeat the checks in a Windows executable once matching export templates are installed. `C:\Users\Dylan\AppData\Roaming\Godot\export_templates` is empty, and no matching template archive was found in Downloads. No Windows export was produced.

The earlier graphical Linux launch failed because WSL lacked a working OpenGL/EGL driver stack. Windows editor rendering and physical-mouse behavior are now verified as described above. Exported-build validation remains a separate future check when a Windows build is produced.

## Breadcrumb route follow-up

After accepting the first combat checkpoint, the user requested a breadcrumb preview of the character's route, enabled by default. Both demo scenes now show gold dots along the remaining navigation path. Dots stay anchored to the route and disappear as the player passes them; arrival, entering melee, death, and reset clear the display. Replacing a destination or steering with held LMB updates the preview. Rejected destinations and HUD input preserve the active route.

`PathBreadcrumbs.enabled` defaults to true and can support a future player-facing visibility setting; no settings menu was added in this step. Rendering does not modify the movement command or navigation bake.

- [x] `tests/breadcrumb_test.gd`: **21 assertions, zero failures**, using the Windows Compatibility renderer. Includes actual MultiMesh transform checks for obstacle routing and endpoints, progress, replacement, rejected destinations, HUD input, visibility, arrival, combat approach, death, and reset.
- [x] All **31 movement assertions** and **31 combat assertions** still pass.
- [x] Visually inspect a captured 1280 × 800 route: clear gold dots follow the walkable route around the ruin to the destination. Local screenshot: `builds/playtest/breadcrumb-route.png` (ignored).
- [ ] User checks breadcrumb visibility and spacing during click movement and held steering in the combat scene.

Run breadcrumb checks **without `--headless`**: the headless rendering server does not retain the instance transforms these visual checks inspect. The normal movement and combat suites remain headless-compatible.

## Scope

This is implementation step 1, **Prove movement first**. The practice target demonstrates selection and navigation approach only. Combat, auto-attacks, NPC interaction, New Game/Continue, quests, and the authored full zone belong to subsequent milestones. The full-prototype definition of done remains open.
