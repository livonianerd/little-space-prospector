# Little Space Prospector

A peaceful **3D asteroid garden**, built with Godot 4.7.2 and the Compatibility renderer. Walk around little worlds, follow imperfect clues, find three ship components, and bring resources home to improve your spaceship. No enemies, death, timers, or game over.

The existing GitHub Pages address is **https://livonianerd.github.io/little-space-prospector/**. Local changes appear there after they are pushed and the existing Pages workflow succeeds.

## Play

- **WASD / arrows:** walk in four directions across the entire curved surface, including underneath.
- **Tap a destination / E / Tab:** choose a reachable asteroid. Named rings identify nearby stones; the selected ring is gold. Clues suggest contents without revealing exact quantities.
- **Space / Jetpack:** take an assisted hop to the selected destination. The jetpack plans an arc around rocks; a blocked/missed hop returns safely to its departure point. There is no fuel limit.
- **R / Home:** return to Hearth with everything collected.
- **B / Ship:** open the workshop while at Hearth. Install components or buy upgrades.
- **Escape:** close the workshop.
- **Music On/Off:** toggle the original ambient loop. The setting is saved. Web audio starts only after a key, click, or touch.
- **Touch:** hold directional pads (two fingers can move diagonally), tap a destination, and tap Jetpack. Landscape is recommended.

Gold nuggets, crystals, crates, and rare starbells sit directly on asteroid surfaces. Walk close to collect them. One asteroid is empty. Nine stones have different radii, softly irregular shapes, colors, heights, spacing, and resource concentrations. Each offers at least two destinations at the starting hop range. The ship components are on Honey drift, Copper orchard, and Rose lantern; their exact positions require exploration.

Golden fins cost **6 gold** and add **4m hop reach**. A crystal window costs **3 crystals**, adds a visible scanner antenna, and reports remaining resources on a selected destination. Garden lights cost **8 gold + 2 crystals** and decorate the landing pad. Each of the three installed components visibly builds the ship and adds **0.6m reach**. Resources do not respawn; the field contains enough to complete all upgrades.

Progress saves after collections and purchases. Returning/reloading starts at Hearth, retaining inventory, discoveries, ship upgrades, and music preference. Existing version-one inventories, components, and upgrades are migrated; the new field has fresh resource IDs. Browser saves use site storage; desktop saves use Godot's `user://prospector.json`. Clearing browser storage clears web progress.

## Run and export

Open `project.godot` in **Godot 4.7.2 stable**, or install the pinned editor/templates with `bash tools/install-godot.sh` (Linux; curl/unzip required).

```sh
.tools/godot --path .
# The original three-stone prototype is retained for focused playtesting:
.tools/godot --path . -- --prototype

.tools/godot --headless --editor --path . --import --quit
.tools/godot --headless --path . --script tests/smoke.gd -- --smoke-test --prototype
.tools/godot --headless --path . --script tests/smoke.gd -- --smoke-test
mkdir -p build/web build/linux build/windows
.tools/godot --headless --path . --export-release Web build/web/index.html
.tools/godot --headless --path . --export-release Linux build/linux/little-space-prospector.x86_64
.tools/godot --headless --path . --export-release Windows build/windows/little-space-prospector.exe
python3 -m http.server 8000
```

Open `http://localhost:8000/build/web/`. Append `?prototype` for the three-stone cluster. WebGL 2 is required. Web exports remain single-threaded and work under a GitHub repository subpath without cross-origin isolation headers.

The existing `.github/workflows/web.yml`, `linux.yml`, and `windows.yml` retain Pages deployment and Linux/Windows export artifacts. Linux requires x86-64/OpenGL 3.3; keep the executable and `.pck` together. Windows requires 64-bit Windows/OpenGL 3.3; keep the `.exe` and `.pck` together. Windows binaries are unsigned. Pushing a `v*` tag retains the existing release packaging behavior.

## Implementation and checks

All 3D artwork is procedural and original. Movement parallel-transports an orthonormal tangent frame around the surface; it does not rely on world-up look-at calculations or unstable spherical character-body physics. The camera follows that frame, so the terrain rotates under the astronaut. The same radius function positions the mesh, feet, and resources. Hop arcs are sampled against every asteroid before departure.

The original 32-second score and four cues are in `assets/`. `python3 tools/generate-audio.py` reproduces them with only Python's standard library. Reverb wraps around the loop boundary. Low-poly meshes, a batched starfield, one light, no shadows, and no post-processing keep rendering modest.

See [TESTING.md](TESTING.md) for verification and remaining real-device coverage. The browser test uses Playwright; `?test` exposes read-only state for assertions and is not needed during normal play.
