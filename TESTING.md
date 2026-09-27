# Redesign verification

Testing uses the existing Godot 4.7.2 editor and matching Web, Linux, and Windows templates.

## Automated simulation

`tests/smoke.gd` runs first with `-- --smoke-test --prototype` (three stones), then `-- --smoke-test` (nine stones). Normal player saves are disabled; a separate temporary save is used for persistence checks.

Verified:

- More than one full great-circle walk in two directions, over poles and the underside; feet remain on the radius function and the camera/frame remain finite and orthogonal. Camera sightlines shorten before intersecting neighboring stones.
- At least two starting-range destinations per asteroid.
- Assisted landing between all three prototype stones.
- Clear hop trajectories on every directed field edge from all six cardinal surface normals, sampling each trajectory against every asteroid.
- Invalid destination returns exactly to the departure position.
- Every resource can be reached using real tangent movement; repeat collection cannot duplicate rewards.
- Fins deduct their cost once and extend range; scanner reveals remaining quantities; component installation caps at three.
- Touch press/release changes movement input correctly.
- Inventory, unique components, installed parts, collected IDs, and music preference survive a save round trip.
- The music asset imports as a forward loop.

## Browser playtest

Run a server from the repository root and:

```sh
npm install --prefix /tmp/prospector-browser playwright
NODE_PATH=/tmp/prospector-browser/node_modules node tools/browser-check.cjs
```

The test uses Chromium with software WebGL, first the prototype, then the expanded field. It asserts game state rather than merely dispatching input. The full browser suite passed with no browser errors. Screenshots are written to `/tmp/prospector-*.png` for visual inspection. The `?test` URL exposes read-only diagnostics.

Coverage: gesture-gated music start, keyboard collection, a sustained circuit, selection/hops, workshop open/close, browser-persisted gold and music setting after reload, nine-stone rendering, and emulated simultaneous touch movement plus a touch hop. Landscape touch viewport: 844 × 390.

## Exports and limitations

Web, Linux x86-64, and Windows x86-64 exports are built locally using the retained presets. Linux is also launched headlessly (120 frames, exit code 0). Both desktop ZIPs are rebuilt and pass archive-integrity checks. Windows is cross-exported, not executed on Windows. GitHub Actions and Pages deployment configuration are preserved; a local export does not verify a new public deployment.

Still requires real-device testing:

- iOS Safari and Android Chrome: sustained frame rate, temperature/memory use, finger comfort, browser chrome, rotation, background/resume, and audio unlock behavior.
- Real speakers/headphones: perceived mix, loop seam, and music comfort over a longer session. Automated checks verify playback state, not perceived sound quality.
- Linux desktop hardware acceleration and Windows runtime/input/audio.
- Long human play sessions to assess navigation comfort, resource visibility, and upgrade pacing. Automated paths cannot establish subjective feel.

Browser storage remains subject to private-mode/site-data restrictions. The test browser is not a substitute for mobile GPU performance measurements.
